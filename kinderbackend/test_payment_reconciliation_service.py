"""Unit tests for services.payment_reconciliation_service.

A fake provider supplies ``ProviderSubscriptionSnapshot`` objects so the
reconciliation logic (status/plan/payment-attempt drift detection and the
status-mapping helpers) can run deterministically against the in-memory DB.
"""

from __future__ import annotations

from datetime import timedelta

import pytest

from core.time_utils import db_utc_now
from models import PaymentAttempt, SubscriptionProfile
from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_provider import PaymentProviderError, ProviderSubscriptionSnapshot
from services.payment_reconciliation_service import PaymentReconciliationService
from services.subscription_service import SUBSCRIPTION_STATUS_PENDING


def _snapshot(
    *,
    status="active",
    current_period_end=None,
    cancel_at=None,
    cancel_at_period_end=False,
    latest_invoice_id=None,
    latest_invoice_status=None,
):
    return ProviderSubscriptionSnapshot(
        provider="stripe",
        subscription_id="sub_x",
        status=status,
        current_period_end=current_period_end,
        cancel_at=cancel_at,
        cancel_at_period_end=cancel_at_period_end,
        latest_invoice_id=latest_invoice_id,
        latest_invoice_status=latest_invoice_status,
    )


class _FakeProvider:
    def __init__(self, *, snapshot=None, error=None):
        self._snapshot = snapshot
        self._error = error

    def retrieve_subscription(self, *, subscription_id):
        if self._error is not None:
            raise self._error
        return self._snapshot


def _service(snapshot=None, error=None):
    return PaymentReconciliationService(
        payment_provider_factory=lambda: _FakeProvider(snapshot=snapshot, error=error)
    )


def _stripe_profile(db, parent, *, plan=PLAN_PREMIUM, status="active", will_renew=True):
    from services.subscription_service import subscription_service

    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider = "stripe"
    profile.provider_subscription_id = "sub_x"
    profile.current_plan_id = plan
    profile.status = status
    profile.will_renew = will_renew
    profile.last_payment_status = "succeeded"
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


# ---------------------------------------------------------------------------
# Pure helper methods
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "invoice_status,expected",
    [
        (None, "pending"),
        ("paid", "succeeded"),
        ("open", "pending"),
        ("draft", "pending"),
        ("uncollectible", "failed"),
        ("void", "failed"),
        ("failed", "failed"),
        ("canceled", "canceled"),
        ("requires_action", "action_required"),
        ("something_else", "pending"),
    ],
)
def test_payment_status_from_invoice(invoice_status, expected):
    assert PaymentReconciliationService._payment_status_from_invoice(invoice_status) == expected


def test_normalize_dt():
    svc = PaymentReconciliationService()
    assert svc._normalize_dt(None) is None
    now = db_utc_now()
    assert svc._normalize_dt(now) is not None


def test_serialize_changes_handles_datetimes():
    svc = PaymentReconciliationService()
    now = db_utc_now()
    serialized = svc._serialize_changes({"expires_at": now, "status": "active"})
    assert serialized["expires_at"] == now.isoformat()
    assert serialized["status"] == "active"


@pytest.mark.parametrize(
    "status,expected_status",
    [
        ("active", "active"),
        ("trialing", "active"),
        ("past_due", "past_due"),
        ("unpaid", "past_due"),
        ("canceled", "canceled"),
        ("incomplete_expired", "canceled"),
        ("incomplete", SUBSCRIPTION_STATUS_PENDING),
        ("weird", SUBSCRIPTION_STATUS_PENDING),
    ],
)
def test_map_provider_snapshot_status(db, create_parent, status, expected_status):
    parent = create_parent(email=f"map-{status}@example.com", plan=PLAN_PREMIUM)
    profile = SubscriptionProfile(user_id=parent.id, current_plan_id=PLAN_PREMIUM, status="active")
    mapped = PaymentReconciliationService._map_provider_snapshot(
        _snapshot(status=status, latest_invoice_status="paid"), profile=profile
    )
    assert mapped["status"] == expected_status


def test_map_provider_snapshot_canceled_forces_free_plan(create_parent, db):
    parent = create_parent(email="map-cancel@example.com", plan=PLAN_PREMIUM)
    profile = SubscriptionProfile(user_id=parent.id, current_plan_id=PLAN_PREMIUM, status="active")
    mapped = PaymentReconciliationService._map_provider_snapshot(
        _snapshot(status="canceled"), profile=profile
    )
    assert mapped["plan_id"] == PLAN_FREE
    assert mapped["last_payment_status"] == "canceled"
    assert mapped["will_renew"] is False


def test_map_provider_snapshot_active_promotes_selected_plan(create_parent, db):
    parent = create_parent(email="map-selected@example.com", plan=PLAN_FREE)
    profile = SubscriptionProfile(
        user_id=parent.id,
        current_plan_id=PLAN_FREE,
        selected_plan_id=PLAN_PREMIUM,
        status="pending",
    )
    mapped = PaymentReconciliationService._map_provider_snapshot(
        _snapshot(status="active"), profile=profile
    )
    assert mapped["plan_id"] == PLAN_PREMIUM


# ---------------------------------------------------------------------------
# reconcile_profile
# ---------------------------------------------------------------------------


def test_reconcile_profile_no_subscription_id_returns_none(db, create_parent):
    parent = create_parent(email="recon-nosub@example.com")
    from services.subscription_service import subscription_service

    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider_subscription_id = None
    db.add(profile)
    db.commit()
    assert _service().reconcile_profile(db=db, profile=profile) is None


def test_reconcile_profile_provider_error(db, create_parent):
    parent = create_parent(email="recon-error@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent)
    svc = _service(error=PaymentProviderError("provider exploded"))
    issue = svc.reconcile_profile(db=db, profile=profile)
    assert issue is not None
    assert issue.issue_type == "error"


def test_reconcile_profile_no_changes_returns_none(db, create_parent):
    parent = create_parent(email="recon-nochange@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent, status="active", will_renew=True)
    # Snapshot mirrors the current profile exactly → no drift.
    snapshot = _snapshot(
        status="active",
        current_period_end=None,
        cancel_at=None,
        cancel_at_period_end=False,
        latest_invoice_status="paid",
    )
    assert _service(snapshot=snapshot).reconcile_profile(db=db, profile=profile) is None


def test_reconcile_profile_detects_cancellation(db, create_parent):
    parent = create_parent(email="recon-cancel@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent, status="active", will_renew=True)
    snapshot = _snapshot(status="canceled")
    issue = _service(snapshot=snapshot).reconcile_profile(db=db, profile=profile)
    assert issue is not None
    assert issue.issue_type == "updated"
    db.refresh(profile)
    assert profile.status == "canceled"
    assert profile.current_plan_id == PLAN_FREE
    db.refresh(parent)
    assert parent.plan == PLAN_FREE  # user_plan projection synced


def test_reconcile_profile_updates_payment_attempt(db, create_parent):
    parent = create_parent(email="recon-attempt@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent, status="active", will_renew=True)
    attempt = PaymentAttempt(
        user_id=parent.id,
        subscription_profile_id=profile.id,
        plan_id=PLAN_PREMIUM,
        attempt_type="renewal",
        status="pending",
        amount_cents=1000,
        provider_reference="in_recon",
        requested_at=db_utc_now() - timedelta(minutes=1),
    )
    db.add(attempt)
    db.commit()

    snapshot = _snapshot(
        status="active",
        latest_invoice_id="in_recon",
        latest_invoice_status="paid",
        current_period_end=None,
    )
    _service(snapshot=snapshot).reconcile_profile(db=db, profile=profile)
    db.refresh(attempt)
    assert attempt.status == "succeeded"
    assert attempt.completed_at is not None


def test_reconcile_payment_attempt_failed_status(db, create_parent):
    parent = create_parent(email="recon-attempt-fail@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent, status="active", will_renew=True)
    attempt = PaymentAttempt(
        user_id=parent.id,
        subscription_profile_id=profile.id,
        plan_id=PLAN_PREMIUM,
        attempt_type="renewal",
        status="pending",
        amount_cents=1000,
        provider_reference="in_fail",
        requested_at=db_utc_now() - timedelta(minutes=1),
    )
    db.add(attempt)
    db.commit()

    snapshot = _snapshot(
        status="active",
        latest_invoice_id="in_fail",
        latest_invoice_status="void",
        current_period_end=None,
    )
    _service(snapshot=snapshot).reconcile_profile(db=db, profile=profile)
    db.refresh(attempt)
    assert attempt.status == "failed"
    assert attempt.failure_code == "INVOICE_STATUS"


# ---------------------------------------------------------------------------
# reconcile_all
# ---------------------------------------------------------------------------


def test_reconcile_all_scans_and_updates(db, create_parent):
    parent = create_parent(email="recon-all@example.com", plan=PLAN_PREMIUM)
    _stripe_profile(db, parent, status="active", will_renew=True)
    snapshot = _snapshot(status="canceled")
    result = _service(snapshot=snapshot).reconcile_all(db=db, limit=10)
    assert result.scanned == 1
    assert result.updated == 1
    assert len(result.issues) == 1


def test_reconcile_all_excludes_pending_when_requested(db, create_parent):
    parent = create_parent(email="recon-all-pending@example.com", plan=PLAN_PREMIUM)
    profile = _stripe_profile(db, parent, status=SUBSCRIPTION_STATUS_PENDING, will_renew=True)
    db.add(profile)
    db.commit()
    snapshot = _snapshot(status="active")
    result = _service(snapshot=snapshot).reconcile_all(db=db, limit=10, include_pending=False)
    # The only profile is pending and therefore filtered out of the scan.
    assert result.scanned == 0


def test_reconcile_all_skips_internal_profiles(db, create_parent):
    parent = create_parent(email="recon-all-internal@example.com", plan=PLAN_FREE)
    from services.subscription_service import subscription_service

    subscription_service._ensure_subscription_profile(db=db, user=parent)  # provider=internal
    db.commit()
    result = _service(snapshot=_snapshot()).reconcile_all(db=db, limit=10)
    assert result.scanned == 0
