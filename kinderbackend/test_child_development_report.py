from datetime import date, datetime, timedelta, timezone

import admin_models  # noqa: F401
from auth import hash_password
from models import ChildProfile, User
from plan_service import PLAN_FREE, PLAN_PREMIUM


def _create_parent(db, *, email: str, plan: str) -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name="Dev Parent",
        role="parent",
        is_active=True,
        email_verified=True,
        plan=plan,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_child(db, parent, *, name="Yara", age=7) -> ChildProfile:
    child = ChildProfile(
        parent_id=parent.id,
        name=name,
        picture_password=["cat", "dog", "apple"],
        date_of_birth=date(date.today().year - age, 1, 1),
        avatar="av1",
        is_active=True,
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


def _recent(minutes_ago: int) -> str:
    base = datetime.now(timezone.utc).replace(hour=12, minute=0, second=0, microsecond=0)
    base -= timedelta(days=1)
    return (base + timedelta(minutes=minutes_ago)).isoformat().replace("+00:00", "Z")


def _post_event(client, headers, **fields):
    resp = client.post("/api/v1/analytics/events", json=fields, headers=headers)
    assert resp.status_code == 200, resp.text
    return resp


def test_development_report_scores_four_domains_with_narrative(client, db, auth_headers):
    parent = _create_parent(db, email="dev-report@example.com", plan=PLAN_PREMIUM)
    child = _create_child(db, parent)
    headers = auth_headers(parent)

    # Seed activities that map to each of the four domains.
    _post_event(
        client,
        headers,
        child_id=child.id,
        event_type="lesson_completed",
        activity_name="Numbers",
        lesson_id="lesson_math_01",
        occurred_at=_recent(5),
        metadata_json={"score": 92, "category": "educational", "completion_status": "completed"},
    )
    _post_event(
        client,
        headers,
        child_id=child.id,
        event_type="activity_completed",
        activity_name="Arabic Reading",
        occurred_at=_recent(7),
        metadata_json={"score": 80, "category": "educational", "completion_status": "completed"},
    )
    _post_event(
        client,
        headers,
        child_id=child.id,
        event_type="activity_completed",
        activity_name="Drawing",
        occurred_at=_recent(9),
        metadata_json={"score": 70, "category": "skillful", "completion_status": "completed"},
    )
    _post_event(
        client,
        headers,
        child_id=child.id,
        event_type="activity_completed",
        activity_name="Sharing and cooperation",
        occurred_at=_recent(11),
        metadata_json={"score": 85, "completion_status": "completed"},
    )
    _post_event(
        client,
        headers,
        child_id=child.id,
        event_type="mood_entry",
        mood_value=5,
        occurred_at=_recent(12),
    )

    resp = client.get(f"/api/v1/reports/development?child_id={child.id}", headers=headers)
    assert resp.status_code == 200, resp.text
    payload = resp.json()

    assert payload["access_level"] == "advanced"
    assert payload["framing"] == "strengths_and_growth"
    assert payload["child"]["id"] == child.id
    assert "ar" in payload["disclaimer"] and "en" in payload["disclaimer"]

    domains = {d["key"]: d for d in payload["domains"]}
    assert set(domains) == {"cognitive", "language", "creative", "social"}

    # Cognitive got the highest-scoring activity.
    assert domains["cognitive"]["score"] is not None
    assert domains["cognitive"]["level"] in {"strong", "advanced"}
    assert domains["cognitive"]["stats"]["activities_count"] >= 1

    # Narrative falls back to the deterministic summary when no AI provider is set.
    assert payload["narrative"]["source"] == "fallback"
    assert payload["narrative"]["summary"].strip()
    assert payload["overall"]["top_domain"] in domains


def test_development_report_handles_insufficient_data(client, db, auth_headers):
    parent = _create_parent(db, email="dev-empty@example.com", plan=PLAN_PREMIUM)
    child = _create_child(db, parent, name="Omar")

    resp = client.get(
        f"/api/v1/reports/development?child_id={child.id}&language=en", headers=auth_headers(parent)
    )
    assert resp.status_code == 200, resp.text
    payload = resp.json()

    for domain in payload["domains"]:
        assert domain["score"] is None
        assert domain["confidence"] == "insufficient"
    assert payload["overall"]["average_score"] is None
    assert payload["narrative"]["language"] == "en"
    assert payload["narrative"]["summary"].strip()


def test_development_report_requires_advanced_plan(client, db, auth_headers):
    parent = _create_parent(db, email="dev-free@example.com", plan=PLAN_FREE)
    child = _create_child(db, parent, name="Free Kid")

    resp = client.get(
        f"/api/v1/reports/development?child_id={child.id}", headers=auth_headers(parent)
    )
    assert resp.status_code == 403


def test_development_report_rejects_other_parents_child(client, db, auth_headers):
    owner = _create_parent(db, email="dev-owner@example.com", plan=PLAN_PREMIUM)
    other = _create_parent(db, email="dev-other@example.com", plan=PLAN_PREMIUM)
    child = _create_child(db, owner, name="Owned")

    resp = client.get(
        f"/api/v1/reports/development?child_id={child.id}", headers=auth_headers(other)
    )
    assert resp.status_code == 404
