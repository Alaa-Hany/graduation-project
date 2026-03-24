from __future__ import annotations

import admin_models  # noqa: F401
from admin_models import AdminUser, AuditLog
from auth import hash_password
from core.time_utils import db_utc_now
from models import (
    BillingTransaction,
    SubscriptionEvent,
    SubscriptionProfile,
    SupportTicket,
    PaymentAttempt,
    User,
)


def _create_parent(db, *, email: str = "parent@example.com") -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name="Parent User",
        role="parent",
        is_active=True,
        plan="PREMIUM",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def test_deleting_admin_preserves_audit_logs(db) -> None:
    admin = AdminUser(
        email="audit.admin@kinderworld.app",
        password_hash=hash_password("AdminPass123!"),
        name="Audit Admin",
        is_active=True,
        token_version=0,
    )
    db.add(admin)
    db.flush()

    log = AuditLog(
        admin_user_id=admin.id,
        action="admin_user.disable",
        entity_type="admin_user",
        entity_id="42",
    )
    db.add(log)
    db.commit()

    db.delete(admin)
    db.commit()

    preserved_log = db.query(AuditLog).filter(AuditLog.id == log.id).one()
    assert preserved_log.admin_user_id is None


def test_deleting_user_preserves_support_ticket(db) -> None:
    user = _create_parent(db, email="support.parent@example.com")

    ticket = SupportTicket(
        user_id=user.id,
        subject="Need help",
        message="Original support message",
        status="open",
    )
    db.add(ticket)
    db.commit()

    db.delete(user)
    db.commit()

    preserved_ticket = db.query(SupportTicket).filter(SupportTicket.id == ticket.id).one()
    assert preserved_ticket.user_id is None
    assert preserved_ticket.subject == "Need help"


def test_deleting_user_preserves_subscription_history(db) -> None:
    user = _create_parent(db, email="billing.parent@example.com")
    now = db_utc_now()

    profile = SubscriptionProfile(
        user_id=user.id,
        current_plan_id="PREMIUM",
        selected_plan_id="PREMIUM",
        status="active",
        last_payment_status="succeeded",
        provider="internal",
        started_at=now,
    )
    db.add(profile)
    db.flush()

    event = SubscriptionEvent(
        user_id=user.id,
        subscription_profile_id=profile.id,
        event_type="upgraded",
        previous_plan_id="FREE",
        plan_id="PREMIUM",
        previous_status="free",
        status="active",
        payment_status="succeeded",
        source="internal",
        occurred_at=now,
    )
    transaction = BillingTransaction(
        user_id=user.id,
        subscription_profile_id=profile.id,
        plan_id="PREMIUM",
        transaction_type="charge",
        amount_cents=999,
        currency="USD",
        status="succeeded",
        effective_at=now,
    )
    attempt = PaymentAttempt(
        user_id=user.id,
        subscription_profile_id=profile.id,
        plan_id="PREMIUM",
        attempt_type="checkout",
        status="succeeded",
        amount_cents=999,
        currency="USD",
        requested_at=now,
        completed_at=now,
    )
    db.add_all([event, transaction, attempt])
    db.commit()

    db.delete(user)
    db.commit()

    assert (
        db.query(SubscriptionProfile).filter(SubscriptionProfile.id == profile.id).first() is None
    )

    preserved_event = db.query(SubscriptionEvent).filter(SubscriptionEvent.id == event.id).one()
    assert preserved_event.user_id is None
    assert preserved_event.subscription_profile_id is None

    preserved_transaction = (
        db.query(BillingTransaction).filter(BillingTransaction.id == transaction.id).one()
    )
    assert preserved_transaction.user_id is None
    assert preserved_transaction.subscription_profile_id is None

    preserved_attempt = db.query(PaymentAttempt).filter(PaymentAttempt.id == attempt.id).one()
    assert preserved_attempt.user_id is None
    assert preserved_attempt.subscription_profile_id is None
