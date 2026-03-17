from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Protocol

from core.settings import settings


class PaymentProviderError(Exception):
    pass


class PaymentProviderUnavailableError(PaymentProviderError):
    pass


class PaymentProviderActionRequiredError(PaymentProviderError):
    pass


@dataclass(slots=True)
class CheckoutSessionResult:
    provider: str
    session_id: str
    checkout_url: str
    status: str
    payment_status: str
    customer_id: str | None = None
    subscription_id: str | None = None
    payment_intent_id: str | None = None
    payment_method_id: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class PortalSessionResult:
    provider: str
    session_id: str
    url: str
    customer_id: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class RefundResult:
    provider: str
    refund_id: str
    status: str
    amount_cents: int
    currency: str
    payment_intent_id: str | None = None
    charge_id: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class ProviderSubscriptionSnapshot:
    provider: str
    subscription_id: str
    status: str
    current_period_end: datetime | None
    cancel_at: datetime | None
    cancel_at_period_end: bool
    latest_invoice_id: str | None = None
    latest_invoice_status: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class PaymentMethodReference:
    provider: str
    customer_id: str
    method_id: str
    method_type: str
    brand: str | None
    last4: str | None
    exp_month: int | None
    exp_year: int | None
    is_default: bool
    fingerprint: str | None = None
    metadata_json: dict[str, Any] = field(default_factory=dict)

    @property
    def label(self) -> str:
        pieces = [part for part in (self.brand, self.last4 and f"ending {self.last4}") if part]
        return " ".join(pieces) if pieces else self.method_id


class PaymentProviderAdapter(Protocol):
    provider_key: str
    is_external: bool

    def create_checkout_session(
        self,
        *,
        plan_id: str,
        user_email: str,
        user_name: str | None,
        customer_id: str | None,
        metadata: dict[str, str],
    ) -> CheckoutSessionResult: ...

    def retrieve_checkout_session(self, *, session_id: str) -> CheckoutSessionResult: ...

    def retrieve_subscription(self, *, subscription_id: str) -> ProviderSubscriptionSnapshot: ...

    def create_billing_portal_session(
        self,
        *,
        customer_id: str,
        metadata: dict[str, str],
    ) -> PortalSessionResult: ...

    def cancel_subscription(self, *, subscription_id: str) -> dict[str, Any]: ...

    def refund_payment(
        self,
        *,
        payment_intent_id: str | None,
        charge_id: str | None,
        amount_cents: int | None,
        reason: str | None,
        metadata: dict[str, str],
    ) -> RefundResult: ...

    def list_payment_methods(self, *, customer_id: str) -> list[PaymentMethodReference]: ...

    def attach_payment_method(
        self,
        *,
        customer_id: str,
        payment_method_id: str,
        set_default: bool,
    ) -> PaymentMethodReference: ...

    def detach_payment_method(self, *, payment_method_id: str) -> dict[str, Any]: ...


def get_payment_provider() -> PaymentProviderAdapter:
    if settings.payment_provider == "stripe":
        from services.payment_providers.stripe_provider import stripe_payment_provider

        return stripe_payment_provider

    from services.payment_providers.internal_provider import internal_payment_provider

    return internal_payment_provider
