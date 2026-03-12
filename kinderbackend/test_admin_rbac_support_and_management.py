"""
Extended admin API tests covering admin auth, RBAC, support flows,
settings, child management, user management, and subscription admin actions.
"""

from __future__ import annotations

import admin_models  # noqa: F401
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from admin_auth import create_admin_access_token, create_admin_refresh_token
from admin_models import AdminUser, AdminUserRole, Permission, Role, RolePermission
from auth import create_access_token, hash_password, verify_password
from database import Base, SessionLocal
from main import app
from models import ChildProfile, SupportTicket, User
from plan_service import PLAN_FREE, PLAN_PREMIUM
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


def _create_custom_role(db, *, name: str, permissions: list[str]) -> Role:
    role = Role(name=name, description=f"Custom role: {name}")
    db.add(role)
    db.flush()

    for permission_name in permissions:
        permission = db.query(Permission).filter(Permission.name == permission_name).one()
        db.add(RolePermission(role_id=role.id, permission_id=permission.id))

    db.commit()
    db.refresh(role)
    return role


def _create_admin(db, *, email: str, password: str = "AdminPass123!", role_names: list[str] | None = None, role_ids: list[int] | None = None, is_active: bool = True) -> AdminUser:
    admin = AdminUser(
        email=email,
        password_hash=hash_password(password),
        name=email.split("@", 1)[0],
        is_active=is_active,
        token_version=0,
    )
    db.add(admin)
    db.flush()

    role_names = role_names or []
    role_ids = role_ids or []

    for role_name in role_names:
        role = db.query(Role).filter(Role.name == role_name).one()
        db.add(AdminUserRole(admin_user_id=admin.id, role_id=role.id))

    for role_id in role_ids:
        db.add(AdminUserRole(admin_user_id=admin.id, role_id=role_id))

    db.commit()
    db.refresh(admin)
    return admin


def _admin_headers(admin: AdminUser) -> dict[str, str]:
    token = create_admin_access_token(admin.id, admin.token_version)
    return {"Authorization": f"Bearer {token}"}


def _create_parent(db, *, email: str, plan: str = PLAN_FREE, name: str = "Parent User", is_active: bool = True) -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name=name,
        role="parent",
        plan=plan,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_child(db, *, parent_id: int, name: str = "Kid One", age: int = 8) -> ChildProfile:
    child = ChildProfile(
        parent_id=parent_id,
        name=name,
        picture_password=["cat", "dog", "apple"],
        age=age,
        avatar="assets/images/avatars/av1.png",
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


def _create_ticket(db, *, user_id: int, subject: str = "Help needed") -> SupportTicket:
    ticket = SupportTicket(
        user_id=user_id,
        subject=subject,
        message="Original support message",
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return ticket


def test_admin_login_me_refresh_and_logout_flow(client: TestClient, db):
    _seed_builtin_rbac(db)
    admin = _create_admin(db, email="super.admin@kinderworld.app", role_names=["super_admin"])

    login = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert login.status_code == 200
    login_payload = login.json()
    assert login_payload["admin"]["email"] == admin.email
    assert "super_admin" in login_payload["admin"]["roles"]
    assert "admin.admins.manage" in login_payload["admin"]["permissions"]

    me = client.get(
        "/admin/auth/me",
        headers={"Authorization": f"Bearer {login_payload['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["admin"]["email"] == admin.email

    refresh = client.post(
        "/admin/auth/refresh",
        json={"refresh_token": login_payload["refresh_token"]},
    )
    assert refresh.status_code == 200
    assert "access_token" in refresh.json()

    logout = client.post(
        "/admin/auth/logout",
        headers={"Authorization": f"Bearer {login_payload['access_token']}"},
    )
    assert logout.status_code == 200
    assert logout.json()["success"] is True

    refresh_after_logout = client.post(
        "/admin/auth/refresh",
        json={"refresh_token": login_payload["refresh_token"]},
    )
    assert refresh_after_logout.status_code == 401
    assert refresh_after_logout.json()["detail"] == "Refresh token has been revoked"


def test_admin_endpoints_reject_parent_tokens_and_enforce_permissions(client: TestClient, db):
    _seed_builtin_rbac(db)
    parent = _create_parent(db, email="plain.parent@gmail.com")
    parent_token = create_access_token(str(parent.id), parent.token_version)

    wrong_token = client.get(
        "/admin/users",
        headers={"Authorization": f"Bearer {parent_token}"},
    )
    assert wrong_token.status_code == 401
    assert wrong_token.json()["detail"] == "Invalid admin token type"

    manager_role = _create_custom_role(db, name="ticket_viewer", permissions=["admin.support.view"])
    limited_admin = _create_admin(
        db,
        email="limited.admin@kinderworld.app",
        role_ids=[manager_role.id],
    )

    denied = client.get("/admin/users", headers=_admin_headers(limited_admin))
    assert denied.status_code == 403
    assert denied.json()["detail"]["code"] == "PERMISSION_DENIED"

    allowed = client.get("/admin/support/tickets", headers=_admin_headers(limited_admin))
    assert allowed.status_code == 200
    assert allowed.json()["items"] == []


def test_admin_support_ticket_assign_reply_close_and_audit(client: TestClient, db):
    _seed_builtin_rbac(db)
    super_admin = _create_admin(db, email="owner.admin@kinderworld.app", role_names=["super_admin"])
    support_admin = _create_admin(db, email="support.admin@kinderworld.app", role_names=["support_admin"])
    parent = _create_parent(db, email="support.parent@gmail.com", plan=PLAN_PREMIUM)
    ticket = _create_ticket(db, user_id=parent.id)

    assign = client.post(
        f"/admin/support/tickets/{ticket.id}/assign",
        json={"admin_user_id": support_admin.id},
        headers=_admin_headers(super_admin),
    )
    assert assign.status_code == 200
    assert assign.json()["item"]["assigned_admin"]["email"] == support_admin.email
    assert assign.json()["item"]["status"] == "in_progress"

    reply = client.post(
        f"/admin/support/tickets/{ticket.id}/reply",
        json={"message": "We are looking into this now."},
        headers=_admin_headers(super_admin),
    )
    assert reply.status_code == 200
    assert reply.json()["item"]["reply_count"] == 1
    assert reply.json()["item"]["thread"][-1]["author_type"] == "admin"

    close = client.post(
        f"/admin/support/tickets/{ticket.id}/close",
        headers=_admin_headers(super_admin),
    )
    assert close.status_code == 200
    assert close.json()["item"]["status"] == "closed"
    assert close.json()["item"]["closed_at"] is not None

    audit = client.get(
        "/admin/audit-logs",
        params={"entity_type": "support_ticket"},
        headers=_admin_headers(super_admin),
    )
    assert audit.status_code == 200
    actions = [item["action"] for item in audit.json()["items"]]
    assert "support.assign" in actions
    assert "support.reply" in actions
    assert "support.close" in actions


def test_admin_user_management_subscription_and_refund_placeholder(client: TestClient, db):
    _seed_builtin_rbac(db)
    admin = _create_admin(db, email="manager.admin@kinderworld.app", role_names=["super_admin"])
    parent = _create_parent(db, email="managed.parent@gmail.com", plan=PLAN_PREMIUM, name="Managed Parent")

    users_list = client.get("/admin/users", headers=_admin_headers(admin))
    assert users_list.status_code == 200
    assert any(item["email"] == parent.email for item in users_list.json()["items"])

    update_user = client.patch(
        f"/admin/users/{parent.id}",
        json={"name": "Managed Parent Updated", "plan": "family_plus"},
        headers=_admin_headers(admin),
    )
    assert update_user.status_code == 200
    assert update_user.json()["item"]["name"] == "Managed Parent Updated"
    assert update_user.json()["item"]["plan"] == "FAMILY_PLUS"

    disable = client.post(f"/admin/users/{parent.id}/disable", headers=_admin_headers(admin))
    assert disable.status_code == 200
    assert disable.json()["item"]["is_active"] is False

    enable = client.post(f"/admin/users/{parent.id}/enable", headers=_admin_headers(admin))
    assert enable.status_code == 200
    assert enable.json()["item"]["is_active"] is True

    reset_password = client.post(
        f"/admin/users/{parent.id}/reset-password",
        json={"new_password": "ResetPass123!"},
        headers=_admin_headers(admin),
    )
    assert reset_password.status_code == 200
    assert reset_password.json()["temporary_password"] == "ResetPass123!"
    db.refresh(parent)
    assert verify_password("ResetPass123!", parent.password_hash)

    subscription_detail = client.get(
        f"/admin/subscriptions/{parent.id}",
        headers=_admin_headers(admin),
    )
    assert subscription_detail.status_code == 200
    assert subscription_detail.json()["item"]["plan"] == "FAMILY_PLUS"

    override_plan = client.post(
        f"/admin/subscriptions/{parent.id}/override-plan",
        json={"plan": "premium"},
        headers=_admin_headers(admin),
    )
    assert override_plan.status_code == 200
    assert override_plan.json()["item"]["plan"] == PLAN_PREMIUM

    cancel_plan = client.post(
        f"/admin/subscriptions/{parent.id}/cancel",
        headers=_admin_headers(admin),
    )
    assert cancel_plan.status_code == 200
    assert cancel_plan.json()["item"]["plan"] == PLAN_FREE

    refund = client.post(
        f"/admin/subscriptions/{parent.id}/refund",
        headers=_admin_headers(admin),
    )
    assert refund.status_code == 501
    assert "Refunds are not supported" in refund.json()["detail"]


def test_admin_settings_and_child_management_endpoints(client: TestClient, db):
    _seed_builtin_rbac(db)
    admin = _create_admin(db, email="settings.admin@kinderworld.app", role_names=["super_admin"])
    parent = _create_parent(db, email="child.parent@gmail.com")
    child = _create_child(db, parent_id=parent.id, name="Nour", age=9)

    settings = client.get("/admin/settings", headers=_admin_headers(admin))
    assert settings.status_code == 200
    assert settings.json()["effective"]["maintenance_mode"] is False

    update_settings = client.patch(
        "/admin/settings",
        json={"maintenance_mode": True, "ai_buddy_enabled": False},
        headers=_admin_headers(admin),
    )
    assert update_settings.status_code == 200
    assert update_settings.json()["effective"]["maintenance_mode"] is True
    assert update_settings.json()["effective"]["ai_buddy_enabled"] is False

    children = client.get("/admin/children", params={"age": 9}, headers=_admin_headers(admin))
    assert children.status_code == 200
    assert len(children.json()["items"]) == 1
    assert children.json()["items"][0]["name"] == "Nour"

    update_child = client.patch(
        f"/admin/children/{child.id}",
        json={"name": "Nour Updated", "age": 10, "date_of_birth": "2016-01-10"},
        headers=_admin_headers(admin),
    )
    assert update_child.status_code == 200
    assert update_child.json()["item"]["name"] == "Nour Updated"
    assert update_child.json()["item"]["age"] == 10

    progress = client.get(f"/admin/children/{child.id}/progress", headers=_admin_headers(admin))
    assert progress.status_code == 200
    assert progress.json()["summary"]["profile_active"] is True

    activity_log = client.get(f"/admin/children/{child.id}/activity-log", headers=_admin_headers(admin))
    assert activity_log.status_code == 200
    assert isinstance(activity_log.json()["entries"], list)

    deactivate = client.post(
        f"/admin/children/{child.id}/deactivate",
        headers=_admin_headers(admin),
    )
    assert deactivate.status_code == 200
    assert deactivate.json()["item"]["is_active"] is False


def test_last_super_admin_protections_and_self_disable_guard(client: TestClient, db):
    _seed_builtin_rbac(db)
    super_admin = _create_admin(db, email="sole.super@kinderworld.app", role_names=["super_admin"])
    manager_role = _create_custom_role(db, name="admins_manager", permissions=["admin.admins.manage"])
    manager = _create_admin(db, email="manager.only@kinderworld.app", role_ids=[manager_role.id])

    self_disable = client.post(
        f"/admin/admin-users/{super_admin.id}/disable",
        headers=_admin_headers(super_admin),
    )
    assert self_disable.status_code == 400
    assert self_disable.json()["detail"] == "You cannot disable your own admin account"

    disable_last_super_admin = client.post(
        f"/admin/admin-users/{super_admin.id}/disable",
        headers=_admin_headers(manager),
    )
    assert disable_last_super_admin.status_code == 400
    assert "last active super admin" in disable_last_super_admin.json()["detail"]
