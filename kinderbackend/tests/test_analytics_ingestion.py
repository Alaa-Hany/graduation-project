"""
Tests for analytics event ingestion and aggregation.
"""

from __future__ import annotations
import pytest
from models import ChildActivityEvent, ChildDailyActivitySummary, ChildSessionLog

EVENTS_URL = "/api/v1/analytics/events"
SESSIONS_URL = "/api/v1/analytics/sessions"
BASIC_REPORTS_URL = "/api/v1/reports/basic"


@pytest.fixture
def parent(create_parent):
    return create_parent(email="analytics.parent@example.invalid")


@pytest.fixture
def child(parent, create_child):
    return create_child(parent_id=parent.id, name="TestChild", age=7)


@pytest.fixture
def parent_headers(parent, auth_headers):
    return auth_headers(parent)


def test_ingest_lesson_completed_event(client, db, parent, child, parent_headers, api):
    resp = client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "lesson_completed",
            "lesson_id": "lesson-abc-01",
            "activity_name": "Alphabet Lesson",
            "duration_seconds": 300,
        },
        headers=parent_headers,
    )
    assert resp.status_code == 200
    body = api.parse(resp)
    assert body["event"]["child_id"] == child.id
    assert body["event"]["event_type"] == "lesson_completed"
    assert body["event"]["id"] is not None


def test_ingest_activity_completed_event(client, db, parent, child, parent_headers, api):
    resp = client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "activity_completed",
            "activity_name": "Drawing Activity",
            "duration_seconds": 120,
        },
        headers=parent_headers,
    )
    assert resp.status_code == 200
    assert api.parse(resp)["event"]["event_type"] == "activity_completed"


def test_ingest_mood_entry_event(client, db, parent, child, parent_headers, api):
    resp = client.post(
        EVENTS_URL,
        json={"child_id": child.id, "event_type": "mood_entry", "mood_value": 4},
        headers=parent_headers,
    )
    assert resp.status_code == 200
    assert api.parse(resp)["event"]["event_type"] == "mood_entry"


def test_ingest_achievement_unlocked_event(client, db, parent, child, parent_headers, api):
    resp = client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "achievement_unlocked",
            "achievement_key": "first_lesson",
        },
        headers=parent_headers,
    )
    assert resp.status_code == 200
    assert api.parse(resp)["event"]["event_type"] == "achievement_unlocked"


def test_invalid_event_type_rejected(client, db, parent, child, parent_headers):
    resp = client.post(
        EVENTS_URL,
        json={"child_id": child.id, "event_type": "not_a_real_event"},
        headers=parent_headers,
    )
    assert resp.status_code == 422


def test_event_persisted_to_database(client, db, parent, child, parent_headers):
    client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "lesson_completed",
            "lesson_id": "lesson-db-check",
        },
        headers=parent_headers,
    )
    event = (
        db.query(ChildActivityEvent)
        .filter(
            ChildActivityEvent.child_id == child.id,
            ChildActivityEvent.lesson_id == "lesson-db-check",
        )
        .first()
    )
    assert event is not None
    assert event.event_type == "lesson_completed"


def test_unauthenticated_event_ingestion_rejected(client, db, child):
    resp = client.post(EVENTS_URL, json={"child_id": child.id, "event_type": "lesson_completed"})
    assert resp.status_code in {401, 403}


def test_cannot_ingest_event_for_another_parents_child(
    client, db, create_parent, create_child, auth_headers, child
):
    other_parent = create_parent(email="other.parent@example.invalid")
    other_headers = auth_headers(other_parent)
    resp = client.post(
        EVENTS_URL,
        json={"child_id": child.id, "event_type": "lesson_completed"},
        headers=other_headers,
    )
    assert resp.status_code in {403, 404}


def test_ingest_session_log(client, db, parent, child, parent_headers, api):
    resp = client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "session_id": "sess-001",
            "source": "child_mode",
            "started_at": "2026-06-17T10:00:00Z",
            "ended_at": "2026-06-17T10:25:00Z",
        },
        headers=parent_headers,
    )
    assert resp.status_code == 200
    body = api.parse(resp)
    assert body["session"]["child_id"] == child.id
    assert body["session"]["duration_seconds"] == 25 * 60


def test_session_log_persisted_to_database(client, db, parent, child, parent_headers):
    client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "session_id": "sess-db-check",
            "started_at": "2026-06-17T09:00:00Z",
            "ended_at": "2026-06-17T09:30:00Z",
        },
        headers=parent_headers,
    )
    log = (
        db.query(ChildSessionLog)
        .filter(ChildSessionLog.child_id == child.id, ChildSessionLog.session_id == "sess-db-check")
        .first()
    )
    assert log is not None
    assert log.duration_seconds == 30 * 60


def test_session_with_inverted_timestamps_rejected(client, db, parent, child, parent_headers):
    resp = client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "started_at": "2026-06-17T11:00:00Z",
            "ended_at": "2026-06-17T10:00:00Z",
        },
        headers=parent_headers,
    )
    assert resp.status_code == 422


def test_lesson_completed_increments_daily_summary(client, db, parent, child, parent_headers):
    client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "lesson_completed",
            "lesson_id": "lesson-agg-01",
            "occurred_at": "2026-06-17T08:00:00Z",
        },
        headers=parent_headers,
    )
    summary = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .first()
    )
    assert summary is not None
    assert summary.lessons_completed >= 1
    assert summary.activities_completed >= 1


def test_multiple_events_accumulate_in_daily_summary(client, db, parent, child, parent_headers):
    for _ in range(3):
        client.post(
            EVENTS_URL,
            json={
                "child_id": child.id,
                "event_type": "activity_completed",
                "occurred_at": "2026-06-17T08:00:00Z",
            },
            headers=parent_headers,
        )
    summary = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .first()
    )
    assert summary is not None
    assert summary.activities_completed >= 3


def test_session_log_increments_screen_time_in_daily_summary(
    client, db, parent, child, parent_headers
):
    client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "started_at": "2026-06-17T07:00:00Z",
            "ended_at": "2026-06-17T07:20:00Z",
        },
        headers=parent_headers,
    )
    summary = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .first()
    )
    assert summary is not None
    assert summary.screen_time_minutes >= 20


def test_basic_reports_endpoint_reflects_ingested_events(client, db, parent, child, parent_headers):
    client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "lesson_completed",
            "lesson_id": "lesson-report-check",
        },
        headers=parent_headers,
    )
    resp = client.get(
        BASIC_REPORTS_URL, params={"child_id": child.id, "days": 7}, headers=parent_headers
    )
    assert resp.status_code == 200
