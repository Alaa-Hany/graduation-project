from typing import Any, List, Optional

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from services.subscription_service import subscription_service

router = APIRouter(prefix="/subscription", tags=["subscription"])
public_router = APIRouter(tags=["subscription"])
billing_router = APIRouter(prefix="/billing", tags=["subscription"])


@billing_router.post(
    "/portal",
    summary="Open Billing Portal",
    description="Open the provider billing portal to manage subscriptions or payment methods.",
)
def billing_portal(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.billing_portal(db=db, user=user)


class SubscriptionLifecycleOut(BaseModel):
    current_plan_id: str
    selected_plan_id: Optional[str] = None
    status: str
    started_at: Optional[str] = None
    last_payment_status: str
    provider: str
    provider_customer_id: Optional[str] = None
    provider_subscription_id: Optional[str] = None
    billing_interval: Optional[str] = None
    expires_at: Optional[str] = None
    cancel_at: Optional[str] = None
    will_renew: bool = False
    is_active: bool
    has_paid_access: bool


class SubscriptionHistorySummaryOut(BaseModel):
    event_count: int
    billing_transaction_count: int
    payment_attempt_count: int


class SubscriptionEventOut(BaseModel):
    id: int
    event_type: str
    previous_plan_id: Optional[str] = None
    plan_id: str
    previous_status: Optional[str] = None
    status: str
    payment_status: Optional[str] = None
    source: str
    provider_reference: Optional[str] = None
    details_json: dict[str, Any] = Field(default_factory=dict)
    occurred_at: Optional[str] = None


class BillingTransactionOut(BaseModel):
    id: int
    plan_id: str
    transaction_type: str
    amount_cents: int
    currency: str
    status: str
    provider_reference: Optional[str] = None
    effective_at: Optional[str] = None
    metadata_json: dict[str, Any] = Field(default_factory=dict)


class PaymentAttemptOut(BaseModel):
    id: int
    plan_id: str
    attempt_type: str
    status: str
    amount_cents: int
    currency: str
    provider_reference: Optional[str] = None
    failure_code: Optional[str] = None
    failure_message: Optional[str] = None
    requested_at: Optional[str] = None
    completed_at: Optional[str] = None
    metadata_json: dict[str, Any] = Field(default_factory=dict)


class SubscriptionInfo(BaseModel):
    plan: str
    current_plan_id: str
    limits: dict[str, Any]
    features: dict[str, Any]
    lifecycle: SubscriptionLifecycleOut
    history_summary: SubscriptionHistorySummaryOut
    recent_events: List[SubscriptionEventOut]
    billing_history: List[BillingTransactionOut]
    payment_attempts: List[PaymentAttemptOut]


class SubscriptionChange(BaseModel):
    plan: str


class PlanOut(BaseModel):
    id: str
    name: str
    price: float
    billing_type: str
    access_type: str
    pricing: dict[str, Any] = Field(default_factory=dict)
    limits: dict[str, Any]
    features: dict[str, Any]


class SubscriptionStatus(BaseModel):
    current_plan_id: str
    is_active: bool
    status: str
    started_at: Optional[str] = None
    last_payment_status: Optional[str] = None
    has_paid_access: Optional[bool] = None


class SubscriptionHistoryOut(BaseModel):
    user_id: int
    current_plan_id: str
    status: str
    events: List[SubscriptionEventOut]
    billing_transactions: List[BillingTransactionOut]
    payment_attempts: List[PaymentAttemptOut]


class SubscriptionSelectRequest(BaseModel):
    plan_id: str | None = Field(
        None,
        description="Plan id: FREE|PREMIUM|FAMILY_PLUS",
    )
    plan_type: str | None = Field(
        None,
        description="Alias for plan_id (Flutter compat): free|premium|family_plus",
    )
    session_id: str | None = Field(
        None,
        description="Checkout session id returned by select/checkout for external providers",
    )
    billing_interval: str | None = Field(
        "monthly",
        description="Billing interval for recurring plans: monthly|yearly",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "plan_id": "PREMIUM",
                    "billing_interval": "monthly",
                },
                {
                    "plan_type": "family_plus",
                    "billing_interval": "yearly",
                    "session_id": "cs_test_12345",
                },
            ]
        }
    )

    @property
    def resolved_plan(self) -> str:
        raw = self.plan_id or self.plan_type or ""
        return raw.strip().upper().replace("-", "_")


class SubscriptionSelectResponse(SubscriptionStatus):
    payment_intent_url: Optional[str] = None
    session_id: Optional[str] = None
    checkout_url: Optional[str] = None
    provider: Optional[str] = None
    checkout_status: Optional[str] = None
    payment_status: Optional[str] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "current_plan_id": "PREMIUM",
                "is_active": True,
                "status": "active",
                "started_at": "2026-03-24T12:00:00Z",
                "last_payment_status": "paid",
                "has_paid_access": True,
                "payment_intent_url": None,
                "session_id": "cs_test_12345",
                "checkout_url": "https://checkout.example.invalid/session/cs_test_12345",
                "provider": "stripe",
                "checkout_status": "pending",
                "payment_status": "requires_action",
            }
        }
    )


@router.get(
    "/me",
    response_model=SubscriptionInfo,
    summary="Get Full Purchase Access Details",
    description="Return the current parent's plan access, limits, purchase state, and recent payment history.",
    response_description="Purchase access details including lifecycle, plan limits, and recent history.",
)
def get_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.get_subscription(db=db, user=user)


@router.get(
    "/history",
    response_model=SubscriptionHistoryOut,
    summary="Get Purchase History",
    description="Return the current parent's purchase lifecycle events, billing transactions, and payment attempts.",
    response_description="Purchase history grouped by events, billing transactions, and payment attempts.",
)
def get_subscription_history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.subscription_history(db=db, user=user)


@router.post(
    "/upgrade",
    response_model=SubscriptionInfo,
    summary="Grant Plan Access",
    description="Apply plan access directly without starting a checkout flow.",
    response_description="Updated purchase access details after the override is applied.",
)
def upgrade_subscription(
    payload: SubscriptionChange,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.upgrade_subscription(payload=payload, db=db, user=user)


@public_router.get(
    "/plans",
    response_model=List[PlanOut],
    summary="List Purchase Plans",
    description="Return the currently available public purchase plans and feature summaries.",
    response_description="Available plan catalog for the current backend configuration.",
)
def list_plans():
    return subscription_service.list_plans()


@router.get(
    "",
    response_model=SubscriptionStatus,
    summary="Get Purchase Access Status",
    description="Return the current parent's lightweight purchase-access status without the full history payload.",
    response_description="Current purchase access status for the authenticated parent.",
)
def subscription_status(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.subscription_status(db=db, user=user)


@router.post(
    "/select",
    response_model=SubscriptionSelectResponse,
    summary="Select Subscription Plan",
    description="Choose a plan and billing interval and start a recurring provider checkout session.",
    response_description="Purchase status plus any provider checkout details needed by the client.",
)
def select_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.select_subscription(payload=payload, db=db, user=user)


@router.post(
    "/checkout",
    response_model=SubscriptionSelectResponse,
    summary="Create Checkout Session",
    description="Create or resume a provider-backed recurring checkout session for the selected plan.",
    response_description="Checkout session details and updated purchase status.",
)
def create_checkout_session(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.create_checkout_session(payload=payload, db=db, user=user)


@router.post(
    "/activate",
    response_model=SubscriptionSelectResponse,
    summary="Activate Purchased Plan",
    description="Finalize plan access after a checkout step has completed or when the provider supports direct activation.",
    response_description="Activated purchase status and any remaining provider metadata.",
)
def activate_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.activate_subscription(payload=payload, db=db, user=user)


@router.post(
    "/cancel",
    summary="Cancel Subscription",
    description="Cancel the active recurring subscription. Disabled for free accounts.",
)
def cancel_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    snapshot = subscription_service.get_subscription(db=db, user=user)
    lifecycle = snapshot.get("lifecycle", {})
    if lifecycle.get("current_plan_id") == "FREE" and not lifecycle.get("provider_subscription_id"):
        from fastapi import HTTPException

        raise HTTPException(status_code=410, detail="No active subscription to cancel")
    return subscription_service.cancel_subscription(db=db, user=user)


@router.post(
    "/manage",
    summary="Manage Subscription",
    description="Open the billing portal to manage payment methods and the recurring subscription.",
)
def manage_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.manage_subscription(db=db, user=user)


def _payment_redirect_page(title: str, message: str) -> HTMLResponse:
    return HTMLResponse(f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{title}</title>
<style>
body {{ font-family: -apple-system, Roboto, sans-serif; background: #0f172a; color: #f8fafc;
       display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }}
.card {{ text-align: center; padding: 32px; max-width: 360px; }}
h1 {{ font-size: 20px; margin-bottom: 8px; }}
p {{ font-size: 14px; color: #cbd5e1; }}
</style>
</head>
<body>
<div class="card">
<h1>{title}</h1>
<p>{message}</p>
</div>
</body>
</html>""")


@public_router.get("/payment/success", response_class=HTMLResponse, include_in_schema=False)
def payment_success_page():
    return _payment_redirect_page(
        "Payment received",
        "You can close this window and return to the Kinder World app.",
    )


@public_router.get("/payment/cancel", response_class=HTMLResponse, include_in_schema=False)
def payment_cancel_page():
    return _payment_redirect_page(
        "Checkout cancelled",
        "No charge was made. You can close this window and return to the Kinder World app.",
    )


@public_router.get("/payment/return", response_class=HTMLResponse, include_in_schema=False)
def payment_return_page():
    return _payment_redirect_page(
        "Billing portal closed",
        "You can close this window and return to the Kinder World app.",
    )
