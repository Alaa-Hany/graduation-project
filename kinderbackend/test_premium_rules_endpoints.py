from datetime import timedelta

from core.time_utils import utc_now
from models import SupportTicket


def _record_event(client, headers, *, child_id: int, event_type: str, occurred_at, **extra):
    payload = {
        "child_id": child_id,
        "event_type": event_type,
        "occurred_at": occurred_at.isoformat(),
        **extra,
    }
    response = client.post("/analytics/events", json=payload, headers=headers)
    assert response.status_code == 200, response.text


def _record_session(client, headers, *, child_id: int, started_at, ended_at, **extra):
    payload = {
        "child_id": child_id,
        "started_at": started_at.isoformat(),
        "ended_at": ended_at.isoformat(),
        **extra,
    }
    response = client.post("/analytics/sessions", json=payload, headers=headers)
    assert response.status_code == 200, response.text


def test_premium_rules_endpoints_use_backend_data(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="premium.rules@example.com", plan="PREMIUM")
    active_child = create_child(parent_id=parent.id, name="Lina", age=8)
    inactive_child = create_child(parent_id=parent.id, name="Omar", age=7)
    headers = auth_headers(parent)
    now = utc_now()

    _record_session(
        client,
        headers,
        child_id=active_child.id,
        started_at=now - timedelta(hours=2),
        ended_at=now - timedelta(hours=1, minutes=20),
        metadata_json={"screen": "learn"},
    )
    _record_event(
        client,
        headers,
        child_id=active_child.id,
        event_type="lesson_completed",
        occurred_at=now - timedelta(days=1),
        activity_name="Math Builder",
        duration_seconds=900,
        metadata_json={
            "score": 88,
            "completion_status": "completed",
            "content_type": "lessons",
        },
    )
    _record_event(
        client,
        headers,
        child_id=active_child.id,
        event_type="mood_entry",
        occurred_at=now - timedelta(days=1, hours=1),
        mood_value=1,
        metadata_json={"mood_label": "sad"},
    )
    _record_event(
        client,
        headers,
        child_id=active_child.id,
        event_type="mood_entry",
        occurred_at=now - timedelta(hours=4),
        mood_value=2,
        metadata_json={"mood_label": "tired"},
    )
    _record_event(
        client,
        headers,
        child_id=active_child.id,
        event_type="achievement_unlocked",
        occurred_at=now - timedelta(hours=3),
        achievement_key="streak3",
        activity_name="Daily Streak",
    )

    insights = client.get("/ai/insights", headers=headers)
    assert insights.status_code == 200
    insights_payload = insights.json()
    assert insights_payload["data_source"] == "backend_rules"
    assert insights_payload["insights"]
    assert any(item["code"] in {"mood_support", "content_affinity", "inactivity_watch"} for item in insights_payload["insights"])

    smart_notifications = client.get("/notifications/smart", headers=headers)
    assert smart_notifications.status_code == 200
    smart_payload = smart_notifications.json()
    assert smart_payload["data_source"] == "backend_rules"
    assert any(item["type"] == "INACTIVITY_ALERT" for item in smart_payload["notifications"])
    assert any(item["type"] == "MOOD_TREND" for item in smart_payload["notifications"])

    offline = client.get("/downloads/offline", headers=headers)
    assert offline.status_code == 200
    offline_payload = offline.json()
    assert offline_payload["data_source"] == "backend_rules"
    assert offline_payload["quota_mb"] == 500
    assert offline_payload["used_mb"] >= 20
    assert offline_payload["remaining_mb"] <= 500


def test_priority_support_and_admin_queue_are_rules_based(
    client,
    db,
    create_parent,
    auth_headers,
    create_admin,
    admin_headers,
    seed_builtin_rbac,
):
    seed_builtin_rbac()
    admin = create_admin(email="support.admin@example.com", role_names=["super_admin"])
    family_parent = create_parent(email="family.plus@example.com", plan="FAMILY_PLUS")
    premium_parent = create_parent(email="premium.other@example.com", plan="PREMIUM")

    urgent_ticket = SupportTicket(
        user_id=family_parent.id,
        subject="Billing issue needs attention",
        message="Payment status looks wrong",
        email=family_parent.email,
        category="billing_issue",
        status="open",
    )
    standard_ticket = SupportTicket(
        user_id=premium_parent.id,
        subject="General question",
        message="I need some help with the app",
        email=premium_parent.email,
        category="general_inquiry",
        status="open",
    )
    db.add_all([urgent_ticket, standard_ticket])
    db.commit()

    priority = client.get("/support/priority", headers=auth_headers(family_parent))
    assert priority.status_code == 200
    priority_payload = priority.json()
    assert priority_payload["support_level"] == "priority"
    assert priority_payload["data_source"] == "backend_rules"
    assert priority_payload["highest_priority_ticket"]["ticket_id"] == urgent_ticket.id
    assert priority_payload["highest_priority_ticket"]["priority_level"] in {"urgent", "high"}

    admin_list = client.get("/admin/support/tickets", headers=admin_headers(admin))
    assert admin_list.status_code == 200
    items = admin_list.json()["items"]
    assert items[0]["id"] == urgent_ticket.id
    assert items[0]["priority_score"] >= items[1]["priority_score"]
    assert items[0]["priority_level"] in {"urgent", "high"}
