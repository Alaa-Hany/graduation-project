from __future__ import annotations

import os
from datetime import date, datetime, timedelta

from sqlalchemy.orm import Session

from core.time_utils import to_db_utc, utc_now, utc_start_of_day
from models import (
    ActivitySession,
    AiBuddyMessage,
    AiBuddySession,
    AiInteraction,
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildProfile,
    ChildSessionLog,
    ScreenTimeLog,
)


def _archive_after_days() -> int:
    try:
        value = int((os.getenv("ANALYTICS_RETENTION_DAYS") or "365").strip())
    except (TypeError, ValueError):
        value = 365
    return max(value, 30)


def _summary_archive_after_days() -> int:
    try:
        value = int((os.getenv("ANALYTICS_SUMMARY_RETENTION_DAYS") or "1825").strip())
    except (TypeError, ValueError):
        value = 1825
    return max(value, 365)


def apply_tracking_retention(db: Session, *, now: datetime | None = None) -> dict:
    now = to_db_utc(now or utc_now())
    archive_cutoff = now - timedelta(days=_archive_after_days())
    summary_cutoff = now.date() - timedelta(days=_summary_archive_after_days())

    touched = {
        "child_activity_events_archived": 0,
        "child_session_logs_archived": 0,
        "activity_sessions_archived": 0,
        "screen_time_logs_archived": 0,
        "ai_interactions_archived": 0,
        "ai_buddy_sessions_archived": 0,
        "ai_buddy_messages_archived": 0,
        "daily_summaries_archived": 0,
    }

    touched["child_activity_events_archived"] = (
        db.query(ChildActivityEvent)
        .filter(
            ChildActivityEvent.archived_at.is_(None),
            ChildActivityEvent.occurred_at < archive_cutoff,
        )
        .update({ChildActivityEvent.archived_at: now}, synchronize_session=False)
    )

    touched["child_session_logs_archived"] = (
        db.query(ChildSessionLog)
        .filter(
            ChildSessionLog.archived_at.is_(None),
            ChildSessionLog.started_at < archive_cutoff,
        )
        .update({ChildSessionLog.archived_at: now}, synchronize_session=False)
    )

    touched["activity_sessions_archived"] = (
        db.query(ActivitySession)
        .filter(
            ActivitySession.archived_at.is_(None),
            ActivitySession.started_at < archive_cutoff,
        )
        .update({ActivitySession.archived_at: now}, synchronize_session=False)
    )

    touched["screen_time_logs_archived"] = (
        db.query(ScreenTimeLog)
        .filter(
            ScreenTimeLog.archived_at.is_(None),
            ScreenTimeLog.logged_at < archive_cutoff,
        )
        .update({ScreenTimeLog.archived_at: now}, synchronize_session=False)
    )

    touched["ai_interactions_archived"] = (
        db.query(AiInteraction)
        .filter(
            AiInteraction.archived_at.is_(None),
            AiInteraction.occurred_at < archive_cutoff,
        )
        .update({AiInteraction.archived_at: now}, synchronize_session=False)
    )

    touched["ai_buddy_sessions_archived"] = (
        db.query(AiBuddySession)
        .filter(
            AiBuddySession.archived_at.is_(None),
            AiBuddySession.retention_expires_at.is_not(None),
            AiBuddySession.retention_expires_at < now,
        )
        .update({AiBuddySession.archived_at: now}, synchronize_session=False)
    )

    touched["ai_buddy_messages_archived"] = (
        db.query(AiBuddyMessage)
        .filter(
            AiBuddyMessage.archived_at.is_(None),
            AiBuddyMessage.retention_expires_at.is_not(None),
            AiBuddyMessage.retention_expires_at < now,
        )
        .update({AiBuddyMessage.archived_at: now}, synchronize_session=False)
    )

    touched["daily_summaries_archived"] = (
        db.query(ChildDailyActivitySummary)
        .filter(
            ChildDailyActivitySummary.archived_at.is_(None),
            ChildDailyActivitySummary.summary_date < summary_cutoff,
        )
        .update({ChildDailyActivitySummary.archived_at: now}, synchronize_session=False)
    )

    db.commit()
    return touched


def rebuild_daily_summary_for_child(
    db: Session,
    *,
    child_id: int,
    day: date,
    source: str = "rebuild",
) -> dict:
    child = (
        db.query(ChildProfile)
        .filter(ChildProfile.id == child_id, ChildProfile.deleted_at.is_(None))
        .first()
    )
    if child is None:
        raise ValueError("Child not found")

    start_dt = utc_start_of_day(day)
    end_dt = start_dt + timedelta(days=1)

    sessions = (
        db.query(ChildSessionLog)
        .filter(
            ChildSessionLog.child_id == child_id,
            ChildSessionLog.archived_at.is_(None),
            ChildSessionLog.started_at >= start_dt,
            ChildSessionLog.started_at < end_dt,
        )
        .all()
    )
    events = (
        db.query(ChildActivityEvent)
        .filter(
            ChildActivityEvent.child_id == child_id,
            ChildActivityEvent.archived_at.is_(None),
            ChildActivityEvent.occurred_at >= start_dt,
            ChildActivityEvent.occurred_at < end_dt,
        )
        .all()
    )

    summary = (
        db.query(ChildDailyActivitySummary)
        .filter(
            ChildDailyActivitySummary.child_id == child_id,
            ChildDailyActivitySummary.summary_date == day,
        )
        .first()
    )
    if summary is None:
        summary = ChildDailyActivitySummary(child_id=child_id, summary_date=day)
        db.add(summary)

    summary.screen_time_minutes = sum(
        max(int((item.duration_seconds or 0) / 60), 0) for item in sessions
    )
    summary.activities_completed = len(events)
    summary.lessons_completed = sum(1 for item in events if item.event_type == "lesson_completed")
    summary.mood_entries = sum(1 for item in events if item.event_type == "mood_entry")
    summary.achievements_unlocked = sum(
        1 for item in events if item.event_type == "achievement_unlocked"
    )
    summary.ai_interactions_count = (
        db.query(AiInteraction)
        .filter(
            AiInteraction.child_id == child_id,
            AiInteraction.archived_at.is_(None),
            AiInteraction.occurred_at >= start_dt,
            AiInteraction.occurred_at < end_dt,
        )
        .count()
    )
    summary.data_source = source
    summary.last_event_at = max(
        [item.occurred_at for item in events] + [item.started_at for item in sessions],
        default=None,
    )
    summary.archived_at = None
    db.add(summary)
    db.commit()
    db.refresh(summary)

    return {
        "child_id": summary.child_id,
        "summary_date": summary.summary_date.isoformat(),
        "screen_time_minutes": summary.screen_time_minutes,
        "activities_completed": summary.activities_completed,
        "lessons_completed": summary.lessons_completed,
        "mood_entries": summary.mood_entries,
        "achievements_unlocked": summary.achievements_unlocked,
        "ai_interactions_count": summary.ai_interactions_count,
        "data_source": summary.data_source,
    }
