from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from admin_deps import require_permission
from core.observability import get_recent_events, summarize_events
from core.settings import settings
from deps import get_db
from models import PaymentAttempt, PaymentWebhookEvent, SubscriptionEvent
from services.ai_buddy_response_generator import ai_buddy_response_generator
from services.payment_provider import get_payment_provider

router = APIRouter(prefix="/admin/diagnostics", tags=["Admin Diagnostics"])


def _payment_readiness() -> dict[str, object]:
    provider = get_payment_provider()
    missing: list[str] = []
    if settings.payment_provider == "stripe":
        missing = [
            name
            for name, value in {
                "STRIPE_SECRET_KEY": settings.stripe_secret_key,
                "STRIPE_WEBHOOK_SECRET": settings.stripe_webhook_secret,
                "STRIPE_CHECKOUT_SUCCESS_URL": settings.stripe_checkout_success_url,
                "STRIPE_CHECKOUT_CANCEL_URL": settings.stripe_checkout_cancel_url,
                "STRIPE_PORTAL_RETURN_URL": settings.stripe_portal_return_url,
                "STRIPE_PRICE_PREMIUM_MONTHLY": settings.stripe_price_premium_monthly,
                "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": settings.stripe_price_family_plus_monthly,
            }.items()
            if not value
        ]
    return {
        "provider": provider.provider_key,
        "is_external": provider.is_external,
        "configured": len(missing) == 0,
        "missing": missing,
    }


def _ai_readiness() -> dict[str, object]:
    state = ai_buddy_response_generator.provider_state()
    return {
        "configured": state.configured,
        "mode": state.mode,
        "status": state.status,
        "reason": state.reason,
    }


@router.get("/health")
def diagnostics_health(
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.settings.edit")),
):
    webhook_failures = (
        db.query(func.count(PaymentWebhookEvent.id))
        .filter(
            (PaymentWebhookEvent.status == "failed")
            | (PaymentWebhookEvent.signature_valid.is_(False))
        )
        .scalar()
        or 0
    )
    reconciliation_issues = (
        db.query(func.count(SubscriptionEvent.id))
        .filter(
            SubscriptionEvent.event_type.in_(
                ["reconciliation_mismatch", "reconciliation_error"]
            )
        )
        .scalar()
        or 0
    )
    payment_failures = (
        db.query(func.count(PaymentAttempt.id))
        .filter(PaymentAttempt.status.in_(["failed", "action_required"]))
        .scalar()
        or 0
    )
    return {
        "environment": settings.environment,
        "payment": _payment_readiness(),
        "ai": _ai_readiness(),
        "background_jobs": {
            "payment_reconciliation_enabled": settings.payment_reconciliation_enabled,
            "payment_reconciliation_schedule": settings.payment_reconciliation_schedule,
        },
        "counters": {
            "webhook_failures": webhook_failures,
            "reconciliation_issues": reconciliation_issues,
            "payment_failures": payment_failures,
        },
    }


@router.get("/events")
def diagnostics_events(
    limit: int = Query(100, ge=1, le=500),
    category: str = Query(""),
    name_prefix: str = Query(""),
    min_severity: str = Query("info"),
    admin=Depends(require_permission("admin.settings.edit")),
):
    events = get_recent_events(
        limit=limit,
        category=category or None,
        name_prefix=name_prefix or None,
        min_severity=min_severity or None,
    )
    return {
        "items": events,
        "summary": summarize_events(events),
        "filters": {
            "category": category,
            "name_prefix": name_prefix,
            "min_severity": min_severity,
        },
    }
