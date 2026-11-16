"""Unit tests for services.subscription_service_parts.lifecycle.SubscriptionLifecycleMixin.

Drives the real ``subscription_service`` singleton against the in-memory DB.
The default internal provider covers the simple upgrade/admin paths; a
configurable fake provider injected via ``_payment_provider_factory`` drives the
external-provider error branches (cancel / activate / refund / billing portal).
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentProviderActionRequiredError,
    PaymentProviderError,
    PaymentProviderUnavailableError,
    PortalSessionResult,
    RefundResult,
)
from services.subscription_service import subscription_service

# ---------------------------------------------------------------------------
# Fake external provider
# ---------------------------------------------------------------------------


class FakeProvider:
    provider_key = "stripe"
    is_external = True

    def __init__(self, *, raise_on=None, error=None, owner_id=None, plan_id=PLAN_PREMIUM):
        self.raise_on = raise_on or set()
        self.error = error or PaymentProviderError("boom")
        # Metadata Stripe echoes back for the session (set by us at creation).
        self.metadata = (
            {"user_id": str(owner_id), "plan_id": plan_id} if owner_id is not None else {}
        )

    def _maybe_raise(self, method):
        if method in self.raise_on:
            raise self.error

    def cancel_subscription(self, *, subscription_id):
        self._maybe_raise("cancel")
        return {"id": subscription_id, "status": "canceled"}

    def retrieve_checkout_session(self, *, session_id):
        self._maybe_raise("retrieve")
        return CheckoutSessionResult(
            provider="stripe",
            session_id=session_id,
            checkout_url="https://x",
            status="complete",
            payment_status="paid",
            customer_id="cus_x",
            subscription_id="sub_x",
            payment_intent_id="pi_x",
            raw={},
            metadata=dict(self.metadata),
        )

    def refund_payment(self, *, payment_intent_id, charge_id, amount_cents, reason, metadata):
        self._maybe_raise("refund")
        return RefundResult(
            provider="stripe",
            refund_id="re_x",
            status="succeeded",
            amount_cents=amount_cents or 1000,
            currency="usd",
            payment_intent_id=payment_intent_id,
            charge_id=charge_id,
            raw={},
        )

    def create_billing_portal_session(self, *, customer_id, metadata):
        self._maybe_raise("portal")
        return PortalSessionResult(
            provider="stripe",
            session_id="bps_x",
            url="https://billing",
            customer_id=customer_id,
            raw={},
        )

    def list_payment_methods(self, *, customer_id):
        return []


@pytest.fixture
def use_provider(monkeypatch):
    def _use(provider):
        monkeypatch.setattr(subscription_service, "_payment_provider_factory", lambda: provider)

    return _use


def _select_payload(plan, *, session_id=None, billing_interval="monthly"):
    return SimpleNamespace(
        resolved_plan=plan, session_id=session_id, billing_interval=billing_interval
    )


# ---------------------------------------------------------------------------
# admin_override_subscription (internal provider)
# ---------------------------------------------------------------------------


def test_service_has_no_parent_direct_grant():
    # Paid plans must only come from a verified checkout; the old parent-facing
    # upgrade_subscription shortcut must not come back.
    assert not hasattr(subscription_service, "upgrade_subscription")


def test_admin_override_to_free(db, create_parent):
    parent = create_parent(email="ao-free@example.com", plan=PLAN_PREMIUM)
    result = subscription_service.admin_override_subscription(
        db=db, user=parent, plan=PLAN_FREE, source="admin"
    )
    assert result["current_plan_id"] == PLAN_FREE


def test_admin_override_to_premium(db, create_parent):
    parent = create_parent(email="ao-prem@example.com", plan=PLAN_FREE)
    result = subscription_service.admin_override_subscription(
        db=db, user=parent, plan=PLAN_PREMIUM, source="admin"
    )
    assert result["current_plan_id"] == PLAN_PREMIUM


def test_admin_override_to_premium_in_production(db, create_parent, monkeypatch):
    """Internal admin grant must not generate a mock checkout id in production.

    Regression: admin dashboard upgrade (free -> premium) raised
    ``RuntimeError: Mock checkout session ids are not allowed in production``.
    """
    from core.settings import settings

    monkeypatch.setattr(type(settings), "is_production", property(lambda self: True))
    assert settings.is_production is True

    parent = create_parent(email="ao-prem-prod@example.com", plan=PLAN_FREE)
    result = subscription_service.admin_override_subscription(
        db=db, user=parent, plan=PLAN_PREMIUM, source="admin"
    )
    assert result["current_plan_id"] == PLAN_PREMIUM


# ---------------------------------------------------------------------------
# cancel_subscription
# ---------------------------------------------------------------------------


def test_cancel_internal_sets_free(db, create_parent):
    parent = create_parent(email="cancel-internal@example.com", plan=PLAN_PREMIUM)
    result = subscription_service.cancel_subscription(db=db, user=parent)
    assert result["current_plan_id"] == PLAN_FREE


def test_cancel_external_provider_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="cancel-503@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.provider_subscription_id = "sub_cancel"
    db.add(profile)
    db.commit()

    use_provider(FakeProvider(raise_on={"cancel"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.cancel_subscription(db=db, user=parent)
    assert exc.value.status_code == 503


def test_cancel_external_provider_error(db, create_parent, use_provider):
    parent = create_parent(email="cancel-502@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.provider_subscription_id = "sub_cancel2"
    db.add(profile)
    db.commit()

    use_provider(FakeProvider(raise_on={"cancel"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.cancel_subscription(db=db, user=parent)
    assert exc.value.status_code == 502


def test_cancel_external_provider_success_schedules_cancel(db, create_parent, use_provider):
    parent = create_parent(email="cancel-ok@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.provider_subscription_id = "sub_cancel3"
    db.add(profile)
    db.commit()

    use_provider(FakeProvider())
    subscription_service.cancel_subscription(db=db, user=parent)
    db.refresh(profile)
    assert profile.will_renew is False


# ---------------------------------------------------------------------------
# select_subscription validation
# ---------------------------------------------------------------------------


def test_select_missing_plan(db, create_parent):
    parent = create_parent(email="sel-missing@example.com")
    with pytest.raises(HTTPException) as exc:
        subscription_service.select_subscription(payload=_select_payload(""), db=db, user=parent)
    assert exc.value.status_code == 422


def test_select_invalid_plan(db, create_parent):
    parent = create_parent(email="sel-invalid@example.com")
    with pytest.raises(HTTPException) as exc:
        subscription_service.select_subscription(
            payload=_select_payload("NOPE"), db=db, user=parent
        )
    assert exc.value.status_code == 400


def test_select_free_returns_snapshot(db, create_parent):
    parent = create_parent(email="sel-free@example.com")
    result = subscription_service.select_subscription(
        payload=_select_payload(PLAN_FREE), db=db, user=parent
    )
    assert result["current_plan_id"] == PLAN_FREE


# ---------------------------------------------------------------------------
# activate_subscription
# ---------------------------------------------------------------------------


def test_activate_missing_plan(db, create_parent):
    parent = create_parent(email="act-missing@example.com")
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(payload=_select_payload(""), db=db, user=parent)
    assert exc.value.status_code == 422


def test_activate_free_returns_snapshot(db, create_parent):
    parent = create_parent(email="act-free@example.com")
    result = subscription_service.activate_subscription(
        payload=_select_payload(PLAN_FREE), db=db, user=parent
    )
    assert result["current_plan_id"] == PLAN_FREE


def test_activate_missing_session_id(db, create_parent, use_provider):
    parent = create_parent(email="act-nosession@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider())
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id=None), db=db, user=parent
        )
    assert exc.value.status_code == 422


def test_activate_provider_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="act-503@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(raise_on={"retrieve"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_x"), db=db, user=parent
        )
    assert exc.value.status_code == 503


def test_activate_provider_error(db, create_parent, use_provider):
    parent = create_parent(email="act-502@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(raise_on={"retrieve"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_x"), db=db, user=parent
        )
    assert exc.value.status_code == 502


def test_activate_success(db, create_parent, use_provider):
    parent = create_parent(email="act-ok@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=parent.id))
    result = subscription_service.activate_subscription(
        payload=_select_payload(PLAN_PREMIUM, session_id="cs_ok"), db=db, user=parent
    )
    assert result["current_plan_id"] == PLAN_PREMIUM


def test_activate_rejects_session_owned_by_another_user(db, create_parent, use_provider):
    victim = create_parent(email="act-victim@example.com", plan=PLAN_FREE)
    attacker = create_parent(email="act-attacker@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=victim.id))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_victim"), db=db, user=attacker
        )
    assert exc.value.status_code == 403
    db.refresh(attacker)
    assert attacker.plan == PLAN_FREE


def test_activate_rejects_session_without_owner_metadata(db, create_parent, use_provider):
    parent = create_parent(email="act-nometa@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=None))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_nometa"), db=db, user=parent
        )
    assert exc.value.status_code == 403


def test_activate_rejects_session_paid_for_a_different_plan(db, create_parent, use_provider):
    from plan_service import PLAN_FAMILY_PLUS

    parent = create_parent(email="act-wrongplan@example.com", plan=PLAN_FREE)
    # Paid for PREMIUM, tries to claim the pricier FAMILY_PLUS.
    use_provider(FakeProvider(owner_id=parent.id, plan_id=PLAN_PREMIUM))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_FAMILY_PLUS, session_id="cs_plan"), db=db, user=parent
        )
    assert exc.value.status_code == 403


def test_activate_rejects_session_already_used_by_another_account(db, create_parent, use_provider):
    first = create_parent(email="act-first@example.com", plan=PLAN_FREE)
    second = create_parent(email="act-second@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=first.id))
    subscription_service.activate_subscription(
        payload=_select_payload(PLAN_PREMIUM, session_id="cs_shared"), db=db, user=first
    )
    # Even if the provider metadata were somehow made to match, a session that
    # already activated one account can't activate a second one.
    use_provider(FakeProvider(owner_id=second.id))
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_shared"), db=db, user=second
        )
    assert exc.value.status_code == 409
    db.refresh(second)
    assert second.plan == PLAN_FREE


def test_activate_rejects_replay_of_consumed_session_after_downgrade(
    db, create_parent, use_provider
):
    parent = create_parent(email="act-replay@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=parent.id))
    subscription_service.activate_subscription(
        payload=_select_payload(PLAN_PREMIUM, session_id="cs_replay"), db=db, user=parent
    )
    # Access is revoked (refund / lapse), then the old paid session is replayed.
    subscription_service.admin_override_subscription(
        db=db, user=parent, plan=PLAN_FREE, source="admin"
    )
    with pytest.raises(HTTPException) as exc:
        subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_replay"), db=db, user=parent
        )
    assert exc.value.status_code == 409
    db.refresh(parent)
    assert parent.plan == PLAN_FREE


def test_activate_same_session_twice_by_owner_is_idempotent(db, create_parent, use_provider):
    """Normal use: retrying activation with your own session still works."""
    parent = create_parent(email="act-retry@example.com", plan=PLAN_FREE)
    use_provider(FakeProvider(owner_id=parent.id))
    for _ in range(2):
        result = subscription_service.activate_subscription(
            payload=_select_payload(PLAN_PREMIUM, session_id="cs_retry"), db=db, user=parent
        )
        assert result["current_plan_id"] == PLAN_PREMIUM


# ---------------------------------------------------------------------------
# manage_subscription / billing_portal 410 guards
# ---------------------------------------------------------------------------


def test_manage_internal_unavailable(db, create_parent):
    parent = create_parent(email="manage-internal@example.com")
    with pytest.raises(HTTPException) as exc:
        subscription_service.manage_subscription(db=db, user=parent)
    assert exc.value.status_code == 410


def test_billing_portal_internal_unavailable(db, create_parent):
    parent = create_parent(email="portal-internal@example.com")
    with pytest.raises(HTTPException) as exc:
        subscription_service.billing_portal(db=db, user=parent)
    assert exc.value.status_code == 410


def test_manage_active_without_subscription_id_unavailable(db, create_parent):
    parent = create_parent(email="manage-active@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.status = "active"
    profile.provider_subscription_id = None
    db.add(profile)
    db.commit()
    with pytest.raises(HTTPException) as exc:
        subscription_service.manage_subscription(db=db, user=parent)
    assert exc.value.status_code == 410


# ---------------------------------------------------------------------------
# refund_subscription
# ---------------------------------------------------------------------------


def test_refund_no_target(db, create_parent):
    parent = create_parent(email="refund-notarget@example.com", plan=PLAN_FREE)
    with pytest.raises(HTTPException) as exc:
        subscription_service.refund_subscription(db=db, user=parent, source="admin")
    assert exc.value.status_code == 409


def _activate_premium_with_target(db, parent, use_provider):
    """Activate premium via checkout so a refundable payment attempt exists."""
    use_provider(FakeProvider(owner_id=parent.id))
    subscription_service.activate_subscription(
        payload=_select_payload(PLAN_PREMIUM, session_id="cs_refund"), db=db, user=parent
    )


def test_refund_success(db, create_parent, use_provider):
    parent = create_parent(email="refund-ok@example.com", plan=PLAN_FREE)
    _activate_premium_with_target(db, parent, use_provider)
    result = subscription_service.refund_subscription(db=db, user=parent, source="admin")
    assert result["success"] is True
    assert result["refund_id"] == "re_x"


def test_refund_action_required(db, create_parent, use_provider):
    parent = create_parent(email="refund-501@example.com", plan=PLAN_FREE)
    _activate_premium_with_target(db, parent, use_provider)
    use_provider(
        FakeProvider(raise_on={"refund"}, error=PaymentProviderActionRequiredError("manual"))
    )
    with pytest.raises(HTTPException) as exc:
        subscription_service.refund_subscription(db=db, user=parent, source="admin")
    assert exc.value.status_code == 501


def test_refund_provider_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="refund-503@example.com", plan=PLAN_FREE)
    _activate_premium_with_target(db, parent, use_provider)
    use_provider(FakeProvider(raise_on={"refund"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.refund_subscription(db=db, user=parent, source="admin")
    assert exc.value.status_code == 503


def test_refund_provider_error(db, create_parent, use_provider):
    parent = create_parent(email="refund-502@example.com", plan=PLAN_FREE)
    _activate_premium_with_target(db, parent, use_provider)
    use_provider(FakeProvider(raise_on={"refund"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.refund_subscription(db=db, user=parent, source="admin")
    assert exc.value.status_code == 502


# ---------------------------------------------------------------------------
# _ensure_subscription_profile reconciliation branches
# ---------------------------------------------------------------------------


def test_ensure_profile_reconciles_premium_to_free(db, create_parent):
    parent = create_parent(email="recon-free@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    # Simulate a stale active/premium profile after the user dropped to FREE.
    parent.plan = PLAN_FREE
    parent.is_premium = False
    profile.status = "active"
    profile.will_renew = True
    db.add_all([parent, profile])
    db.commit()

    reconciled = subscription_service._ensure_subscription_profile(db=db, user=parent)
    assert reconciled.current_plan_id == PLAN_FREE
    assert reconciled.status == "free"
    assert reconciled.will_renew is False


def test_ensure_profile_reconciles_free_to_active(db, create_parent):
    parent = create_parent(email="recon-active@example.com", plan=PLAN_FREE)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    # Simulate the user being upgraded to premium while the profile lags as free.
    parent.plan = PLAN_PREMIUM
    parent.is_premium = True
    profile.status = "free"
    profile.last_payment_status = "not_applicable"
    db.add_all([parent, profile])
    db.commit()

    reconciled = subscription_service._ensure_subscription_profile(db=db, user=parent)
    assert reconciled.current_plan_id == PLAN_PREMIUM
    assert reconciled.status == "active"
