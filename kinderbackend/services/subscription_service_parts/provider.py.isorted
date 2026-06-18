from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.message_catalog import SubscriptionMessages
from core.observability import emit_event
from core.time_utils import db_utc_now
from models import BillingTransaction, PaymentAttempt, PaymentMethod, SubscriptionProfile, User
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PaymentProviderActionRequiredError,
    PaymentProviderError,
    PaymentProviderUnavailableError,
    PortalSessionResult,
)
from services.subscription_service_parts.common import (
    PAYMENT_STATUS_ACTION_REQUIRED,
    PAYMENT_STATUS_CANCELED,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PENDING,
    PAYMENT_STATUS_SUCCEEDED,
    logger,
)


class SubscriptionProviderMixin:
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
                raise HTTPException(
                    status_code=409,
                    detail=SubscriptionMessages.NO_PROVIDER_CUSTOMER_EXISTS,
                )
            if not provider_method_id:
                raise HTTPException(
                    status_code=422,
                    detail=SubscriptionMessages.PROVIDER_METHOD_ID_REQUIRED,
                )
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
                raise HTTPException(
                    status_code=500,
                    detail=SubscriptionMessages.PAYMENT_METHOD_SYNC_FAILED,
                )
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
            raise HTTPException(
                status_code=404,
                detail=SubscriptionMessages.PAYMENT_METHOD_NOT_FOUND,
            )

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
                BillingTransaction.transaction_type.in_(["purchase", "upgrade", "activation"]),
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
                details_json={"operation": "billing_portal", "code": "NO_CUSTOMER"},
                provider_reference=provider_reference,
                occurred_at=now,
            )
            db.commit()
            raise HTTPException(
                status_code=409,
                detail=SubscriptionMessages.NO_BILLING_CUSTOMER_AVAILABLE,
            )

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
            method.provider_method_id: method
            for method in active_methods
            if method.provider_method_id
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
