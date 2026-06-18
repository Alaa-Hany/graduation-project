from __future__ import annotations

import os
from datetime import date, datetime, timedelta
from math import floor

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.time_utils import ensure_utc, to_db_utc, utc_now, utc_start_of_day
from models import (
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildProfile,
    ChildSessionLog,
    User,
)

TRACKED_EVENT_TYPES = {
    "activity_completed",
    "lesson_completed",
    "mood_entry",
    "achievement_unlocked",
}
COMPLETION_EVENT_TYPES = {"activity_completed", "lesson_completed"}


class AnalyticsIngestionService:
    @staticmethod
    def _start_of_day(day: date) -> datetime:
        return utc_start_of_day(day)

    def _ensure_parent_child_access(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> ChildProfile:
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

    @staticmethod
    def _retention_days() -> int:
        try:
            value = int((os.getenv("ANALYTICS_RETENTION_DAYS") or "365").strip())
        except (TypeError, ValueError):
            value = 365
        return max(value, 30)

    def _retention_expires_at(self, occurred_at: datetime) -> datetime:
        return occurred_at + timedelta(days=self._retention_days())

    def _get_or_create_daily_summary(
        self,
        *,
        db: Session,
        child_id: int,
        summary_date: date,
    ) -> ChildDailyActivitySummary:
        summary = (
            db.query(ChildDailyActivitySummary)
            .filter(
                ChildDailyActivitySummary.child_id == child_id,
                ChildDailyActivitySummary.summary_date == summary_date,
                ChildDailyActivitySummary.archived_at.is_(None),
            )
            .first()
        )
        if summary is not None:
            return summary
        summary = ChildDailyActivitySummary(
            child_id=child_id,
            summary_date=summary_date,
            screen_time_minutes=0,
            activities_completed=0,
            lessons_completed=0,
            mood_entries=0,
            achievements_unlocked=0,
            ai_interactions_count=0,
            data_source="realtime",
        )
        db.add(summary)
        db.flush()
        return summary

    def _increment_daily_summary(
        self,
        *,
        db: Session,
        child_id: int,
        occurred_at: datetime,
        screen_time_minutes: int = 0,
        activities_completed: int = 0,
        lessons_completed: int = 0,
        mood_entries: int = 0,
        achievements_unlocked: int = 0,
        ai_interactions_count: int = 0,
    ) -> None:
        summary = self._get_or_create_daily_summary(
            db=db,
            child_id=child_id,
            summary_date=occurred_at.date(),
        )
        summary.screen_time_minutes = max(
            int(summary.screen_time_minutes or 0) + max(screen_time_minutes, 0),
            0,
        )
        summary.activities_completed = max(
            int(summary.activities_completed or 0) + max(activities_completed, 0),
            0,
        )
        summary.lessons_completed = max(
            int(summary.lessons_completed or 0) + max(lessons_completed, 0),
            0,
        )
        summary.mood_entries = max(
            int(summary.mood_entries or 0) + max(mood_entries, 0),
            0,
        )
        summary.achievements_unlocked = max(
            int(summary.achievements_unlocked or 0) + max(achievements_unlocked, 0),
            0,
        )
        summary.ai_interactions_count = max(
            int(summary.ai_interactions_count or 0) + max(ai_interactions_count, 0),
            0,
        )
        if summary.last_event_at is None or occurred_at > summary.last_event_at:
            summary.last_event_at = occurred_at
        db.add(summary)

    def record_activity_event(self, *, db: Session, parent: User, payload) -> dict:
        if payload.event_type not in TRACKED_EVENT_TYPES:
            raise HTTPException(
                status_code=422,
                detail={
                    "code": "INVALID_ACTIVITY_EVENT_TYPE",
                    "message": f"Unsupported event_type '{payload.event_type}'",
                    "allowed_types": sorted(TRACKED_EVENT_TYPES),
                },
            )

        self._ensure_parent_child_access(db=db, parent=parent, child_id=payload.child_id)
        occurred_at = to_db_utc(payload.occurred_at or utc_now())

        event = ChildActivityEvent(
            child_id=payload.child_id,
            event_type=payload.event_type,
            occurred_at=occurred_at,
            source=payload.source,
            activity_name=payload.activity_name,
            lesson_id=payload.lesson_id,
            mood_value=payload.mood_value,
            achievement_key=payload.achievement_key,
            points=payload.points,
            duration_seconds=payload.duration_seconds,
            metadata_json=payload.metadata_json,
            retention_expires_at=self._retention_expires_at(occurred_at),
        )
        db.add(event)
        self._increment_daily_summary(
            db=db,
            child_id=payload.child_id,
            occurred_at=occurred_at,
            activities_completed=1 if payload.event_type in COMPLETION_EVENT_TYPES else 0,
            lessons_completed=1 if payload.event_type == "lesson_completed" else 0,
            mood_entries=1 if payload.event_type == "mood_entry" else 0,
            achievements_unlocked=1 if payload.event_type == "achievement_unlocked" else 0,
        )
        db.commit()
        db.refresh(event)

        return {
            "event": {
                "id": event.id,
                "child_id": event.child_id,
                "event_type": event.event_type,
                "occurred_at": event.occurred_at.isoformat() if event.occurred_at else None,
            }
        }

    def record_session_log(self, *, db: Session, parent: User, payload) -> dict:
        self._ensure_parent_child_access(db=db, parent=parent, child_id=payload.child_id)
        started_at = ensure_utc(payload.started_at)
        ended_at = ensure_utc(payload.ended_at)
        if ended_at < started_at:
            raise HTTPException(
                status_code=422,
                detail="ended_at must be greater than or equal to started_at",
            )
        duration = max(int((ended_at - started_at).total_seconds()), 0)
        session_log = ChildSessionLog(
            child_id=payload.child_id,
            session_id=payload.session_id,
            source=payload.source,
            started_at=started_at,
            ended_at=ended_at,
            duration_seconds=duration,
            metadata_json=payload.metadata_json,
            retention_expires_at=self._retention_expires_at(ended_at),
        )
        db.add(session_log)
        self._increment_daily_summary(
            db=db,
            child_id=payload.child_id,
            occurred_at=started_at,
            screen_time_minutes=floor(duration / 60),
        )
        db.commit()
        db.refresh(session_log)

        return {
            "session": {
                "id": session_log.id,
                "child_id": session_log.child_id,
                "duration_seconds": session_log.duration_seconds,
                "started_at": (
                    session_log.started_at.isoformat() if session_log.started_at else None
                ),
                "ended_at": session_log.ended_at.isoformat() if session_log.ended_at else None,
            }
        }
