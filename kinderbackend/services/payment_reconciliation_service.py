from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.orm import Session

from core.observability import emit_event
from core.time_utils import db_utc_now, ensure_utc
from models import PaymentAttempt, SubscriptionEvent, SubscriptionProfile, User
from plan_service import PLAN_FREE
from services.payment_provider import (
    PaymentProviderError,
    ProviderSubscriptionSnapshot,
    get_payment_provider,
)
from services.subscription_service import (
    PAYMENT_STATUS_ACTION_REQUIRED,
    PAYMENT_STATUS_CANCELED,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PENDING,
    PAYMENT_STATUS_SUCCEEDED,
    SUBSCRIPTION_STATUS_ACTIVE,
    SUBSCRIPTION_STATUS_CANCELED,
    SUBSCRIPTION_STATUS_PAST_DUE,
    SUBSCRIPTION_STATUS_PENDING,
    subscription_service,
)


logger = logging.getLogger(__name__)


@dataclass(slots=True)
class ReconciliationIssue:
    user_id: int
    profile_id: int
    provider_subscription_id: str
    issue_type: str
    details: dict[str, Any]


@dataclass(slots=True)
class ReconciliationResult:
    scanned: int = 0
    updated: int = 0
    mismatches: int = 0
    errors: int = 0
    issues: list[ReconciliationIssue] = field(default_factory=list)


class PaymentReconciliationService:
    def __init__(self) -> None:
        self._payment_provider_factory = get_payment_provider

    def reconcile_all(
        self,
        *,
        db: Session,
        limit: int = 100,
        include_pending: bool = True,
    ) -> ReconciliationResult:
        result = ReconciliationResult()
        logger.info(
            "reconciliation_started limit=%s include_pending=%s",
            limit,
            include_pending,
        )
        emit_event(
            "payment.reconciliation.started",
            category="payment",
            limit=limit,
            include_pending=include_pending,
        )
        query = db.query(SubscriptionProfile).filter(
            SubscriptionProfile.provider != "internal",
            SubscriptionProfile.provider_subscription_id.isnot(None),
        )
        if not include_pending:
            query = query.filter(SubscriptionProfile.status != SUBSCRIPTION_STATUS_PENDING)

        profiles = query.order_by(SubscriptionProfile.updated_at.desc()).limit(limit).all()
        for profile in profiles:
            result.scanned += 1
            issue = self.reconcile_profile(db=db, profile=profile)
            if issue is None:
                continue
            if issue.issue_type in {"error"}:
                result.errors += 1
            else:
                result.mismatches += 1
            if issue.issue_type == "updated":
                result.updated += 1
            result.issues.append(issue)
        logger.info(
            "reconciliation_finished scanned=%s updated=%s mismatches=%s errors=%s",
            result.scanned,
            result.updated,
            result.mismatches,
            result.errors,
        )
        emit_event(
            "payment.reconciliation.finished",
            category="payment",
            scanned=result.scanned,
            updated=result.updated,
            mismatches=result.mismatches,
            errors=result.errors,
        )
        return result

    def reconcile_profile(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
    ) -> ReconciliationIssue | None:
        if not profile.provider_subscription_id:
            return None

        provider = self._payment_provider_factory()
        try:
            snapshot = provider.retrieve_subscription(
                subscription_id=profile.provider_subscription_id
            )
        except PaymentProviderError as exc:
            logger.warning(
                "reconciliation_provider_error profile_id=%s provider=%s error=%s",
                profile.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.reconciliation.error",
                category="payment",
                severity="error",
                profile_id=profile.id,
                user_id=profile.user_id,
                provider=profile.provider,
                reason=str(exc),
            )
            self._record_reconciliation_event(
                db=db,
                profile=profile,
                event_type="reconciliation_error",
                details={"error": str(exc), "provider": profile.provider},
            )
            return ReconciliationIssue(
                user_id=profile.user_id,
                profile_id=profile.id,
                provider_subscription_id=profile.provider_subscription_id,
                issue_type="error",
                details={"error": str(exc)},
            )

        desired = self._map_provider_snapshot(snapshot, profile=profile)
        changes: dict[str, Any] = {}
        if profile.status != desired["status"]:
            changes["status"] = desired["status"]
        if profile.last_payment_status != desired["last_payment_status"]:
            changes["last_payment_status"] = desired["last_payment_status"]
        if profile.will_renew != desired["will_renew"]:
            changes["will_renew"] = desired["will_renew"]
        if self._normalize_dt(profile.expires_at) != self._normalize_dt(
            desired["expires_at"]
        ):
            changes["expires_at"] = desired["expires_at"]
        if self._normalize_dt(profile.cancel_at) != self._normalize_dt(
            desired["cancel_at"]
        ):
            changes["cancel_at"] = desired["cancel_at"]
        if profile.current_plan_id != desired["plan_id"]:
            changes["current_plan_id"] = desired["plan_id"]
            if desired["plan_id"] == PLAN_FREE:
                changes["selected_plan_id"] = None

        user = db.query(User).filter(User.id == profile.user_id).first()
        if user is not None:
            desired_plan = desired.get("plan_id")
            if desired_plan and user.plan != desired_plan:
                changes["user_plan"] = desired_plan

        self._reconcile_payment_attempts(
            db=db,
            profile=profile,
            snapshot=snapshot,
            now=db_utc_now(),
        )

        if not changes:
            return None

        for field, value in changes.items():
            if field == "user_plan" and user is not None:
                subscription_service._sync_user_plan_projection(  # noqa: SLF001
                    user=user,
                    plan=value,
                    when=db_utc_now(),
                )
                db.add(user)
            else:
                setattr(profile, field, value)
        profile.updated_at = db_utc_now()
        db.add(profile)
        logger.info(
            "reconciliation_updated profile_id=%s user_id=%s changes=%s",
            profile.id,
            profile.user_id,
            self._serialize_changes(changes),
        )
        emit_event(
            "payment.reconciliation.mismatch",
            category="payment",
            severity="warn",
            profile_id=profile.id,
            user_id=profile.user_id,
            provider=profile.provider,
            changes=self._serialize_changes(changes),
        )
        self._record_reconciliation_event(
            db=db,
            profile=profile,
            event_type="reconciliation_mismatch",
            details={
                "provider_status": snapshot.status,
                "provider_invoice_status": snapshot.latest_invoice_status,
                "changes": self._serialize_changes(changes),
            },
        )
        db.commit()
        return ReconciliationIssue(
            user_id=profile.user_id,
            profile_id=profile.id,
            provider_subscription_id=profile.provider_subscription_id,
            issue_type="updated",
            details={"changes": self._serialize_changes(changes)},
        )

    def _reconcile_payment_attempts(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        snapshot: ProviderSubscriptionSnapshot,
        now,
    ) -> None:
        if not snapshot.latest_invoice_id:
            return
        attempt = (
            db.query(PaymentAttempt)
            .filter(
                PaymentAttempt.subscription_profile_id == profile.id,
                PaymentAttempt.provider_reference == snapshot.latest_invoice_id,
            )
            .order_by(PaymentAttempt.requested_at.desc(), PaymentAttempt.id.desc())
            .first()
        )
        if attempt is None:
            return

        desired_status = self._payment_status_from_invoice(snapshot.latest_invoice_status)
        if desired_status == attempt.status:
            return
        attempt.status = desired_status
        if desired_status == PAYMENT_STATUS_SUCCEEDED:
            attempt.completed_at = now
            attempt.failure_code = None
            attempt.failure_message = None
        elif desired_status in {PAYMENT_STATUS_FAILED, PAYMENT_STATUS_CANCELED}:
            attempt.completed_at = now
            attempt.failure_code = "INVOICE_STATUS"
            attempt.failure_message = (
                f"Invoice {snapshot.latest_invoice_id} status "
                f"{snapshot.latest_invoice_status}"
            )
        db.add(attempt)
        db.flush()

    @staticmethod
    def _serialize_changes(changes: dict[str, Any]) -> dict[str, Any]:
        serialized: dict[str, Any] = {}
        for key, value in changes.items():
            if hasattr(value, "isoformat"):
                serialized[key] = value.isoformat()
            else:
                serialized[key] = value
        return serialized

    @staticmethod
    def _normalize_dt(value):
        if value is None:
            return None
        return ensure_utc(value)

    @staticmethod
    def _map_provider_snapshot(
        snapshot: ProviderSubscriptionSnapshot,
        *,
        profile: SubscriptionProfile,
    ) -> dict[str, Any]:
        status = snapshot.status or "unknown"
        status_lower = status.lower()
        if status_lower in {"active", "trialing"}:
            mapped_status = SUBSCRIPTION_STATUS_ACTIVE
        elif status_lower in {"past_due", "unpaid"}:
            mapped_status = SUBSCRIPTION_STATUS_PAST_DUE
        elif status_lower in {"canceled", "incomplete_expired"}:
            mapped_status = SUBSCRIPTION_STATUS_CANCELED
        elif status_lower in {"incomplete"}:
            mapped_status = SUBSCRIPTION_STATUS_PENDING
        else:
            mapped_status = SUBSCRIPTION_STATUS_PENDING

        last_payment_status = PaymentReconciliationService._payment_status_from_invoice(
            snapshot.latest_invoice_status
        )
        if mapped_status == SUBSCRIPTION_STATUS_CANCELED:
            last_payment_status = PAYMENT_STATUS_CANCELED

        plan_id = profile.current_plan_id
        if mapped_status in {SUBSCRIPTION_STATUS_ACTIVE, SUBSCRIPTION_STATUS_PAST_DUE}:
            if plan_id == PLAN_FREE and profile.selected_plan_id:
                plan_id = profile.selected_plan_id
        if mapped_status in {SUBSCRIPTION_STATUS_CANCELED}:
            plan_id = PLAN_FREE

        return {
            "status": mapped_status,
            "last_payment_status": last_payment_status,
            "will_renew": bool(not snapshot.cancel_at_period_end)
            if mapped_status in {SUBSCRIPTION_STATUS_ACTIVE, SUBSCRIPTION_STATUS_PAST_DUE}
            else False,
            "expires_at": snapshot.current_period_end,
            "cancel_at": snapshot.cancel_at,
            "plan_id": plan_id,
        }

    @staticmethod
    def _payment_status_from_invoice(status: str | None) -> str:
        if not status:
            return PAYMENT_STATUS_PENDING
        normalized = status.lower()
        if normalized in {"paid"}:
            return PAYMENT_STATUS_SUCCEEDED
        if normalized in {"open", "draft"}:
            return PAYMENT_STATUS_PENDING
        if normalized in {"uncollectible", "void", "failed"}:
            return PAYMENT_STATUS_FAILED
        if normalized in {"canceled"}:
            return PAYMENT_STATUS_CANCELED
        if normalized in {"requires_action", "action_required"}:
            return PAYMENT_STATUS_ACTION_REQUIRED
        return PAYMENT_STATUS_PENDING

    def _record_reconciliation_event(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        event_type: str,
        details: dict[str, Any],
    ) -> None:
        event = SubscriptionEvent(
            user_id=profile.user_id,
            subscription_profile_id=profile.id,
            event_type=event_type,
            previous_plan_id=profile.current_plan_id,
            plan_id=profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source="reconciliation",
            provider_reference=profile.provider_subscription_id,
            details_json=details,
            occurred_at=db_utc_now(),
        )
        db.add(event)
        db.flush()


payment_reconciliation_service = PaymentReconciliationService()
