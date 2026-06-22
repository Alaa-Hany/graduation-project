"""Unit tests for services.subscription_service_parts.provider.SubscriptionProviderMixin.

Drives payment-method add/delete/sync and the billing-portal session creation
(including every provider-error branch) through the real ``subscription_service``
singleton with a configurable fake provider injected via
``_payment_provider_factory``.
"""

from __future__ import annotations

import pytest
from fastapi import HTTPException

from models import PaymentMethod
from plan_service import PLAN_PREMIUM
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PaymentProviderActionRequiredError,
    PaymentProviderError,
    PaymentProviderUnavailableError,
    PortalSessionResult,
)
from services.subscription_service import subscription_service


def _method_ref(method_id="pm_card", *, is_default=True):
    return PaymentMethodReference(
        provider="stripe",
        customer_id="cus_x",
        method_id=method_id,
        method_type="card",
        brand="visa",
        last4="4242",
        exp_month=12,
        exp_year=2030,
        is_default=is_default,
        fingerprint="fp",
    )


class FakeProvider:
    def __init__(self, *, is_external=True, provider_key="stripe", raise_on=None, error=None,
                 methods=None):
        self.is_external = is_external
        self.provider_key = provider_key
        self.raise_on = raise_on or set()
        self.error = error or PaymentProviderError("boom")
        self._methods = methods if methods is not None else [_method_ref()]

    def _maybe(self, name):
        if name in self.raise_on:
            raise self.error

    def attach_payment_method(self, *, customer_id, payment_method_id, set_default):
        self._maybe("attach")
        return _method_ref(payment_method_id, is_default=set_default)

    def detach_payment_method(self, *, payment_method_id):
        self._maybe("detach")
        return {"id": payment_method_id, "detached": True}

    def list_payment_methods(self, *, customer_id):
        self._maybe("list")
        return self._methods

    def create_billing_portal_session(self, *, customer_id, metadata):
        self._maybe("portal")
        return PortalSessionResult(
            provider=self.provider_key,
            session_id="bps_x",
            url="https://portal",
            customer_id=customer_id,
            raw={},
        )


@pytest.fixture
def use_provider(monkeypatch):
    def _use(provider):
        monkeypatch.setattr(subscription_service, "_payment_provider_factory", lambda: provider)

    return _use


def _stripe_profile(db, parent, *, customer_id="cus_x", sub_id=None, status="active"):
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.provider_customer_id = customer_id
    profile.provider_subscription_id = sub_id
    profile.status = status
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


# ---------------------------------------------------------------------------
# add_payment_method
# ---------------------------------------------------------------------------


def test_add_payment_method_internal(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-internal@example.com")
    use_provider(FakeProvider(is_external=False, provider_key="internal"))
    result = subscription_service.add_payment_method(
        db=db, user=parent, label="Visa 4242", set_default=True
    )
    assert result["label"] == "Visa 4242"


def test_add_payment_method_external_no_customer(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-nocus@example.com")
    use_provider(FakeProvider())
    with pytest.raises(HTTPException) as exc:
        subscription_service.add_payment_method(
            db=db, user=parent, label="x", provider_method_id="pm_card"
        )
    assert exc.value.status_code == 409


def test_add_payment_method_external_missing_method_id(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-noid@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    use_provider(FakeProvider())
    with pytest.raises(HTTPException) as exc:
        subscription_service.add_payment_method(db=db, user=parent, label="x")
    assert exc.value.status_code == 422


def test_add_payment_method_external_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-503@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    use_provider(FakeProvider(raise_on={"attach"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.add_payment_method(
            db=db, user=parent, label="x", provider_method_id="pm_card"
        )
    assert exc.value.status_code == 503


def test_add_payment_method_external_error(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-502@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    use_provider(FakeProvider(raise_on={"attach"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.add_payment_method(
            db=db, user=parent, label="x", provider_method_id="pm_card"
        )
    assert exc.value.status_code == 502


def test_add_payment_method_external_success(db, create_parent, use_provider):
    parent = create_parent(email="pm-add-ok@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    use_provider(FakeProvider(methods=[_method_ref("pm_card")]))
    result = subscription_service.add_payment_method(
        db=db, user=parent, label="ignored", provider_method_id="pm_card", set_default=True
    )
    assert result["provider_method_id"] == "pm_card"


# ---------------------------------------------------------------------------
# delete_payment_method
# ---------------------------------------------------------------------------


def test_delete_payment_method_not_found(db, create_parent, use_provider):
    parent = create_parent(email="pm-del-404@example.com")
    use_provider(FakeProvider(is_external=False))
    with pytest.raises(HTTPException) as exc:
        subscription_service.delete_payment_method(db=db, user=parent, method_id=999999)
    assert exc.value.status_code == 404


def test_delete_payment_method_internal(db, create_parent, use_provider):
    parent = create_parent(email="pm-del-internal@example.com")
    method = PaymentMethod(user_id=parent.id, label="Visa", provider="internal")
    db.add(method)
    db.commit()
    db.refresh(method)
    use_provider(FakeProvider(is_external=False))
    subscription_service.delete_payment_method(db=db, user=parent, method_id=method.id)
    db.refresh(method)
    assert method.deleted_at is not None


def test_delete_payment_method_external_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="pm-del-503@example.com")
    method = PaymentMethod(
        user_id=parent.id, label="Visa", provider="stripe", provider_method_id="pm_card"
    )
    db.add(method)
    db.commit()
    db.refresh(method)
    use_provider(FakeProvider(raise_on={"detach"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.delete_payment_method(db=db, user=parent, method_id=method.id)
    assert exc.value.status_code == 503


def test_delete_payment_method_external_error(db, create_parent, use_provider):
    parent = create_parent(email="pm-del-502@example.com")
    method = PaymentMethod(
        user_id=parent.id, label="Visa", provider="stripe", provider_method_id="pm_card"
    )
    db.add(method)
    db.commit()
    db.refresh(method)
    use_provider(FakeProvider(raise_on={"detach"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.delete_payment_method(db=db, user=parent, method_id=method.id)
    assert exc.value.status_code == 502


# ---------------------------------------------------------------------------
# sync_payment_methods
# ---------------------------------------------------------------------------


def test_sync_payment_methods_internal_returns_list(db, create_parent, use_provider):
    parent = create_parent(email="pm-sync-internal@example.com")
    db.add(PaymentMethod(user_id=parent.id, label="Visa", provider="internal"))
    db.commit()
    use_provider(FakeProvider(is_external=False))
    result = subscription_service.sync_payment_methods(db=db, user=parent)
    assert len(result) == 1


def test_sync_payment_methods_external_replaces(db, create_parent, use_provider):
    parent = create_parent(email="pm-sync-ext@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    # A stale local method that is no longer present provider-side should be removed.
    db.add(
        PaymentMethod(
            user_id=parent.id, label="Old", provider="stripe", provider_method_id="pm_old"
        )
    )
    db.commit()
    use_provider(FakeProvider(methods=[_method_ref("pm_new")]))
    result = subscription_service.sync_payment_methods(db=db, user=parent)
    provider_ids = {m["provider_method_id"] for m in result}
    assert "pm_new" in provider_ids
    assert "pm_old" not in provider_ids


def test_sync_payment_methods_external_list_error_is_swallowed(db, create_parent, use_provider):
    parent = create_parent(email="pm-sync-err@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent)
    use_provider(FakeProvider(raise_on={"list"}, error=PaymentProviderError("down")))
    # Provider failure is swallowed; the local (empty) list is returned.
    result = subscription_service.sync_payment_methods(db=db, user=parent)
    assert result == []


# ---------------------------------------------------------------------------
# billing_portal → _create_portal_session
# ---------------------------------------------------------------------------


def test_billing_portal_success(db, create_parent, use_provider):
    parent = create_parent(email="portal-ok@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent, sub_id="sub_x")
    use_provider(FakeProvider())
    result = subscription_service.billing_portal(db=db, user=parent)
    assert result["url"] == "https://portal"
    assert result["session_id"] == "bps_x"


def test_billing_portal_no_customer(db, create_parent, use_provider):
    parent = create_parent(email="portal-nocus@example.com", plan=PLAN_PREMIUM)
    # provider != internal and not (active w/o sub id) → reaches _create_portal_session,
    # which then rejects because there is no provider customer id.
    _stripe_profile(db, parent, customer_id=None, status="past_due")
    use_provider(FakeProvider())
    with pytest.raises(HTTPException) as exc:
        subscription_service.billing_portal(db=db, user=parent)
    assert exc.value.status_code == 409


def test_billing_portal_action_required(db, create_parent, use_provider):
    parent = create_parent(email="portal-501@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent, sub_id="sub_x")
    use_provider(
        FakeProvider(raise_on={"portal"}, error=PaymentProviderActionRequiredError("not configured"))
    )
    with pytest.raises(HTTPException) as exc:
        subscription_service.billing_portal(db=db, user=parent)
    assert exc.value.status_code == 501


def test_billing_portal_unavailable(db, create_parent, use_provider):
    parent = create_parent(email="portal-503@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent, sub_id="sub_x")
    use_provider(FakeProvider(raise_on={"portal"}, error=PaymentProviderUnavailableError("down")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.billing_portal(db=db, user=parent)
    assert exc.value.status_code == 503


def test_billing_portal_provider_error(db, create_parent, use_provider):
    parent = create_parent(email="portal-502@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent, sub_id="sub_x")
    use_provider(FakeProvider(raise_on={"portal"}, error=PaymentProviderError("boom")))
    with pytest.raises(HTTPException) as exc:
        subscription_service.billing_portal(db=db, user=parent)
    assert exc.value.status_code == 502


# ---------------------------------------------------------------------------
# pure helpers
# ---------------------------------------------------------------------------


def _checkout(status="complete", payment_status="paid"):
    return CheckoutSessionResult(
        provider="stripe",
        session_id="cs_x",
        checkout_url="https://x",
        status=status,
        payment_status=payment_status,
        customer_id="cus_x",
        subscription_id="sub_x",
        payment_intent_id="pi_x",
        raw={},
    )


@pytest.mark.parametrize(
    "status,payment_status,expected",
    [
        ("complete", "paid", "succeeded"),
        ("open", "requires_action", "action_required"),
        ("expired", "unpaid", "canceled"),
        ("open", "unpaid", "pending"),
    ],
)
def test_payment_status_from_checkout(status, payment_status, expected):
    result = subscription_service._payment_status_from_checkout(
        _checkout(status=status, payment_status=payment_status)
    )
    assert result == expected


def test_checkout_is_paid():
    assert subscription_service._checkout_is_paid(_checkout("complete", "paid")) is True
    assert subscription_service._checkout_is_paid(_checkout("open", "unpaid")) is False


def test_build_checkout_payload():
    payload = subscription_service._build_checkout_payload(checkout=_checkout())
    assert payload["session_id"] == "cs_x"
    assert payload["provider"] == "stripe"
