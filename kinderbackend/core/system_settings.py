from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from models import SystemSetting

DEFAULT_SYSTEM_SETTINGS: dict[str, Any] = {
    "maintenance_mode": False,
    "registration_enabled": True,
    "ai_buddy_enabled": True,
    "feature_flags": {
        "support_center": True,
        "analytics_dashboard": True,
        "cms": True,
    },
    "defaults": {
        "default_plan": "FREE",
        "default_child_limit": 1,
    },
}


def _coerce_bool(value: Any, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes", "on"}:
            return True
        if lowered in {"false", "0", "no", "off"}:
            return False
    if isinstance(value, (int, float)):
        return bool(value)
    return default


def ensure_default_settings(db: Session) -> dict[str, SystemSetting]:
    existing_items = db.query(SystemSetting).all()
    existing = {item.key: item for item in existing_items}
    changed = False
    for key, value in DEFAULT_SYSTEM_SETTINGS.items():
        if key not in existing:
            item = SystemSetting(key=key, value_json=value)
            db.add(item)
            db.flush()
            existing[key] = item
            changed = True
    if changed:
        db.commit()
        existing_items = db.query(SystemSetting).all()
        existing = {item.key: item for item in existing_items}
    return existing


def get_bool_setting(db: Session, key: str, default: bool) -> bool:
    existing = ensure_default_settings(db)
    setting = existing.get(key)
    raw = setting.value_json if setting is not None else default
    return _coerce_bool(raw, default)


def get_dict_setting(db: Session, key: str, default: dict[str, Any]) -> dict[str, Any]:
    existing = ensure_default_settings(db)
    setting = existing.get(key)
    raw = setting.value_json if setting is not None else default
    if isinstance(raw, dict):
        return raw
    return default


def get_default_child_limit(db: Session) -> int | None:
    """Return the admin-configured default child limit for the FREE plan.

    Falls back to the built-in default when unset or invalid. A value <= 0 is
    treated as "unset" so it never silently blocks all child creation."""
    defaults = get_dict_setting(db, "defaults", DEFAULT_SYSTEM_SETTINGS["defaults"])
    raw = defaults.get("default_child_limit")
    if raw is None:
        return None
    try:
        limit = int(raw)
    except (TypeError, ValueError):
        return None
    return limit if limit > 0 else None


def is_maintenance_mode(db: Session) -> bool:
    return get_bool_setting(db, "maintenance_mode", default=False)


def is_registration_enabled(db: Session) -> bool:
    return get_bool_setting(db, "registration_enabled", default=True)


def is_ai_buddy_enabled(db: Session) -> bool:
    return get_bool_setting(db, "ai_buddy_enabled", default=True)


def require_ai_buddy_enabled(db: Session) -> None:
    if not is_ai_buddy_enabled(db):
        raise HTTPException(
            status_code=503,
            detail={
                "message": "AI Buddy is currently disabled by system settings",
                "code": "AI_BUDDY_DISABLED",
            },
        )


def require_registration_enabled(db: Session) -> None:
    if not is_registration_enabled(db):
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Registration is currently disabled by system settings",
                "code": "REGISTRATION_DISABLED",
            },
        )
