from datetime import date, datetime
from typing import Dict, Optional

from core.time_utils import ensure_utc
from models import ChildProfile, Notification, User
from plan_service import get_plan_features, get_plan_limits, get_user_plan


def _iso_z(dt: Optional[datetime]) -> Optional[str]:
    if not dt:
        return None
    s = ensure_utc(dt).isoformat()
    if s.endswith("Z") or s.endswith("+00:00"):
        return s
    return s + "Z"


def _iso_date(d: Optional[date]) -> Optional[str]:
    if not d:
        return None
    return d.isoformat()


def _age_from_dob(dob: Optional[date]) -> Optional[int]:
    if not dob:
        return None
    today = date.today()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return max(age, 0)


def user_to_json(user: User) -> Dict:
    plan = get_user_plan(user)
    return {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "name": user.name,
        "is_active": bool(user.is_active),
        "plan": plan,
        "limits": get_plan_limits(plan),
        "features": get_plan_features(plan),
        "created_at": _iso_z(user.created_at),
        "updated_at": _iso_z(user.updated_at),
    }


def child_to_json(child: ChildProfile) -> Dict:
    stored_age = getattr(child, "age", None)
    age_from_dob = _age_from_dob(getattr(child, "date_of_birth", None))
    resolved_age = stored_age if stored_age is not None else age_from_dob
    return {
        "id": child.id,
        "parent_id": child.parent_id,
        "name": child.name,
        "date_of_birth": _iso_date(getattr(child, "date_of_birth", None)),
        "age": resolved_age,
        "avatar": getattr(child, "avatar", None),
        "is_active": bool(getattr(child, "is_active", True)),
        "created_at": _iso_z(child.created_at),
        "updated_at": _iso_z(getattr(child, "updated_at", None)),
    }


def notification_to_json(notification: Notification) -> Dict:
    return {
        "id": notification.id,
        "type": notification.type,
        "title": notification.title,
        "body": notification.body,
        "child_id": notification.child_id,
        "is_read": bool(notification.is_read),
        "created_at": _iso_z(notification.created_at),
    }
