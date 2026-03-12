from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from deps import get_db, get_current_user
from models import User
from notification_service import notify_subscription_changed
from plan_service import (
    PLAN_FREE,
    get_plan_catalog,
    get_plan_features,
    get_plan_limits,
    get_user_plan,
    validate_plan_value,
)

router = APIRouter(prefix="/subscription", tags=["subscription"])
public_router = APIRouter(tags=["subscription"])
billing_router = APIRouter(prefix="/billing", tags=["subscription"])


class SubscriptionInfo(BaseModel):
    plan: str
    limits: dict
    features: dict


class SubscriptionChange(BaseModel):
    plan: str


class PlanOut(BaseModel):
    id: str
    name: str
    price: float
    period: str
    features: dict


class SubscriptionStatus(BaseModel):
    current_plan_id: str
    is_active: bool
    expires_at: Optional[str] = None
    will_renew: Optional[bool] = None


class SubscriptionSelectRequest(BaseModel):
    plan_id: str | None = Field(None, description="Plan id: FREE|PREMIUM|FAMILY_PLUS")
    plan_type: str | None = Field(None, description="Alias for plan_id (Flutter compat): free|premium|family_plus")

    @property
    def resolved_plan(self) -> str:
        """Return the plan identifier, normalised to uppercase."""
        raw = self.plan_id or self.plan_type or ""
        return raw.strip().upper().replace("-", "_")


class SubscriptionSelectResponse(SubscriptionStatus):
    payment_intent_url: Optional[str] = None
    session_id: Optional[str] = None


def _build_mock_checkout(plan: str, user_id: int) -> dict[str, str]:
    normalized_plan = plan.lower()
    session_id = f"mock_session_{user_id}_{normalized_plan}"
    return {
        "session_id": session_id,
        "payment_intent_url": f"https://example.invalid/mock-checkout/{session_id}",
    }


@router.get("/me", response_model=SubscriptionInfo)
def get_subscription(user: User = Depends(get_current_user)):
    plan = get_user_plan(user)
    return {
        "plan": plan,
        "limits": get_plan_limits(plan),
        "features": get_plan_features(plan),
    }


@router.post("/upgrade", response_model=SubscriptionInfo)
def upgrade_subscription(
    payload: SubscriptionChange,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    previous_plan = get_user_plan(user)
    try:
        plan = validate_plan_value(payload.plan)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid plan")

    user.plan = plan
    db.add(user)
    db.commit()
    db.refresh(user)
    notify_subscription_changed(
        db,
        user=user,
        old_plan=previous_plan,
        new_plan=plan,
        source="parent_upgrade",
    )
    db.commit()

    return {
        "plan": plan,
        "limits": get_plan_limits(plan),
        "features": get_plan_features(plan),
    }


@router.post("/cancel", response_model=SubscriptionInfo)
def cancel_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    previous_plan = get_user_plan(user)
    user.plan = PLAN_FREE
    db.add(user)
    db.commit()
    db.refresh(user)
    notify_subscription_changed(
        db,
        user=user,
        old_plan=previous_plan,
        new_plan=PLAN_FREE,
        source="parent_cancel",
    )
    db.commit()

    return {
        "plan": PLAN_FREE,
        "limits": get_plan_limits(PLAN_FREE),
        "features": get_plan_features(PLAN_FREE),
    }


@public_router.get("/plans", response_model=List[PlanOut])
def list_plans():
    catalog = get_plan_catalog()
    plans = []
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


@router.get("", response_model=SubscriptionStatus)
def subscription_status(user: User = Depends(get_current_user)):
    plan = get_user_plan(user)
    return {
        "current_plan_id": plan,
        "is_active": bool(user.is_active),
        "expires_at": None,
        "will_renew": None,
    }


@router.post("/select", response_model=SubscriptionSelectResponse)
def select_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    requested = payload.resolved_plan
    if not requested:
        raise HTTPException(status_code=422, detail="plan_id or plan_type is required")
    catalog = get_plan_catalog()
    if requested not in catalog:
        raise HTTPException(status_code=400, detail=f"Invalid plan '{requested}'. Valid: {list(catalog.keys())}")

    plan = requested
    previous_plan = get_user_plan(user)
    user.plan = plan
    db.add(user)
    db.commit()
    db.refresh(user)
    notify_subscription_changed(
        db,
        user=user,
        old_plan=previous_plan,
        new_plan=plan,
        source="parent_select",
    )
    db.commit()

    response = {
        "current_plan_id": plan,
        "is_active": True,
        "expires_at": None,
        "will_renew": False,
    }
    if plan != PLAN_FREE:
        response.update(_build_mock_checkout(plan, user.id))
    return response


@router.post("/activate", response_model=SubscriptionSelectResponse)
def activate_subscription(
    payload: SubscriptionSelectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Alias for /subscription/select — keeps frontend compatibility."""
    return select_subscription(payload=payload, db=db, user=user)


@router.post("/manage")
def manage_subscription(user: User = Depends(get_current_user)):
    raise HTTPException(
        status_code=501,
        detail="Billing portal is not configured yet",
    )


@billing_router.post("/portal")
def billing_portal(user: User = Depends(get_current_user)):
    raise HTTPException(
        status_code=501,
        detail="Billing portal is not configured yet",
    )
