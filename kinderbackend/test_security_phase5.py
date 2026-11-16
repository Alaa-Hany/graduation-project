"""Phase 5 backend side of #7: analytics writes with an Idempotency-Key are
stored once, even when the app retries or re-syncs them."""

from __future__ import annotations

import pytest

from models import ChildActivityEvent, ChildDailyActivitySummary, ChildSessionLog

EVENTS_URL = "/api/v1/analytics/events"
SESSIONS_URL = "/api/v1/analytics/sessions"

_EVENT = {"event_type": "activity_completed", "activity_name": "Puzzle", "points": 40}
_SESSION = {
    "started_at": "2026-11-10T10:00:00Z",
    "ended_at": "2026-11-10T10:20:00Z",
}


@pytest.fixture
def family(create_parent, create_child, auth_headers):
    parent = create_parent(email="p5.family@example.com")
    child = create_child(parent_id=parent.id, name="P5Kid")
    return child, auth_headers(parent)


def _summary(db, child_id):
    db.expire_all()
    return (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child_id)
        .one()
    )


def test_retried_event_with_same_key_is_stored_once(client, db, family):
    child, headers = family
    keyed = {**headers, "Idempotency-Key": "progress-event:rec-1"}
    first = client.post(EVENTS_URL, json={"child_id": child.id, **_EVENT}, headers=keyed)
    retry = client.post(EVENTS_URL, json={"child_id": child.id, **_EVENT}, headers=keyed)

    assert first.status_code == retry.status_code == 200
    assert retry.json()["event"]["id"] == first.json()["event"]["id"]
    assert retry.json()["event"]["duplicate"] is True
    assert db.query(ChildActivityEvent).filter_by(child_id=child.id).count() == 1
    assert _summary(db, child.id).activities_completed == 1


def test_different_keys_and_keyless_requests_are_separate_events(client, db, family):
    child, headers = family
    for key in ("progress-event:a", "progress-event:b"):
        client.post(
            EVENTS_URL,
            json={"child_id": child.id, **_EVENT},
            headers={**headers, "Idempotency-Key": key},
        )
    # Older app versions send no key: still accepted, just not de-duplicated.
    for _ in range(2):
        client.post(EVENTS_URL, json={"child_id": child.id, **_EVENT}, headers=headers)
    assert db.query(ChildActivityEvent).filter_by(child_id=child.id).count() == 4
    assert _summary(db, child.id).activities_completed == 4


def test_same_key_is_scoped_per_child(client, db, create_parent, create_child, auth_headers):
    parent = create_parent(email="p5.siblings@example.com")
    kids = [create_child(parent_id=parent.id, name=n) for n in ("A", "B")]
    headers = {**auth_headers(parent), "Idempotency-Key": "mood:same-id"}
    for kid in kids:
        response = client.post(EVENTS_URL, json={"child_id": kid.id, **_EVENT}, headers=headers)
        assert response.status_code == 200
        assert "duplicate" not in response.json()["event"]


def test_retried_session_with_same_key_is_stored_once(client, db, family):
    child, headers = family
    keyed = {**headers, "Idempotency-Key": "progress-session:rec-1"}
    for _ in range(3):
        response = client.post(SESSIONS_URL, json={"child_id": child.id, **_SESSION}, headers=keyed)
        assert response.status_code == 200
    assert db.query(ChildSessionLog).filter_by(child_id=child.id).count() == 1
    assert _summary(db, child.id).screen_time_minutes == 20


def test_concurrent_duplicate_is_caught_by_the_unique_constraint(client, db, family, monkeypatch):
    """Two copies arriving together both pass the pre-check; the database's
    unique constraint stops the second, which then returns the first row."""
    from services.analytics_ingestion_service import AnalyticsIngestionService

    child, headers = family
    keyed = {**headers, "Idempotency-Key": "progress-event:race"}
    first = client.post(EVENTS_URL, json={"child_id": child.id, **_EVENT}, headers=keyed)

    real_find = AnalyticsIngestionService._find_by_idempotency_key
    calls = {"n": 0}

    def _miss_first_lookup(**kwargs):
        calls["n"] += 1
        return None if calls["n"] == 1 else real_find(**kwargs)

    monkeypatch.setattr(
        AnalyticsIngestionService, "_find_by_idempotency_key", staticmethod(_miss_first_lookup)
    )
    raced = client.post(EVENTS_URL, json={"child_id": child.id, **_EVENT}, headers=keyed)

    assert raced.status_code == 200
    assert raced.json()["event"]["id"] == first.json()["event"]["id"]
    assert db.query(ChildActivityEvent).filter_by(child_id=child.id).count() == 1
    assert _summary(db, child.id).activities_completed == 1


def test_other_integrity_error_answers_409_not_500(client, db, family, monkeypatch):
    """A failed insert that is not a duplicate (nothing to return) must give a
    clean 409 and store nothing, not crash."""
    from sqlalchemy.exc import IntegrityError

    child, headers = family
    real_commit = db.commit

    def _failing_commit():
        raise IntegrityError("INSERT", {}, Exception("FOREIGN KEY constraint failed"))

    monkeypatch.setattr(db, "commit", _failing_commit)
    response = client.post(
        SESSIONS_URL,
        json={"child_id": child.id, **_SESSION},
        headers={**headers, "Idempotency-Key": "progress-session:fk"},
    )
    monkeypatch.setattr(db, "commit", real_commit)

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "ANALYTICS_STORE_CONFLICT"
    assert db.query(ChildSessionLog).filter_by(child_id=child.id).count() == 0


def test_idempotency_key_header_is_allowed_by_cors(client):
    preflight = client.options(
        EVENTS_URL,
        headers={
            "Origin": "http://localhost:44377",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type,idempotency-key",
        },
    )
    allowed = preflight.headers.get("access-control-allow-headers", "").lower()
    assert "idempotency-key" in allowed
