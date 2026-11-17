import json
from datetime import datetime, timedelta
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# Upper bounds for client-supplied analytics. Real activities award well under
# 500 XP and nobody plays for a day straight, so these only stop forged or
# runaway payloads from inflating reports or bloating the database.
MAX_EVENT_POINTS = 1000
MAX_EVENT_DURATION_SECONDS = 24 * 60 * 60
MAX_SESSION_SPAN = timedelta(hours=24)
MAX_METADATA_BYTES = 8 * 1024
MAX_GAMIFICATION_BYTES = 64 * 1024
MAX_GAMIFICATION_KEYS = 1000


def _json_size(value: object) -> int:
    return len(json.dumps(value, separators=(",", ":"), default=str).encode("utf-8"))


def _check_metadata(value: Optional[dict]) -> Optional[dict]:
    if value is not None and _json_size(value) > MAX_METADATA_BYTES:
        raise ValueError(f"metadata_json must be at most {MAX_METADATA_BYTES} bytes")
    return value


class ActivityEventIn(BaseModel):
    child_id: int
    event_type: str = Field(min_length=1, max_length=64)
    occurred_at: Optional[datetime] = None
    source: str = Field(default="app", max_length=32)
    activity_name: Optional[str] = Field(default=None, max_length=200)
    lesson_id: Optional[str] = Field(default=None, max_length=128)
    mood_value: Optional[int] = Field(default=None, ge=1, le=5)
    achievement_key: Optional[str] = Field(default=None, max_length=128)
    points: Optional[int] = Field(default=None, ge=0, le=MAX_EVENT_POINTS)
    duration_seconds: Optional[int] = Field(default=None, ge=0, le=MAX_EVENT_DURATION_SECONDS)
    metadata_json: Optional[dict] = None

    _metadata_size = field_validator("metadata_json")(_check_metadata)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "event_type": "lesson_completed",
                "lesson_id": "lesson_alphabet_01",
                "activity_name": "Alphabet Lesson",
                "duration_seconds": 420,
            }
        }
    )


class GamificationStateIn(BaseModel):
    """Local-first gamification snapshot the child app syncs so coins, badges,
    achievements and reward-store purchases survive a fresh device / storage
    reset. ``data`` is an opaque key→value map of the child's local entries;
    ``updated_at`` (epoch millis) drives last-write-wins on the server.
    """

    child_id: int
    updated_at: int = Field(ge=0)
    data: dict

    @field_validator("data")
    @classmethod
    def _data_size(cls, value: dict) -> dict:
        if len(value) > MAX_GAMIFICATION_KEYS:
            raise ValueError(f"data must have at most {MAX_GAMIFICATION_KEYS} keys")
        if _json_size(value) > MAX_GAMIFICATION_BYTES:
            raise ValueError(f"data must be at most {MAX_GAMIFICATION_BYTES} bytes")
        return value

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "updated_at": 1750000000000,
                "data": {"gam_coins_1": 120, "store_owned_1": '["hat_1"]'},
            }
        }
    )


class SessionLogIn(BaseModel):
    child_id: int
    session_id: Optional[str] = Field(default=None, max_length=128)
    source: str = Field(default="app", max_length=32)
    started_at: datetime
    ended_at: datetime
    metadata_json: Optional[dict] = None

    _metadata_size = field_validator("metadata_json")(_check_metadata)

    @model_validator(mode="after")
    def _span_is_reasonable(self) -> "SessionLogIn":
        try:
            span = self.ended_at - self.started_at
        except TypeError:  # one naive, one aware: the service normalises these
            return self
        if span > MAX_SESSION_SPAN:
            raise ValueError("a session cannot be longer than 24 hours")
        return self

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "session_id": "s-123",
                "started_at": "2026-03-15T10:00:00Z",
                "ended_at": "2026-03-15T10:25:00Z",
                "source": "child_mode",
            }
        }
    )
