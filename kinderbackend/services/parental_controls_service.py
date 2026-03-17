from __future__ import annotations

from typing import Iterable

from fastapi import HTTPException
from sqlalchemy.orm import Session

from models import (
    ChildBlockedApp,
    ChildBlockedSite,
    ChildParentalControlSetting,
    ChildProfile,
    ChildScheduleRule,
    ParentalControl,
    User,
)


def _default_account_controls(user_id: int) -> ParentalControl:
    return ParentalControl(
        user_id=user_id,
        daily_limit_enabled=True,
        hours_per_day=2,
        break_reminders_enabled=True,
        age_appropriate_only=True,
        block_educational=False,
        require_approval=False,
        sleep_mode=True,
        bedtime="8:00 PM",
        wake_time="7:00 AM",
        emergency_lock=False,
    )


def get_or_create_account_controls(db: Session, user: User) -> ParentalControl:
    controls = db.query(ParentalControl).filter(ParentalControl.user_id == user.id).first()
    if controls is None:
        controls = _default_account_controls(user.id)
        db.add(controls)
        db.commit()
        db.refresh(controls)
    return controls


def account_controls_to_json(controls: ParentalControl) -> dict:
    return {
        "daily_limit_enabled": controls.daily_limit_enabled,
        "hours_per_day": controls.hours_per_day,
        "break_reminders_enabled": controls.break_reminders_enabled,
        "age_appropriate_only": controls.age_appropriate_only,
        "block_educational": controls.block_educational,
        "require_approval": controls.require_approval,
        "sleep_mode": controls.sleep_mode,
        "bedtime": controls.bedtime,
        "wake_time": controls.wake_time,
        "emergency_lock": controls.emergency_lock,
    }


def update_account_controls(db: Session, user: User, payload) -> dict:
    controls = get_or_create_account_controls(db, user)
    controls.daily_limit_enabled = payload.daily_limit_enabled
    controls.hours_per_day = payload.hours_per_day
    controls.break_reminders_enabled = payload.break_reminders_enabled
    controls.age_appropriate_only = payload.age_appropriate_only
    controls.block_educational = payload.block_educational
    controls.require_approval = payload.require_approval
    controls.sleep_mode = payload.sleep_mode
    controls.bedtime = payload.bedtime
    controls.wake_time = payload.wake_time
    controls.emergency_lock = payload.emergency_lock
    db.commit()
    db.refresh(controls)
    return {"settings": account_controls_to_json(controls)}


def _require_parent_child(db: Session, parent: User, child_id: int) -> ChildProfile:
    child = (
        db.query(ChildProfile)
        .filter(ChildProfile.id == child_id, ChildProfile.deleted_at.is_(None))
        .first()
    )
    if child is None:
        raise HTTPException(status_code=404, detail="Child not found")
    if child.parent_id != parent.id:
        raise HTTPException(status_code=403, detail="Forbidden")
    return child


def _create_default_child_setting(
    db: Session, parent: User, child: ChildProfile
) -> ChildParentalControlSetting:
    account = get_or_create_account_controls(db, parent)
    setting = ChildParentalControlSetting(
        parent_id=parent.id,
        child_id=child.id,
        daily_limit_enabled=account.daily_limit_enabled,
        daily_limit_minutes=max((account.hours_per_day or 0) * 60, 0),
        break_reminders_enabled=account.break_reminders_enabled,
        age_appropriate_only=account.age_appropriate_only,
        require_approval=account.require_approval,
        sleep_mode=account.sleep_mode,
        bedtime_start="21:00",
        bedtime_end="07:00",
        emergency_lock=account.emergency_lock,
        enforcement_mode="monitor",
        device_status="unknown",
        pending_changes=True,
    )
    db.add(setting)
    db.flush()
    return setting


def _get_or_create_child_setting(
    db: Session, parent: User, child_id: int
) -> ChildParentalControlSetting:
    child = _require_parent_child(db, parent, child_id)
    setting = (
        db.query(ChildParentalControlSetting)
        .filter(ChildParentalControlSetting.child_id == child.id)
        .first()
    )
    if setting is None:
        setting = _create_default_child_setting(db, parent, child)
        db.commit()
        db.refresh(setting)
    return setting


def _replace_schedule_rules(
    db: Session, setting: ChildParentalControlSetting, rules: Iterable
) -> None:
    db.query(ChildScheduleRule).filter(ChildScheduleRule.setting_id == setting.id).delete()
    for item in rules:
        db.add(
            ChildScheduleRule(
                setting_id=setting.id,
                day_of_week=item.day_of_week,
                start_time=item.start_time,
                end_time=item.end_time,
                is_allowed=item.is_allowed,
            )
        )


def _replace_blocked_apps(
    db: Session, setting: ChildParentalControlSetting, apps: Iterable
) -> None:
    db.query(ChildBlockedApp).filter(ChildBlockedApp.setting_id == setting.id).delete()
    for app in apps:
        db.add(
            ChildBlockedApp(
                setting_id=setting.id,
                app_identifier=app.app_identifier,
                app_name=app.app_name,
                reason=app.reason,
            )
        )


def _replace_blocked_sites(
    db: Session, setting: ChildParentalControlSetting, sites: Iterable
) -> None:
    db.query(ChildBlockedSite).filter(ChildBlockedSite.setting_id == setting.id).delete()
    for site in sites:
        db.add(
            ChildBlockedSite(
                setting_id=setting.id,
                domain=site.domain.lower().strip(),
                label=site.label,
                reason=site.reason,
            )
        )


def child_setting_to_json(setting: ChildParentalControlSetting) -> dict:
    return {
        "child_id": setting.child_id,
        "settings": {
            "daily_limit_enabled": setting.daily_limit_enabled,
            "daily_limit_minutes": setting.daily_limit_minutes,
            "break_reminders_enabled": setting.break_reminders_enabled,
            "age_appropriate_only": setting.age_appropriate_only,
            "require_approval": setting.require_approval,
            "sleep_mode": setting.sleep_mode,
            "bedtime_start": setting.bedtime_start,
            "bedtime_end": setting.bedtime_end,
            "emergency_lock": setting.emergency_lock,
        },
        "allowed_windows": [
            {
                "id": rule.id,
                "day_of_week": rule.day_of_week,
                "start_time": rule.start_time,
                "end_time": rule.end_time,
                "is_allowed": rule.is_allowed,
            }
            for rule in sorted(
                setting.schedule_rules or [], key=lambda x: (x.day_of_week, x.start_time)
            )
        ],
        "blocked_apps": [
            {
                "id": app.id,
                "app_identifier": app.app_identifier,
                "app_name": app.app_name,
                "reason": app.reason,
            }
            for app in sorted(
                setting.blocked_apps or [], key=lambda x: (x.app_name or "", x.app_identifier)
            )
        ],
        "blocked_sites": [
            {
                "id": site.id,
                "domain": site.domain,
                "label": site.label,
                "reason": site.reason,
            }
            for site in sorted(setting.blocked_sites or [], key=lambda x: x.domain)
        ],
        "enforcement": {
            "enforcement_mode": setting.enforcement_mode,
            "device_status": setting.device_status,
            "pending_changes": setting.pending_changes,
            "last_synced_at": (
                setting.last_synced_at.isoformat() if setting.last_synced_at else None
            ),
        },
        "updated_at": setting.updated_at.isoformat() if setting.updated_at else None,
    }


def get_child_controls(db: Session, parent: User, child_id: int) -> dict:
    setting = _get_or_create_child_setting(db, parent, child_id)
    return child_setting_to_json(setting)


def update_child_controls(db: Session, parent: User, child_id: int, payload) -> dict:
    setting = _get_or_create_child_setting(db, parent, child_id)
    setting.daily_limit_enabled = payload.daily_limit_enabled
    setting.daily_limit_minutes = payload.daily_limit_minutes
    setting.break_reminders_enabled = payload.break_reminders_enabled
    setting.age_appropriate_only = payload.age_appropriate_only
    setting.require_approval = payload.require_approval
    setting.sleep_mode = payload.sleep_mode
    setting.bedtime_start = payload.bedtime_start
    setting.bedtime_end = payload.bedtime_end
    setting.emergency_lock = payload.emergency_lock
    setting.enforcement_mode = payload.enforcement_mode
    setting.device_status = payload.device_status
    setting.pending_changes = payload.pending_changes
    setting.last_synced_at = payload.last_synced_at

    _replace_schedule_rules(db, setting, payload.allowed_windows)
    _replace_blocked_apps(db, setting, payload.blocked_apps)
    _replace_blocked_sites(db, setting, payload.blocked_sites)
    db.commit()
    db.refresh(setting)
    return child_setting_to_json(setting)


def update_child_schedule_rules(db: Session, parent: User, child_id: int, payload) -> dict:
    setting = _get_or_create_child_setting(db, parent, child_id)
    _replace_schedule_rules(db, setting, payload.allowed_windows)
    setting.pending_changes = True
    db.commit()
    db.refresh(setting)
    return child_setting_to_json(setting)


def update_child_blocked_apps(db: Session, parent: User, child_id: int, payload) -> dict:
    setting = _get_or_create_child_setting(db, parent, child_id)
    _replace_blocked_apps(db, setting, payload.blocked_apps)
    setting.pending_changes = True
    db.commit()
    db.refresh(setting)
    return child_setting_to_json(setting)


def update_child_blocked_sites(db: Session, parent: User, child_id: int, payload) -> dict:
    setting = _get_or_create_child_setting(db, parent, child_id)
    _replace_blocked_sites(db, setting, payload.blocked_sites)
    setting.pending_changes = True
    db.commit()
    db.refresh(setting)
    return child_setting_to_json(setting)


def list_parent_child_controls(db: Session, parent: User) -> list[dict]:
    children = (
        db.query(ChildProfile)
        .filter(
            ChildProfile.parent_id == parent.id,
            ChildProfile.deleted_at.is_(None),
        )
        .order_by(ChildProfile.created_at.desc(), ChildProfile.id.desc())
        .all()
    )
    output = []
    for child in children:
        setting = _get_or_create_child_setting(db, parent, child.id)
        output.append(
            {
                "child": {
                    "id": child.id,
                    "name": child.name,
                    "age": child.age,
                    "is_active": child.is_active,
                },
                "control": child_setting_to_json(setting),
            }
        )
    return output
