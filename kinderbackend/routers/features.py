import logging

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from deps import get_current_user, get_db, require_feature
from models import User
from schemas.analytics import ActivityEventIn, SessionLogIn
from core.system_settings import require_ai_buddy_enabled
from services.notification_service import notification_service
from services.analytics_service import analytics_service
from services.parental_controls_service import list_parent_child_controls

logger = logging.getLogger(__name__)
router = APIRouter(tags=["features"])
FEATURE_ERROR_CODE = "FEATURE_NOT_AVAILABLE_IN_PLAN"


# ===============================
# ANALYTICS INGESTION
# ===============================


@router.post("/analytics/events")
def ingest_activity_event(
    payload: ActivityEventIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return analytics_service.record_activity_event(db=db, parent=user, payload=payload)


@router.post("/analytics/sessions")
def ingest_session_log(
    payload: SessionLogIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return analytics_service.record_session_log(db=db, parent=user, payload=payload)


# ===============================
# REPORTS ENDPOINTS (Free & Premium)
# ===============================


@router.get("/reports/basic")
def get_basic_reports(
    user: User = Depends(require_feature("basic_reports")),
    db: Session = Depends(get_db),
):
    logger.info("Basic reports requested by user %s", user.id)
    return analytics_service.build_basic_report(db=db, user=user)


@router.get("/reports/advanced")
def advanced_reports(
    user: User = Depends(require_feature("advanced_reports")),
    db: Session = Depends(get_db),
):
    logger.info("Advanced reports requested by user %s", user.id)
    return analytics_service.build_advanced_report(db=db, user=user)


# ===============================
# NOTIFICATIONS (Free & Premium)
# ===============================


@router.get("/notifications/basic")
def get_notifications(user: User = Depends(require_feature("basic_notifications"))):
    """
    Get basic notifications (Free users).
    Includes system alerts, weekly summaries.
    """
    logger.info(f"Basic notifications requested by user {user.id}")
    return notification_service.get_basic_feature_notifications(user=user)


@router.get("/notifications/smart")
def get_smart_notifications(user: User = Depends(require_feature("smart_notifications"))):
    """
    Get AI-driven smart notifications (Premium+ only).
    Includes behavioral insights, anomaly alerts, predictive warnings.
    """
    logger.info(f"Smart notifications requested by user {user.id}")
    return notification_service.get_smart_feature_notifications(user=user)


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
    return {"controls": controls, "access_level": "basic", "data_source": "backend_parental_controls"}


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
    return {
        "insights": [
            "Bedtime recommendations: Consider moving bedtime 30 minutes earlier (based on sleep goals)",
            "App suggestion: Try 'Khan Academy' - matches educational interests",
        ]
    }


@router.get("/downloads/offline")
def offline_downloads(user: User = Depends(require_feature("offline_downloads"))):
    """Download content for offline use (Premium+ only)."""
    logger.info(f"Offline download requested by user {user.id}")
    return {
        "status": "downloads enabled",
        "quota_mb": 500,
        "used_mb": 120
    }


# ===============================
# FAMILY PLUS ONLY
# ===============================


@router.get("/support/priority")
def get_priority_support(user: User = Depends(require_feature("priority_support"))):
    """Priority support ticket access (Family Plus only)."""
    logger.info(f"Priority support requested by user {user.id}")
    return {
        "support_level": "priority",
        "response_time_hours": 2,
        "support_channels": ["email", "chat", "phone"]
    }
