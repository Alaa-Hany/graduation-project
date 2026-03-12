import logging
from datetime import date, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from deps import get_db, require_feature
from models import ChildProfile, Notification, PaymentMethod, SupportTicket, User

logger = logging.getLogger(__name__)
router = APIRouter(tags=["features"])
FEATURE_ERROR_CODE = "FEATURE_NOT_AVAILABLE_IN_PLAN"


def _serialize_child(child: ChildProfile) -> dict:
    return {
        "id": child.id,
        "name": child.name,
        "age": child.age,
        "avatar": child.avatar,
        "is_active": child.is_active,
        "created_at": child.created_at.isoformat() if child.created_at else None,
        "updated_at": child.updated_at.isoformat() if child.updated_at else None,
    }


def _build_empty_daily_points(days: int) -> list[dict]:
    today = date.today()
    points: list[dict] = []
    for offset in range(days - 1, -1, -1):
        point_date = today - timedelta(days=offset)
        points.append(
            {
                "date": point_date.isoformat(),
                "screen_time_minutes": 0,
                "activities_completed": 0,
                "lessons_completed": 0,
                "data_available": False,
            }
        )
    return points


def _data_availability(children: list[ChildProfile]) -> dict[str, bool]:
    has_children = bool(children)
    return {
        "child_profiles": has_children,
        "screen_time": False,
        "activities": False,
        "lessons": False,
        "mood_trends": False,
        "achievements": False,
    }


def _basic_summary(db: Session, user_id: int, children: list[ChildProfile]) -> dict:
    unread_notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read.is_(False))
        .count()
    )
    open_support_tickets = (
        db.query(SupportTicket)
        .filter(
            SupportTicket.user_id == user_id,
            SupportTicket.status.in_(("open", "in_progress")),
        )
        .count()
    )
    payment_methods = (
        db.query(PaymentMethod)
        .filter(PaymentMethod.user_id == user_id)
        .count()
    )
    return {
        "child_count": len(children),
        "active_child_count": sum(1 for child in children if child.is_active),
        "unread_notifications": unread_notifications,
        "open_support_tickets": open_support_tickets,
        "payment_methods_count": payment_methods,
    }


# ===============================
# REPORTS ENDPOINTS (Free & Premium)
# ===============================


@router.get("/reports/basic")
def get_basic_reports(
    user: User = Depends(require_feature("basic_reports")),
    db: Session = Depends(get_db),
):
    """
    Return truthful parent report metadata based on backend data that actually
    exists today. Session analytics are explicitly marked unavailable until a
    richer tracking source is synced.
    """
    logger.info("Basic reports requested by user %s", user.id)
    children = (
        db.query(ChildProfile)
        .filter(ChildProfile.parent_id == user.id)
        .order_by(ChildProfile.created_at.desc(), ChildProfile.id.desc())
        .all()
    )
    return {
        "reports": _build_empty_daily_points(7),
        "summary": _basic_summary(db, user.id, children),
        "children": [_serialize_child(child) for child in children],
        "data_availability": _data_availability(children),
        "data_source": "backend_child_profiles",
        "access_level": "basic",
    }


@router.get("/reports/advanced")
def advanced_reports(
    user: User = Depends(require_feature("advanced_reports")),
    db: Session = Depends(get_db),
):
    """
    Return advanced report metadata using available backend profile data without
    claiming unsupported analytics.
    """
    logger.info("Advanced reports requested by user %s", user.id)
    children = (
        db.query(ChildProfile)
        .filter(ChildProfile.parent_id == user.id)
        .order_by(ChildProfile.created_at.desc(), ChildProfile.id.desc())
        .all()
    )
    newest_child = children[0] if children else None
    age_distribution = {
        "5_6": sum(1 for child in children if (child.age or 0) in (5, 6)),
        "7_9": sum(1 for child in children if 7 <= (child.age or 0) <= 9),
        "10_12": sum(1 for child in children if 10 <= (child.age or 0) <= 12),
        "unknown": sum(1 for child in children if child.age is None),
    }

    return {
        "reports": {
            "daily_overview": _build_empty_daily_points(30),
            "children": [_serialize_child(child) for child in children],
            "account_summary": {
                **_basic_summary(db, user.id, children),
                "newest_child_created_at": newest_child.created_at.isoformat()
                if newest_child and newest_child.created_at
                else None,
            },
            "age_distribution": age_distribution,
            "data_availability": _data_availability(children),
            "insight_notes": [
                "Activity analytics are not yet synced to the backend.",
                "Child roster summaries are generated from saved parent and child profiles.",
            ],
            "comparison": {
                "status": "not_available",
                "reason": "No historical backend activity tracking is currently stored.",
            },
        },
        "access_level": "advanced",
    }


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
    return {
        "notifications": [
            {
                "id": 1,
                "type": "SCREEN_TIME_LIMIT",
                "message": "Child reached 1 hour screen time today",
                "created_at": "2024-01-18T14:30:00Z"
            },
            {
                "id": 2,
                "type": "WEEKLY_SUMMARY",
                "message": "Weekly summary ready for review",
                "created_at": "2024-01-17T08:00:00Z"
            },
        ],
        "access_level": "basic"
    }


@router.get("/notifications/smart")
def get_smart_notifications(user: User = Depends(require_feature("smart_notifications"))):
    """
    Get AI-driven smart notifications (Premium+ only).
    Includes behavioral insights, anomaly alerts, predictive warnings.
    """
    logger.info(f"Smart notifications requested by user {user.id}")
    return {
        "notifications": [
            {
                "id": 1,
                "type": "BEHAVIORAL_INSIGHT",
                "message": "Child's usage pattern changing: 20% increase in evening usage",
                "severity": "warning",
                "created_at": "2024-01-18T16:00:00Z"
            },
            {
                "id": 2,
                "type": "ANOMALY_ALERT",
                "message": "Unusual activity: New app installed at 2 AM",
                "severity": "critical",
                "created_at": "2024-01-18T02:15:00Z"
            },
        ],
        "access_level": "smart"
    }


# ===============================
# PARENTAL CONTROLS (Free & Premium)
# ===============================


@router.get("/parental-controls/basic")
def get_basic_parental_controls(user: User = Depends(require_feature("basic_parental_controls"))):
    """
    Get basic parental controls (Free users).
    Includes screen time limits, app blocking.
    """
    logger.info(f"Basic parental controls requested by user {user.id}")
    return {
        "controls": [
            {"id": 1, "type": "SCREEN_TIME_LIMIT", "value": 60, "unit": "minutes"},
            {"id": 2, "type": "BEDTIME", "start": "21:00", "end": "07:00"},
            {"id": 3, "type": "BLOCKED_APPS", "apps": ["TikTok", "Snapchat"]},
        ],
        "access_level": "basic"
    }


@router.get("/parental-controls/advanced")
def get_advanced_parental_controls(user: User = Depends(require_feature("advanced_reports"))):
    """
    Get advanced parental controls (Premium+ only).
    Includes smart rules, per-app time limits, location tracking.
    """
    logger.info(f"Advanced parental controls requested by user {user.id}")
    return {
        "controls": [
            {"id": 1, "type": "SCREEN_TIME_LIMIT", "value": 60, "unit": "minutes"},
            {"id": 2, "type": "SMART_RULE", "rule": "Allow 15 min YouTube only on weekends"},
            {"id": 3, "type": "PER_APP_LIMIT", "app": "Games", "limit": 30, "unit": "minutes"},
            {"id": 4, "type": "LOCATION_TRACKING", "enabled": True},
        ],
        "access_level": "advanced"
    }


# ===============================
# PREMIUM FEATURES
# ===============================


@router.get("/ai/insights")
def get_ai_insights(user: User = Depends(require_feature("ai_insights"))):
    """Get AI-powered insights (Premium+ only)."""
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
