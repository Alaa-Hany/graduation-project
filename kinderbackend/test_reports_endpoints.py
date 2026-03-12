from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

import admin_models  # noqa: F401
import pytest

from auth import create_access_token, hash_password
from database import Base, SessionLocal
from main import app
from models import ChildProfile, Notification, PaymentMethod, SupportTicket, User
from plan_service import PLAN_FREE, PLAN_PREMIUM


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


def _create_parent(db, *, email: str, plan: str) -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name="Report Parent",
        role="parent",
        is_active=True,
        plan=plan,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _headers(user: User) -> dict[str, str]:
    token = create_access_token(str(user.id), getattr(user, "token_version", 0))
    return {"Authorization": f"Bearer {token}"}


def test_basic_reports_returns_dynamic_parent_summary(client: TestClient, db):
    parent = _create_parent(db, email="reports-basic@example.com", plan=PLAN_FREE)
    db.add_all(
        [
            ChildProfile(
                parent_id=parent.id,
                name="Dana",
                picture_password=["cat", "dog", "apple"],
                age=7,
                avatar="av1",
                is_active=True,
            ),
            ChildProfile(
                parent_id=parent.id,
                name="Lina",
                picture_password=["sun", "moon", "star"],
                age=9,
                avatar="av2",
                is_active=False,
            ),
            Notification(
                user_id=parent.id,
                type="SYSTEM",
                title="Unread",
                body="Unread body",
                is_read=False,
            ),
            SupportTicket(
                user_id=parent.id,
                subject="Need help",
                message="Testing report summary",
                status="open",
            ),
            PaymentMethod(
                user_id=parent.id,
                label="Visa ending 1111",
            ),
        ]
    )
    db.commit()

    response = client.get("/reports/basic", headers=_headers(parent))

    assert response.status_code == 200
    payload = response.json()
    assert payload["access_level"] == "basic"
    assert payload["data_source"] == "backend_child_profiles"
    assert payload["summary"]["child_count"] == 2
    assert payload["summary"]["active_child_count"] == 1
    assert payload["summary"]["unread_notifications"] == 1
    assert payload["summary"]["open_support_tickets"] == 1
    assert payload["summary"]["payment_methods_count"] == 1
    assert len(payload["children"]) == 2
    assert payload["data_availability"]["screen_time"] is False


def test_advanced_reports_returns_dynamic_profile_metadata(client: TestClient, db):
    parent = _create_parent(db, email="reports-advanced@example.com", plan=PLAN_PREMIUM)
    db.add_all(
        [
            ChildProfile(
                parent_id=parent.id,
                name="Adam",
                picture_password=["cat", "dog", "apple"],
                age=5,
                avatar="av1",
                is_active=True,
            ),
            ChildProfile(
                parent_id=parent.id,
                name="Sara",
                picture_password=["sun", "moon", "star"],
                age=10,
                avatar="av2",
                is_active=True,
            ),
        ]
    )
    db.commit()

    response = client.get("/reports/advanced", headers=_headers(parent))

    assert response.status_code == 200
    payload = response.json()
    assert payload["access_level"] == "advanced"
    reports = payload["reports"]
    assert reports["account_summary"]["child_count"] == 2
    assert reports["age_distribution"]["5_6"] == 1
    assert reports["age_distribution"]["10_12"] == 1
    assert reports["comparison"]["status"] == "not_available"
    assert "not yet synced" in reports["insight_notes"][0]
