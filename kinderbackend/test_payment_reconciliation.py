from __future__ import annotations

from datetime import timedelta

import pytest

from core.time_utils import db_utc_now
from models import PaymentAttempt, SubscriptionEvent, SubscriptionProfile
from services.payment_provider import PaymentProviderError, ProviderSubscriptionSnapshot
from services.payment_reconciliation_service import PaymentReconciliationService
from services.subscription_service import (
    PAYMENT_STATUS_PENDING,
    PAYMENT_STATUS_SUCCEEDED,
    SUBSCRIPTION_STATUS_PENDING,
)


def _create_profile(db, user):
    profile = SubscriptionProfile(
        user_id=user.id,
        current_plan_id="PREMIUM",
        selected_plan_id="PREMIUM",
        status=SUBSCRIPTION_STATUS_PENDING,
        last_payment_status=PAYMENT_STATUS_PENDING,
        will_renew=False,
        provider="stripe",
        provider_subscription_id="sub_123",
        provider_customer_id="cus_123",
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def test_reconciliation_updates_profile_and_attempt(db, create_parent):
    user = create_parent(plan="PREMIUM")
    profile = _create_profile(db, user)

    attempt = PaymentAttempt(
        user_id=user.id,
        subscription_profile_id=profile.id,
        plan_id="PREMIUM",
        attempt_type="invoice_payment",
        status=PAYMENT_STATUS_PENDING,
        amount_cents=1000,
        currency="USD",
        provider_reference="inv_123",
        requested_at=db_utc_now(),
        completed_at=None,
    )
    db.add(attempt)
    db.commit()

    class StubProvider:
        provider_key = "stripe"
        is_external = True

        def retrieve_subscription(self, *, subscription_id: str) -> ProviderSubscriptionSnapshot:
            return ProviderSubscriptionSnapshot(
                provider="stripe",
                subscription_id=subscription_id,
                status="active",
                current_period_end=db_utc_now() + timedelta(days=30),
                cancel_at=None,
                cancel_at_period_end=False,
                latest_invoice_id="inv_123",
                latest_invoice_status="paid",
                raw={},
            )

    service = PaymentReconciliationService()
    service._payment_provider_factory = lambda: StubProvider()  # noqa: SLF001

    issue = service.reconcile_profile(db=db, profile=profile)
    assert issue is not None
    assert issue.issue_type == "updated"

    db.refresh(profile)
    assert profile.status == "active"
    assert profile.last_payment_status == PAYMENT_STATUS_SUCCEEDED
    assert profile.will_renew is True
    assert profile.expires_at is not None

    updated_attempt = (
        db.query(PaymentAttempt)
        .filter(PaymentAttempt.id == attempt.id)
        .first()
    )
    assert updated_attempt is not None
    assert updated_attempt.status == PAYMENT_STATUS_SUCCEEDED
    assert updated_attempt.completed_at is not None

    event = (
        db.query(SubscriptionEvent)
        .filter(
            SubscriptionEvent.subscription_profile_id == profile.id,
            SubscriptionEvent.event_type == "reconciliation_mismatch",
        )
        .first()
    )
    assert event is not None


def test_reconciliation_records_error(db, create_parent):
    user = create_parent(plan="PREMIUM", email="parent2@example.com")
    profile = _create_profile(db, user)

    class StubProvider:
        provider_key = "stripe"
        is_external = True

        def retrieve_subscription(self, *, subscription_id: str) -> ProviderSubscriptionSnapshot:
            raise PaymentProviderError("provider unavailable")

    service = PaymentReconciliationService()
    service._payment_provider_factory = lambda: StubProvider()  # noqa: SLF001

    issue = service.reconcile_profile(db=db, profile=profile)
    assert issue is not None
    assert issue.issue_type == "error"

    event = (
        db.query(SubscriptionEvent)
        .filter(
            SubscriptionEvent.subscription_profile_id == profile.id,
            SubscriptionEvent.event_type == "reconciliation_error",
        )
        .first()
    )
    assert event is not None
