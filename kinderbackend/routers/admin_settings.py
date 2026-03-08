from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from admin_deps import require_permission
from admin_utils import serialize_system_setting, write_audit_log
from deps import get_db
from models import SystemSetting

router = APIRouter(prefix="/admin/settings", tags=["Admin Settings"])

DEFAULT_SETTINGS: dict[str, Any] = {
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


class SystemSettingsUpdateRequest(BaseModel):
    maintenance_mode: bool | None = None
    registration_enabled: bool | None = None
    ai_buddy_enabled: bool | None = None
    feature_flags: dict[str, Any] | None = None
    defaults: dict[str, Any] | None = None


def _setting_by_key(db: Session) -> dict[str, SystemSetting]:
    items = db.query(SystemSetting).all()
    return {item.key: item for item in items}


def _ensure_default_settings(db: Session) -> dict[str, SystemSetting]:
    existing = _setting_by_key(db)
    changed = False
    for key, value in DEFAULT_SETTINGS.items():
        if key not in existing:
            item = SystemSetting(key=key, value_json=value)
            db.add(item)
            db.flush()
            existing[key] = item
            changed = True
    if changed:
        db.commit()
        existing = _setting_by_key(db)
    return existing


def _settings_payload(existing: dict[str, SystemSetting]) -> dict[str, Any]:
    return {
        "settings": {
            key: serialize_system_setting(existing[key]) if key in existing else None
            for key in DEFAULT_SETTINGS.keys()
        },
        "effective": {
            key: (existing[key].value_json if key in existing else value)
            for key, value in DEFAULT_SETTINGS.items()
        },
    }


@router.get("")
def get_admin_settings(
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.settings.edit")),
):
    existing = _ensure_default_settings(db)
    return _settings_payload(existing)


@router.patch("")
def update_admin_settings(
    payload: SystemSettingsUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.settings.edit")),
):
    existing = _ensure_default_settings(db)
    before = _settings_payload(existing)

    updates = {
        "maintenance_mode": payload.maintenance_mode,
        "registration_enabled": payload.registration_enabled,
        "ai_buddy_enabled": payload.ai_buddy_enabled,
        "feature_flags": payload.feature_flags,
        "defaults": payload.defaults,
    }
    for key, value in updates.items():
        if value is None:
            continue
        item = existing[key]
        item.value_json = value
        item.updated_by = admin.id
        item.updated_at = datetime.utcnow()
        db.add(item)

    db.flush()
    refreshed = _setting_by_key(db)
    after = _settings_payload(refreshed)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="settings.update",
        entity_type="system_settings",
        entity_id="global",
        before_json=before,
        after_json=after,
    )
    db.commit()
    return after
