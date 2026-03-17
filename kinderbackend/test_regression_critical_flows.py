from __future__ import annotations

from datetime import timedelta

from core.time_utils import db_utc_now
from services.payment_reconciliation_service import payment_reconciliation_service
from test_public_content_routes import _create_category, _create_content, _create_quiz


def _seed_child_content(db):
    category = _create_category(
        db,
        slug="regression-learning",
        title_en="Regression Learning",
        title_ar="Regression Learning",
    )
    lesson = _create_content(
        db,
        slug="regression-lesson",
        title_en="Regression Lesson",
        title_ar="Regression Lesson",
        content_type="lesson",
        category_id=category.id,
        body_en="Regression lesson body",
        age_group="5-7",
    )
    _create_quiz(
        db,
        content_id=lesson.id,
        category_id=category.id,
        title_en="Regression Quiz",
    )
    return category, lesson


def _create_super_admin(seed_builtin_rbac, create_admin, admin_headers):
    seed_builtin_rbac()
    admin = create_admin(email="regression.admin@example.com", role_names=["super_admin"])
    return admin, admin_headers(admin)


def test_regression_parent_onboarding_login(client):
    register_payload = {
        "name": "Regression Parent",
        "email": "regression.parent@example.com",
        "password": "Password123!",
        "confirm_password": "Password123!",
    }
    register = client.post("/auth/register", json=register_payload)
    assert register.status_code == 200
    register_json = register.json()
    assert register_json["user"]["email"] == "regression.parent@example.com"

    access_token = register_json["access_token"]
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {access_token}"})
    assert me.status_code == 200
    assert me.json()["user"]["email"] == "regression.parent@example.com"

    login = client.post(
        "/auth/login",
        json={"email": "regression.parent@example.com", "password": "Password123!"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["email"] == "regression.parent@example.com"


def test_regression_child_mode_content_usage(client, db, create_parent):
    parent = create_parent(email="regression.child.parent@example.com")
    _seed_child_content(db)

    child_register = client.post(
        "/auth/child/register",
        json={
            "name": "Regression Kid",
            "picture_password": ["cat", "dog", "apple"],
            "age": 7,
            "parent_email": parent.email,
        },
    )
    assert child_register.status_code == 200
    child_payload = child_register.json()["child"]

    child_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child_payload["id"],
            "name": "Regression Kid",
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "device-regression-1",
        },
    )
    assert child_login.status_code == 200
    assert child_login.json()["session_token"]

    categories = client.get("/content/child/categories")
    assert categories.status_code == 200
    assert any(
        item["slug"] == "regression-learning" for item in categories.json()["items"]
    )

    items = client.get("/content/child/items", params={"category_slug": "regression-learning"})
    assert items.status_code == 200
    assert any(item["slug"] == "regression-lesson" for item in items.json()["items"])

    detail = client.get("/content/child/items/regression-lesson")
    assert detail.status_code == 200
    assert detail.json()["item"]["slug"] == "regression-lesson"


def test_regression_reports_from_backend(client, create_parent, create_child, auth_headers):
    parent = create_parent(email="regression.reports@example.com")
    child = create_child(parent_id=parent.id)
    headers = auth_headers(parent)

    event_payload = {
        "child_id": child.id,
        "event_type": "lesson_completed",
        "lesson_id": "regression-lesson",
        "activity_name": "Regression Lesson",
        "duration_seconds": 240,
    }
    event_resp = client.post("/analytics/events", json=event_payload, headers=headers)
    assert event_resp.status_code == 200

    session_payload = {
        "child_id": child.id,
        "session_id": "regression-session-1",
        "started_at": db_utc_now().isoformat(),
        "ended_at": (db_utc_now() + timedelta(minutes=15)).isoformat(),
        "source": "child_mode",
    }
    session_resp = client.post("/analytics/sessions", json=session_payload, headers=headers)
    assert session_resp.status_code == 200

    report = client.get("/reports/basic", headers=headers)
    assert report.status_code == 200
    assert report.json().get("child_summary") is not None


def test_regression_subscription_lifecycle_and_history(client, create_parent, auth_headers):
    parent = create_parent(email="regression.subscription@example.com")
    headers = auth_headers(parent)

    baseline = client.get("/subscription/me", headers=headers)
    assert baseline.status_code == 200

    checkout = client.post(
        "/subscription/checkout",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert checkout.status_code == 200
    checkout_payload = checkout.json()
    assert checkout_payload.get("session_id")
    assert checkout_payload.get("checkout_url")

    snapshot = client.get("/subscription/me", headers=headers)
    assert snapshot.status_code == 200
    snapshot_payload = snapshot.json()
    assert snapshot_payload["current_plan_id"] in {"PREMIUM", "FAMILY_PLUS", "FREE"}
    assert snapshot_payload["lifecycle"]["status"] in {"active", "pending_activation", "free"}

    history = client.get("/subscription/history", headers=headers)
    assert history.status_code == 200
    history_payload = history.json()
    assert isinstance(history_payload["events"], list)
    assert isinstance(history_payload["payment_attempts"], list)


def test_regression_payment_provider_webhook_reconciliation(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    create_parent,
    auth_headers,
):
    _admin, admin_auth = _create_super_admin(seed_builtin_rbac, create_admin, admin_headers)
    parent = create_parent(email="regression.payments@example.com")
    headers = auth_headers(parent)

    checkout = client.post(
        "/subscription/checkout",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert checkout.status_code == 200

    portal = client.post("/billing/portal", headers=headers)
    assert portal.status_code in {409, 501, 503}

    webhook = client.post("/webhooks/stripe", content=b"{}")
    assert webhook.status_code == 400

    reconcile = client.post(
        "/admin/subscriptions/reconcile",
        json={"limit": 10, "include_pending": True},
        headers=admin_auth,
    )
    assert reconcile.status_code == 200
    assert reconcile.json()["scanned"] == 0

    direct = payment_reconciliation_service.reconcile_all(db=db, limit=10, include_pending=True)
    assert direct.scanned == 0


def test_regression_ai_buddy_session_and_visibility(
    client, create_parent, create_child, auth_headers
):
    parent = create_parent(email="regression.ai@example.com")
    child = create_child(parent_id=parent.id)
    headers = auth_headers(parent)

    start = client.post("/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    assert start.status_code == 200
    session_id = start.json()["session"]["id"]

    message = client.post(
        f"/ai-buddy/sessions/{session_id}/messages",
        json={"child_id": child.id, "content": "I want to hurt myself"},
        headers=headers,
    )
    assert message.status_code == 200
    assistant = message.json()["assistant_message"]
    assert assistant["safety_status"] in {"needs_refusal", "needs_safe_redirect", "allowed"}

    visibility = client.get(
        f"/ai-buddy/children/{child.id}/visibility",
        headers=headers,
    )
    assert visibility.status_code == 200
    assert visibility.json()["child_id"] == child.id


def test_regression_admin_content_support_subscriptions(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    create_parent,
    auth_headers,
):
    _admin, admin_auth = _create_super_admin(seed_builtin_rbac, create_admin, admin_headers)
    parent = create_parent(email="regression.admin.parent@example.com")
    headers = auth_headers(parent)

    _seed_child_content(db)
    client.get("/subscription/me", headers=headers)

    ticket = client.post(
        "/support/contact",
        json={
            "subject": "Regression support",
            "message": "Need help verifying the regression flow.",
            "category": "general_inquiry",
        },
        headers=headers,
    )
    assert ticket.status_code == 200

    content_list = client.get("/admin/contents", headers=admin_auth)
    assert content_list.status_code == 200
    assert isinstance(content_list.json()["items"], list)

    support_list = client.get("/admin/support/tickets", headers=admin_auth)
    assert support_list.status_code == 200
    assert support_list.json()["pagination"]["total"] >= 1

    subscriptions = client.get("/admin/subscriptions", headers=admin_auth)
    assert subscriptions.status_code == 200
    assert isinstance(subscriptions.json()["items"], list)

    subscription_detail = client.get(f"/admin/subscriptions/{parent.id}", headers=admin_auth)
    assert subscription_detail.status_code == 200
    assert subscription_detail.json()["item"]["user_id"] == parent.id
