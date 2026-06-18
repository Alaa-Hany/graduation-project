from __future__ import annotations

from sqlalchemy.orm import Session

from models import (
    BillingTransaction,
    PaymentAttempt,
    PaymentMethod,
    SubscriptionEvent,
    SubscriptionProfile,
    User,
)
from plan_service import PLAN_FREE, get_plan_features, get_plan_limits
from services.subscription_service_parts.common import SUBSCRIPTION_STATUS_FREE


class SubscriptionHistoryMixin:
    def get_subscription(self, *, db: Session, user: User) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)
        from services.subscription_service_parts.common import logger

        logger.info(
            "subscription_snapshot user_id=%s plan=%s status=%s provider=%s",
            user.id,
            profile.current_plan_id,
            profile.status,
            profile.provider,
        )
        return self._build_subscription_snapshot(db=db, user=user, profile=profile)

    def subscription_status(self, *, db: Session, user: User) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        return self._build_status_payload(user=user, profile=profile)

    def subscription_history(self, *, db: Session, user: User) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)
        return {
            "user_id": user.id,
            "current_plan_id": profile.current_plan_id,
            "status": profile.status,
            "events": self._list_subscription_events(db=db, profile=profile),
            "billing_transactions": self._list_billing_transactions(db=db, profile=profile),
            "payment_attempts": self._list_payment_attempts(db=db, profile=profile),
        }

    def _build_subscription_snapshot(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
    ) -> dict[str, object]:
        plan = profile.current_plan_id
        return {
            "plan": plan,
            "current_plan_id": plan,
            "limits": get_plan_limits(plan),
            "features": get_plan_features(plan),
            "lifecycle": self._serialize_lifecycle(user=user, profile=profile),
            "history_summary": {
                "event_count": self._count_for_model(
                    db=db,
                    model=SubscriptionEvent,
                    profile_id=profile.id,
                ),
                "billing_transaction_count": self._count_for_model(
                    db=db,
                    model=BillingTransaction,
                    profile_id=profile.id,
                ),
                "payment_attempt_count": self._count_for_model(
                    db=db,
                    model=PaymentAttempt,
                    profile_id=profile.id,
                ),
            },
            "recent_events": self._list_subscription_events(db=db, profile=profile, limit=10),
            "billing_history": self._list_billing_transactions(db=db, profile=profile, limit=10),
            "payment_attempts": self._list_payment_attempts(db=db, profile=profile, limit=10),
        }

    def _build_status_payload(
        self, *, user: User, profile: SubscriptionProfile
    ) -> dict[str, object]:
        lifecycle = self._serialize_lifecycle(user=user, profile=profile)
        return {
            "current_plan_id": profile.current_plan_id,
            "is_active": bool(lifecycle["has_paid_access"]),
            "status": profile.status,
            "started_at": lifecycle["started_at"],
            "last_payment_status": profile.last_payment_status,
            "has_paid_access": bool(lifecycle["has_paid_access"]),
        }

    def _selection_payload_from_snapshot(self, snapshot: dict[str, object]) -> dict[str, object]:
        lifecycle = snapshot.get("lifecycle", {})
        if not isinstance(lifecycle, dict):
            lifecycle = {}
        return {
            "current_plan_id": snapshot.get("current_plan_id", snapshot.get("plan", PLAN_FREE)),
            "is_active": lifecycle.get("account_is_active", lifecycle.get("is_active", False)),
            "status": lifecycle.get("status", SUBSCRIPTION_STATUS_FREE),
            "started_at": lifecycle.get("started_at"),
            "last_payment_status": lifecycle.get("last_payment_status"),
            "has_paid_access": lifecycle.get("has_paid_access", False),
        }

    def _serialize_lifecycle(
        self, *, user: User, profile: SubscriptionProfile
    ) -> dict[str, object]:
        has_paid_access = bool(user.is_active) and profile.current_plan_id != PLAN_FREE
        return {
            "current_plan_id": profile.current_plan_id,
            "selected_plan_id": profile.selected_plan_id,
            "status": profile.status,
            "started_at": profile.started_at.isoformat() if profile.started_at else None,
            "last_payment_status": profile.last_payment_status,
            "provider": profile.provider,
            "provider_customer_id": profile.provider_customer_id,
            "is_active": has_paid_access,
            "has_paid_access": has_paid_access,
            "account_is_active": bool(user.is_active),
        }

    def _record_subscription_event(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
        event_type: str,
        previous_plan_id: str | None,
        plan_id: str,
        previous_status: str | None,
        status: str,
        payment_status: str | None,
        source: str,
        details_json: dict | None,
        provider_reference: str | None,
        occurred_at,
    ) -> SubscriptionEvent:
        event = SubscriptionEvent(
            user_id=user.id,
            subscription_profile_id=profile.id,
            event_type=event_type,
            previous_plan_id=previous_plan_id,
            plan_id=plan_id,
            previous_status=previous_status,
            status=status,
            payment_status=payment_status,
            source=source,
            provider_reference=provider_reference,
            details_json=details_json,
            occurred_at=occurred_at,
        )
        db.add(event)
        db.flush()
        return event

    def _record_billing_transaction(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
        plan_id: str,
        transaction_type: str,
        amount_cents: int,
        status: str,
        provider_reference: str | None,
        effective_at,
        metadata_json: dict | None,
    ) -> BillingTransaction:
        transaction = BillingTransaction(
            user_id=user.id,
            subscription_profile_id=profile.id,
            plan_id=plan_id,
            transaction_type=transaction_type,
            amount_cents=amount_cents,
            currency="USD",
            status=status,
            provider_reference=provider_reference,
            effective_at=effective_at,
            metadata_json=metadata_json,
        )
        db.add(transaction)
        db.flush()
        return transaction

    def _record_payment_attempt(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
        plan_id: str,
        attempt_type: str,
        status: str,
        amount_cents: int,
        requested_at,
        completed_at,
        metadata_json: dict | None,
        provider_reference: str | None,
        failure_code: str | None = None,
        failure_message: str | None = None,
    ) -> PaymentAttempt:
        attempt = PaymentAttempt(
            user_id=user.id,
            subscription_profile_id=profile.id,
            plan_id=plan_id,
            attempt_type=attempt_type,
            status=status,
            amount_cents=amount_cents,
            currency="USD",
            provider_reference=provider_reference,
            failure_code=failure_code,
            failure_message=failure_message,
            requested_at=requested_at,
            completed_at=completed_at,
            metadata_json=metadata_json,
        )
        db.add(attempt)
        db.flush()
        return attempt

    def _list_subscription_events(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        limit: int = 50,
    ) -> list[dict[str, object]]:
        rows = (
            db.query(SubscriptionEvent)
            .filter(SubscriptionEvent.subscription_profile_id == profile.id)
            .order_by(SubscriptionEvent.occurred_at.desc(), SubscriptionEvent.id.desc())
            .limit(limit)
            .all()
        )
        return [self._serialize_subscription_event(item) for item in rows]

    def _list_billing_transactions(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        limit: int = 50,
    ) -> list[dict[str, object]]:
        rows = (
            db.query(BillingTransaction)
            .filter(BillingTransaction.subscription_profile_id == profile.id)
            .order_by(BillingTransaction.effective_at.desc(), BillingTransaction.id.desc())
            .limit(limit)
            .all()
        )
        return [self._serialize_billing_transaction(item) for item in rows]

    def _list_payment_attempts(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        limit: int = 50,
    ) -> list[dict[str, object]]:
        rows = (
            db.query(PaymentAttempt)
            .filter(PaymentAttempt.subscription_profile_id == profile.id)
            .order_by(PaymentAttempt.requested_at.desc(), PaymentAttempt.id.desc())
            .limit(limit)
            .all()
        )
        return [self._serialize_payment_attempt(item) for item in rows]

    @staticmethod
    def _serialize_subscription_event(item: SubscriptionEvent) -> dict[str, object]:
        return {
            "id": item.id,
            "event_type": item.event_type,
            "previous_plan_id": item.previous_plan_id,
            "plan_id": item.plan_id,
            "previous_status": item.previous_status,
            "status": item.status,
            "payment_status": item.payment_status,
            "source": item.source,
            "provider_reference": item.provider_reference,
            "details_json": item.details_json or {},
            "occurred_at": item.occurred_at.isoformat() if item.occurred_at else None,
        }

    @staticmethod
    def _serialize_billing_transaction(item: BillingTransaction) -> dict[str, object]:
        return {
            "id": item.id,
            "plan_id": item.plan_id,
            "transaction_type": item.transaction_type,
            "amount_cents": item.amount_cents,
            "currency": item.currency,
            "status": item.status,
            "provider_reference": item.provider_reference,
            "effective_at": item.effective_at.isoformat() if item.effective_at else None,
            "metadata_json": item.metadata_json or {},
        }

    @staticmethod
    def _serialize_payment_attempt(item: PaymentAttempt) -> dict[str, object]:
        return {
            "id": item.id,
            "plan_id": item.plan_id,
            "attempt_type": item.attempt_type,
            "status": item.status,
            "amount_cents": item.amount_cents,
            "currency": item.currency,
            "provider_reference": item.provider_reference,
            "failure_code": item.failure_code,
            "failure_message": item.failure_message,
            "requested_at": item.requested_at.isoformat() if item.requested_at else None,
            "completed_at": item.completed_at.isoformat() if item.completed_at else None,
            "metadata_json": item.metadata_json or {},
        }

    @staticmethod
    def _serialize_payment_method(method: PaymentMethod) -> dict[str, object]:
        exp_month = None
        exp_year = None
        if getattr(method, "expires_at", None):
            try:
                exp_month = method.expires_at.month
                exp_year = method.expires_at.year
            except Exception:
                exp_month = None
                exp_year = None

        return {
            "id": method.id,
            "label": method.label,
            "provider": method.provider,
            "provider_customer_id": method.provider_customer_id,
            "provider_method_id": method.provider_method_id,
            "method_type": method.method_type,
            "brand": method.brand,
            "last4": method.last4,
            "exp_month": exp_month,
            "exp_year": exp_year,
            "is_default": bool(method.is_default),
            "created_at": method.created_at.isoformat() if method.created_at else None,
            "metadata_json": method.metadata_json or {},
        }

    @staticmethod
    def _count_for_model(*, db: Session, model, profile_id: int) -> int:
        return db.query(model).filter(model.subscription_profile_id == profile_id).count()
