from auth import hash_password
from core.time_utils import db_utc_now
from models import ChildProfile, User
from plan_service import PLAN_FREE
from services.child_service import PICTURE_PASSWORD_HASH_SCHEME


def _create_parent(db, email: str = "child.auth.parent@example.com") -> User:
    user = User(
        email=email,
        password_hash=hash_password("Password123!"),
        name="Parent",
        role="parent",
        plan=PLAN_FREE,
        is_active=True,
        email_verified=True,
        created_at=db_utc_now(),
        updated_at=db_utc_now(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_child(
    db,
    *,
    parent_id: int,
    name: str = "Kid",
    picture_password: list[str] | None = None,
) -> ChildProfile:
    import json

    # Create proper bcrypt_json_v1 hashed password
    items = picture_password or ["cat", "dog", "apple"]
    canonical = json.dumps(items, separators=(",", ":"), ensure_ascii=True)
    envelope = {
        "scheme": PICTURE_PASSWORD_HASH_SCHEME,
        "hash": hash_password(canonical),
        "length": len(items),
    }

    child = ChildProfile(
        parent_id=parent_id,
        name=name,
        picture_password=envelope,  # This will be JSON-encoded by the setter
        age=7,
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


def test_child_login_returns_expiring_session_token(client, db):
    parent = _create_parent(db)
    child = _create_child(db, parent_id=parent.id)

    response = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["child_id"] == child.id
    assert "session_token" in body and body["session_token"]
    assert "session_expires_at" in body and body["session_expires_at"]
    assert body["session_ttl_minutes"] >= 5


def test_child_create_and_change_password_store_hashed_picture_password(client, db):
    parent = _create_parent(db, email="child.hash.parent@example.com")
    login = client.post(
        "/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
        },
    )
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    create = client.post(
        "/children",
        json={
            "name": "Hash Kid",
            "picture_password": ["cat", "dog", "apple"],
            "age": 7,
        },
        headers=headers,
    )
    assert create.status_code == 200
    child_id = create.json()["child"]["id"]

    child = db.query(ChildProfile).filter(ChildProfile.id == child_id).one()
    assert isinstance(child.picture_password, dict)
    assert child.picture_password["scheme"] == PICTURE_PASSWORD_HASH_SCHEME
    assert child.picture_password["hash"]

    change = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child_id,
            "name": "Hash Kid",
            "current_picture_password": ["cat", "dog", "apple"],
            "new_picture_password": ["tree", "book", "fish"],
        },
    )
    assert change.status_code == 200

    db.refresh(child)
    assert isinstance(child.picture_password, dict)
    assert child.picture_password["scheme"] == PICTURE_PASSWORD_HASH_SCHEME
    assert child.picture_password["hash"]


def test_child_login_accepts_legacy_raw_picture_password_rows(client, db):
    parent = _create_parent(db, email="child.legacy.parent@example.com")
    child = _create_child(
        db,
        parent_id=parent.id,
        name="Legacy Kid",
        picture_password=["cat", "dog", "apple"],
    )

    response = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )

    assert response.status_code == 200


def test_child_session_validate_and_parent_auth_rejects_child_token(client, db):
    parent = _create_parent(db, email="child.token.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="TokenKid")

    login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-a",
        },
    )
    assert login.status_code == 200
    session_token = login.json()["session_token"]

    validate = client.post(
        "/auth/child/session/validate",
        json={
            "session_token": session_token,
            "device_id": "tablet-a",
        },
    )
    assert validate.status_code == 200
    assert validate.json()["success"] is True
    assert validate.json()["child_id"] == child.id

    parent_only = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {session_token}"},
    )
    assert parent_only.status_code == 401
    assert parent_only.json()["detail"] == "Invalid token type"


def test_child_session_validate_requires_matching_device_for_bound_sessions(client, db):
    parent = _create_parent(db, email="child.validate.device.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="ValidateKid")

    login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-a",
        },
    )
    assert login.status_code == 200
    session_token = login.json()["session_token"]

    missing_device = client.post(
        "/auth/child/session/validate",
        json={
            "session_token": session_token,
        },
    )
    assert missing_device.status_code == 401
    assert missing_device.json()["detail"] == "Device ID is required for this child session"

    wrong_device = client.post(
        "/auth/child/session/validate",
        json={
            "session_token": session_token,
            "device_id": "tablet-b",
        },
    )
    assert wrong_device.status_code == 401
    assert wrong_device.json()["detail"] == "Child session is bound to a different device"


def test_child_login_rate_limit_blocks_repeated_invalid_attempts(client, db, monkeypatch):
    monkeypatch.setenv("CHILD_AUTH_RATE_LIMIT_MAX_ATTEMPTS", "2")
    monkeypatch.setenv("CHILD_AUTH_RATE_LIMIT_WINDOW_SECONDS", "300")

    parent = _create_parent(db, email="child.limit.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="LimitKid")

    for _ in range(2):
        failed = client.post(
            "/auth/child/login",
            json={
                "child_id": child.id,
                "name": child.name,
                "picture_password": ["wrong", "wrong", "wrong"],
            },
        )
        assert failed.status_code == 401

    blocked = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "CHILD_AUTH_RATE_LIMIT_EXCEEDED"


def test_child_device_binding_rejects_unbound_device_when_enabled(client, db, monkeypatch):
    monkeypatch.setenv("CHILD_AUTH_DEVICE_BINDING_ENABLED", "true")
    monkeypatch.setenv("CHILD_AUTH_REQUIRE_DEVICE_ID", "true")

    parent = _create_parent(db, email="child.device.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="DeviceKid")

    first = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-1",
        },
    )
    assert first.status_code == 200

    second = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-2",
        },
    )
    assert second.status_code == 403
    assert second.json()["detail"] == "This child account is bound to a different device"
