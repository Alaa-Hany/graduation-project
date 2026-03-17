from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _validate_hhmm(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    text = value.strip()
    if len(text) != 5 or text[2] != ":":
        raise ValueError("Time must be in HH:MM format")
    hh, mm = text.split(":")
    if not (hh.isdigit() and mm.isdigit()):
        raise ValueError("Time must be in HH:MM format")
    h = int(hh)
    m = int(mm)
    if h < 0 or h > 23 or m < 0 or m > 59:
        raise ValueError("Time must be a valid 24-hour value")
    return f"{h:02d}:{m:02d}"


class AccountParentalControlsPayload(BaseModel):
    daily_limit_enabled: bool
    hours_per_day: int
    break_reminders_enabled: bool
    age_appropriate_only: bool
    block_educational: bool
    require_approval: bool
    sleep_mode: bool
    bedtime: str | None = None
    wake_time: str | None = None
    emergency_lock: bool = False


class ScheduleRuleIn(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6)
    start_time: str
    end_time: str
    is_allowed: bool = True

    @field_validator("start_time", "end_time")
    @classmethod
    def validate_time(cls, value: str) -> str:
        validated = _validate_hhmm(value)
        if validated is None:
            raise ValueError("Time is required")
        return validated


class BlockedAppIn(BaseModel):
    app_identifier: str
    app_name: str | None = None
    reason: str | None = None


class BlockedSiteIn(BaseModel):
    domain: str
    label: str | None = None
    reason: str | None = None


class ChildParentalControlsPayload(BaseModel):
    daily_limit_enabled: bool = True
    daily_limit_minutes: int = Field(default=120, ge=0, le=24 * 60)
    break_reminders_enabled: bool = True
    age_appropriate_only: bool = True
    require_approval: bool = False
    sleep_mode: bool = True
    bedtime_start: str | None = None
    bedtime_end: str | None = None
    emergency_lock: bool = False
    enforcement_mode: str = "monitor"
    device_status: str = "unknown"
    pending_changes: bool = True
    last_synced_at: datetime | None = None
    allowed_windows: List[ScheduleRuleIn] = Field(default_factory=list)
    blocked_apps: List[BlockedAppIn] = Field(default_factory=list)
    blocked_sites: List[BlockedSiteIn] = Field(default_factory=list)

    @field_validator("bedtime_start", "bedtime_end")
    @classmethod
    def validate_bedtime(cls, value: Optional[str]) -> Optional[str]:
        return _validate_hhmm(value)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "daily_limit_enabled": True,
                "daily_limit_minutes": 120,
                "break_reminders_enabled": True,
                "age_appropriate_only": True,
                "require_approval": True,
                "sleep_mode": True,
                "bedtime_start": "21:00",
                "bedtime_end": "07:00",
                "enforcement_mode": "enforce",
                "device_status": "online",
                "pending_changes": True,
                "allowed_windows": [
                    {
                        "day_of_week": 1,
                        "start_time": "16:00",
                        "end_time": "18:00",
                        "is_allowed": True,
                    }
                ],
                "blocked_apps": [{"app_identifier": "com.social.app", "app_name": "Social App"}],
                "blocked_sites": [{"domain": "example.com"}],
            }
        }
    )


class ChildScheduleRulesPayload(BaseModel):
    allowed_windows: List[ScheduleRuleIn] = Field(default_factory=list)


class ChildBlockedAppsPayload(BaseModel):
    blocked_apps: List[BlockedAppIn] = Field(default_factory=list)


class ChildBlockedSitesPayload(BaseModel):
    blocked_sites: List[BlockedSiteIn] = Field(default_factory=list)
