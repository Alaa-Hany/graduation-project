from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any, Protocol

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.observability import emit_event
from core.settings import settings
from core.time_utils import db_utc_now, ensure_utc
from models import (
    BillingTransaction,
    PaymentAttempt,
    PaymentMethod,
    SubscriptionEvent,
    SubscriptionProfile,
    User,
)
from plan_service import (
    PLAN_FAMILY_PLUS,
    PLAN_FREE,
    get_plan_catalog,
    get_plan_features,
    get_plan_limits,
    get_user_plan,
    validate_plan_value,
)
from services.notification_service import notification_service
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PaymentProviderActionRequiredError,
    PaymentProviderError,
    PaymentProviderUnavailableError,
    PortalSessionResult,
    get_payment_provider,
)

PLAN_PREMIUM = "PREMIUM"

logger = logging.getLogger(__name__)

SUBSCRIPTION_STATUS_FREE = "free"
SUBSCRIPTION_STATUS_PENDING = "pending_activation"
SUBSCRIPTION_STATUS_ACTIVE = "active"
SUBSCRIPTION_STATUS_CANCELED = "canceled"
SUBSCRIPTION_STATUS_EXPIRED = "expired"
SUBSCRIPTION_STATUS_PAST_DUE = "past_due"

PAYMENT_STATUS_NOT_APPLICABLE = "not_applicable"
PAYMENT_STATUS_PENDING = "pending"
PAYMENT_STATUS_SUCCEEDED = "succeeded"
PAYMENT_STATUS_FAILED = "failed"
PAYMENT_STATUS_CANCELED = "canceled"
PAYMENT_STATUS_ACTION_REQUIRED = "action_required"


class PlanChangePayload(Protocol):
    plan: str


class SubscriptionSelectionPayload(Protocol):
    @property
    def resolved_plan(self) -> str: ...

    session_id: str | None


class RefundRequestPayload(Protocol):
    amount_cents: int | None
    reason: str | None


class SubscriptionService:
    def __init__(self) -> None:
        self._payment_provider_factory = get_payment_provider

    def get_subscription(self, *, db: Session, user: User) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)
        logger.info(
            "subscription_snapshot user_id=%s plan=%s status=%s provider=%s",
            user.id,
            profile.current_plan_id,
            profile.status,
            profile.provider,
        )
        return self._build_subscription_snapshot(db=db, user=user, profile=profile)

    def upgrade_subscription(
        self,
        *,
        payload: PlanChangePayload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        try:
            plan = validate_plan_value(payload.plan)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid plan")

        if plan == PLAN_FREE:
            return self.cancel_subscription(db=db, user=user)
        self._activate_plan(
            db=db,
            user=user,
            plan=plan,
            source="parent_upgrade",
            request_origin="upgrade",
        )
        db.commit()
        db.refresh(user)
        return self.get_subscription(db=db, user=user)

    def cancel_subscription(
        self,
        *,
        db: Session,
        user: User,
        source: str = "parent_cancel",
    ) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        now = db_utc_now()
        previous_plan = profile.current_plan_id
        previous_status = profile.status
        provider_reference = profile.provider_subscription_id

        if previous_plan != PLAN_FREE or profile.status != SUBSCRIPTION_STATUS_FREE:
            provider = self._payment_provider()
            if (
                provider.is_external
                and profile.provider_subscription_id
                and previous_status in {SUBSCRIPTION_STATUS_ACTIVE, SUBSCRIPTION_STATUS_PAST_DUE}
            ):
                try:
                    provider.cancel_subscription(subscription_id=profile.provider_subscription_id)
                except PaymentProviderError as exc:
                    raise HTTPException(status_code=502, detail=str(exc))
            profile.cancel_at = now
            profile.status = SUBSCRIPTION_STATUS_CANCELED
            profile.will_renew = False
            profile.last_payment_status = PAYMENT_STATUS_CANCELED
            profile.current_plan_id = PLAN_FREE
            profile.selected_plan_id = None
            self._sync_user_plan_projection(user=user, plan=PLAN_FREE, when=now)
            db.add(profile)
            db.add(user)

            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="cancel",
                previous_plan_id=previous_plan,
                plan_id=PLAN_FREE,
                previous_status=previous_status,
                status=profile.status,
                payment_status=profile.last_payment_status,
                source=source,
                details_json={"cancel_at": profile.cancel_at.isoformat()},
                provider_reference=provider_reference,
                occurred_at=now,
            )
            self._record_billing_transaction(
                db=db,
                user=user,
                profile=profile,
                plan_id=PLAN_FREE,
                transaction_type="cancel",
                amount_cents=0,
                status="succeeded",
                provider_reference=provider_reference,
                effective_at=now,
                metadata_json={"source": source},
            )
            notification_service.notify_subscription_changed(
                db,
                user=user,
                old_plan=previous_plan,
                new_plan=PLAN_FREE,
                source=source,
            )
            db.commit()
            db.refresh(user)
            db.refresh(profile)

        return self.get_subscription(db=db, user=user)

    def list_plans(self) -> list[dict[str, object]]:
        catalog = get_plan_catalog()
        plans: list[dict[str, object]] = []
        for plan_id, details in catalog.items():
            plans.append(
                {
                    "id": details["id"],
                    "name": details["name"],
                    "price": details["price"],
                    "period": details["period"],
                    "features": get_plan_features(plan_id),
                }
            )
        return plans

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

    def create_checkout_session(
        self,
        *,
        payload: SubscriptionSelectionPayload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        return self.select_subscription(payload=payload, db=db, user=user)

    def select_subscription(
        self,
        *,
        payload: SubscriptionSelectionPayload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        requested = payload.resolved_plan
        if not requested:
            raise HTTPException(status_code=422, detail="plan_id or plan_type is required")

        catalog = get_plan_catalog()
        if requested not in catalog:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid plan '{requested}'. Valid: {list(catalog.keys())}",
            )

        if requested == PLAN_FREE:
            status_payload = self.cancel_subscription(
                db=db,
                user=user,
                source="parent_select_free",
            )
            return self._selection_payload_from_snapshot(status_payload)

        profile = self._ensure_subscription_profile(db=db, user=user)
        now = db_utc_now()
        previous_plan = profile.current_plan_id
        previous_status = profile.status
        provider = self._payment_provider()
        profile.selected_plan_id = requested
        profile.status = SUBSCRIPTION_STATUS_PENDING
        profile.last_payment_status = PAYMENT_STATUS_PENDING
        profile.provider = provider.provider_key
        db.add(profile)

        try:
            checkout = self._create_provider_checkout_session(
                plan=requested,
                user=user,
                profile=profile,
            )
        except HTTPException as exc:
            emit_event(
                "payment.checkout.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                plan_id=requested,
                provider=profile.provider,
                reason=str(exc.detail),
                source="parent_select",
                request_origin="select",
            )
            logger.warning(
                "checkout_failed user_id=%s plan=%s provider=%s error=%s",
                user.id,
                requested,
                profile.provider,
                exc.detail,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="checkout_failed",
                previous_plan_id=previous_plan,
                plan_id=requested,
                previous_status=previous_status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source="parent_select",
                details_json={
                    "request_origin": "select",
                    "error": exc.detail,
                },
                provider_reference=profile.provider_subscription_id,
                occurred_at=now,
            )
            db.commit()
            raise
        emit_event(
            "payment.checkout.created",
            category="payment",
            user_id=user.id,
            profile_id=profile.id,
            plan_id=requested,
            provider=checkout.provider,
            session_id=checkout.session_id,
            checkout_status=checkout.status,
            payment_status=checkout.payment_status,
            source="parent_select",
            request_origin="select",
        )
        checkout_attempt = self._record_payment_attempt(
            db=db,
            user=user,
            profile=profile,
            plan_id=requested,
            attempt_type="checkout",
            status=(
                PAYMENT_STATUS_SUCCEEDED
                if self._checkout_is_paid(checkout)
                else PAYMENT_STATUS_PENDING
            ),
            amount_cents=self._price_cents_for_plan(requested),
            requested_at=now,
            completed_at=now if self._checkout_is_paid(checkout) else None,
            metadata_json=self._checkout_metadata(checkout=checkout, request_origin="select"),
            provider_reference=checkout.session_id,
        )
        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type="select",
            previous_plan_id=previous_plan,
            plan_id=requested,
            previous_status=previous_status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source="parent_select",
            details_json={
                "request_origin": "select",
                **self._checkout_metadata(checkout=checkout, request_origin="select"),
            },
            provider_reference=checkout.session_id,
            occurred_at=now,
        )

        if self._checkout_is_paid(checkout):
            logger.info(
                "checkout_completed user_id=%s plan=%s provider=%s session_id=%s",
                user.id,
                requested,
                checkout.provider,
                checkout.session_id,
            )
            emit_event(
                "payment.checkout.completed",
                category="payment",
                user_id=user.id,
                profile_id=profile.id,
                plan_id=requested,
                provider=checkout.provider,
                session_id=checkout.session_id,
                checkout_status=checkout.status,
                payment_status=checkout.payment_status,
            )
            self._activate_plan(
                db=db,
                user=user,
                plan=requested,
                source="parent_select",
                request_origin="select",
                payment_attempt=checkout_attempt,
                checkout=checkout,
            )
        else:
            profile.provider_customer_id = checkout.customer_id or profile.provider_customer_id
            profile.provider_subscription_id = (
                checkout.subscription_id or profile.provider_subscription_id
            )
            db.add(profile)

        db.commit()
        db.refresh(user)
        db.refresh(profile)
        logger.info(
            "checkout_snapshot user_id=%s plan=%s status=%s payment_status=%s",
            user.id,
            profile.current_plan_id,
            profile.status,
            profile.last_payment_status,
        )
        if checkout.customer_id:
            self._sync_payment_methods_from_provider_if_supported(
                db=db,
                user=user,
                profile=profile,
            )

        selection_payload = self._build_status_payload(user=user, profile=profile)
        selection_payload.update(self._build_checkout_payload(checkout=checkout))
        return selection_payload

    def activate_subscription(
        self,
        *,
        payload: SubscriptionSelectionPayload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        requested = payload.resolved_plan
        if not requested:
            raise HTTPException(status_code=422, detail="plan_id or plan_type is required")
        if requested == PLAN_FREE:
            status_payload = self.cancel_subscription(
                db=db,
                user=user,
                source="parent_activate_free",
            )
            return self._selection_payload_from_snapshot(status_payload)

        profile = self._ensure_subscription_profile(db=db, user=user)
        provider = self._payment_provider()
        if not provider.is_external:
            self._activate_plan(
                db=db,
                user=user,
                plan=requested,
                source="parent_activate",
                request_origin="activate",
            )
            db.commit()
            db.refresh(user)
            profile = self._ensure_subscription_profile(db=db, user=user)
            return self._build_status_payload(user=user, profile=profile)

        checkout_attempt = self._latest_checkout_attempt(
            db=db,
            profile=profile,
            plan_id=requested,
            session_id=payload.session_id,
        )
        session_id = payload.session_id or (
            checkout_attempt.provider_reference if checkout_attempt is not None else None
        )
        if not session_id:
            raise HTTPException(status_code=422, detail="session_id is required to activate this plan")

        try:
            checkout = provider.retrieve_checkout_session(session_id=session_id)
        except PaymentProviderUnavailableError as exc:
            emit_event(
                "subscription.activation.failed",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                plan_id=requested,
                provider=profile.provider,
                session_id=session_id,
                reason=str(exc),
                code="PROVIDER_UNAVAILABLE",
            )
            logger.warning(
                "activate_checkout_unavailable user_id=%s plan=%s session_id=%s error=%s",
                user.id,
                requested,
                session_id,
                str(exc),
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="activation_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=requested,
                previous_status=profile.status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source="parent_activate",
                details_json={"error": str(exc), "code": "PROVIDER_UNAVAILABLE"},
                provider_reference=session_id,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=503, detail=str(exc))
        except PaymentProviderError as exc:
            emit_event(
                "subscription.activation.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                plan_id=requested,
                provider=profile.provider,
                session_id=session_id,
                reason=str(exc),
                code="PROVIDER_ERROR",
            )
            logger.warning(
                "activate_checkout_failed user_id=%s plan=%s session_id=%s error=%s",
                user.id,
                requested,
                session_id,
                str(exc),
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="activation_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=requested,
                previous_status=profile.status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source="parent_activate",
                details_json={"error": str(exc), "code": "PROVIDER_ERROR"},
                provider_reference=session_id,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=502, detail=str(exc))

        now = db_utc_now()
        if checkout_attempt is None:
            checkout_attempt = self._record_payment_attempt(
                db=db,
                user=user,
                profile=profile,
                plan_id=requested,
                attempt_type="activation",
                status=PAYMENT_STATUS_PENDING,
                amount_cents=self._price_cents_for_plan(requested),
                requested_at=now,
                completed_at=None,
                metadata_json=self._checkout_metadata(checkout=checkout, request_origin="activate"),
                provider_reference=checkout.session_id,
            )

        checkout_attempt.provider_reference = checkout.session_id
        checkout_attempt.metadata_json = self._checkout_metadata(
            checkout=checkout,
            request_origin="activate",
        )

        if not self._checkout_is_paid(checkout):
            logger.info(
                "activate_pending user_id=%s plan=%s session_id=%s status=%s payment_status=%s",
                user.id,
                requested,
                checkout.session_id,
                checkout.status,
                checkout.payment_status,
            )
            emit_event(
                "subscription.activation.pending",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                plan_id=requested,
                provider=checkout.provider,
                session_id=checkout.session_id,
                checkout_status=checkout.status,
                payment_status=checkout.payment_status,
            )
            checkout_attempt.status = self._payment_status_from_checkout(checkout)
            checkout_attempt.failure_code = "PAYMENT_NOT_COMPLETED"
            checkout_attempt.failure_message = (
                f"Checkout session {checkout.session_id} is {checkout.status}/{checkout.payment_status}"
            )
            db.add(checkout_attempt)
            profile.last_payment_status = checkout_attempt.status
            profile.provider_customer_id = checkout.customer_id or profile.provider_customer_id
            profile.provider_subscription_id = (
                checkout.subscription_id or profile.provider_subscription_id
            )
            db.add(profile)
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="failure",
                previous_plan_id=profile.current_plan_id,
                plan_id=requested,
                previous_status=profile.status,
                status=profile.status,
                payment_status=checkout_attempt.status,
                source="parent_activate",
                details_json={
                    "request_origin": "activate",
                    **self._checkout_metadata(checkout=checkout, request_origin="activate"),
                },
                provider_reference=checkout.session_id,
                occurred_at=now,
            )
            db.commit()
            raise HTTPException(status_code=409, detail="Payment is not completed yet")

        logger.info(
            "activate_success user_id=%s plan=%s session_id=%s provider=%s",
            user.id,
            requested,
            checkout.session_id,
            checkout.provider,
        )
        emit_event(
            "subscription.activation.succeeded",
            category="payment",
            user_id=user.id,
            profile_id=profile.id,
            plan_id=requested,
            provider=checkout.provider,
            session_id=checkout.session_id,
            checkout_status=checkout.status,
            payment_status=checkout.payment_status,
        )
        checkout_attempt.status = PAYMENT_STATUS_SUCCEEDED
        checkout_attempt.completed_at = now
        checkout_attempt.failure_code = None
        checkout_attempt.failure_message = None
        db.add(checkout_attempt)
        self._activate_plan(
            db=db,
            user=user,
            plan=requested,
            source="parent_activate",
            request_origin="activate",
            payment_attempt=checkout_attempt,
            checkout=checkout,
        )
        db.commit()
        db.refresh(user)
        profile = self._ensure_subscription_profile(db=db, user=user)
        self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)

        payload_out = self._build_status_payload(user=user, profile=profile)
        payload_out.update(self._build_checkout_payload(checkout=checkout))
        return payload_out

    def manage_subscription(self, *, db: Session, user: User) -> dict[str, object]:
        return self._create_portal_session(db=db, user=user, source="parent_manage")

    def billing_portal(self, *, db: Session, user: User) -> dict[str, object]:
        return self._create_portal_session(db=db, user=user, source="billing_portal")

    def refund_subscription(
        self,
        *,
        db: Session,
        user: User,
        source: str,
        amount_cents: int | None = None,
        reason: str | None = None,
    ) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        provider = self._payment_provider()
        latest_success = self._latest_successful_billing_transaction(db=db, profile=profile)
        payment_attempt = self._latest_succeeded_payment_attempt(db=db, profile=profile)
        payment_intent_id = None
        provider_reference = latest_success.provider_reference if latest_success else None
        if payment_attempt and isinstance(payment_attempt.metadata_json, dict):
            payment_intent_id = str(payment_attempt.metadata_json.get("payment_intent_id") or "") or None

        if not payment_intent_id and not provider_reference:
            logger.warning(
                "refund_failed_no_target user_id=%s provider=%s",
                user.id,
                profile.provider,
            )
            emit_event(
                "payment.refund.failed",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="NO_REFUND_TARGET",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="refund_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=profile.last_payment_status,
                source=source,
                details_json={"code": "NO_REFUND_TARGET"},
                provider_reference=provider_reference,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=409, detail="No refundable payment found")

        try:
            refund = provider.refund_payment(
                payment_intent_id=payment_intent_id,
                charge_id=None,
                amount_cents=amount_cents,
                reason=reason,
                metadata={
                    "user_id": str(user.id),
                    "profile_id": str(profile.id),
                    "source": source,
                },
            )
        except PaymentProviderActionRequiredError as exc:
            logger.warning(
                "refund_action_required user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.refund.failed",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="ACTION_REQUIRED",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="refund_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=profile.last_payment_status,
                source=source,
                details_json={"error": str(exc), "code": "ACTION_REQUIRED"},
                provider_reference=provider_reference,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=501, detail=str(exc))
        except PaymentProviderUnavailableError as exc:
            logger.warning(
                "refund_provider_unavailable user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.refund.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="PROVIDER_UNAVAILABLE",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="refund_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=profile.last_payment_status,
                source=source,
                details_json={"error": str(exc), "code": "PROVIDER_UNAVAILABLE"},
                provider_reference=provider_reference,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=503, detail=str(exc))
        except PaymentProviderError as exc:
            logger.warning(
                "refund_provider_failed user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.refund.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="PROVIDER_ERROR",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="refund_failed",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=profile.last_payment_status,
                source=source,
                details_json={"error": str(exc), "code": "PROVIDER_ERROR"},
                provider_reference=provider_reference,
                occurred_at=db_utc_now(),
            )
            db.commit()
            raise HTTPException(status_code=502, detail=str(exc))

        now = db_utc_now()
        logger.info(
            "refund_succeeded user_id=%s provider=%s refund_id=%s amount_cents=%s",
            user.id,
            refund.provider,
            refund.refund_id,
            refund.amount_cents,
        )
        emit_event(
            "payment.refund.succeeded",
            category="payment",
            user_id=user.id,
            profile_id=profile.id,
            provider=refund.provider,
            refund_id=refund.refund_id,
            amount_cents=refund.amount_cents,
            source=source,
        )
        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type="refund",
            previous_plan_id=profile.current_plan_id,
            plan_id=profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source=source,
            details_json={
                "refund_id": refund.refund_id,
                "amount_cents": refund.amount_cents,
                "currency": refund.currency.upper(),
                "reason": reason,
            },
            provider_reference=refund.refund_id,
            occurred_at=now,
        )
        self._record_billing_transaction(
            db=db,
            user=user,
            profile=profile,
            plan_id=profile.current_plan_id,
            transaction_type="refund",
            amount_cents=-abs(refund.amount_cents),
            status=refund.status,
            provider_reference=refund.refund_id or provider_reference,
            effective_at=now,
            metadata_json={
                "source": source,
                "payment_intent_id": refund.payment_intent_id,
                "charge_id": refund.charge_id,
            },
        )
        db.commit()
        return {
            "success": True,
            "refund_id": refund.refund_id,
            "status": refund.status,
            "amount_cents": refund.amount_cents,
            "currency": refund.currency.upper(),
        }

    def admin_override_subscription(
        self,
        *,
        db: Session,
        user: User,
        plan: str,
        source: str,
    ) -> dict[str, object]:
        try:
            normalized = validate_plan_value(plan)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid plan")
        if normalized == PLAN_FREE:
            return self.cancel_subscription(db=db, user=user, source=source)
        self._activate_plan(
            db=db,
            user=user,
            plan=normalized,
            source=source,
            request_origin="admin_override",
        )
        db.commit()
        db.refresh(user)
        return self.get_subscription(db=db, user=user)

    def sync_payment_methods(self, *, db: Session, user: User) -> list[dict[str, object]]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)
        methods = self._list_user_payment_methods(db=db, user=user)
        return [self._serialize_payment_method(method) for method in methods]

    def add_payment_method(
        self,
        *,
        db: Session,
        user: User,
        label: str,
        provider_method_id: str | None = None,
        set_default: bool = False,
    ) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        provider = self._payment_provider()
        if provider.is_external:
            if not profile.provider_customer_id:
                raise HTTPException(status_code=409, detail="No provider customer exists for this account")
            if not provider_method_id:
                raise HTTPException(status_code=422, detail="provider_method_id is required")
            try:
                method_ref = provider.attach_payment_method(
                    customer_id=profile.provider_customer_id,
                    payment_method_id=provider_method_id,
                    set_default=set_default,
                )
            except PaymentProviderUnavailableError as exc:
                raise HTTPException(status_code=503, detail=str(exc))
            except PaymentProviderError as exc:
                raise HTTPException(status_code=502, detail=str(exc))

            self._upsert_provider_payment_method(db=db, user=user, method_ref=method_ref)
            db.commit()
            self._sync_payment_methods_from_provider_if_supported(db=db, user=user, profile=profile)
            method = (
                db.query(PaymentMethod)
                .filter(
                    PaymentMethod.user_id == user.id,
                    PaymentMethod.provider_method_id == method_ref.method_id,
                    PaymentMethod.deleted_at.is_(None),
                )
                .first()
            )
            if method is None:
                raise HTTPException(status_code=500, detail="Payment method sync failed")
            return self._serialize_payment_method(method)

        method = PaymentMethod(user_id=user.id, label=label.strip(), provider=provider.provider_key)
        db.add(method)
        db.commit()
        db.refresh(method)
        return self._serialize_payment_method(method)

    def delete_payment_method(self, *, db: Session, user: User, method_id: int) -> None:
        method = (
            db.query(PaymentMethod)
            .filter(
                PaymentMethod.id == method_id,
                PaymentMethod.user_id == user.id,
                PaymentMethod.deleted_at.is_(None),
            )
            .first()
        )
        if not method:
            raise HTTPException(status_code=404, detail="Payment method not found")

        provider = self._payment_provider()
        if provider.is_external and method.provider_method_id:
            try:
                provider.detach_payment_method(payment_method_id=method.provider_method_id)
            except PaymentProviderUnavailableError as exc:
                raise HTTPException(status_code=503, detail=str(exc))
            except PaymentProviderError as exc:
                raise HTTPException(status_code=502, detail=str(exc))

        method.deleted_at = db_utc_now()
        db.add(method)
        db.commit()

    def _ensure_subscription_profile(self, *, db: Session, user: User) -> SubscriptionProfile:
        profile = getattr(user, "subscription_profile", None)
        if profile is not None:
            updated = False
            now = db_utc_now()
            plan = get_user_plan(user)
            if profile.current_plan_id != plan:
                profile.current_plan_id = plan
                updated = True
            if plan == PLAN_FREE:
                if profile.status == SUBSCRIPTION_STATUS_ACTIVE:
                    profile.status = SUBSCRIPTION_STATUS_FREE
                    updated = True
                if profile.last_payment_status == PAYMENT_STATUS_SUCCEEDED and not user.is_premium:
                    profile.last_payment_status = PAYMENT_STATUS_NOT_APPLICABLE
                    updated = True
                if profile.will_renew:
                    profile.will_renew = False
                    updated = True
            elif bool(user.is_active):
                if profile.status in (SUBSCRIPTION_STATUS_FREE, SUBSCRIPTION_STATUS_PENDING):
                    profile.status = SUBSCRIPTION_STATUS_ACTIVE
                    updated = True
                if profile.started_at is None:
                    profile.started_at = ensure_utc(user.updated_at or user.created_at or now)
                    updated = True
                if profile.expires_at is None:
                    profile.expires_at = profile.started_at + self._plan_duration(plan)
                    updated = True
                if not profile.will_renew:
                    profile.will_renew = True
                    updated = True
                if profile.last_payment_status == PAYMENT_STATUS_NOT_APPLICABLE:
                    profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
                    updated = True
            if updated:
                db.add(profile)
                db.flush()
            return profile

        now = db_utc_now()
        plan = get_user_plan(user)
        status = SUBSCRIPTION_STATUS_FREE
        started_at = None
        expires_at = None
        will_renew = False
        last_payment_status = PAYMENT_STATUS_NOT_APPLICABLE
        if plan != PLAN_FREE and bool(user.is_active):
            status = SUBSCRIPTION_STATUS_ACTIVE
            started_at = ensure_utc(user.updated_at or user.created_at or now)
            expires_at = started_at + self._plan_duration(plan)
            will_renew = True
            last_payment_status = PAYMENT_STATUS_SUCCEEDED

        profile = SubscriptionProfile(
            user_id=user.id,
            current_plan_id=plan,
            selected_plan_id=None,
            started_at=started_at,
            expires_at=expires_at,
            cancel_at=None,
            will_renew=will_renew,
            status=status,
            last_payment_status=last_payment_status,
            provider="internal",
        )
        db.add(profile)
        db.flush()
        user.subscription_profile = profile
        return profile

    def _activate_plan(
        self,
        *,
        db: Session,
        user: User,
        plan: str,
        source: str,
        request_origin: str,
        payment_attempt: PaymentAttempt | None = None,
        checkout: CheckoutSessionResult | None = None,
    ) -> SubscriptionProfile:
        profile = self._ensure_subscription_profile(db=db, user=user)
        now = db_utc_now()
        previous_plan = profile.current_plan_id
        previous_status = profile.status
        was_same_active_plan = (
            previous_plan == plan and profile.status == SUBSCRIPTION_STATUS_ACTIVE and plan != PLAN_FREE
        )

        if payment_attempt is None:
            payment_attempt = self._record_payment_attempt(
                db=db,
                user=user,
                profile=profile,
                plan_id=plan,
                attempt_type="renewal" if was_same_active_plan else "activation",
                status=PAYMENT_STATUS_SUCCEEDED,
                amount_cents=self._price_cents_for_plan(plan),
                requested_at=now,
                completed_at=now,
                metadata_json={"request_origin": request_origin, "mode": "internal"},
                provider_reference=self._mock_session_id(plan=plan, user_id=user.id),
            )

        if checkout is not None:
            profile.provider = checkout.provider
            profile.provider_customer_id = checkout.customer_id or profile.provider_customer_id
            profile.provider_subscription_id = checkout.subscription_id or profile.provider_subscription_id

        profile.selected_plan_id = None
        profile.current_plan_id = plan
        profile.status = SUBSCRIPTION_STATUS_ACTIVE
        profile.started_at = ensure_utc(profile.started_at or now)
        if was_same_active_plan and profile.expires_at is not None and profile.expires_at > now:
            profile.expires_at = profile.expires_at + self._plan_duration(plan)
            event_type = "renew"
            transaction_type = "renewal"
        else:
            profile.started_at = now
            profile.expires_at = now + self._plan_duration(plan)
            profile.cancel_at = None
            event_type = "activate"
            transaction_type = "activation"
        profile.will_renew = True
        profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
        db.add(profile)

        self._sync_user_plan_projection(user=user, plan=plan, when=now)
        db.add(user)

        provider_reference = (
            checkout.subscription_id
            if checkout is not None and checkout.subscription_id
            else payment_attempt.provider_reference
        )
        details_json = {
            "request_origin": request_origin,
            "payment_attempt_id": payment_attempt.id,
        }
        if checkout is not None:
            details_json.update(self._checkout_metadata(checkout=checkout, request_origin=request_origin))

        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type=event_type,
            previous_plan_id=previous_plan,
            plan_id=plan,
            previous_status=previous_status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source=source,
            details_json=details_json,
            provider_reference=provider_reference,
            occurred_at=now,
        )
        self._record_billing_transaction(
            db=db,
            user=user,
            profile=profile,
            plan_id=plan,
            transaction_type=transaction_type,
            amount_cents=self._price_cents_for_plan(plan),
            status="succeeded",
            provider_reference=provider_reference,
            effective_at=now,
            metadata_json=details_json,
        )
        notification_service.notify_subscription_changed(
            db,
            user=user,
            old_plan=previous_plan,
            new_plan=plan,
            source=source,
        )
        db.flush()
        return profile

    def _sync_user_plan_projection(self, *, user: User, plan: str, when) -> None:
        user.plan = plan
        user.is_premium = plan != PLAN_FREE
        user.updated_at = when

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

    def _build_status_payload(self, *, user: User, profile: SubscriptionProfile) -> dict[str, object]:
        lifecycle = self._serialize_lifecycle(user=user, profile=profile)
        return {
            "current_plan_id": profile.current_plan_id,
            "is_active": bool(user.is_active),
            "status": profile.status,
            "started_at": lifecycle["started_at"],
            "expires_at": lifecycle["expires_at"],
            "cancel_at": lifecycle["cancel_at"],
            "will_renew": profile.will_renew,
            "last_payment_status": profile.last_payment_status,
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
            "expires_at": lifecycle.get("expires_at"),
            "cancel_at": lifecycle.get("cancel_at"),
            "will_renew": lifecycle.get("will_renew"),
            "last_payment_status": lifecycle.get("last_payment_status"),
        }

    def _serialize_lifecycle(self, *, user: User, profile: SubscriptionProfile) -> dict[str, object]:
        has_paid_access = bool(user.is_active) and profile.current_plan_id != PLAN_FREE
        return {
            "current_plan_id": profile.current_plan_id,
            "selected_plan_id": profile.selected_plan_id,
            "status": profile.status,
            "started_at": profile.started_at.isoformat() if profile.started_at else None,
            "expires_at": profile.expires_at.isoformat() if profile.expires_at else None,
            "cancel_at": profile.cancel_at.isoformat() if profile.cancel_at else None,
            "will_renew": bool(profile.will_renew),
            "last_payment_status": profile.last_payment_status,
            "provider": profile.provider,
            "provider_customer_id": profile.provider_customer_id,
            "provider_subscription_id": profile.provider_subscription_id,
            "is_active": bool(user.is_active),
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
        return {
            "id": method.id,
            "label": method.label,
            "provider": method.provider,
            "provider_customer_id": method.provider_customer_id,
            "provider_method_id": method.provider_method_id,
            "method_type": method.method_type,
            "brand": method.brand,
            "last4": method.last4,
            "exp_month": method.exp_month,
            "exp_year": method.exp_year,
            "is_default": bool(method.is_default),
            "created_at": method.created_at.isoformat() if method.created_at else None,
            "metadata_json": method.metadata_json or {},
        }

    def _payment_provider(self):
        return self._payment_provider_factory()

    def _create_provider_checkout_session(
        self,
        *,
        plan: str,
        user: User,
        profile: SubscriptionProfile,
    ) -> CheckoutSessionResult:
        provider = self._payment_provider()
        try:
            return provider.create_checkout_session(
                plan_id=plan,
                user_email=user.email,
                user_name=user.name,
                customer_id=profile.provider_customer_id,
                metadata={
                    "user_id": str(user.id),
                    "profile_id": str(profile.id),
                    "plan_id": plan,
                },
            )
        except PaymentProviderUnavailableError as exc:
            raise HTTPException(status_code=503, detail=str(exc))
        except PaymentProviderActionRequiredError as exc:
            raise HTTPException(status_code=409, detail=str(exc))
        except PaymentProviderError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @staticmethod
    def _checkout_is_paid(checkout: CheckoutSessionResult) -> bool:
        return checkout.status == "complete" and checkout.payment_status in {"paid", "succeeded"}

    @staticmethod
    def _payment_status_from_checkout(checkout: CheckoutSessionResult) -> str:
        if checkout.payment_status in {"paid", "succeeded"}:
            return PAYMENT_STATUS_SUCCEEDED
        if checkout.payment_status in {"requires_action", "action_required"}:
            return PAYMENT_STATUS_ACTION_REQUIRED
        if checkout.status in {"expired", "canceled"}:
            return PAYMENT_STATUS_CANCELED
        return PAYMENT_STATUS_PENDING

    @staticmethod
    def _checkout_metadata(
        *,
        checkout: CheckoutSessionResult,
        request_origin: str,
    ) -> dict[str, Any]:
        return {
            "request_origin": request_origin,
            "provider": checkout.provider,
            "checkout_url": checkout.checkout_url,
            "session_id": checkout.session_id,
            "checkout_status": checkout.status,
            "payment_status": checkout.payment_status,
            "customer_id": checkout.customer_id,
            "subscription_id": checkout.subscription_id,
            "payment_intent_id": checkout.payment_intent_id,
            "payment_method_id": checkout.payment_method_id,
        }

    def _build_checkout_payload(self, *, checkout: CheckoutSessionResult) -> dict[str, object]:
        return {
            "session_id": checkout.session_id,
            "payment_intent_url": checkout.checkout_url,
            "checkout_url": checkout.checkout_url,
            "provider": checkout.provider,
            "checkout_status": checkout.status,
            "payment_status": checkout.payment_status,
        }

    def _latest_checkout_attempt(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
        plan_id: str,
        session_id: str | None,
    ) -> PaymentAttempt | None:
        query = db.query(PaymentAttempt).filter(
            PaymentAttempt.subscription_profile_id == profile.id,
            PaymentAttempt.plan_id == plan_id,
            PaymentAttempt.attempt_type.in_(["checkout", "activation"]),
        )
        if session_id:
            query = query.filter(PaymentAttempt.provider_reference == session_id)
        return query.order_by(PaymentAttempt.requested_at.desc(), PaymentAttempt.id.desc()).first()

    def _latest_successful_billing_transaction(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
    ) -> BillingTransaction | None:
        return (
            db.query(BillingTransaction)
            .filter(
                BillingTransaction.subscription_profile_id == profile.id,
                BillingTransaction.status == "succeeded",
                BillingTransaction.transaction_type.in_(["activation", "renewal"]),
            )
            .order_by(BillingTransaction.effective_at.desc(), BillingTransaction.id.desc())
            .first()
        )

    def _latest_succeeded_payment_attempt(
        self,
        *,
        db: Session,
        profile: SubscriptionProfile,
    ) -> PaymentAttempt | None:
        return (
            db.query(PaymentAttempt)
            .filter(
                PaymentAttempt.subscription_profile_id == profile.id,
                PaymentAttempt.status == PAYMENT_STATUS_SUCCEEDED,
            )
            .order_by(PaymentAttempt.requested_at.desc(), PaymentAttempt.id.desc())
            .first()
        )

    def _create_portal_session(self, *, db: Session, user: User, source: str) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        now = db_utc_now()
        provider = self._payment_provider()
        provider_reference = profile.provider_customer_id or profile.provider_subscription_id

        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type="manage_request",
            previous_plan_id=profile.current_plan_id,
            plan_id=profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source=source,
            details_json={"operation": "billing_portal"},
            provider_reference=provider_reference,
            occurred_at=now,
        )

        if not profile.provider_customer_id:
            logger.warning(
                "portal_no_customer user_id=%s provider=%s",
                user.id,
                profile.provider,
            )
            emit_event(
                "payment.portal.failed",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="NO_CUSTOMER",
                source=source,
            )
            db.commit()
            raise HTTPException(status_code=409, detail="No billing customer is available for this account")

        try:
            portal = provider.create_billing_portal_session(
                customer_id=profile.provider_customer_id,
                metadata={
                    "user_id": str(user.id),
                    "profile_id": str(profile.id),
                    "source": source,
                },
            )
        except PaymentProviderActionRequiredError as exc:
            logger.warning(
                "portal_not_configured user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.portal.failed",
                category="payment",
                severity="warn",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="BILLING_PORTAL_NOT_CONFIGURED",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="failure",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source=source,
                details_json={
                    "operation": "billing_portal",
                    "code": "BILLING_PORTAL_NOT_CONFIGURED",
                },
                provider_reference=provider_reference,
                occurred_at=now,
            )
            db.commit()
            raise HTTPException(status_code=501, detail=str(exc))
        except PaymentProviderUnavailableError as exc:
            logger.warning(
                "portal_provider_unavailable user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.portal.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="PROVIDER_UNAVAILABLE",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="failure",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source=source,
                details_json={
                    "operation": "billing_portal",
                    "code": "PROVIDER_UNAVAILABLE",
                    "error": str(exc),
                },
                provider_reference=provider_reference,
                occurred_at=now,
            )
            db.commit()
            raise HTTPException(status_code=503, detail=str(exc))
        except PaymentProviderError as exc:
            logger.warning(
                "portal_provider_failed user_id=%s provider=%s error=%s",
                user.id,
                profile.provider,
                str(exc),
            )
            emit_event(
                "payment.portal.failed",
                category="payment",
                severity="error",
                user_id=user.id,
                profile_id=profile.id,
                provider=profile.provider,
                reason="PROVIDER_ERROR",
                source=source,
            )
            self._record_subscription_event(
                db=db,
                user=user,
                profile=profile,
                event_type="failure",
                previous_plan_id=profile.current_plan_id,
                plan_id=profile.current_plan_id,
                previous_status=profile.status,
                status=profile.status,
                payment_status=PAYMENT_STATUS_FAILED,
                source=source,
                details_json={"operation": "billing_portal", "code": "PROVIDER_ERROR"},
                provider_reference=provider_reference,
                occurred_at=now,
            )
            db.commit()
            raise HTTPException(status_code=502, detail=str(exc))

        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type="manage_link_created",
            previous_plan_id=profile.current_plan_id,
            plan_id=profile.current_plan_id,
            previous_status=profile.status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source=source,
            details_json={"portal_session_id": portal.session_id},
            provider_reference=portal.session_id,
            occurred_at=now,
        )
        logger.info(
            "portal_created user_id=%s provider=%s session_id=%s",
            user.id,
            portal.provider,
            portal.session_id,
        )
        emit_event(
            "payment.portal.created",
            category="payment",
            user_id=user.id,
            profile_id=profile.id,
            provider=portal.provider,
            session_id=portal.session_id,
            source=source,
        )
        db.commit()
        return self._serialize_portal_session(portal)

    @staticmethod
    def _serialize_portal_session(portal: PortalSessionResult) -> dict[str, object]:
        return {
            "provider": portal.provider,
            "session_id": portal.session_id,
            "url": portal.url,
            "customer_id": portal.customer_id,
        }

    def _sync_payment_methods_from_provider_if_supported(
        self,
        *,
        db: Session,
        user: User,
        profile: SubscriptionProfile,
    ) -> None:
        provider = self._payment_provider()
        if not provider.is_external or not profile.provider_customer_id:
            return
        try:
            references = provider.list_payment_methods(customer_id=profile.provider_customer_id)
        except PaymentProviderError:
            return
        self._replace_payment_methods(
            db=db,
            user=user,
            provider_key=provider.provider_key,
            customer_id=profile.provider_customer_id,
            references=references,
        )
        db.flush()

    def _replace_payment_methods(
        self,
        *,
        db: Session,
        user: User,
        provider_key: str,
        customer_id: str,
        references: list[PaymentMethodReference],
    ) -> None:
        active_methods = (
            db.query(PaymentMethod)
            .filter(
                PaymentMethod.user_id == user.id,
                PaymentMethod.provider == provider_key,
                PaymentMethod.deleted_at.is_(None),
            )
            .all()
        )
        by_provider_id = {
            method.provider_method_id: method for method in active_methods if method.provider_method_id
        }
        current_ids = {reference.method_id for reference in references}

        for reference in references:
            method = by_provider_id.get(reference.method_id)
            if method is None:
                method = PaymentMethod(user_id=user.id, label=reference.label)
            self._apply_method_reference(
                method=method,
                provider_key=provider_key,
                customer_id=customer_id,
                reference=reference,
            )
            method.deleted_at = None
            db.add(method)

        for method in active_methods:
            if method.provider_method_id and method.provider_method_id not in current_ids:
                method.deleted_at = db_utc_now()
                db.add(method)

    def _upsert_provider_payment_method(
        self,
        *,
        db: Session,
        user: User,
        method_ref: PaymentMethodReference,
    ) -> None:
        method = (
            db.query(PaymentMethod)
            .filter(
                PaymentMethod.user_id == user.id,
                PaymentMethod.provider == method_ref.provider,
                PaymentMethod.provider_method_id == method_ref.method_id,
            )
            .first()
        )
        if method is None:
            method = PaymentMethod(user_id=user.id, label=method_ref.label)
        self._apply_method_reference(
            method=method,
            provider_key=method_ref.provider,
            customer_id=method_ref.customer_id,
            reference=method_ref,
        )
        method.deleted_at = None
        db.add(method)

    @staticmethod
    def _apply_method_reference(
        *,
        method: PaymentMethod,
        provider_key: str,
        customer_id: str,
        reference: PaymentMethodReference,
    ) -> None:
        method.label = reference.label
        method.provider = provider_key
        method.provider_customer_id = customer_id
        method.provider_method_id = reference.method_id
        method.method_type = reference.method_type
        method.brand = reference.brand
        method.last4 = reference.last4
        method.exp_month = reference.exp_month
        method.exp_year = reference.exp_year
        method.is_default = reference.is_default
        method.fingerprint = reference.fingerprint
        method.metadata_json = reference.metadata_json

    def _list_user_payment_methods(self, *, db: Session, user: User) -> list[PaymentMethod]:
        return (
            db.query(PaymentMethod)
            .filter(PaymentMethod.user_id == user.id, PaymentMethod.deleted_at.is_(None))
            .order_by(PaymentMethod.is_default.desc(), PaymentMethod.created_at.desc())
            .all()
        )

    @staticmethod
    def _count_for_model(*, db: Session, model, profile_id: int) -> int:
        return db.query(model).filter(model.subscription_profile_id == profile_id).count()

    @staticmethod
    def _plan_duration(plan: str) -> timedelta:
        catalog = get_plan_catalog()
        details = catalog.get(plan, catalog[PLAN_FREE])
        period = str(details.get("period", "month")).lower()
        if period == "month":
            return timedelta(days=30)
        return timedelta(days=30)

    @staticmethod
    def _price_cents_for_plan(plan: str) -> int:
        catalog = get_plan_catalog()
        details = catalog.get(plan, catalog[PLAN_FREE])
        return int(float(details.get("price", 0)) * 100)

    @staticmethod
    def _mock_session_id(*, plan: str, user_id: int) -> str:
        if settings.is_production:
            raise RuntimeError("Mock checkout session ids are not allowed in production.")
        normalized_plan = plan.lower()
        return f"mock_session_{user_id}_{normalized_plan}"

    @classmethod
    def _build_mock_checkout(cls, *, plan: str, user_id: int) -> dict[str, str]:
        session_id = cls._mock_session_id(plan=plan, user_id=user_id)
        return {
            "session_id": session_id,
            "payment_intent_url": f"https://example.invalid/mock-checkout/{session_id}",
        }


subscription_service = SubscriptionService()
