from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import uuid4
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.observability import emit_event
from core.time_utils import db_utc_now
from models import PaymentAttempt, PaymentWebhookEvent, SubscriptionProfile, User
from plan_service import PLAN_FREE
from services.payment_webhook_verifier import (
    WebhookVerificationError,
    stripe_webhook_verifier,
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
    SubscriptionService,
    subscription_service,
)


logger = logging.getLogger(__name__)


class PaymentWebhookService:
    def __init__(self) -> None:
        self._stripe_verifier = stripe_webhook_verifier
        self._subscription_service: SubscriptionService = subscription_service

    def handle_stripe_webhook(
        self,
        *,
        db: Session,
        payload: bytes,
        signature: str | None,
    ) -> dict[str, Any]:
        try:
            event = self._stripe_verifier.verify(payload=payload, signature=signature)
        except WebhookVerificationError as exc:
            emit_event(
                "payment.webhook.signature_invalid",
                category="payment",
                severity="warn",
                provider="stripe",
                reason=str(exc),
            )
            record = PaymentWebhookEvent(
                provider="stripe",
                event_id=f"invalid_{uuid4()}",
                event_type="signature_invalid",
                status="failed",
                signature_valid=False,
                error_message=str(exc),
                payload_json=None,
                received_at=db_utc_now(),
            )
            db.add(record)
            db.commit()
            logger.warning(
                "webhook_signature_invalid provider=stripe error=%s",
                str(exc),
            )
            raise HTTPException(status_code=400, detail=str(exc))

        event_id = str(event.get("id") or "").strip()
        event_type = str(event.get("type") or "").strip()
        if not event_id or not event_type:
            raise HTTPException(status_code=400, detail="Webhook event is missing id or type")

        emit_event(
            "payment.webhook.received",
            category="payment",
            provider="stripe",
            event_id=event_id,
            event_type=event_type,
        )
        record = self._get_webhook_record(db=db, provider="stripe", event_id=event_id)
        if record is not None and record.status in {"processed", "ignored", "duplicate", "processing"}:
            logger.info(
                "webhook_duplicate provider=stripe event_id=%s event_type=%s status=%s",
                event_id,
                event_type,
                record.status,
            )
            emit_event(
                "payment.webhook.duplicate",
                category="payment",
                severity="warn",
                provider="stripe",
                event_id=event_id,
                event_type=event_type,
                status=record.status,
            )
            return {
                "received": True,
                "provider": "stripe",
                "event_id": event_id,
                "event_type": event_type,
                "status": "duplicate",
            }

        now = db_utc_now()
        if record is None:
            record = PaymentWebhookEvent(
                provider="stripe",
                event_id=event_id,
                event_type=event_type,
                status="processing",
                signature_valid=True,
                payload_json=event,
                received_at=now,
            )
        else:
            record.status = "processing"
            record.signature_valid = True
            record.payload_json = event
            record.error_message = None
        db.add(record)
        db.flush()

        try:
            result = self._dispatch_verified_event(db=db, event=event, record=record)
            record.status = result["status"]
            record.processed_at = db_utc_now()
            record.provider_customer_id = result.get("provider_customer_id")
            record.provider_subscription_id = result.get("provider_subscription_id")
            record.provider_invoice_id = result.get("provider_invoice_id")
            record.provider_session_id = result.get("provider_session_id")
            record.subscription_profile_id = result.get("subscription_profile_id")
            db.add(record)
            db.commit()
            logger.info(
                "webhook_processed provider=stripe event_id=%s event_type=%s status=%s profile_id=%s",
                event_id,
                event_type,
                record.status,
                record.subscription_profile_id,
            )
            emit_event(
                "payment.webhook.processed",
                category="payment",
                provider="stripe",
                event_id=event_id,
                event_type=event_type,
                status=result["status"],
                subscription_profile_id=record.subscription_profile_id,
            )
            return {
                "received": True,
                "provider": "stripe",
                "event_id": event_id,
                "event_type": event_type,
                "status": result["status"],
            }
        except HTTPException:
            db.rollback()
            raise
        except Exception as exc:
            db.rollback()
            record = self._get_webhook_record(db=db, provider="stripe", event_id=event_id)
            if record is not None:
                record.status = "failed"
                record.error_message = str(exc)
                record.processed_at = db_utc_now()
                db.add(record)
                db.commit()
            logger.exception(
                "webhook_failed provider=stripe event_id=%s event_type=%s error=%s",
                event_id,
                event_type,
                str(exc),
            )
            emit_event(
                "payment.webhook.failed",
                category="payment",
                severity="error",
                provider="stripe",
                event_id=event_id,
                event_type=event_type,
                reason=str(exc),
            )
            raise

    def _dispatch_verified_event(
        self,
        *,
        db: Session,
        event: dict[str, Any],
        record: PaymentWebhookEvent,
    ) -> dict[str, Any]:
        event_type = str(event.get("type") or "")
        data_object = self._event_object(event)
        if event_type == "checkout.session.completed":
            return self._handle_checkout_session_completed(db=db, obj=data_object)
        if event_type == "invoice.paid":
            return self._handle_invoice_paid(db=db, obj=data_object)
        if event_type == "invoice.payment_failed":
            return self._handle_invoice_payment_failed(db=db, obj=data_object)
        if event_type == "customer.subscription.updated":
            return self._handle_subscription_updated(db=db, obj=data_object)
        if event_type == "customer.subscription.deleted":
            return self._handle_subscription_deleted(db=db, obj=data_object)

        return {
            "status": "ignored",
            "provider_customer_id": self._as_str(data_object.get("customer")),
            "provider_subscription_id": self._subscription_id_from_object(data_object),
            "provider_invoice_id": self._invoice_id_from_object(data_object, event_type=event_type),
            "provider_session_id": self._session_id_from_object(data_object, event_type=event_type),
            "subscription_profile_id": None,
        }

    def _handle_checkout_session_completed(self, *, db: Session, obj: dict[str, Any]) -> dict[str, Any]:
        user, profile = self._resolve_profile_context(db=db, obj=obj)
        if user is None or profile is None:
            return self._ignored_result(obj=obj, event_type="checkout.session.completed")

        now = db_utc_now()
        plan_id = self._infer_plan_id(obj=obj, profile=profile)
        checkout = self._checkout_result_from_object(obj)
        profile.provider = "stripe"
        profile.provider_customer_id = checkout.customer_id or profile.provider_customer_id
        profile.provider_subscription_id = checkout.subscription_id or profile.provider_subscription_id
        profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
        db.add(profile)

        attempt = self._upsert_payment_attempt(
            db=db,
            user=user,
            profile=profile,
            provider_reference=checkout.session_id,
            plan_id=plan_id or profile.selected_plan_id or profile.current_plan_id,
            attempt_type="checkout",
            status=PAYMENT_STATUS_SUCCEEDED,
            amount_cents=self._amount_cents_from_object(obj=obj, fallback_plan=plan_id),
            completed=True,
            metadata_json=self._checkout_attempt_metadata(checkout=checkout),
        )

        already_active_for_plan = (
            plan_id is not None
            and profile.current_plan_id == plan_id
            and profile.status == SUBSCRIPTION_STATUS_ACTIVE
        )
        if plan_id and not already_active_for_plan:
            self._subscription_service._activate_plan(  # noqa: SLF001
                db=db,
                user=user,
                plan=plan_id,
                source="webhook_checkout_completed",
                request_origin="webhook_checkout_completed",
                payment_attempt=attempt,
                checkout=checkout,
            )
        else:
            profile.status = profile.status or SUBSCRIPTION_STATUS_PENDING
            db.add(profile)

        self._subscription_service._record_subscription_event(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            event_type="checkout_completed",
            previous_plan_id=profile.current_plan_id,
            plan_id=plan_id or profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=PAYMENT_STATUS_SUCCEEDED,
            source="webhook_checkout_completed",
            details_json={
                "session_status": checkout.status,
                "payment_status": checkout.payment_status,
                "payment_intent_id": checkout.payment_intent_id,
            },
            provider_reference=checkout.session_id,
            occurred_at=now,
        )
        self._subscription_service._sync_payment_methods_from_provider_if_supported(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
        )
        return {
            "status": "processed",
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "provider_invoice_id": None,
            "provider_session_id": checkout.session_id,
            "subscription_profile_id": profile.id,
        }

    def _handle_invoice_paid(self, *, db: Session, obj: dict[str, Any]) -> dict[str, Any]:
        user, profile = self._resolve_profile_context(db=db, obj=obj)
        if user is None or profile is None:
            return self._ignored_result(obj=obj, event_type="invoice.paid")

        now = db_utc_now()
        invoice_id = self._invoice_id_from_object(obj, event_type="invoice.paid")
        plan_id = self._infer_plan_id(obj=obj, profile=profile)
        billing_reason = self._as_str(obj.get("billing_reason")) or "invoice"
        period_end = self._invoice_period_end(obj)
        amount_cents = int(obj.get("amount_paid") or obj.get("amount_due") or 0)

        profile.provider = "stripe"
        profile.provider_customer_id = self._as_str(obj.get("customer")) or profile.provider_customer_id
        profile.provider_subscription_id = self._subscription_id_from_object(obj) or profile.provider_subscription_id
        profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
        db.add(profile)

        attempt_type = "renewal" if billing_reason == "subscription_cycle" else "invoice_payment"
        attempt = self._upsert_payment_attempt(
            db=db,
            user=user,
            profile=profile,
            provider_reference=invoice_id,
            plan_id=plan_id or profile.current_plan_id,
            attempt_type=attempt_type,
            status=PAYMENT_STATUS_SUCCEEDED,
            amount_cents=amount_cents,
            completed=True,
            metadata_json={
                "billing_reason": billing_reason,
                "payment_intent_id": self._as_str(obj.get("payment_intent")),
                "subscription_id": profile.provider_subscription_id,
            },
        )

        should_activate = (
            plan_id is not None
            and (profile.current_plan_id != plan_id or profile.status != SUBSCRIPTION_STATUS_ACTIVE)
        )
        should_renew = (
            plan_id is not None
            and profile.current_plan_id == plan_id
            and profile.status == SUBSCRIPTION_STATUS_ACTIVE
            and billing_reason == "subscription_cycle"
        )

        if should_activate or should_renew:
            self._subscription_service._activate_plan(  # noqa: SLF001
                db=db,
                user=user,
                plan=plan_id or profile.current_plan_id,
                source="webhook_invoice_paid",
                request_origin="webhook_invoice_paid",
                payment_attempt=attempt,
            )
        else:
            if plan_id and profile.current_plan_id == PLAN_FREE:
                profile.current_plan_id = plan_id
                self._subscription_service._sync_user_plan_projection(user=user, plan=plan_id, when=now)  # noqa: SLF001
                db.add(user)
            if profile.status in {SUBSCRIPTION_STATUS_PENDING, SUBSCRIPTION_STATUS_PAST_DUE}:
                profile.status = SUBSCRIPTION_STATUS_ACTIVE
            if period_end is not None and (profile.expires_at is None or period_end > profile.expires_at):
                profile.expires_at = period_end
            profile.will_renew = not bool(obj.get("cancel_at_period_end"))
            db.add(profile)
            self._subscription_service._record_billing_transaction(  # noqa: SLF001
                db=db,
                user=user,
                profile=profile,
                plan_id=plan_id or profile.current_plan_id,
                transaction_type="invoice_paid",
                amount_cents=amount_cents,
                status="succeeded",
                provider_reference=invoice_id,
                effective_at=now,
                metadata_json={"billing_reason": billing_reason},
            )

        self._subscription_service._record_subscription_event(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            event_type="invoice_paid",
            previous_plan_id=profile.current_plan_id,
            plan_id=plan_id or profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=PAYMENT_STATUS_SUCCEEDED,
            source="webhook_invoice_paid",
            details_json={"billing_reason": billing_reason},
            provider_reference=invoice_id,
            occurred_at=now,
        )
        if period_end is not None and (profile.expires_at is None or period_end > profile.expires_at):
            profile.expires_at = period_end
            db.add(profile)
        return {
            "status": "processed",
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "provider_invoice_id": invoice_id,
            "provider_session_id": None,
            "subscription_profile_id": profile.id,
        }

    def _handle_invoice_payment_failed(self, *, db: Session, obj: dict[str, Any]) -> dict[str, Any]:
        user, profile = self._resolve_profile_context(db=db, obj=obj)
        if user is None or profile is None:
            return self._ignored_result(obj=obj, event_type="invoice.payment_failed")

        now = db_utc_now()
        invoice_id = self._invoice_id_from_object(obj, event_type="invoice.payment_failed")
        plan_id = self._infer_plan_id(obj=obj, profile=profile) or profile.current_plan_id
        amount_cents = int(obj.get("amount_due") or obj.get("amount_paid") or 0)
        failure_message = self._failure_message_from_invoice(obj)

        profile.provider = "stripe"
        profile.provider_customer_id = self._as_str(obj.get("customer")) or profile.provider_customer_id
        profile.provider_subscription_id = self._subscription_id_from_object(obj) or profile.provider_subscription_id
        profile.last_payment_status = PAYMENT_STATUS_FAILED
        profile.status = (
            SUBSCRIPTION_STATUS_PAST_DUE
            if profile.current_plan_id != PLAN_FREE
            else SUBSCRIPTION_STATUS_PENDING
        )
        profile.will_renew = True
        db.add(profile)

        self._upsert_payment_attempt(
            db=db,
            user=user,
            profile=profile,
            provider_reference=invoice_id,
            plan_id=plan_id,
            attempt_type="renewal",
            status=PAYMENT_STATUS_FAILED,
            amount_cents=amount_cents,
            completed=True,
            metadata_json={
                "billing_reason": self._as_str(obj.get("billing_reason")),
                "subscription_id": profile.provider_subscription_id,
            },
            failure_code="INVOICE_PAYMENT_FAILED",
            failure_message=failure_message,
        )
        self._subscription_service._record_subscription_event(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            event_type="invoice_payment_failed",
            previous_plan_id=profile.current_plan_id,
            plan_id=plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=PAYMENT_STATUS_FAILED,
            source="webhook_invoice_payment_failed",
            details_json={"message": failure_message},
            provider_reference=invoice_id,
            occurred_at=now,
        )
        self._subscription_service._record_billing_transaction(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            plan_id=plan_id,
            transaction_type="invoice_failed",
            amount_cents=amount_cents,
            status="failed",
            provider_reference=invoice_id,
            effective_at=now,
            metadata_json={"message": failure_message},
        )
        return {
            "status": "processed",
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "provider_invoice_id": invoice_id,
            "provider_session_id": None,
            "subscription_profile_id": profile.id,
        }

    def _handle_subscription_updated(self, *, db: Session, obj: dict[str, Any]) -> dict[str, Any]:
        user, profile = self._resolve_profile_context(db=db, obj=obj)
        if user is None or profile is None:
            return self._ignored_result(obj=obj, event_type="customer.subscription.updated")

        now = db_utc_now()
        provider_subscription_id = self._subscription_id_from_object(obj)
        provider_customer_id = self._as_str(obj.get("customer"))
        plan_id = self._infer_plan_id(obj=obj, profile=profile)
        previous_plan = profile.current_plan_id
        previous_status = profile.status

        profile.provider = "stripe"
        profile.provider_customer_id = provider_customer_id or profile.provider_customer_id
        profile.provider_subscription_id = provider_subscription_id or profile.provider_subscription_id
        profile.expires_at = self._timestamp_to_utc(obj.get("current_period_end")) or profile.expires_at
        profile.cancel_at = self._timestamp_to_utc(obj.get("cancel_at")) or profile.cancel_at

        provider_status = self._as_str(obj.get("status"))
        if provider_status in {"active", "trialing"}:
            profile.status = SUBSCRIPTION_STATUS_ACTIVE
            profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
            profile.will_renew = not bool(obj.get("cancel_at_period_end"))
            if plan_id:
                profile.current_plan_id = plan_id
                self._subscription_service._sync_user_plan_projection(user=user, plan=plan_id, when=now)  # noqa: SLF001
                db.add(user)
        elif provider_status in {"past_due", "unpaid"}:
            profile.status = SUBSCRIPTION_STATUS_PAST_DUE
            profile.last_payment_status = PAYMENT_STATUS_FAILED
            profile.will_renew = True
            if plan_id:
                profile.current_plan_id = plan_id
                self._subscription_service._sync_user_plan_projection(user=user, plan=plan_id, when=now)  # noqa: SLF001
                db.add(user)
        elif provider_status in {"incomplete", "incomplete_expired"}:
            profile.status = SUBSCRIPTION_STATUS_PENDING
            profile.last_payment_status = PAYMENT_STATUS_ACTION_REQUIRED
        elif provider_status == "canceled":
            profile.status = SUBSCRIPTION_STATUS_CANCELED
            profile.last_payment_status = PAYMENT_STATUS_CANCELED
            profile.will_renew = False
            profile.current_plan_id = PLAN_FREE
            profile.selected_plan_id = None
            self._subscription_service._sync_user_plan_projection(user=user, plan=PLAN_FREE, when=now)  # noqa: SLF001
            db.add(user)
        db.add(profile)

        self._subscription_service._record_subscription_event(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            event_type="provider_subscription_updated",
            previous_plan_id=previous_plan,
            plan_id=profile.current_plan_id,
            previous_status=previous_status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source="webhook_subscription_updated",
            details_json={"provider_status": provider_status},
            provider_reference=provider_subscription_id,
            occurred_at=now,
        )
        return {
            "status": "processed",
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "provider_invoice_id": None,
            "provider_session_id": None,
            "subscription_profile_id": profile.id,
        }

    def _handle_subscription_deleted(self, *, db: Session, obj: dict[str, Any]) -> dict[str, Any]:
        user, profile = self._resolve_profile_context(db=db, obj=obj)
        if user is None or profile is None:
            return self._ignored_result(obj=obj, event_type="customer.subscription.deleted")

        now = db_utc_now()
        provider_subscription_id = self._subscription_id_from_object(obj)
        previous_plan = profile.current_plan_id
        previous_status = profile.status

        profile.provider = "stripe"
        profile.provider_customer_id = self._as_str(obj.get("customer")) or profile.provider_customer_id
        profile.provider_subscription_id = provider_subscription_id or profile.provider_subscription_id
        profile.cancel_at = self._timestamp_to_utc(obj.get("canceled_at")) or now
        profile.expires_at = self._timestamp_to_utc(obj.get("current_period_end")) or profile.expires_at
        profile.status = SUBSCRIPTION_STATUS_CANCELED
        profile.last_payment_status = PAYMENT_STATUS_CANCELED
        profile.will_renew = False
        profile.current_plan_id = PLAN_FREE
        profile.selected_plan_id = None
        db.add(profile)
        self._subscription_service._sync_user_plan_projection(user=user, plan=PLAN_FREE, when=now)  # noqa: SLF001
        db.add(user)

        self._subscription_service._record_subscription_event(  # noqa: SLF001
            db=db,
            user=user,
            profile=profile,
            event_type="cancel",
            previous_plan_id=previous_plan,
            plan_id=PLAN_FREE,
            previous_status=previous_status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source="webhook_subscription_deleted",
            details_json={"provider_status": "canceled"},
            provider_reference=provider_subscription_id,
            occurred_at=now,
        )
        if previous_plan != PLAN_FREE or previous_status != SUBSCRIPTION_STATUS_CANCELED:
            self._subscription_service._record_billing_transaction(  # noqa: SLF001
                db=db,
                user=user,
                profile=profile,
                plan_id=PLAN_FREE,
                transaction_type="cancel",
                amount_cents=0,
                status="succeeded",
                provider_reference=provider_subscription_id,
                effective_at=now,
                metadata_json={"source": "webhook_subscription_deleted"},
            )
        return {
            "status": "processed",
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "provider_invoice_id": None,
            "provider_session_id": None,
            "subscription_profile_id": profile.id,
        }

    def _resolve_profile_context(
        self,
        *,
        db: Session,
        obj: dict[str, Any],
    ) -> tuple[User | None, SubscriptionProfile | None]:
        metadata = self._metadata_from_object(obj)
        profile = None
        user = None

        profile_id = self._as_int(metadata.get("profile_id"))
        if profile_id is not None:
            profile = db.query(SubscriptionProfile).filter(SubscriptionProfile.id == profile_id).first()

        if profile is None:
            subscription_id = self._subscription_id_from_object(obj)
            if subscription_id:
                profile = (
                    db.query(SubscriptionProfile)
                    .filter(SubscriptionProfile.provider_subscription_id == subscription_id)
                    .first()
                )

        if profile is None:
            customer_id = self._as_str(obj.get("customer"))
            if customer_id:
                profile = (
                    db.query(SubscriptionProfile)
                    .filter(SubscriptionProfile.provider_customer_id == customer_id)
                    .first()
                )

        if profile is None:
            user_id = self._as_int(metadata.get("user_id"))
            if user_id is not None:
                user = db.query(User).filter(User.id == user_id).first()
                if user is not None:
                    profile = self._subscription_service._ensure_subscription_profile(db=db, user=user)  # noqa: SLF001

        if profile is not None and user is None:
            user = profile.user or db.query(User).filter(User.id == profile.user_id).first()

        return user, profile

    def _upsert_payment_attempt(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
        provider_reference: str | None,
        plan_id: str,
        attempt_type: str,
        status: str,
        amount_cents: int,
        completed: bool,
        metadata_json: dict[str, Any],
        failure_code: str | None = None,
        failure_message: str | None = None,
    ) -> PaymentAttempt:
        attempt = None
        if provider_reference:
            attempt = (
                db.query(PaymentAttempt)
                .filter(
                    PaymentAttempt.subscription_profile_id == profile.id,
                    PaymentAttempt.provider_reference == provider_reference,
                )
                .first()
            )
        if attempt is None:
            return self._subscription_service._record_payment_attempt(  # noqa: SLF001
                db=db,
                user=user,
                profile=profile,
                plan_id=plan_id,
                attempt_type=attempt_type,
                status=status,
                amount_cents=amount_cents,
                requested_at=db_utc_now(),
                completed_at=db_utc_now() if completed else None,
                metadata_json=metadata_json,
                provider_reference=provider_reference,
                failure_code=failure_code,
                failure_message=failure_message,
            )

        attempt.plan_id = plan_id
        attempt.attempt_type = attempt_type
        attempt.status = status
        attempt.amount_cents = amount_cents
        attempt.metadata_json = metadata_json
        attempt.failure_code = failure_code
        attempt.failure_message = failure_message
        attempt.completed_at = db_utc_now() if completed else attempt.completed_at
        db.add(attempt)
        db.flush()
        return attempt

    def _infer_plan_id(self, *, obj: dict[str, Any], profile: SubscriptionProfile | None) -> str | None:
        metadata = self._metadata_from_object(obj)
        for key in ("plan_id", "plan", "selected_plan_id"):
            value = self._normalize_plan(metadata.get(key))
            if value:
                return value

        price_id = self._price_id_from_object(obj)
        if price_id:
            price_plan = self._plan_from_price_id(price_id)
            if price_plan:
                return price_plan

        if profile is not None:
            if profile.selected_plan_id:
                return profile.selected_plan_id
            if profile.current_plan_id and profile.current_plan_id != PLAN_FREE:
                return profile.current_plan_id
        return None

    @staticmethod
    def _normalize_plan(value: Any) -> str | None:
        raw = str(value or "").strip().upper().replace("-", "_")
        return raw or None

    @staticmethod
    def _metadata_from_object(obj: dict[str, Any]) -> dict[str, Any]:
        metadata = obj.get("metadata")
        return metadata if isinstance(metadata, dict) else {}

    @staticmethod
    def _event_object(event: dict[str, Any]) -> dict[str, Any]:
        data = event.get("data")
        if not isinstance(data, dict):
            return {}
        obj = data.get("object")
        return obj if isinstance(obj, dict) else {}

    @staticmethod
    def _as_str(value: Any) -> str | None:
        if value is None:
            return None
        raw = str(value).strip()
        return raw or None

    @staticmethod
    def _as_int(value: Any) -> int | None:
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _timestamp_to_utc(value: Any) -> datetime | None:
        if value in (None, ""):
            return None
        try:
            return datetime.fromtimestamp(int(value), tz=timezone.utc)
        except (TypeError, ValueError, OSError):
            return None

    def _invoice_period_end(self, obj: dict[str, Any]) -> datetime | None:
        lines = obj.get("lines")
        if isinstance(lines, dict):
            data = lines.get("data")
            if isinstance(data, list):
                timestamps = [
                    self._timestamp_to_utc(((item.get("period") or {}).get("end")))
                    for item in data
                    if isinstance(item, dict)
                ]
                timestamps = [item for item in timestamps if item is not None]
                if timestamps:
                    return max(timestamps)
        return self._timestamp_to_utc(obj.get("current_period_end"))

    def _price_id_from_object(self, obj: dict[str, Any]) -> str | None:
        lines = obj.get("lines")
        if isinstance(lines, dict):
            data = lines.get("data")
            if isinstance(data, list):
                for item in data:
                    if not isinstance(item, dict):
                        continue
                    price = item.get("price")
                    if isinstance(price, dict) and price.get("id"):
                        return self._as_str(price.get("id"))
        items = obj.get("items")
        if isinstance(items, dict):
            data = items.get("data")
            if isinstance(data, list):
                for item in data:
                    if not isinstance(item, dict):
                        continue
                    price = item.get("price")
                    if isinstance(price, dict) and price.get("id"):
                        return self._as_str(price.get("id"))
        return None

    def _plan_from_price_id(self, price_id: str | None) -> str | None:
        if not price_id:
            return None
        from core.settings import settings

        if price_id == settings.stripe_price_premium_monthly:
            return "PREMIUM"
        if price_id == settings.stripe_price_family_plus_monthly:
            return "FAMILY_PLUS"
        return None

    @staticmethod
    def _subscription_id_from_object(obj: dict[str, Any]) -> str | None:
        if obj.get("object") == "subscription":
            subscription_id = obj.get("id")
        else:
            subscription_id = obj.get("subscription")
        return str(subscription_id).strip() if subscription_id else None

    @staticmethod
    def _invoice_id_from_object(obj: dict[str, Any], *, event_type: str) -> str | None:
        if event_type.startswith("invoice."):
            return str(obj.get("id")).strip() if obj.get("id") else None
        invoice_id = obj.get("invoice")
        return str(invoice_id).strip() if invoice_id else None

    @staticmethod
    def _session_id_from_object(obj: dict[str, Any], *, event_type: str) -> str | None:
        if event_type.startswith("checkout.session."):
            return str(obj.get("id")).strip() if obj.get("id") else None
        return None

    def _checkout_result_from_object(self, obj: dict[str, Any]):
        from services.payment_provider import CheckoutSessionResult

        return CheckoutSessionResult(
            provider="stripe",
            session_id=self._as_str(obj.get("id")) or "",
            checkout_url=self._as_str(obj.get("url")) or "",
            status=self._as_str(obj.get("status")) or "complete",
            payment_status=self._as_str(obj.get("payment_status")) or "paid",
            customer_id=self._as_str(obj.get("customer")),
            subscription_id=self._as_str(obj.get("subscription")),
            payment_intent_id=self._as_str(obj.get("payment_intent")),
            payment_method_id=self._as_str(obj.get("payment_method")),
            raw=obj,
        )

    def _amount_cents_from_object(self, *, obj: dict[str, Any], fallback_plan: str | None) -> int:
        amount_total = obj.get("amount_total")
        if amount_total is not None:
            try:
                return int(amount_total)
            except (TypeError, ValueError):
                pass
        if fallback_plan:
            return self._subscription_service._price_cents_for_plan(fallback_plan)  # noqa: SLF001
        return 0

    @staticmethod
    def _failure_message_from_invoice(obj: dict[str, Any]) -> str:
        last_error = obj.get("last_finalization_error")
        if isinstance(last_error, dict) and last_error.get("message"):
            return str(last_error["message"])
        return "Provider reported a failed invoice payment"

    @staticmethod
    def _checkout_attempt_metadata(checkout) -> dict[str, Any]:
        return {
            "provider": checkout.provider,
            "session_id": checkout.session_id,
            "checkout_url": checkout.checkout_url,
            "status": checkout.status,
            "payment_status": checkout.payment_status,
            "customer_id": checkout.customer_id,
            "subscription_id": checkout.subscription_id,
            "payment_intent_id": checkout.payment_intent_id,
            "payment_method_id": checkout.payment_method_id,
        }

    @staticmethod
    def _get_webhook_record(
        *,
        db: Session,
        provider: str,
        event_id: str,
    ) -> PaymentWebhookEvent | None:
        return (
            db.query(PaymentWebhookEvent)
            .filter(
                PaymentWebhookEvent.provider == provider,
                PaymentWebhookEvent.event_id == event_id,
            )
            .first()
        )

    def _ignored_result(self, *, obj: dict[str, Any], event_type: str) -> dict[str, Any]:
        return {
            "status": "ignored",
            "provider_customer_id": self._as_str(obj.get("customer")),
            "provider_subscription_id": self._subscription_id_from_object(obj),
            "provider_invoice_id": self._invoice_id_from_object(obj, event_type=event_type),
            "provider_session_id": self._session_id_from_object(obj, event_type=event_type),
            "subscription_profile_id": None,
        }


payment_webhook_service = PaymentWebhookService()
