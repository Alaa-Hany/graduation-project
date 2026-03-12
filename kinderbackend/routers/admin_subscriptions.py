from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import build_pagination_payload, serialize_subscription_record, write_audit_log
from deps import get_db
from models import User
from notification_service import notify_subscription_changed
from plan_service import PLAN_FREE, validate_plan_value

router = APIRouter(prefix="/admin/subscriptions", tags=["Admin Subscriptions"])


class SubscriptionOverrideRequest(BaseModel):
    plan: str


def _subscriptions_query(db: Session):
    return db.query(User).options(
        joinedload(User.children),
        joinedload(User.payment_methods),
    )


def _get_subscription_or_404(subscription_id: int, db: Session) -> User:
    user = _subscriptions_query(db).filter(User.id == subscription_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Subscription record not found")
    return user


@router.get("")
def list_admin_subscriptions(
    search: str = Query(""),
    status_filter: str = Query("", alias="status"),
    plan_filter: str = Query("", alias="plan"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.view")),
):
    query = _subscriptions_query(db)

    if search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(User.email).like(term)
            | func.lower(func.coalesce(User.name, "")).like(term)
        )

    normalized_plan = plan_filter.strip().upper()
    if normalized_plan:
        query = query.filter(func.upper(User.plan) == normalized_plan)

    normalized_status = status_filter.strip().lower()
    if normalized_status == "active":
        query = query.filter(User.is_active.is_(True), func.upper(User.plan) != PLAN_FREE)
    elif normalized_status == "free":
        query = query.filter(User.is_active.is_(True), func.upper(User.plan) == PLAN_FREE)
    elif normalized_status == "disabled":
        query = query.filter(User.is_active.is_(False))

    total = query.count()
    items = (
        query.order_by(User.updated_at.desc(), User.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_subscription_record(item) for item in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {
            "search": search,
            "status": normalized_status,
            "plan": normalized_plan,
        },
    }


@router.get("/{subscription_id}")
def get_admin_subscription(
    subscription_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.view")),
):
    user = _get_subscription_or_404(subscription_id, db)
    return {"item": serialize_subscription_record(user)}


@router.post("/{subscription_id}/override-plan")
def override_subscription_plan(
    subscription_id: int,
    payload: SubscriptionOverrideRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    try:
        plan = validate_plan_value(payload.plan)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid plan")

    previous_plan = before["plan"]
    user.plan = plan
    user.updated_at = datetime.utcnow()
    db.add(user)
    db.flush()
    notify_subscription_changed(
        db,
        user=user,
        old_plan=previous_plan,
        new_plan=plan,
        source="admin_override",
    )
    after = serialize_subscription_record(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="subscription.override_plan",
        entity_type="subscription",
        entity_id=user.id,
        before_json=before,
        after_json=after,
    )
    db.commit()
    return {"success": True, "item": after}


@router.post("/{subscription_id}/cancel")
def cancel_admin_subscription(
    subscription_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    previous_plan = before["plan"]
    user.plan = PLAN_FREE
    user.updated_at = datetime.utcnow()
    db.add(user)
    db.flush()
    notify_subscription_changed(
        db,
        user=user,
        old_plan=previous_plan,
        new_plan=PLAN_FREE,
        source="admin_cancel",
    )
    after = serialize_subscription_record(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="subscription.cancel",
        entity_type="subscription",
        entity_id=user.id,
        before_json=before,
        after_json=after,
    )
    db.commit()
    return {"success": True, "item": after}


@router.post("/{subscription_id}/refund")
def refund_admin_subscription(
    subscription_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    after = {
        "id": user.id,
        "refund_supported": False,
        "message": "Refunds are not supported by the current payment model",
    }
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="subscription.refund_not_supported",
        entity_type="subscription",
        entity_id=user.id,
        before_json=before,
        after_json=after,
    )
    db.commit()
    raise HTTPException(
        status_code=501,
        detail="Refunds are not supported by the current payment model",
    )
