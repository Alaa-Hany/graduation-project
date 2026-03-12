from __future__ import annotations

import admin_models  # noqa: F401
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from admin_auth import create_admin_access_token
from admin_models import AdminUser, AdminUserRole, Permission, Role, RolePermission
from auth import create_access_token, hash_password
from database import Base, SessionLocal
from main import app
from models import Notification, SupportTicket, User
from routers.admin_seed import PERMISSION_DEFS, ROLE_DEFS


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


def _seed_builtin_rbac(db) -> None:
    permission_by_name: dict[str, Permission] = {}
    for permission_name, description in PERMISSION_DEFS:
        permission = db.query(Permission).filter(Permission.name == permission_name).first()
        if permission is None:
            permission = Permission(name=permission_name, description=description)
            db.add(permission)
            db.flush()
        permission_by_name[permission_name] = permission

    for role_name, permission_names in ROLE_DEFS.items():
        role = db.query(Role).filter(Role.name == role_name).first()
        if role is None:
            role = Role(name=role_name, description=f"Built-in role: {role_name}")
            db.add(role)
            db.flush()
        existing_permission_ids = {
            mapping.permission_id
            for mapping in db.query(RolePermission).filter(RolePermission.role_id == role.id).all()
        }
        for permission_name in permission_names:
            permission = permission_by_name[permission_name]
            if permission.id not in existing_permission_ids:
                db.add(RolePermission(role_id=role.id, permission_id=permission.id))
    db.commit()


def _create_parent(db, email: str) -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name="Parent",
        role="parent",
        is_active=True,
        plan="FREE",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_admin(db, email: str) -> AdminUser:
    admin = AdminUser(
        email=email,
        password_hash=hash_password("AdminPass123!"),
        name="Admin",
        is_active=True,
        token_version=0,
    )
    db.add(admin)
    db.flush()
    role = db.query(Role).filter(Role.name == "super_admin").one()
    db.add(AdminUserRole(admin_user_id=admin.id, role_id=role.id))
    db.commit()
    db.refresh(admin)
    return admin


def _parent_headers(user: User) -> dict[str, str]:
    token = create_access_token(str(user.id), getattr(user, "token_version", 0))
    return {"Authorization": f"Bearer {token}"}


def _admin_headers(admin: AdminUser) -> dict[str, str]:
    token = create_admin_access_token(admin.id, admin.token_version)
    return {"Authorization": f"Bearer {token}"}


def test_support_ticket_admin_updates_create_parent_notifications(client: TestClient, db):
    _seed_builtin_rbac(db)
    parent = _create_parent(db, "notify.parent@gmail.com")
    admin = _create_admin(db, "notify.admin@gmail.com")
    ticket = SupportTicket(
        user_id=parent.id,
        subject="Need support",
        message="Please help with an account problem.",
        category="login_issue",
        email=parent.email,
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    reply = client.post(
        f"/admin/support/tickets/{ticket.id}/reply",
        json={"message": "We are looking into it."},
        headers=_admin_headers(admin),
    )
    assert reply.status_code == 200

    resolve = client.post(
        f"/admin/support/tickets/{ticket.id}/resolve",
        headers=_admin_headers(admin),
    )
    assert resolve.status_code == 200

    notifications = (
        db.query(Notification)
        .filter(Notification.user_id == parent.id)
        .order_by(Notification.created_at.asc())
        .all()
    )
    assert len(notifications) == 2
    assert notifications[0].type == "SUPPORT_TICKET_UPDATE"
    assert "Need support" in notifications[0].body
    assert notifications[1].title == "Support ticket resolved"


def test_subscription_changes_create_notifications_and_are_listed(client: TestClient, db):
    _seed_builtin_rbac(db)
    parent = _create_parent(db, "subscription.notify@gmail.com")
    admin = _create_admin(db, "subscription.admin@gmail.com")
    headers = _parent_headers(parent)

    select = client.post(
        "/subscription/select",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert select.status_code == 200

    cancel = client.post("/subscription/cancel", headers=headers)
    assert cancel.status_code == 200

    override = client.post(
        f"/admin/subscriptions/{parent.id}/override-plan",
        json={"plan": "family_plus"},
        headers=_admin_headers(admin),
    )
    assert override.status_code == 200

    listed = client.get("/notifications", headers=headers)
    assert listed.status_code == 200
    payload = listed.json()
    assert payload["summary"]["unread_count"] == 3
    assert payload["notifications"][0]["type"] == "SUBSCRIPTION_UPDATED"
    assert payload["notifications"][0]["child_id"] is None
