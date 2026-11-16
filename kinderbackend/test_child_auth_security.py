from datetime import date

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
        date_of_birth=date(date.today().year - 7, 1, 1),
    )
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


def test_child_login_wrong_name_and_wrong_pictures_are_indistinguishable(client, db):
    """A right name with wrong pictures must look exactly like a wrong name,
    so the response can't be used to confirm a child's name before guessing
    the picture password."""
    parent = _create_parent(db, email="child.codes.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="CodeKid")

    wrong_name = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": "NotCodeKid",
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    wrong_pictures = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["wrong", "wrong", "wrong"],
        },
    )

    assert wrong_name.status_code == wrong_pictures.status_code == 401
    assert wrong_name.json()["detail"] == wrong_pictures.json()["detail"]
    assert wrong_pictures.json()["detail"]["code"] == "CHILD_INVALID_CREDENTIALS"


def test_child_login_failure_counter_is_per_child_across_ips(client, db, monkeypatch):
    """Rotating IPs must not reset the guess budget for one child."""
    from core.settings import settings

    monkeypatch.setenv("CHILD_AUTH_RATE_LIMIT_MAX_ATTEMPTS", "3")
    monkeypatch.setenv("CHILD_AUTH_RATE_LIMIT_WINDOW_SECONDS", "300")
    original = settings.trust_cf_connecting_ip
    object.__setattr__(settings, "trust_cf_connecting_ip", True)
    try:
        parent = _create_parent(db, email="child.rotate.parent@example.com")
        child = _create_child(db, parent_id=parent.id, name="RotateKid")
        other = _create_child(db, parent_id=parent.id, name="OtherKid")

        for i in range(3):
            failed = client.post(
                "/api/v1/auth/child/login",
                json={
                    "child_id": child.id,
                    "name": child.name,
                    "picture_password": ["wrong", "wrong", "wrong"],
                },
                headers={"CF-Connecting-IP": f"198.51.100.{i + 1}"},
            )
            assert failed.status_code == 401

        # A brand-new IP with the correct pictures is still blocked.
        blocked = client.post(
            "/api/v1/auth/child/login",
            json={
                "child_id": child.id,
                "name": child.name,
                "picture_password": ["cat", "dog", "apple"],
            },
            headers={"CF-Connecting-IP": "203.0.113.77"},
        )
        assert blocked.status_code == 429
        assert blocked.json()["detail"]["code"] == "CHILD_AUTH_RATE_LIMIT_EXCEEDED"

        # Normal use: a different child is not affected by that lockout.
        ok = client.post(
            "/api/v1/auth/child/login",
            json={
                "child_id": other.id,
                "name": other.name,
                "picture_password": ["cat", "dog", "apple"],
            },
            headers={"CF-Connecting-IP": "198.51.100.1"},
        )
        assert ok.status_code == 200
    finally:
        object.__setattr__(settings, "trust_cf_connecting_ip", original)


def _parent_headers(client, email: str) -> dict[str, str]:
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "Password123!"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def test_child_change_password_requires_parent_token(client, db):
    parent = _create_parent(db, email="child.change.noauth.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="NoAuthKid")
    body = {
        "child_id": child.id,
        "name": child.name,
        "current_picture_password": ["cat", "dog", "apple"],
        "new_picture_password": ["tree", "book", "fish"],
    }

    anonymous = client.post("/api/v1/auth/child/change-password", json=body)
    assert anonymous.status_code == 401

    child_login = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    child_token = child_login.json()["session_token"]
    with_child_token = client.post(
        "/api/v1/auth/child/change-password",
        json=body,
        headers={"Authorization": f"Bearer {child_token}"},
    )
    assert with_child_token.status_code == 401

    stranger = _create_parent(db, email="child.change.stranger@example.com")
    other_family = client.post(
        "/api/v1/auth/child/change-password",
        json=body,
        headers=_parent_headers(client, stranger.email),
    )
    assert other_family.status_code == 404

    # The password is unchanged after all three rejected attempts.
    still_ok = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert still_ok.status_code == 200


def test_child_login_unknown_id_is_indistinguishable_from_wrong_name(client, db):
    parent = _create_parent(db, email="child.enum.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="EnumKid")
    body = {"name": "Guess", "picture_password": ["cat", "dog", "apple"]}

    unknown = client.post("/api/v1/auth/child/login", json={"child_id": 999999, **body})
    wrong_name = client.post("/api/v1/auth/child/login", json={"child_id": child.id, **body})

    assert unknown.status_code == wrong_name.status_code == 401
    assert unknown.json()["detail"] == wrong_name.json()["detail"]
    assert unknown.json()["detail"]["message"] == "Invalid credentials"
    assert unknown.json()["error"] == wrong_name.json()["error"]


def test_child_login_returns_expiring_session_token(client, db):
    parent = _create_parent(db)
    child = _create_child(db, parent_id=parent.id)

    response = client.post(
        "/api/v1/auth/child/login",
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
        "/api/v1/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
        },
    )
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    create = client.post(
        "/api/v1/children",
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
        "/api/v1/auth/child/change-password",
        json={
            "child_id": child_id,
            "name": "Hash Kid",
            "current_picture_password": ["cat", "dog", "apple"],
            "new_picture_password": ["tree", "book", "fish"],
        },
        headers=headers,
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
        "/api/v1/auth/child/login",
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
        "/api/v1/auth/child/login",
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
        "/api/v1/auth/child/session/validate",
        json={
            "session_token": session_token,
            "device_id": "tablet-a",
        },
    )
    assert validate.status_code == 200
    assert validate.json()["success"] is True
    assert validate.json()["child_id"] == child.id

    parent_only = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {session_token}"},
    )
    assert parent_only.status_code == 401
    assert parent_only.json()["detail"] == "Invalid token type"


def test_child_session_validate_requires_matching_device_for_bound_sessions(client, db):
    parent = _create_parent(db, email="child.validate.device.parent@example.com")
    child = _create_child(db, parent_id=parent.id, name="ValidateKid")

    login = client.post(
        "/api/v1/auth/child/login",
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
        "/api/v1/auth/child/session/validate",
        json={
            "session_token": session_token,
        },
    )
    assert missing_device.status_code == 401
    assert missing_device.json()["detail"] == "Device ID is required for this child session"

    wrong_device = client.post(
        "/api/v1/auth/child/session/validate",
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
            "/api/v1/auth/child/login",
            json={
                "child_id": child.id,
                "name": child.name,
                "picture_password": ["wrong", "wrong", "wrong"],
            },
        )
        assert failed.status_code == 401

    blocked = client.post(
        "/api/v1/auth/child/login",
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
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-1",
        },
    )
    assert first.status_code == 200

    second = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-2",
        },
    )
    assert second.status_code == 403
    assert second.json()["detail"] == "This child account is bound to a different device"
