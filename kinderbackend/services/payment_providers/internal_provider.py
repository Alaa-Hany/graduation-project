from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.settings import settings
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PaymentProviderActionRequiredError,
    PaymentProviderUnavailableError,
    PortalSessionResult,
    RefundResult,
    ProviderSubscriptionSnapshot,
)


class InternalPaymentProvider:
    provider_key = "internal"
    is_external = False

    @staticmethod
    def _ensure_non_production() -> None:
        if settings.is_production:
            raise PaymentProviderUnavailableError(
                "Internal payment provider is not allowed in production."
            )

    def create_checkout_session(
        self,
        *,
        plan_id: str,
        user_email: str,
        user_name: str | None,
        customer_id: str | None,
        metadata: dict[str, str],
    ) -> CheckoutSessionResult:
        self._ensure_non_production()
        user_id = metadata.get("user_id", "0")
        normalized_plan = plan_id.lower()
        session_id = f"mock_session_{user_id}_{normalized_plan}"
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=session_id,
            checkout_url=f"https://example.invalid/mock-checkout/{session_id}",
            status="complete",
            payment_status="paid",
            customer_id=customer_id or f"mock_customer_{user_id}",
            subscription_id=f"mock_subscription_{user_id}_{normalized_plan}",
            payment_intent_id=f"mock_pi_{user_id}_{normalized_plan}",
            raw={"mode": "internal"},
        )

    def retrieve_checkout_session(self, *, session_id: str) -> CheckoutSessionResult:
        self._ensure_non_production()
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=session_id,
            checkout_url=f"https://example.invalid/mock-checkout/{session_id}",
            status="complete",
            payment_status="paid",
            customer_id="mock_customer",
            subscription_id="mock_subscription",
            payment_intent_id=f"mock_pi_{session_id}",
            raw={"mode": "internal"},
        )

    def create_billing_portal_session(
        self,
        *,
        customer_id: str,
        metadata: dict[str, str],
    ) -> PortalSessionResult:
        self._ensure_non_production()
        raise PaymentProviderActionRequiredError("Billing portal is not configured yet")

    def retrieve_subscription(self, *, subscription_id: str) -> ProviderSubscriptionSnapshot:
        self._ensure_non_production()
        return ProviderSubscriptionSnapshot(
            provider=self.provider_key,
            subscription_id=subscription_id,
            status="active",
            current_period_end=datetime.now(timezone.utc),
            cancel_at=None,
            cancel_at_period_end=False,
            latest_invoice_id=None,
            latest_invoice_status=None,
            raw={"mode": "internal"},
        )

    def cancel_subscription(self, *, subscription_id: str) -> dict[str, Any]:
        self._ensure_non_production()
        return {
            "id": subscription_id,
            "status": "canceled",
        }

    def refund_payment(
        self,
        *,
        payment_intent_id: str | None,
        charge_id: str | None,
        amount_cents: int | None,
        reason: str | None,
        metadata: dict[str, str],
    ) -> RefundResult:
        self._ensure_non_production()
        raise PaymentProviderActionRequiredError(
            "Refunds are not supported by the current payment model"
        )

    def list_payment_methods(self, *, customer_id: str) -> list[PaymentMethodReference]:
        self._ensure_non_production()
        return []

    def attach_payment_method(
        self,
        *,
        customer_id: str,
        payment_method_id: str,
        set_default: bool,
    ) -> PaymentMethodReference:
        self._ensure_non_production()
        return PaymentMethodReference(
            provider=self.provider_key,
            customer_id=customer_id,
            method_id=payment_method_id,
            method_type="card",
            brand=None,
            last4=None,
            exp_month=None,
            exp_year=None,
            is_default=set_default,
        )

    def detach_payment_method(self, *, payment_method_id: str) -> dict[str, Any]:
        self._ensure_non_production()
        return {"id": payment_method_id, "detached": True}


internal_payment_provider = InternalPaymentProvider()
