from typing import Any, List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from services.subscription_service import subscription_service

router = APIRouter(prefix="/subscription", tags=["subscription"])
public_router = APIRouter(tags=["subscription"])
billing_router = APIRouter(prefix="/billing", tags=["subscription"])


class SubscriptionLifecycleOut(BaseModel):
    current_plan_id: str
    selected_plan_id: Optional[str] = None
    status: str
    started_at: Optional[str] = None
    expires_at: Optional[str] = None
    cancel_at: Optional[str] = None
    will_renew: bool
    last_payment_status: str
    provider: str
    provider_customer_id: Optional[str] = None
    provider_subscription_id: Optional[str] = None
    is_active: bool


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
    period: str
    features: dict[str, Any]


class SubscriptionStatus(BaseModel):
    current_plan_id: str
    is_active: bool
    status: str
    started_at: Optional[str] = None
    expires_at: Optional[str] = None
    cancel_at: Optional[str] = None
    will_renew: Optional[bool] = None
    last_payment_status: Optional[str] = None


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


class RefundRequest(BaseModel):
    amount_cents: int | None = None
    reason: str | None = None


@router.get("/me", response_model=SubscriptionInfo)
def get_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.get_subscription(db=db, user=user)


@router.get("/history", response_model=SubscriptionHistoryOut)
def get_subscription_history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.subscription_history(db=db, user=user)


@router.post("/upgrade", response_model=SubscriptionInfo)
def upgrade_subscription(
    payload: SubscriptionChange,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.upgrade_subscription(payload=payload, db=db, user=user)


@router.post("/cancel", response_model=SubscriptionInfo)
def cancel_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.cancel_subscription(db=db, user=user)


@public_router.get("/plans", response_model=List[PlanOut])
def list_plans():
    return subscription_service.list_plans()


@router.get("", response_model=SubscriptionStatus)
def subscription_status(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.subscription_status(db=db, user=user)


@router.post("/select", response_model=SubscriptionSelectResponse)
def select_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.select_subscription(payload=payload, db=db, user=user)


@router.post("/checkout", response_model=SubscriptionSelectResponse)
def create_checkout_session(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.create_checkout_session(payload=payload, db=db, user=user)


@router.post("/activate", response_model=SubscriptionSelectResponse)
def activate_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.activate_subscription(payload=payload, db=db, user=user)


@router.post("/manage")
def manage_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.manage_subscription(db=db, user=user)


@billing_router.post("/portal")
def billing_portal(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return subscription_service.billing_portal(db=db, user=user)
