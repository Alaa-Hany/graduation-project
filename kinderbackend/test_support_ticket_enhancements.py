from __future__ import annotations

import admin_models  # noqa: F401
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
import pytest

from admin_auth import create_admin_access_token
from admin_models import AdminUser, AdminUserRole, Permission, Role, RolePermission
from auth import create_access_token, hash_password
from database import Base, SessionLocal
from main import app
from models import SupportTicket, SupportTicketMessage, User
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


def _create_parent(db, *, email: str, name: str = "Parent User") -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name=name,
        role="parent",
        is_active=True,
        plan="FREE",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_admin(db, *, email: str, role_names: list[str]) -> AdminUser:
    admin = AdminUser(
        email=email,
        password_hash=hash_password("AdminPass123!"),
        name=email.split("@", 1)[0],
        is_active=True,
        token_version=0,
    )
    db.add(admin)
    db.flush()
    for role_name in role_names:
        role = db.query(Role).filter(Role.name == role_name).one()
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


def test_parent_support_ticket_creation_history_detail_and_reply(client: TestClient, db):
    parent = _create_parent(db, email="parent.support@gmail.com")
    headers = _parent_headers(parent)

    create = client.post(
        "/support/contact",
        json={
            "subject": "Billing question",
            "message": "I need help understanding my current plan billing.",
            "category": "billing_issue",
        },
        headers=headers,
    )
    assert create.status_code == 200
    created_ticket = create.json()["item"]
    assert created_ticket["category"] == "billing_issue"
    assert created_ticket["status"] == "open"
    assert len(created_ticket["thread"]) == 1

    history = client.get("/support/tickets", headers=headers)
    assert history.status_code == 200
    assert history.json()["summary"]["total"] == 1
    assert history.json()["items"][0]["category"] == "billing_issue"

    detail = client.get(f"/support/tickets/{created_ticket['id']}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["item"]["thread"][0]["author_type"] == "user"

    reply = client.post(
        f"/support/tickets/{created_ticket['id']}/reply",
        json={"message": "I still need an invoice copy."},
        headers=headers,
    )
    assert reply.status_code == 200
    assert reply.json()["item"]["reply_count"] == 1
    assert reply.json()["item"]["thread"][-1]["author_type"] == "user"

    stored = db.query(SupportTicketMessage).filter(SupportTicketMessage.ticket_id == created_ticket["id"]).one()
    assert stored.user_id == parent.id


def test_parent_support_validation_and_cross_user_access(client: TestClient, db):
    owner = _create_parent(db, email="owner@gmail.com")
    other = _create_parent(db, email="other@gmail.com")

    invalid_category = client.post(
        "/support/contact",
        json={
            "subject": "Need help",
            "message": "This is a valid support message body.",
            "category": "unknown_issue",
        },
        headers=_parent_headers(owner),
    )
    assert invalid_category.status_code == 422
    assert invalid_category.json()["detail"]["code"] == "INVALID_SUPPORT_CATEGORY"

    short_message = client.post(
        "/support/contact",
        json={
            "subject": "Hi",
            "message": "short",
            "category": "technical_issue",
        },
        headers=_parent_headers(owner),
    )
    assert short_message.status_code == 422
    assert short_message.json()["detail"]["code"] == "SUBJECT_TOO_SHORT"

    ticket = SupportTicket(
        user_id=owner.id,
        subject="Login problem",
        message="I cannot access my account after password reset.",
        category="login_issue",
        email=owner.email,
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    forbidden_detail = client.get(f"/support/tickets/{ticket.id}", headers=_parent_headers(other))
    assert forbidden_detail.status_code == 404

    closed_ticket = SupportTicket(
        user_id=owner.id,
        subject="Already closed",
        message="This ticket is already closed by the team.",
        category="general_inquiry",
        email=owner.email,
        status="closed",
    )
    db.add(closed_ticket)
    db.commit()
    db.refresh(closed_ticket)

    reply_closed = client.post(
        f"/support/tickets/{closed_ticket.id}/reply",
        json={"message": "Please reopen this ticket."},
        headers=_parent_headers(owner),
    )
    assert reply_closed.status_code == 400
    assert reply_closed.json()["detail"]["code"] == "TICKET_CLOSED"


def test_admin_support_filters_resolve_and_closed_reply_guard(client: TestClient, db):
    _seed_builtin_rbac(db)
    admin = _create_admin(db, email="support.admin@gmail.com", role_names=["super_admin"])
    parent = _create_parent(db, email="ticket.parent@gmail.com")

    billing_ticket = SupportTicket(
        user_id=parent.id,
        subject="Billing issue",
        message="I was charged twice for the same subscription.",
        category="billing_issue",
        email=parent.email,
        status="open",
    )
    technical_ticket = SupportTicket(
        user_id=parent.id,
        subject="Technical issue",
        message="The app freezes every time I open the reports screen.",
        category="technical_issue",
        email=parent.email,
        status="in_progress",
    )
    db.add(billing_ticket)
    db.add(technical_ticket)
    db.commit()
    db.refresh(billing_ticket)
    db.refresh(technical_ticket)

    filtered = client.get(
        "/admin/support/tickets",
        params={"status": "open", "category": "billing_issue"},
        headers=_admin_headers(admin),
    )
    assert filtered.status_code == 200
    assert len(filtered.json()["items"]) == 1
    assert filtered.json()["items"][0]["category"] == "billing_issue"

    resolve = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/resolve",
        headers=_admin_headers(admin),
    )
    assert resolve.status_code == 200
    assert resolve.json()["item"]["status"] == "resolved"

    parent_reply = client.post(
        f"/support/tickets/{technical_ticket.id}/reply",
        json={"message": "The reports issue still happens on my phone."},
        headers=_parent_headers(parent),
    )
    assert parent_reply.status_code == 200
    assert parent_reply.json()["item"]["status"] == "open"

    close = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/close",
        headers=_admin_headers(admin),
    )
    assert close.status_code == 200
    assert close.json()["item"]["status"] == "closed"

    reply_closed = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/reply",
        json={"message": "This should not be sent"},
        headers=_admin_headers(admin),
    )
    assert reply_closed.status_code == 400
    assert reply_closed.json()["detail"] == "Closed tickets cannot receive replies"

    invalid_filter = client.get(
        "/admin/support/tickets",
        params={"category": "bad_filter"},
        headers=_admin_headers(admin),
    )
    assert invalid_filter.status_code == 422
