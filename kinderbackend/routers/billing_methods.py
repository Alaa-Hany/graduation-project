from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from services.subscription_service import subscription_service

# Own the dedicated /billing/methods subtree rather than sharing the bare
# /billing prefix with subscription.billing_router. The public paths are
# unchanged (/billing/methods, /billing/methods/{id}); this just makes prefix
# ownership explicit so the two routers can't silently collide on a future route.
router = APIRouter(prefix="/billing/methods", tags=["billing"])


class PaymentMethodIn(BaseModel):
    label: str = Field("Payment method", min_length=2, max_length=100)
    provider_method_id: str | None = None
    set_default: bool = False


@router.get("")
def list_methods(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    methods = subscription_service.sync_payment_methods(db=db, user=user)
    return {"methods": methods}


@router.post("")
def add_method(
    payload: PaymentMethodIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    method = subscription_service.add_payment_method(
        db=db,
        user=user,
        label=payload.label,
        provider_method_id=payload.provider_method_id,
        set_default=payload.set_default,
    )
    return {"method": method}


@router.delete("/{method_id}")
def delete_method(
    method_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    subscription_service.delete_payment_method(db=db, user=user, method_id=method_id)
    return {"success": True}
