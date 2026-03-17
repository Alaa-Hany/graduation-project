from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import build_pagination_payload, serialize_subscription_record, write_audit_log
from core.admin_security import require_sensitive_action_confirmation
from deps import get_db
from models import PaymentAttempt, PaymentWebhookEvent, SubscriptionEvent, User
from plan_service import PLAN_FREE, validate_plan_value
from services.payment_reconciliation_service import payment_reconciliation_service
from services.subscription_service import subscription_service

router = APIRouter(prefix="/admin/subscriptions", tags=["Admin Subscriptions"])


class SubscriptionOverrideRequest(BaseModel):
    plan: str


class SubscriptionRefundRequest(BaseModel):
    amount_cents: int | None = None
    reason: str | None = None


class ReconciliationRequest(BaseModel):
    limit: int = 100
    include_pending: bool = True


def _subscriptions_query(db: Session):
    return db.query(User).options(
        joinedload(User.children),
        joinedload(User.payment_methods),
        joinedload(User.subscription_profile),
        joinedload(User.subscription_events),
        joinedload(User.billing_transactions),
        joinedload(User.payment_attempts),
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
            func.lower(User.email).like(term) | func.lower(func.coalesce(User.name, "")).like(term)
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
    item = serialize_subscription_record(user)
    profile = user.subscription_profile
    if profile is not None:
        item["recent_events"] = subscription_service._list_subscription_events(  # noqa: SLF001
            db=db,
            profile=profile,
            limit=20,
        )
        item["billing_history"] = subscription_service._list_billing_transactions(  # noqa: SLF001
            db=db,
            profile=profile,
            limit=20,
        )
        item["payment_attempts"] = subscription_service._list_payment_attempts(  # noqa: SLF001
            db=db,
            profile=profile,
            limit=20,
        )
    else:
        item["recent_events"] = []
        item["billing_history"] = []
        item["payment_attempts"] = []
    return {"item": item}


@router.get("/diagnostics")
def subscription_diagnostics(
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.view")),
):
    webhook_failures = (
        db.query(PaymentWebhookEvent)
        .filter(
            (PaymentWebhookEvent.status == "failed")
            | (PaymentWebhookEvent.signature_valid.is_(False))
        )
        .order_by(PaymentWebhookEvent.received_at.desc())
        .limit(limit)
        .all()
    )
    checkout_failures = (
        db.query(SubscriptionEvent)
        .filter(SubscriptionEvent.event_type.in_(["checkout_failed", "activation_failed"]))
        .order_by(SubscriptionEvent.occurred_at.desc())
        .limit(limit)
        .all()
    )
    portal_failures = (
        db.query(SubscriptionEvent)
        .filter(
            SubscriptionEvent.event_type == "failure",
            SubscriptionEvent.source.in_(["billing_portal", "parent_manage"]),
        )
        .order_by(SubscriptionEvent.occurred_at.desc())
        .limit(limit)
        .all()
    )
    refund_failures = (
        db.query(SubscriptionEvent)
        .filter(SubscriptionEvent.event_type == "refund_failed")
        .order_by(SubscriptionEvent.occurred_at.desc())
        .limit(limit)
        .all()
    )
    reconciliation_events = (
        db.query(SubscriptionEvent)
        .filter(
            SubscriptionEvent.event_type.in_(
                ["reconciliation_mismatch", "reconciliation_error"]
            )
        )
        .order_by(SubscriptionEvent.occurred_at.desc())
        .limit(limit)
        .all()
    )
    payment_failures = (
        db.query(PaymentAttempt)
        .filter(PaymentAttempt.status.in_(["failed", "action_required"]))
        .order_by(PaymentAttempt.requested_at.desc())
        .limit(limit)
        .all()
    )

    def _serialize_webhook(item: PaymentWebhookEvent):
        return {
            "id": item.id,
            "provider": item.provider,
            "event_id": item.event_id,
            "event_type": item.event_type,
            "status": item.status,
            "signature_valid": bool(item.signature_valid),
            "error_message": item.error_message,
            "received_at": item.received_at.isoformat() if item.received_at else None,
        }

    def _serialize_event(item: SubscriptionEvent):
        return subscription_service._serialize_subscription_event(item)  # noqa: SLF001

    def _serialize_attempt(item: PaymentAttempt):
        return subscription_service._serialize_payment_attempt(item)  # noqa: SLF001

    return {
        "summary": {
            "webhook_failures": len(webhook_failures),
            "checkout_failures": len(checkout_failures),
            "portal_failures": len(portal_failures),
            "refund_failures": len(refund_failures),
            "reconciliation_events": len(reconciliation_events),
            "payment_failures": len(payment_failures),
        },
        "webhook_failures": [_serialize_webhook(item) for item in webhook_failures],
        "checkout_failures": [_serialize_event(item) for item in checkout_failures],
        "portal_failures": [_serialize_event(item) for item in portal_failures],
        "refund_failures": [_serialize_event(item) for item in refund_failures],
        "reconciliation_events": [_serialize_event(item) for item in reconciliation_events],
        "payment_failures": [_serialize_attempt(item) for item in payment_failures],
    }


@router.post("/reconcile")
def reconcile_subscriptions(
    payload: ReconciliationRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    require_sensitive_action_confirmation(request, action="subscription.reconcile")
    result = payment_reconciliation_service.reconcile_all(
        db=db,
        limit=payload.limit,
        include_pending=payload.include_pending,
    )
    return {
        "scanned": result.scanned,
        "updated": result.updated,
        "mismatches": result.mismatches,
        "errors": result.errors,
        "issues": [
            {
                "user_id": item.user_id,
                "profile_id": item.profile_id,
                "provider_subscription_id": item.provider_subscription_id,
                "issue_type": item.issue_type,
                "details": item.details,
            }
            for item in result.issues
        ],
    }


@router.post("/{subscription_id}/override-plan")
def override_subscription_plan(
    subscription_id: int,
    payload: SubscriptionOverrideRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    require_sensitive_action_confirmation(request, action="subscription.override_plan")
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    try:
        plan = validate_plan_value(payload.plan)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid plan")
    subscription_service.admin_override_subscription(
        db=db,
        user=user,
        plan=plan,
        source="admin_override",
    )
    db.refresh(user)
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
    require_sensitive_action_confirmation(request, action="subscription.cancel")
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    subscription_service.cancel_subscription(db=db, user=user, source="admin_cancel")
    db.refresh(user)
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
    payload: SubscriptionRefundRequest | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.subscription.override")),
):
    require_sensitive_action_confirmation(request, action="subscription.refund")
    user = _get_subscription_or_404(subscription_id, db)
    before = serialize_subscription_record(user)
    result = subscription_service.refund_subscription(
        db=db,
        user=user,
        source="admin_refund",
        amount_cents=payload.amount_cents if payload is not None else None,
        reason=payload.reason if payload is not None else None,
    )
    db.refresh(user)
    after = {
        "subscription": serialize_subscription_record(user),
        "refund": result,
    }
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="subscription.refund",
        entity_type="subscription",
        entity_id=user.id,
        before_json=before,
        after_json=after,
    )
    db.commit()
    return {"success": True, **result, "item": after["subscription"]}
