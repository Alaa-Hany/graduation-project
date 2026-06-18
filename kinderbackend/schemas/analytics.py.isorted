from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ActivityEventIn(BaseModel):
    child_id: int
    event_type: str
    occurred_at: Optional[datetime] = None
    source: str = "app"
    activity_name: Optional[str] = None
    lesson_id: Optional[str] = None
    mood_value: Optional[int] = Field(default=None, ge=1, le=5)
    achievement_key: Optional[str] = None
    points: Optional[int] = None
    duration_seconds: Optional[int] = Field(default=None, ge=0)
    metadata_json: Optional[dict] = None

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


class SessionLogIn(BaseModel):
    child_id: int
    session_id: Optional[str] = None
    source: str = "app"
    started_at: datetime
    ended_at: datetime
    metadata_json: Optional[dict] = None

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
