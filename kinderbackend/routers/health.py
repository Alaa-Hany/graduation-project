from __future__ import annotations

import time

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from core.settings import settings
from core.time_utils import db_utc_now
from deps import get_db
from services.ai_buddy_response_generator import ai_buddy_response_generator
from services.payment_provider import get_payment_provider

router = APIRouter(prefix="/health", tags=["Health"])


def _check_db(db: Session) -> dict[str, object]:
    started = time.perf_counter()
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:
        return {
            "status": "fail",
            "latency_ms": int((time.perf_counter() - started) * 1000),
            "error": str(exc),
        }
    return {
        "status": "ok",
        "latency_ms": int((time.perf_counter() - started) * 1000),
    }


def _payment_readiness() -> dict[str, object]:
    provider = get_payment_provider()
    readiness = {
        "provider": provider.provider_key,
        "is_external": provider.is_external,
        "configured": True,
        "missing": [],
    }
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
        readiness["missing"] = missing
        readiness["configured"] = len(missing) == 0
    return readiness


def _ai_readiness() -> dict[str, object]:
    state = ai_buddy_response_generator.provider_state()
    return {
        "configured": state.configured,
        "mode": state.mode,
        "status": state.status,
        "reason": state.reason,
    }


def _background_readiness() -> dict[str, object]:
    return {
        "payment_reconciliation_enabled": settings.payment_reconciliation_enabled,
        "payment_reconciliation_schedule": settings.payment_reconciliation_schedule,
    }


@router.get("")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "service": "kinderbackend",
        "environment": settings.environment,
        "timestamp": db_utc_now().isoformat(),
    }


@router.get("/db")
def health_db(db: Session = Depends(get_db)) -> dict[str, object]:
    return _check_db(db)


@router.get("/ready")
def readiness(db: Session = Depends(get_db)) -> dict[str, object]:
    db_status = _check_db(db)
    payment = _payment_readiness()
    ai = _ai_readiness()
    background = _background_readiness()
    ok = db_status["status"] == "ok" and payment["configured"]
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "fail",
                "db": db_status,
                "payment": payment,
                "ai": ai,
                "background_jobs": background,
            },
        )
    return {
        "status": "ok",
        "db": db_status,
        "payment": payment,
        "ai": ai,
        "background_jobs": background,
    }
