"""Hard deletion of parent accounts and child data (audit finding #2).

Two entry points share one purge routine:

* ``delete_parent_account`` - DELETE /auth/account. Runs immediately after the
  parent re-enters their password (and a 2FA code when 2FA is on). Deletes the
  parent, every child (soft-deleted ones too) and all their data. Billing
  history rows are kept for accounting but lose every link to the person.
* ``purge_soft_deleted_children`` - removes children whose soft delete is older
  than the grace period (``CHILD_PURGE_GRACE_DAYS``, default 30).

Every table is deleted explicitly instead of relying on database
``ON DELETE CASCADE``, so the result is the same on SQLite and Postgres and
does not depend on which FKs happen to declare a cascade.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from auth import verify_password
from core.redis_client import get_redis_client
from core.report_cache import invalidate_report_cache
from core.time_utils import to_db_utc, utc_now
from models import (
    ActivitySession,
    AiBuddyMessage,
    AiBuddySession,
    AiInteraction,
    BillingTransaction,
    ChildActivityEvent,
    ChildBlockedApp,
    ChildBlockedSite,
    ChildDailyActivitySummary,
    ChildMoodEntry,
    ChildParentalControlSetting,
    ChildProfile,
    ChildScheduleRule,
    ChildSessionLog,
    LessonProgress,
    Notification,
    ParentalControl,
    PaymentAttempt,
    PaymentMethod,
    PaymentWebhookEvent,
    PrivacySetting,
    RewardRedemption,
    ScreenTimeLog,
    SubscriptionEvent,
    SubscriptionProfile,
    SupportTicket,
    SupportTicketMessage,
    User,
)
from services.two_factor_service import two_factor_service

logger = logging.getLogger(__name__)

# Tables whose rows belong to exactly one child (all keyed by ``child_id``).
_CHILD_SCOPED_MODELS = (
    ChildSessionLog,
    ChildActivityEvent,
    ActivitySession,
    LessonProgress,
    ChildMoodEntry,
    RewardRedemption,
    ScreenTimeLog,
    AiInteraction,
    AiBuddyMessage,
    ChildDailyActivitySummary,
)


def child_purge_grace_days() -> int:
    try:
        value = int((os.getenv("CHILD_PURGE_GRACE_DAYS") or "30").strip())
    except (TypeError, ValueError):
        value = 30
    return max(value, 1)


class AccountDeletionService:
    # ── shared purge ───────────────────────────────────────────────────────

    def _purge_children(self, db: Session, child_ids: list[int]) -> int:
        """Delete the given children and every row that belongs to them."""
        if not child_ids:
            return 0

        setting_ids = [
            row.id
            for row in db.query(ChildParentalControlSetting.id)
            .filter(ChildParentalControlSetting.child_id.in_(child_ids))
            .all()
        ]
        if setting_ids:
            for model in (ChildScheduleRule, ChildBlockedApp, ChildBlockedSite):
                db.query(model).filter(model.setting_id.in_(setting_ids)).delete(
                    synchronize_session=False
                )
            db.query(ChildParentalControlSetting).filter(
                ChildParentalControlSetting.id.in_(setting_ids)
            ).delete(synchronize_session=False)

        for model in _CHILD_SCOPED_MODELS:
            db.query(model).filter(model.child_id.in_(child_ids)).delete(synchronize_session=False)
        # Messages are gone above; now their sessions.
        db.query(AiBuddySession).filter(AiBuddySession.child_id.in_(child_ids)).delete(
            synchronize_session=False
        )
        db.query(Notification).filter(Notification.child_id.in_(child_ids)).delete(
            synchronize_session=False
        )
        deleted = (
            db.query(ChildProfile)
            .filter(ChildProfile.id.in_(child_ids))
            .delete(synchronize_session=False)
        )
        self._forget_child_runtime_state(child_ids)
        return int(deleted or 0)

    @staticmethod
    def _forget_child_runtime_state(child_ids: list[int]) -> None:
        """Best-effort cleanup of login counters / device bindings in Redis."""
        rc = get_redis_client()
        if rc is None:
            from services import child_service as child_module

            for cid in child_ids:
                child_module._FAILED_ATTEMPTS.pop(child_module._child_failed_key(cid), None)
                child_module._DEVICE_BINDINGS.pop(cid, None)
            return
        keys = [f"child:failed:{cid}" for cid in child_ids]
        keys += [f"child:device:{cid}" for cid in child_ids]
        try:
            rc.delete(*keys)
        except Exception as exc:  # pragma: no cover - Redis outage only
            logger.error("child_purge_redis_cleanup_failed error=%s", exc)

    # ── parent account deletion ────────────────────────────────────────────

    def delete_parent_account(
        self,
        *,
        db: Session,
        user: User,
        password: str,
        two_factor_code: str | None,
        payment_provider_factory=None,
    ) -> dict:
        if not password or not verify_password(password, user.password_hash):
            raise HTTPException(status_code=401, detail="Password is incorrect")
        two_factor_service.require_parent_login_code(account=user, code=two_factor_code)

        user_id = int(user.id)
        profile = (
            db.query(SubscriptionProfile).filter(SubscriptionProfile.user_id == user_id).first()
        )

        # 1. Stop billing first. If the provider can't be reached we abort, so a
        #    deleted account is never left with a live paid subscription.
        self._delete_provider_customer(profile, payment_provider_factory)

        # 2. Children (including soft-deleted ones) and all their data.
        child_ids = [
            row.id for row in db.query(ChildProfile.id).filter(ChildProfile.parent_id == user_id)
        ]
        children_deleted = self._purge_children(db, child_ids)

        # 3. Parent-owned rows.
        ticket_ids = [
            row.id for row in db.query(SupportTicket.id).filter(SupportTicket.user_id == user_id)
        ]
        if ticket_ids:
            db.query(SupportTicketMessage).filter(
                SupportTicketMessage.ticket_id.in_(ticket_ids)
            ).delete(synchronize_session=False)
            db.query(SupportTicket).filter(SupportTicket.id.in_(ticket_ids)).delete(
                synchronize_session=False
            )
        db.query(SupportTicketMessage).filter(SupportTicketMessage.user_id == user_id).update(
            {SupportTicketMessage.user_id: None}, synchronize_session=False
        )
        session_ids = [
            row.id
            for row in db.query(AiBuddySession.id).filter(AiBuddySession.parent_user_id == user_id)
        ]
        if session_ids:
            db.query(AiBuddyMessage).filter(AiBuddyMessage.session_id.in_(session_ids)).delete(
                synchronize_session=False
            )
            db.query(AiBuddySession).filter(AiBuddySession.id.in_(session_ids)).delete(
                synchronize_session=False
            )
        for model in (Notification, PrivacySetting, ParentalControl, PaymentMethod):
            db.query(model).filter(model.user_id == user_id).delete(synchronize_session=False)
        # Any leftover per-child settings created by this parent.
        db.query(ChildParentalControlSetting).filter(
            ChildParentalControlSetting.parent_id == user_id
        ).delete(synchronize_session=False)

        # 4. Billing history is kept for accounting, but anonymised: no user,
        #    no profile link, and webhook payloads (which hold the email) wiped.
        for model in (SubscriptionEvent, BillingTransaction, PaymentAttempt):
            db.query(model).filter(model.user_id == user_id).update(
                {model.user_id: None}, synchronize_session=False
            )
        if profile is not None:
            for model in (SubscriptionEvent, BillingTransaction, PaymentAttempt):
                db.query(model).filter(model.subscription_profile_id == profile.id).update(
                    {model.subscription_profile_id: None}, synchronize_session=False
                )
            webhook_filter = PaymentWebhookEvent.subscription_profile_id == profile.id
            if profile.provider_customer_id:
                webhook_filter = webhook_filter | (
                    PaymentWebhookEvent.provider_customer_id == profile.provider_customer_id
                )
            db.query(PaymentWebhookEvent).filter(webhook_filter).update(
                {
                    PaymentWebhookEvent.payload_json: None,
                    PaymentWebhookEvent.subscription_profile_id: None,
                },
                synchronize_session=False,
            )
            db.query(SubscriptionProfile).filter(SubscriptionProfile.id == profile.id).delete(
                synchronize_session=False
            )

        # 5. The account itself.
        db.query(User).filter(User.id == user_id).delete(synchronize_session=False)
        db.commit()
        invalidate_report_cache(user_id)

        logger.info(
            "parent_account_deleted user_id=%s children_deleted=%s", user_id, children_deleted
        )
        return {"success": True, "children_deleted": children_deleted}

    @staticmethod
    def _delete_provider_customer(profile, payment_provider_factory) -> None:
        if profile is None or not profile.provider_customer_id:
            return
        if profile.provider in (None, "", "internal"):
            return
        if payment_provider_factory is None:
            from services.subscription_service import subscription_service

            payment_provider_factory = subscription_service._payment_provider
        provider = payment_provider_factory()
        if getattr(provider, "provider_key", None) != profile.provider:
            logger.error(
                "account_delete_provider_mismatch profile_provider=%s configured=%s",
                profile.provider,
                getattr(provider, "provider_key", None),
            )
            raise HTTPException(
                status_code=503,
                detail="Billing provider is unavailable. Please try again later.",
            )
        try:
            provider.delete_customer(customer_id=profile.provider_customer_id)
        except Exception as exc:
            # Already gone (e.g. a previous attempt deleted it in Stripe but the
            # DB step failed): treat as done so the parent can still finish.
            if getattr(exc, "code", None) == "resource_missing":
                logger.info(
                    "account_delete_provider_customer_already_gone profile_id=%s", profile.id
                )
                return
            logger.error(
                "account_delete_provider_failed profile_id=%s error_type=%s",
                profile.id,
                type(exc).__name__,
            )
            raise HTTPException(
                status_code=502,
                detail="Could not cancel your subscription. Please try again later.",
            )

    # ── soft-deleted child purge ───────────────────────────────────────────

    def purge_soft_deleted_children(self, db: Session, *, now: datetime | None = None) -> int:
        cutoff = to_db_utc((now or utc_now()) - timedelta(days=child_purge_grace_days()))
        child_ids = [
            row.id
            for row in db.query(ChildProfile.id).filter(
                ChildProfile.deleted_at.is_not(None),
                ChildProfile.deleted_at < cutoff,
            )
        ]
        deleted = self._purge_children(db, child_ids)
        db.commit()
        if deleted:
            logger.info("soft_deleted_children_purged count=%s", deleted)
        return deleted


account_deletion_service = AccountDeletionService()


def data_purge_enabled() -> bool:
    """Background purge runs in production by default; override with DATA_PURGE_ENABLED."""
    from core.settings import settings

    raw = (os.getenv("DATA_PURGE_ENABLED") or "").strip().lower()
    if raw in {"1", "true", "yes", "on"}:
        return True
    if raw in {"0", "false", "no", "off"}:
        return False
    return bool(settings.is_production)


def data_purge_interval_seconds() -> int:
    try:
        hours = float((os.getenv("DATA_PURGE_INTERVAL_HOURS") or "24").strip())
    except (TypeError, ValueError):
        hours = 24.0
    return int(max(hours, 1.0) * 3600)


def run_data_purge_once() -> int:
    """One purge pass with its own DB session (used by the background loop)."""
    from database import SessionLocal

    db = SessionLocal()
    try:
        return account_deletion_service.purge_soft_deleted_children(db)
    except Exception as exc:
        db.rollback()
        logger.error("soft_deleted_children_purge_failed error_type=%s", type(exc).__name__)
        return 0
    finally:
        db.close()
