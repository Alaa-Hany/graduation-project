"""Tests for services.data_lifecycle_service.

Covers the retention/archival sweep (`apply_tracking_retention`), the daily
summary rebuild (`rebuild_daily_summary_for_child`), and the env-driven
retention-window helpers.
"""

from datetime import timedelta

import pytest

from core.time_utils import utc_now, utc_start_of_day, utc_today
from models import (
    AiBuddyMessage,
    AiBuddySession,
    AiInteraction,
    ActivitySession,
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildSessionLog,
    ScreenTimeLog,
)
from services import data_lifecycle_service as dls


def _make_child(create_parent, create_child):
    parent = create_parent(email="lifecycle-parent@example.invalid")
    child = create_child(parent_id=parent.id, name="Retention Kid")
    return parent, child


# ---------------------------------------------------------------------------
# Retention-window env helpers
# ---------------------------------------------------------------------------


def test_archive_after_days_defaults_to_365(monkeypatch):
    monkeypatch.delenv("ANALYTICS_RETENTION_DAYS", raising=False)
    assert dls._archive_after_days() == 365


def test_archive_after_days_reads_env(monkeypatch):
    monkeypatch.setenv("ANALYTICS_RETENTION_DAYS", "500")
    assert dls._archive_after_days() == 500


def test_archive_after_days_clamps_to_minimum(monkeypatch):
    monkeypatch.setenv("ANALYTICS_RETENTION_DAYS", "5")
    assert dls._archive_after_days() == 30


def test_archive_after_days_invalid_falls_back(monkeypatch):
    monkeypatch.setenv("ANALYTICS_RETENTION_DAYS", "not-a-number")
    assert dls._archive_after_days() == 365


def test_summary_archive_after_days_defaults(monkeypatch):
    monkeypatch.delenv("ANALYTICS_SUMMARY_RETENTION_DAYS", raising=False)
    assert dls._summary_archive_after_days() == 1825


def test_summary_archive_after_days_clamps_to_minimum(monkeypatch):
    monkeypatch.setenv("ANALYTICS_SUMMARY_RETENTION_DAYS", "10")
    assert dls._summary_archive_after_days() == 365


def test_summary_archive_after_days_invalid_falls_back(monkeypatch):
    monkeypatch.setenv("ANALYTICS_SUMMARY_RETENTION_DAYS", "")
    assert dls._summary_archive_after_days() == 1825


# ---------------------------------------------------------------------------
# apply_tracking_retention
# ---------------------------------------------------------------------------


def test_apply_tracking_retention_archives_only_old_rows(
    db, create_parent, create_child, monkeypatch
):
    monkeypatch.setenv("ANALYTICS_RETENTION_DAYS", "365")
    monkeypatch.setenv("ANALYTICS_SUMMARY_RETENTION_DAYS", "1825")
    _, child = _make_child(create_parent, create_child)

    now = utc_now()
    old = now - timedelta(days=400)
    recent = now - timedelta(days=10)

    old_event = ChildActivityEvent(
        child_id=child.id, event_type="lesson_completed", occurred_at=old
    )
    recent_event = ChildActivityEvent(
        child_id=child.id, event_type="lesson_completed", occurred_at=recent
    )
    old_session = ChildSessionLog(
        child_id=child.id, started_at=old, ended_at=old, duration_seconds=60
    )
    old_activity = ActivitySession(child_id=child.id, activity_type="game", started_at=old)
    old_screen = ScreenTimeLog(
        child_id=child.id, usage_date=old.date(), minutes_used=30, logged_at=old
    )
    old_ai = AiInteraction(child_id=child.id, interaction_type="chat", occurred_at=old)

    db.add_all([old_event, recent_event, old_session, old_activity, old_screen, old_ai])
    db.commit()

    result = dls.apply_tracking_retention(db, now=now)

    assert result["child_activity_events_archived"] == 1
    assert result["child_session_logs_archived"] == 1
    assert result["activity_sessions_archived"] == 1
    assert result["screen_time_logs_archived"] == 1
    assert result["ai_interactions_archived"] == 1

    db.refresh(old_event)
    db.refresh(recent_event)
    assert old_event.archived_at is not None
    assert recent_event.archived_at is None


def test_apply_tracking_retention_archives_expired_ai_buddy_rows(db, create_parent, create_child):
    parent, child = _make_child(create_parent, create_child)
    now = utc_now()

    session = AiBuddySession(
        child_id=child.id,
        parent_user_id=parent.id,
        retention_expires_at=now - timedelta(days=1),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    message = AiBuddyMessage(
        session_id=session.id,
        child_id=child.id,
        role="child",
        content="hello",
        retention_expires_at=now - timedelta(days=1),
    )
    # A message that is still within its retention window must be left alone.
    fresh_message = AiBuddyMessage(
        session_id=session.id,
        child_id=child.id,
        role="child",
        content="recent",
        retention_expires_at=now + timedelta(days=30),
    )
    db.add_all([message, fresh_message])
    db.commit()

    result = dls.apply_tracking_retention(db, now=now)

    assert result["ai_buddy_sessions_archived"] == 1
    assert result["ai_buddy_messages_archived"] == 1

    db.refresh(fresh_message)
    assert fresh_message.archived_at is None


def test_apply_tracking_retention_archives_old_daily_summaries(db, create_parent, create_child):
    _, child = _make_child(create_parent, create_child)

    old_summary = ChildDailyActivitySummary(
        child_id=child.id,
        summary_date=utc_today() - timedelta(days=4000),
    )
    recent_summary = ChildDailyActivitySummary(
        child_id=child.id,
        summary_date=utc_today() - timedelta(days=1),
    )
    db.add_all([old_summary, recent_summary])
    db.commit()

    result = dls.apply_tracking_retention(db)

    assert result["daily_summaries_archived"] == 1
    db.refresh(recent_summary)
    assert recent_summary.archived_at is None


def test_apply_tracking_retention_noop_on_empty_db(db):
    result = dls.apply_tracking_retention(db)
    assert all(count == 0 for count in result.values())


# ---------------------------------------------------------------------------
# rebuild_daily_summary_for_child
# ---------------------------------------------------------------------------


def test_rebuild_daily_summary_aggregates_sessions_and_events(db, create_parent, create_child):
    _, child = _make_child(create_parent, create_child)

    day = utc_today() - timedelta(days=1)
    start = utc_start_of_day(day)

    db.add_all(
        [
            ChildSessionLog(
                child_id=child.id,
                started_at=start + timedelta(hours=1),
                ended_at=start + timedelta(hours=1, minutes=30),
                duration_seconds=1800,
            ),
            ChildActivityEvent(
                child_id=child.id,
                event_type="lesson_completed",
                occurred_at=start + timedelta(hours=2),
            ),
            ChildActivityEvent(
                child_id=child.id,
                event_type="mood_entry",
                occurred_at=start + timedelta(hours=3),
            ),
            ChildActivityEvent(
                child_id=child.id,
                event_type="achievement_unlocked",
                occurred_at=start + timedelta(hours=4),
            ),
            AiInteraction(
                child_id=child.id,
                interaction_type="chat",
                occurred_at=start + timedelta(hours=5),
            ),
        ]
    )
    db.commit()

    result = dls.rebuild_daily_summary_for_child(db, child_id=child.id, day=day)

    assert result["child_id"] == child.id
    assert result["summary_date"] == day.isoformat()
    assert result["screen_time_minutes"] == 30
    assert result["activities_completed"] == 3
    assert result["lessons_completed"] == 1
    assert result["mood_entries"] == 1
    assert result["achievements_unlocked"] == 1
    assert result["ai_interactions_count"] == 1
    assert result["data_source"] == "rebuild"

    summary = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .one()
    )
    assert summary.summary_date == day


def test_rebuild_daily_summary_updates_existing_row(db, create_parent, create_child):
    _, child = _make_child(create_parent, create_child)
    day = utc_today() - timedelta(days=2)

    existing = ChildDailyActivitySummary(
        child_id=child.id,
        summary_date=day,
        activities_completed=99,
        archived_at=utc_now(),
    )
    db.add(existing)
    db.commit()

    db.add(
        ChildActivityEvent(
            child_id=child.id,
            event_type="lesson_completed",
            occurred_at=utc_start_of_day(day) + timedelta(hours=1),
        )
    )
    db.commit()

    result = dls.rebuild_daily_summary_for_child(db, child_id=child.id, day=day, source="manual")

    assert result["activities_completed"] == 1
    assert result["data_source"] == "manual"

    # The single summary row was reused (not duplicated) and un-archived.
    summaries = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .all()
    )
    assert len(summaries) == 1
    assert summaries[0].archived_at is None


def test_rebuild_daily_summary_unknown_child_raises(db):
    with pytest.raises(ValueError, match="Child not found"):
        dls.rebuild_daily_summary_for_child(db, child_id=999999, day=utc_today())


def test_rebuild_daily_summary_no_activity_yields_zeroes(db, create_parent, create_child):
    _, child = _make_child(create_parent, create_child)
    day = utc_today()

    result = dls.rebuild_daily_summary_for_child(db, child_id=child.id, day=day)

    assert result["screen_time_minutes"] == 0
    assert result["activities_completed"] == 0
    assert result["ai_interactions_count"] == 0
