"""
Extended API tests for parent/child flows, settings, billing, notifications,
support, subscription demo mode, and demo/static feature endpoints.
"""

from __future__ import annotations

import admin_models  # noqa: F401
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from auth import create_access_token, create_refresh_token, hash_password
from database import Base, SessionLocal
from main import app
from models import Notification, PrivacySetting, SupportTicket, User
from plan_service import PLAN_FAMILY_PLUS, PLAN_FREE, PLAN_PREMIUM


@pytest.fixture(scope="session")
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture
def db(test_db):
    connection = test_db.connect()
    transaction = connection.begin()
    session = SessionLocal(bind=connection)
    yield session
    session.close()
    if transaction.is_active:
        transaction.rollback()
    connection.close()


@pytest.fixture
def client(db):
    from deps import get_db

    def override_get_db():
        return db

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def _auth_header(user: User) -> dict[str, str]:
    token = create_access_token(str(user.id), getattr(user, "token_version", 0))
    return {"Authorization": f"Bearer {token}"}


def _create_parent(
    db,
    *,
    email: str,
    plan: str = PLAN_FREE,
    name: str = "Parent User",
    is_active: bool = True,
) -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name=name,
        role="parent",
        is_active=is_active,
        plan=plan,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_notification(db, *, user_id: int, title: str, is_read: bool = False) -> Notification:
    item = Notification(
        user_id=user_id,
        type="SYSTEM",
        title=title,
        body=f"{title} body",
        is_read=is_read,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@pytest.mark.parametrize(
    ("method", "path", "payload"),
    [
        ("get", "/auth/me", None),
        ("get", "/privacy/settings", None),
        ("put", "/privacy/settings", {"analytics_enabled": True, "personalized_recommendations": True, "data_collection_opt_out": False}),
        ("get", "/parental-controls/settings", None),
        ("put", "/parental-controls/settings", {"daily_limit_enabled": True, "hours_per_day": 2, "break_reminders_enabled": True, "age_appropriate_only": True, "block_educational": False, "require_approval": False, "sleep_mode": True, "bedtime": "8:00 PM", "wake_time": "7:00 AM", "emergency_lock": False}),
        ("get", "/notifications", None),
        ("post", "/support/contact", {"subject": "Need help", "message": "Hello"}),
        ("get", "/billing/methods", None),
        ("get", "/subscription/me", None),
    ],
)
def test_parent_protected_endpoints_require_auth(client: TestClient, method: str, path: str, payload: dict | None):
    if payload is None:
        response = getattr(client, method)(path)
    else:
        response = getattr(client, method)(path, json=payload)
    assert response.status_code == 401


def test_parent_register_login_refresh_and_logout_revokes_refresh_token(client: TestClient, db):
    register = client.post(
        "/auth/register",
        json={
            "name": "Parent Example",
            "email": "Parent.Example@GMAIL.com",
            "password": "Password123!",
            "confirmPassword": "Password123!",
        },
    )

    assert register.status_code == 200
    register_data = register.json()
    assert register_data["user"]["email"] == "parent.example@gmail.com"

    refresh = client.post(
        "/auth/refresh",
        json={"refresh_token": register_data["refresh_token"]},
    )
    assert refresh.status_code == 200
    assert "access_token" in refresh.json()

    me = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {register_data['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["user"]["email"] == "parent.example@gmail.com"

    logout = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {register_data['access_token']}"},
    )
    assert logout.status_code == 200
    assert logout.json()["success"] is True

    refresh_after_logout = client.post(
        "/auth/refresh",
        json={"refresh_token": register_data["refresh_token"]},
    )
    assert refresh_after_logout.status_code == 401
    assert refresh_after_logout.json()["detail"] == "Invalid refresh token"

    user = db.query(User).filter(User.email == "parent.example@gmail.com").first()
    assert user is not None
    assert user.token_version == 1


def test_free_plan_child_limit_is_enforced(client: TestClient, db):
    parent = _create_parent(db, email="free.parent@gmail.com", plan=PLAN_FREE)
    headers = _auth_header(parent)

    first = client.post(
        "/children",
        json={
            "name": "Lina",
            "picture_password": ["cat", "dog", "apple"],
            "age": 6,
            "avatar": "boy1",
        },
        headers=headers,
    )
    assert first.status_code == 200
    assert first.json()["child"]["name"] == "Lina"

    second = client.post(
        "/children",
        json={
            "name": "Omar",
            "picture_password": ["sun", "moon", "star"],
            "age": 7,
        },
        headers=headers,
    )
    assert second.status_code == 402
    detail = second.json()["detail"]
    assert detail["code"] == "CHILD_LIMIT_REACHED"
    assert detail["plan"] == PLAN_FREE
    assert detail["limit"] == 1


def test_child_validation_duplicate_name_update_login_and_picture_password_flow(client: TestClient, db):
    parent = _create_parent(db, email="premium.parent@gmail.com", plan=PLAN_PREMIUM)
    headers = _auth_header(parent)

    invalid_age = client.post(
        "/children",
        json={
            "name": "Tiny",
            "picture_password": ["cat", "dog", "apple"],
            "age": 4,
        },
        headers=headers,
    )
    assert invalid_age.status_code == 422
    assert invalid_age.json()["detail"] == "Child age must be between 5 and 12"

    create = client.post(
        "/children",
        json={
            "name": "Mariam",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": "assets/images/avatars/girl1.png",
        },
        headers=headers,
    )
    assert create.status_code == 200
    child = create.json()["child"]
    child_id = child["id"]

    duplicate = client.post(
        "/children",
        json={
            "name": "Mariam",
            "picture_password": ["sun", "moon", "star"],
            "age": 9,
        },
        headers=headers,
    )
    assert duplicate.status_code == 400
    assert duplicate.json()["detail"]["code"] == "CHILD_NAME_EXISTS"

    listing = client.get("/children", headers=headers)
    assert listing.status_code == 200
    assert len(listing.json()["children"]) == 1

    update = client.put(
        f"/children/{child_id}",
        json={
            "name": "Mariam Updated",
            "age": 9,
            "avatar": "assets/images/avatars/girl2.png",
        },
        headers=headers,
    )
    assert update.status_code == 200
    assert update.json()["child"]["name"] == "Mariam Updated"
    assert update.json()["child"]["age"] == 9

    wrong_child_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child_id,
            "name": "Wrong Name",
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert wrong_child_login.status_code == 401

    correct_child_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert correct_child_login.status_code == 200
    assert correct_child_login.json()["success"] is True

    wrong_change = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "current_picture_password": ["sun", "moon", "star"],
            "new_picture_password": ["tree", "book", "fish"],
        },
    )
    assert wrong_change.status_code == 401

    invalid_new_password = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "current_picture_password": ["cat", "dog", "apple"],
            "new_picture_password": ["tree", "book"],
        },
    )
    assert invalid_new_password.status_code == 422

    change = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "current_picture_password": ["cat", "dog", "apple"],
            "new_picture_password": ["tree", "book", "fish"],
        },
    )
    assert change.status_code == 200
    assert change.json()["success"] is True

    old_password_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert old_password_login.status_code == 401

    new_password_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child_id,
            "name": "Mariam Updated",
            "picture_password": ["tree", "book", "fish"],
        },
    )
    assert new_password_login.status_code == 200


def test_privacy_parental_controls_notifications_support_and_billing_persist(client: TestClient, db):
    parent = _create_parent(db, email="settings.parent@gmail.com", plan=PLAN_PREMIUM)
    headers = _auth_header(parent)

    note_one = _create_notification(db, user_id=parent.id, title="Welcome alert", is_read=False)
    note_two = _create_notification(db, user_id=parent.id, title="Weekly summary", is_read=False)

    privacy_get = client.get("/privacy/settings", headers=headers)
    assert privacy_get.status_code == 200
    assert privacy_get.json() == {
        "analytics_enabled": True,
        "personalized_recommendations": True,
        "data_collection_opt_out": False,
    }

    privacy_put = client.put(
        "/privacy/settings",
        json={
            "analytics_enabled": False,
            "personalized_recommendations": False,
            "data_collection_opt_out": True,
        },
        headers=headers,
    )
    assert privacy_put.status_code == 200
    assert privacy_put.json()["success"] is True

    privacy_row = db.query(PrivacySetting).filter(PrivacySetting.user_id == parent.id).first()
    assert privacy_row is not None
    assert privacy_row.analytics_enabled is False
    assert privacy_row.personalized_recommendations is False
    assert privacy_row.data_collection_opt_out is True

    controls_get = client.get("/parental-controls/settings", headers=headers)
    assert controls_get.status_code == 200
    assert controls_get.json()["settings"]["hours_per_day"] == 2

    controls_put = client.put(
        "/parental-controls/settings",
        json={
            "daily_limit_enabled": True,
            "hours_per_day": 3,
            "break_reminders_enabled": False,
            "age_appropriate_only": True,
            "block_educational": True,
            "require_approval": True,
            "sleep_mode": False,
            "bedtime": "9:00 PM",
            "wake_time": "6:30 AM",
            "emergency_lock": True,
        },
        headers=headers,
    )
    assert controls_put.status_code == 200
    assert controls_put.json()["settings"]["hours_per_day"] == 3
    assert controls_put.json()["settings"]["emergency_lock"] is True

    notifications = client.get("/notifications", headers=headers)
    assert notifications.status_code == 200
    assert len(notifications.json()["notifications"]) == 2

    mark_one = client.post(f"/notifications/{note_one.id}/read", headers=headers)
    assert mark_one.status_code == 200
    db.refresh(note_one)
    assert note_one.is_read is True

    mark_all = client.post("/notifications/mark-all-read", headers=headers)
    assert mark_all.status_code == 200
    db.refresh(note_two)
    assert note_two.is_read is True

    support = client.post(
        "/support/contact",
        json={
            "subject": "Payment question",
            "message": "I need help with billing",
            "email": parent.email,
        },
        headers=headers,
    )
    assert support.status_code == 200
    ticket = db.query(SupportTicket).filter(SupportTicket.user_id == parent.id).one()
    assert ticket.subject == "Payment question"
    assert ticket.status == "open"

    add_method = client.post(
        "/billing/methods",
        json={"label": "Visa ending 1234"},
        headers=headers,
    )
    assert add_method.status_code == 200
    method_id = add_method.json()["method"]["id"]

    list_methods = client.get("/billing/methods", headers=headers)
    assert list_methods.status_code == 200
    assert len(list_methods.json()["methods"]) == 1
    assert list_methods.json()["methods"][0]["label"] == "Visa ending 1234"

    delete_method = client.delete(f"/billing/methods/{method_id}", headers=headers)
    assert delete_method.status_code == 200

    missing_delete = client.delete(f"/billing/methods/{method_id}", headers=headers)
    assert missing_delete.status_code == 404


def test_subscription_demo_mode_and_placeholder_billing_endpoints(client: TestClient, db):
    user = _create_parent(db, email="subscription.parent@gmail.com", plan=PLAN_FREE)
    headers = _auth_header(user)

    subscription_me = client.get("/subscription/me", headers=headers)
    assert subscription_me.status_code == 200
    assert subscription_me.json()["plan"] == PLAN_FREE
    assert subscription_me.json()["limits"]["max_children"] == 1

    invalid_select = client.post(
        "/subscription/select",
        json={"plan_id": "enterprise"},
        headers=headers,
    )
    assert invalid_select.status_code == 400

    premium_select = client.post(
        "/subscription/select",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert premium_select.status_code == 200
    premium_payload = premium_select.json()
    assert premium_payload["current_plan_id"] == PLAN_PREMIUM
    assert premium_payload["session_id"].startswith("mock_session_")

    db.refresh(user)
    assert user.plan == PLAN_PREMIUM

    manage = client.post("/subscription/manage", headers=headers)
    assert manage.status_code == 501
    assert "Billing portal is not configured yet" in manage.json()["detail"]

    portal = client.post("/billing/portal", headers=headers)
    assert portal.status_code == 501
    assert "Billing portal is not configured yet" in portal.json()["detail"]


def test_feature_gated_demo_static_responses_match_current_behavior(client: TestClient, db):
    premium_user = _create_parent(db, email="premium.demo@gmail.com", plan=PLAN_PREMIUM)
    family_user = _create_parent(db, email="family.demo@gmail.com", plan=PLAN_FAMILY_PLUS)

    premium_headers = _auth_header(premium_user)
    family_headers = _auth_header(family_user)

    smart_notifications = client.get("/notifications/smart", headers=premium_headers)
    assert smart_notifications.status_code == 200
    smart_payload = smart_notifications.json()
    assert smart_payload["access_level"] == "smart"
    assert smart_payload["notifications"][0]["type"] == "BEHAVIORAL_INSIGHT"

    ai_insights = client.get("/ai/insights", headers=premium_headers)
    assert ai_insights.status_code == 200
    assert len(ai_insights.json()["insights"]) == 2

    offline = client.get("/downloads/offline", headers=premium_headers)
    assert offline.status_code == 200
    assert offline.json()["status"] == "downloads enabled"
    assert offline.json()["quota_mb"] == 500

    advanced_controls = client.get("/parental-controls/advanced", headers=premium_headers)
    assert advanced_controls.status_code == 200
    assert advanced_controls.json()["access_level"] == "advanced"
    assert any(item["type"] == "LOCATION_TRACKING" for item in advanced_controls.json()["controls"])

    priority_support = client.get("/support/priority", headers=family_headers)
    assert priority_support.status_code == 200
    assert priority_support.json()["support_level"] == "priority"
    assert "phone" in priority_support.json()["support_channels"]
