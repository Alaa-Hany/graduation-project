from __future__ import annotations

from collections.abc import Callable

from plan_service import PLAN_FREE
from services.payment_provider import PaymentProviderAdapter, get_payment_provider
from services.subscription_service_parts.common import (
    PAYMENT_STATUS_ACTION_REQUIRED,
    PAYMENT_STATUS_CANCELED,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_NOT_APPLICABLE,
    PAYMENT_STATUS_PENDING,
    PAYMENT_STATUS_SUCCEEDED,
    PLAN_PREMIUM,
    SUBSCRIPTION_STATUS_ACTIVE,
    SUBSCRIPTION_STATUS_CANCELED,
    SUBSCRIPTION_STATUS_EXPIRED,
    SUBSCRIPTION_STATUS_FREE,
    SUBSCRIPTION_STATUS_PAST_DUE,
    SUBSCRIPTION_STATUS_PENDING,
    PlanChangePayload,
    RefundRequestPayload,
    SubscriptionSelectionPayload,
)
from services.subscription_service_parts.history import SubscriptionHistoryMixin
from services.subscription_service_parts.lifecycle import SubscriptionLifecycleMixin
from services.subscription_service_parts.plans import SubscriptionPlansMixin
from services.subscription_service_parts.provider import SubscriptionProviderMixin


# Re-export common plan-access constants and payload protocols for existing imports.
class SubscriptionService(
    SubscriptionLifecycleMixin,
    SubscriptionHistoryMixin,
    SubscriptionProviderMixin,
    SubscriptionPlansMixin,
):
    def __init__(
        self,
        *,
        payment_provider_factory: Callable[[], PaymentProviderAdapter] = get_payment_provider,
    ) -> None:
        self._payment_provider_factory = payment_provider_factory


subscription_service = SubscriptionService()

__all__ = [
    "PLAN_FREE",
    "PAYMENT_STATUS_ACTION_REQUIRED",
    "PAYMENT_STATUS_CANCELED",
    "PAYMENT_STATUS_FAILED",
    "PAYMENT_STATUS_NOT_APPLICABLE",
    "PAYMENT_STATUS_PENDING",
    "PAYMENT_STATUS_SUCCEEDED",
    "PLAN_PREMIUM",
    "SUBSCRIPTION_STATUS_ACTIVE",
    "SUBSCRIPTION_STATUS_CANCELED",
    "SUBSCRIPTION_STATUS_EXPIRED",
    "SUBSCRIPTION_STATUS_FREE",
    "SUBSCRIPTION_STATUS_PAST_DUE",
    "SUBSCRIPTION_STATUS_PENDING",
    "PlanChangePayload",
    "RefundRequestPayload",
    "SubscriptionSelectionPayload",
    "SubscriptionService",
    "subscription_service",
]
