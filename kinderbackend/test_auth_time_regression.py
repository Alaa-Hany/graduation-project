from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException, Request

from auth import decode_token, hash_password
from core.time_utils import utc_now
from models import ChildProfile, User
from schemas.auth import ChildSessionValidateIn
from services.admin_auth_service import AdminAuthService
from services.auth_service import AuthService
from services.child_service import ChildService


def _request() -> Request:
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/admin/auth/login",
            "headers": [],
            "client": ("127.0.0.1", 12345),
            "scheme": "http",
            "server": ("testserver", 80),
        }
    )


@pytest.mark.parametrize(
    "locked_until",
    [
        datetime(2030, 1, 1, 0, 0, 0),
        datetime(2030, 1, 1, 0, 0, 0, tzinfo=UTC),
    ],
)
def test_parent_pin_lockout_comparison_accepts_naive_and_aware_timestamps(
    locked_until: datetime,
) -> None:
    service = AuthService()
    user = SimpleNamespace(parent_pin_locked_until=locked_until)

    assert service._is_parent_pin_locked(user) is True
    assert service._locked_until_iso(user) == "2030-01-01T00:00:00+00:00"


@pytest.mark.parametrize(
    "locked_until",
    [
        datetime(2030, 1, 1, 0, 0, 0),
        datetime(2030, 1, 1, 0, 0, 0, tzinfo=UTC),
    ],
)
def test_admin_login_lockout_accepts_naive_and_aware_timestamps(
    locked_until: datetime,
) -> None:
    admin = SimpleNamespace(
        id=7,
        email=f"locked-{locked_until.tzinfo is None}@example.com",
        password_hash=hash_password("AdminPass123!"),
        locked_until=locked_until,
        failed_login_attempts=5,
    )

    class _FakeQuery:
        def filter(self, *args, **kwargs):
            return self

        def first(self):
            return admin

    class _FakeDb:
        def query(self, *_args, **_kwargs):
            return _FakeQuery()

        def add(self, _value) -> None:
            return None

        def flush(self) -> None:
            return None

        def commit(self) -> None:
            return None

    service = AdminAuthService()
    payload = SimpleNamespace(email=admin.email, password="AdminPass123!")

    with pytest.raises(HTTPException) as exc_info:
        service.login(payload=payload, request=_request(), db=_FakeDb())

    assert exc_info.value.status_code == 423
    assert exc_info.value.detail["code"] == "ADMIN_TEMP_LOCKED"
    assert exc_info.value.detail["locked_until"] == "2030-01-01T00:00:00+00:00"


def test_build_child_session_uses_utc_now_and_env_ttl_deterministically(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixed_now = datetime(2026, 3, 15, 12, 0, 0, tzinfo=UTC)
    child = SimpleNamespace(id=7, name="Kid")
    service = ChildService()

    monkeypatch.setenv("CHILD_SESSION_TTL_MINUTES", "45")
    monkeypatch.setattr("services.child_service.utc_now", lambda: fixed_now)

    session_payload = service._build_child_session(child=child, device_id="tablet-1")
    claims = decode_token(session_payload["session_token"])

    assert session_payload["session_ttl_minutes"] == 45
    assert session_payload["session_expires_at"] == "2026-03-15T12:45:00+00:00"
    assert claims["token_type"] == "child_session"
    assert claims["child_id"] == 7
    assert claims["child_name"] == "Kid"
    assert claims["device_id"] == "tablet-1"


def test_validate_child_session_returns_expiry_as_utc_iso(db) -> None:
    parent = User(
        email="child.session.parent@example.com",
        password_hash=hash_password("Password123!"),
        role="parent",
        is_active=True,
        plan="FREE",
    )
    db.add(parent)
    db.flush()

    child = ChildProfile(
        parent_id=parent.id,
        name="Kid",
        picture_password=["cat", "dog", "apple"],
        age=7,
    )
    db.add(child)
    db.commit()
    db.refresh(child)

    service = ChildService()
    session_payload = service._build_child_session(child=child, device_id=None)

    response = service.validate_child_session(
        payload=ChildSessionValidateIn(session_token=session_payload["session_token"]),
        db=db,
    )

    assert response["success"] is True
    assert response["child_id"] == child.id
    assert response["session_expires_at"].endswith("+00:00")
    assert datetime.fromisoformat(response["session_expires_at"]) > utc_now()
