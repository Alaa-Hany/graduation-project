from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.message_catalog import SubscriptionMessages
from core.observability import emit_event
from core.time_utils import db_utc_now, ensure_utc
from models import PaymentAttempt, SubscriptionProfile, User
from plan_service import PLAN_FREE, get_plan_catalog, get_user_plan, validate_plan_value
from services.notification_service import notification_service
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentProviderActionRequiredError,
    PaymentProviderError,
    PaymentProviderUnavailableError,
)
from services.subscription_service_parts.common import (
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_NOT_APPLICABLE,
    PAYMENT_STATUS_PENDING,
    PAYMENT_STATUS_SUCCEEDED,
    SUBSCRIPTION_STATUS_ACTIVE,
    SUBSCRIPTION_STATUS_FREE,
    SUBSCRIPTION_STATUS_PENDING,
    logger,
)


class SubscriptionLifecycleMixin:
    def upgrade_subscription(
        self,
        *,
        payload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        try:
            plan = validate_plan_value(payload.plan)
        except ValueError:
            raise HTTPException(status_code=400, detail=SubscriptionMessages.INVALID_PLAN)

        if plan == PLAN_FREE:
            self._set_free_access(db=db, user=user, source="parent_upgrade_free")
            db.commit()
            db.refresh(user)
            return self.get_subscription(db=db, user=user)
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
        self._set_free_access(db=db, user=user, source=source)
        db.commit()
        db.refresh(user)
        return self.get_subscription(db=db, user=user)

    def _set_free_access(
        self,
        *,
        db: Session,
        user: User,
        source: str,
    ) -> SubscriptionProfile:
        profile = self._ensure_subscription_profile(db=db, user=user)
        now = db_utc_now()
        previous_plan = profile.current_plan_id
        previous_status = profile.status
        provider_reference = profile.provider_customer_id or profile.provider_subscription_id

        if previous_plan == PLAN_FREE and profile.status == SUBSCRIPTION_STATUS_FREE:
            return profile

        profile.current_plan_id = PLAN_FREE
        profile.selected_plan_id = None
        profile.status = SUBSCRIPTION_STATUS_FREE
        profile.started_at = None
        profile.expires_at = None
        profile.cancel_at = None
        profile.will_renew = False
        profile.last_payment_status = PAYMENT_STATUS_NOT_APPLICABLE
        profile.provider_subscription_id = None
        db.add(profile)

        self._sync_user_plan_projection(user=user, plan=PLAN_FREE, when=now)
        db.add(user)

        self._record_subscription_event(
            db=db,
            user=user,
            profile=profile,
            event_type="access_revoked",
            previous_plan_id=previous_plan,
            plan_id=PLAN_FREE,
            previous_status=previous_status,
            status=profile.status,
            payment_status=profile.last_payment_status,
            source=source,
            details_json={"reason": "manual_revoke_or_free_reset"},
            provider_reference=provider_reference,
            occurred_at=now,
        )
        notification_service.notify_subscription_changed(
            db,
            user=user,
            old_plan=previous_plan,
            new_plan=PLAN_FREE,
            source=source,
        )
        db.flush()
        return profile

    def create_checkout_session(
        self,
        *,
        payload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        return self.select_subscription(payload=payload, db=db, user=user)

    def select_subscription(
        self,
        *,
        payload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        requested = payload.resolved_plan
        if not requested:
            raise HTTPException(
                status_code=422,
                detail=SubscriptionMessages.PLAN_ID_OR_TYPE_REQUIRED,
            )

        catalog = get_plan_catalog()
        if requested not in catalog:
            raise HTTPException(
                status_code=400,
                detail=SubscriptionMessages.invalid_plan_detail(
                    requested=requested,
                    valid_plans=list(catalog.keys()),
                ),
            )

        profile = self._ensure_subscription_profile(db=db, user=user)
        if requested == PLAN_FREE:
            return self._selection_payload_from_snapshot(self.get_subscription(db=db, user=user))
        now = db_utc_now()
        previous_plan = profile.current_plan_id
        previous_status = profile.status
        if previous_plan == requested and profile.status == SUBSCRIPTION_STATUS_ACTIVE:
            return self._selection_payload_from_snapshot(self.get_subscription(db=db, user=user))
        provider = self._payment_provider()
        profile.selected_plan_id = requested
        profile.status = SUBSCRIPTION_STATUS_PENDING
        profile.last_payment_status = PAYMENT_STATUS_PENDING
        profile.provider = provider.provider_key
        profile.cancel_at = None
        profile.will_renew = False
        profile.provider_subscription_id = None
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

        if not self._checkout_is_paid(checkout):
            notification_service.notify_subscription_changed(
                db,
                user=user,
                old_plan=previous_plan,
                new_plan=requested,
                source="parent_select",
                activated=False,
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
            profile.provider_subscription_id = None
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
        payload,
        db: Session,
        user: User,
    ) -> dict[str, object]:
        requested = payload.resolved_plan
        if not requested:
            raise HTTPException(
                status_code=422,
                detail=SubscriptionMessages.PLAN_ID_OR_TYPE_REQUIRED,
            )
        if requested == PLAN_FREE:
            return self._selection_payload_from_snapshot(self.get_subscription(db=db, user=user))

        profile = self._ensure_subscription_profile(db=db, user=user)
        if profile.selected_plan_id and profile.selected_plan_id != requested:
            raise HTTPException(
                status_code=409,
                detail=SubscriptionMessages.PENDING_PLAN_SELECTION_MISMATCH,
            )
        provider = self._payment_provider()

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
            raise HTTPException(
                status_code=422,
                detail=SubscriptionMessages.SESSION_ID_REQUIRED_FOR_ACTIVATION,
            )

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
                f"Checkout session {checkout.session_id} is {checkout.status}/"
                f"{checkout.payment_status}"
            )
            db.add(checkout_attempt)
            profile.last_payment_status = checkout_attempt.status
            profile.provider_customer_id = checkout.customer_id or profile.provider_customer_id
            profile.provider_subscription_id = None
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
            raise HTTPException(
                status_code=409,
                detail=SubscriptionMessages.PAYMENT_NOT_COMPLETED,
            )

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
        profile = self._ensure_subscription_profile(db=db, user=user)
        # One-time purchases (internal provider or completed external one-time) cannot use billing portal
        if profile.provider == "internal":
            raise HTTPException(
                status_code=410,
                detail="Billing portal is disabled for one-time purchases",
            )
        # External provider one-time purchase (active with no provider_subscription_id)
        if (
            profile.status == SUBSCRIPTION_STATUS_ACTIVE
            and profile.provider_subscription_id is None
        ):
            raise HTTPException(
                status_code=410,
                detail="Billing portal is disabled for one-time purchases",
            )
        return self._build_billing_portal_response(db=db, user=user, source="subscription_manage")

    def billing_portal(self, *, db: Session, user: User) -> dict[str, object]:
        profile = self._ensure_subscription_profile(db=db, user=user)
        # One-time purchases (internal provider or completed external one-time) cannot use billing portal
        if profile.provider == "internal":
            raise HTTPException(
                status_code=410,
                detail="Billing portal is disabled for one-time purchases",
            )
        # External provider one-time purchase (active with no provider_subscription_id)
        if (
            profile.status == SUBSCRIPTION_STATUS_ACTIVE
            and profile.provider_subscription_id is None
        ):
            raise HTTPException(
                status_code=410,
                detail="Billing portal is disabled for one-time purchases",
            )
        return self._build_billing_portal_response(db=db, user=user, source="billing_portal")

    def _build_billing_portal_response(
        self,
        *,
        db: Session,
        user: User,
        source: str,
    ) -> dict[str, object]:
        self._ensure_subscription_profile(db=db, user=user)
        portal_payload = self._create_portal_session(db=db, user=user, source=source)
        profile = self._ensure_subscription_profile(db=db, user=user)
        return {
            "operation": "billing_portal",
            "current_plan_id": profile.current_plan_id,
            "selected_plan_id": profile.selected_plan_id,
            "status": profile.status,
            "will_renew": bool(profile.will_renew),
            "last_payment_status": profile.last_payment_status,
            "provider": str(portal_payload["provider"]),
            "provider_subscription_id": profile.provider_subscription_id,
            "session_id": str(portal_payload["session_id"]),
            "url": str(portal_payload["url"]),
            "customer_id": (
                str(portal_payload["customer_id"])
                if portal_payload.get("customer_id") is not None
                else None
            ),
        }

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
            payment_intent_id = (
                str(payment_attempt.metadata_json.get("payment_intent_id") or "") or None
            )

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
            raise HTTPException(
                status_code=409,
                detail=SubscriptionMessages.NO_REFUNDABLE_PAYMENT,
            )

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
            raise HTTPException(status_code=400, detail=SubscriptionMessages.INVALID_PLAN)
        if normalized == PLAN_FREE:
            self._set_free_access(db=db, user=user, source=source)
            db.commit()
            db.refresh(user)
            return self.get_subscription(db=db, user=user)
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
                if profile.started_at is not None:
                    profile.started_at = None
                    updated = True
                if profile.expires_at is not None:
                    profile.expires_at = None
                    updated = True
                if profile.cancel_at is not None:
                    profile.cancel_at = None
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
                if profile.expires_at is not None:
                    profile.expires_at = None
                    updated = True
                if profile.cancel_at is not None:
                    profile.cancel_at = None
                    updated = True
                if profile.will_renew:
                    profile.will_renew = False
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

        if payment_attempt is None:
            payment_attempt = self._record_payment_attempt(
                db=db,
                user=user,
                profile=profile,
                plan_id=plan,
                attempt_type="purchase",
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
            profile.provider_subscription_id = None

        profile.selected_plan_id = None
        profile.current_plan_id = plan
        profile.status = SUBSCRIPTION_STATUS_ACTIVE
        profile.started_at = now
        profile.expires_at = None
        profile.cancel_at = None
        profile.will_renew = False
        profile.last_payment_status = PAYMENT_STATUS_SUCCEEDED
        db.add(profile)

        self._sync_user_plan_projection(user=user, plan=plan, when=now)
        db.add(user)

        provider_reference = payment_attempt.provider_reference
        event_type = "purchase" if previous_plan == PLAN_FREE else "upgrade"
        transaction_type = "purchase" if previous_plan == PLAN_FREE else "upgrade"
        details_json = {
            "request_origin": request_origin,
            "payment_attempt_id": payment_attempt.id,
        }
        if checkout is not None:
            details_json.update(
                self._checkout_metadata(checkout=checkout, request_origin=request_origin)
            )

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
