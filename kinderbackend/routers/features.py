import asyncio
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from core.errors import http_error
from core.report_cache import (
    cache_report,
    get_cached_report,
    invalidate_report_cache,
    report_cache_key,
)
from core.system_settings import require_ai_buddy_enabled
from deps import AnalyticsPrincipal, get_analytics_principal, get_db, require_feature
from models import User
from schemas.analytics import ActivityEventIn, SessionLogIn
from services.analytics_service import analytics_service
from services.child_development_service import child_development_service
from services.notification_service import notification_service
from services.parental_controls_service import list_parent_child_controls
from services.premium_behavior_service import premium_behavior_service

logger = logging.getLogger(__name__)
router = APIRouter(tags=["features"])
FEATURE_ERROR_CODE = "FEATURE_NOT_AVAILABLE_IN_PLAN"


# ===============================
# ANALYTICS INGESTION
# ===============================


def _authorize_child_scope(principal: AnalyticsPrincipal, child_id: int) -> None:
    """A child_session caller may only push data for its own child id."""
    if principal.child is not None and int(child_id) != int(principal.child.id):
        raise http_error(
            status_code=403,
            message="Children can only submit their own analytics.",
            code="CHILD_SCOPE_MISMATCH",
        )


@router.post("/analytics/events")
def ingest_activity_event(
    payload: ActivityEventIn,
    db: Session = Depends(get_db),
    principal: AnalyticsPrincipal = Depends(get_analytics_principal),
):
    _authorize_child_scope(principal, payload.child_id)
    result = analytics_service.record_activity_event(
        db=db, parent=principal.parent, payload=payload
    )
    # New activity invalidates every cached report variant for this parent.
    invalidate_report_cache(principal.parent.id)
    return result


@router.post("/analytics/sessions")
def ingest_session_log(
    payload: SessionLogIn,
    db: Session = Depends(get_db),
    principal: AnalyticsPrincipal = Depends(get_analytics_principal),
):
    _authorize_child_scope(principal, payload.child_id)
    result = analytics_service.record_session_log(db=db, parent=principal.parent, payload=payload)
    # New screen-time data changes report aggregates → drop cached reports.
    invalidate_report_cache(principal.parent.id)
    return result


# ===============================
# REPORTS ENDPOINTS (Free & Premium)
# ===============================


@router.get("/reports/basic")
async def get_basic_reports(
    child_id: int | None = Query(None),
    days: int = Query(7, ge=1, le=365),
    user: User = Depends(require_feature("basic_reports")),
    db: Session = Depends(get_db),
):
    logger.info("Basic reports requested by user %s", user.id)
    cache_key = report_cache_key(user_id=user.id, child_id=child_id, report_type="basic", days=days)
    cached = get_cached_report(cache_key)
    if cached is not None:
        return cached

    # Heavy multi-table aggregation: run off the event loop so concurrent
    # requests are not blocked while the DB work happens.
    payload = await asyncio.to_thread(
        analytics_service.build_basic_report,
        db=db,
        user=user,
        child_id=child_id,
        days=days,
    )
    cache_report(cache_key, payload)
    return payload


@router.get("/reports/advanced")
async def advanced_reports(
    child_id: int | None = Query(None),
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(require_feature("advanced_reports")),
    db: Session = Depends(get_db),
):
    logger.info("Advanced reports requested by user %s", user.id)
    cache_key = report_cache_key(
        user_id=user.id, child_id=child_id, report_type="advanced", days=days
    )
    cached = get_cached_report(cache_key)
    if cached is not None:
        return cached

    payload = await asyncio.to_thread(
        analytics_service.build_advanced_report,
        db=db,
        user=user,
        child_id=child_id,
        days=days,
    )
    cache_report(cache_key, payload)
    return payload


@router.get("/reports/development")
async def child_development_report(
    child_id: int = Query(..., description="Child to evaluate"),
    days: int = Query(30, ge=1, le=365),
    language: str = Query("ar"),
    user: User = Depends(require_feature("advanced_reports")),
    db: Session = Depends(get_db),
):
    """Parent-facing development profile: four strength/growth areas with an AI summary."""
    logger.info("Development report requested by user %s for child %s", user.id, child_id)
    lang = "ar" if str(language).lower().startswith("ar") else "en"
    cache_key = report_cache_key(
        user_id=user.id, child_id=child_id, report_type=f"development_{lang}", days=days
    )
    cached = get_cached_report(cache_key)
    if cached is not None:
        return cached

    payload = await asyncio.to_thread(
        child_development_service.build_development_profile,
        db=db,
        user=user,
        child_id=child_id,
        days=days,
        language=lang,
    )
    cache_report(cache_key, payload)
    return payload


# ===============================
# NOTIFICATIONS (Free & Premium)
# ===============================


@router.get("/notifications/basic")
def get_notifications(
    user: User = Depends(require_feature("basic_notifications")),
    db: Session = Depends(get_db),
):
    """
    Get basic notifications (Free users).
    Includes system alerts, weekly summaries.
    """
    logger.info(f"Basic notifications requested by user {user.id}")
    return notification_service.get_basic_feature_notifications(db=db, user=user)


@router.get("/notifications/smart")
def get_smart_notifications(
    user: User = Depends(require_feature("smart_notifications")),
    db: Session = Depends(get_db),
):
    """
    Get AI-driven smart notifications (Premium+ only).
    Includes behavioral insights, anomaly alerts, predictive warnings.
    """
    logger.info(f"Smart notifications requested by user {user.id}")
    return notification_service.get_smart_feature_notifications(db=db, user=user)


# ===============================
# PARENTAL CONTROLS (Free & Premium)
# ===============================


@router.get("/parental-controls/basic")
def get_basic_parental_controls(
    user: User = Depends(require_feature("basic_parental_controls")),
    db: Session = Depends(get_db),
):
    """
    Get basic parental controls (Free users).
    Includes screen time limits, app blocking.
    """
    logger.info("Basic parental controls requested by user %s", user.id)
    items = list_parent_child_controls(db, user)
    controls: list[dict] = []
    for item in items:
        child = item["child"]
        control = item["control"]
        settings = control["settings"]
        controls.append(
            {
                "child_id": child["id"],
                "child_name": child["name"],
                "type": "SCREEN_TIME_LIMIT",
                "enabled": settings["daily_limit_enabled"],
                "value_minutes": settings["daily_limit_minutes"],
            }
        )
        controls.append(
            {
                "child_id": child["id"],
                "child_name": child["name"],
                "type": "BEDTIME",
                "enabled": settings["sleep_mode"],
                "start": settings["bedtime_start"],
                "end": settings["bedtime_end"],
            }
        )
        controls.append(
            {
                "child_id": child["id"],
                "child_name": child["name"],
                "type": "BLOCKED_APPS",
                "count": len(control["blocked_apps"]),
            }
        )
    return {
        "controls": controls,
        "access_level": "basic",
        "data_source": "backend_parental_controls",
    }


@router.get("/parental-controls/advanced")
def get_advanced_parental_controls(
    user: User = Depends(require_feature("advanced_reports")),
    db: Session = Depends(get_db),
):
    """
    Get advanced parental controls (Premium+ only).
    Includes smart rules, per-app time limits, location tracking.
    """
    logger.info("Advanced parental controls requested by user %s", user.id)
    items = list_parent_child_controls(db, user)
    return {
        "controls": [
            {
                "child": item["child"],
                "settings": item["control"]["settings"],
                "allowed_windows": item["control"]["allowed_windows"],
                "blocked_apps": item["control"]["blocked_apps"],
                "blocked_sites": item["control"]["blocked_sites"],
                "enforcement": item["control"]["enforcement"],
                "updated_at": item["control"]["updated_at"],
            }
            for item in items
        ],
        "access_level": "advanced",
        "data_source": "backend_parental_controls",
    }


# ===============================
# PREMIUM FEATURES
# ===============================


@router.get("/ai/insights")
def get_ai_insights(
    user: User = Depends(require_feature("ai_insights")),
    db: Session = Depends(get_db),
):
    """Get AI-powered insights (Premium+ only)."""
    require_ai_buddy_enabled(db)
    logger.info(f"AI insights requested by user {user.id}")
    return premium_behavior_service.build_ai_insights(db=db, user=user)


@router.get("/downloads/offline")
def offline_downloads(
    user: User = Depends(require_feature("offline_downloads")),
    db: Session = Depends(get_db),
):
    """Download content for offline use (Premium+ only)."""
    logger.info(f"Offline download requested by user {user.id}")
    return premium_behavior_service.build_offline_downloads(db=db, user=user)


# ===============================
# FAMILY PLUS ONLY
# ===============================


@router.get("/support/priority")
def get_priority_support(
    user: User = Depends(require_feature("priority_support")),
    db: Session = Depends(get_db),
):
    """Priority support ticket access (Family Plus only)."""
    logger.info(f"Priority support requested by user {user.id}")
    return premium_behavior_service.build_priority_support(db=db, user=user)
