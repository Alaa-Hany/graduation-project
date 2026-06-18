from __future__ import annotations

import logging
from typing import Protocol

PLAN_PREMIUM = "PREMIUM"

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

logger = logging.getLogger("services.subscription_service")


class PlanChangePayload(Protocol):
    plan: str


class SubscriptionSelectionPayload(Protocol):
    @property
    def resolved_plan(self) -> str: ...

    session_id: str | None


class RefundRequestPayload(Protocol):
    amount_cents: int | None
    reason: str | None
