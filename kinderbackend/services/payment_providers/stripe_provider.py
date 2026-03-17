from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.settings import settings
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PaymentProviderUnavailableError,
    PortalSessionResult,
    RefundResult,
    ProviderSubscriptionSnapshot,
)


class StripePaymentProvider:
    provider_key = "stripe"
    is_external = True

    def __init__(self) -> None:
        self._client = None

    def create_checkout_session(
        self,
        *,
        plan_id: str,
        user_email: str,
        user_name: str | None,
        customer_id: str | None,
        metadata: dict[str, str],
    ) -> CheckoutSessionResult:
        customer_id = customer_id or self._ensure_customer(
            email=user_email,
            name=user_name,
            metadata=metadata,
        )
        session = self._client_object().checkout.sessions.create(
            params={
                "mode": "subscription",
                "customer": customer_id,
                "success_url": settings.stripe_checkout_success_url,
                "cancel_url": settings.stripe_checkout_cancel_url,
                "line_items": [
                    {
                        "price": self._price_id_for_plan(plan_id),
                        "quantity": 1,
                    }
                ],
                "metadata": metadata,
                "subscription_data": {
                    "metadata": metadata,
                },
            }
        )
        return self._serialize_checkout_session(session)

    def retrieve_checkout_session(self, *, session_id: str) -> CheckoutSessionResult:
        session = self._client_object().checkout.sessions.retrieve(session_id)
        return self._serialize_checkout_session(session)

    def create_billing_portal_session(
        self,
        *,
        customer_id: str,
        metadata: dict[str, str],
    ) -> PortalSessionResult:
        session = self._client_object().billing_portal.sessions.create(
            params={
                "customer": customer_id,
                "return_url": settings.stripe_portal_return_url,
            }
        )
        return PortalSessionResult(
            provider=self.provider_key,
            session_id=session.id,
            url=session.url,
            customer_id=customer_id,
            raw=session.to_dict_recursive(),
        )

    def retrieve_subscription(self, *, subscription_id: str) -> ProviderSubscriptionSnapshot:
        subscription = self._client_object().subscriptions.retrieve(
            subscription_id,
            params={"expand": ["latest_invoice", "latest_invoice.payment_intent"]},
        )
        latest_invoice = getattr(subscription, "latest_invoice", None)
        latest_invoice_id = None
        latest_invoice_status = None
        if latest_invoice is not None:
            latest_invoice_id = getattr(latest_invoice, "id", None)
            latest_invoice_status = getattr(latest_invoice, "status", None)
        else:
            latest_invoice_id = getattr(subscription, "latest_invoice", None)

        def _from_unix(value):
            if value is None:
                return None
            try:
                return datetime.fromtimestamp(int(value), tz=timezone.utc)
            except (TypeError, ValueError, OSError):
                return None

        return ProviderSubscriptionSnapshot(
            provider=self.provider_key,
            subscription_id=subscription.id,
            status=getattr(subscription, "status", None) or "unknown",
            current_period_end=_from_unix(getattr(subscription, "current_period_end", None)),
            cancel_at=_from_unix(getattr(subscription, "cancel_at", None)),
            cancel_at_period_end=bool(getattr(subscription, "cancel_at_period_end", False)),
            latest_invoice_id=str(latest_invoice_id) if latest_invoice_id else None,
            latest_invoice_status=str(latest_invoice_status)
            if latest_invoice_status
            else None,
            raw=subscription.to_dict_recursive(),
        )

    def cancel_subscription(self, *, subscription_id: str) -> dict[str, Any]:
        response = self._client_object().subscriptions.cancel(subscription_id)
        return response.to_dict_recursive()

    def refund_payment(
        self,
        *,
        payment_intent_id: str | None,
        charge_id: str | None,
        amount_cents: int | None,
        reason: str | None,
        metadata: dict[str, str],
    ) -> RefundResult:
        params: dict[str, Any] = {
            "metadata": metadata,
        }
        if payment_intent_id:
            params["payment_intent"] = payment_intent_id
        elif charge_id:
            params["charge"] = charge_id
        else:
            raise PaymentProviderUnavailableError("Refund target is missing")
        if amount_cents:
            params["amount"] = amount_cents
        if reason:
            params["reason"] = reason

        refund = self._client_object().refunds.create(params=params)
        return RefundResult(
            provider=self.provider_key,
            refund_id=refund.id,
            status=refund.status or "pending",
            amount_cents=int(refund.amount or amount_cents or 0),
            currency=str(refund.currency or "usd"),
            payment_intent_id=getattr(refund, "payment_intent", None),
            charge_id=getattr(refund, "charge", None),
            raw=refund.to_dict_recursive(),
        )

    def list_payment_methods(self, *, customer_id: str) -> list[PaymentMethodReference]:
        methods = self._client_object().payment_methods.list(
            params={"customer": customer_id, "type": "card"}
        )
        customer = self._client_object().customers.retrieve(customer_id)
        default_payment_method = None
        invoice_settings = getattr(customer, "invoice_settings", None)
        if invoice_settings is not None:
            default_payment_method = getattr(invoice_settings, "default_payment_method", None)
        return [
            self._serialize_payment_method(
                method,
                customer_id=customer_id,
                default_payment_method=default_payment_method,
            )
            for method in methods.data
        ]

    def attach_payment_method(
        self,
        *,
        customer_id: str,
        payment_method_id: str,
        set_default: bool,
    ) -> PaymentMethodReference:
        method = self._client_object().payment_methods.attach(
            payment_method_id,
            params={"customer": customer_id},
        )
        if set_default:
            self._client_object().customers.update(
                customer_id,
                params={"invoice_settings": {"default_payment_method": payment_method_id}},
            )
        return self._serialize_payment_method(
            method,
            customer_id=customer_id,
            default_payment_method=payment_method_id if set_default else None,
        )

    def detach_payment_method(self, *, payment_method_id: str) -> dict[str, Any]:
        response = self._client_object().payment_methods.detach(payment_method_id)
        return response.to_dict_recursive()

    def _ensure_customer(self, *, email: str, name: str | None, metadata: dict[str, str]) -> str:
        customer = self._client_object().customers.create(
            params={
                "email": email,
                "name": name,
                "metadata": metadata,
            }
        )
        return customer.id

    def _price_id_for_plan(self, plan_id: str) -> str:
        plan = plan_id.upper()
        if plan == "PREMIUM" and settings.stripe_price_premium_monthly:
            return settings.stripe_price_premium_monthly
        if plan == "FAMILY_PLUS" and settings.stripe_price_family_plus_monthly:
            return settings.stripe_price_family_plus_monthly
        raise PaymentProviderUnavailableError(f"No Stripe price configured for plan {plan_id}")

    def _serialize_checkout_session(self, session) -> CheckoutSessionResult:
        payment_intent = getattr(session, "payment_intent", None)
        subscription_id = getattr(session, "subscription", None)
        payment_status = getattr(session, "payment_status", None) or "unpaid"
        status = getattr(session, "status", None) or "open"
        customer_id = getattr(session, "customer", None)
        payment_method_id = None

        if payment_intent:
            try:
                intent = self._client_object().payment_intents.retrieve(payment_intent)
                payment_method_id = getattr(intent, "payment_method", None)
            except Exception:
                payment_method_id = None

        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=session.id,
            checkout_url=session.url,
            status=status,
            payment_status=payment_status,
            customer_id=customer_id,
            subscription_id=subscription_id,
            payment_intent_id=payment_intent,
            payment_method_id=payment_method_id,
            raw=session.to_dict_recursive(),
        )

    def _serialize_payment_method(
        self,
        method,
        *,
        customer_id: str,
        default_payment_method: str | None,
    ) -> PaymentMethodReference:
        card = getattr(method, "card", None)
        return PaymentMethodReference(
            provider=self.provider_key,
            customer_id=customer_id,
            method_id=method.id,
            method_type=getattr(method, "type", None) or "card",
            brand=getattr(card, "brand", None),
            last4=getattr(card, "last4", None),
            exp_month=getattr(card, "exp_month", None),
            exp_year=getattr(card, "exp_year", None),
            is_default=method.id == default_payment_method,
            fingerprint=getattr(card, "fingerprint", None),
            metadata_json=method.to_dict_recursive(),
        )

    def _client_object(self):
        if self._client is not None:
            return self._client
        try:
            from stripe import StripeClient
        except ImportError as exc:
            raise PaymentProviderUnavailableError(
                "Stripe SDK is not installed. Add 'stripe' to backend dependencies."
            ) from exc

        self._client = StripeClient(settings.stripe_secret_key)
        return self._client


stripe_payment_provider = StripePaymentProvider()
