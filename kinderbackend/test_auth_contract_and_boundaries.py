import pytest
from pydantic import ValidationError

from auth import create_refresh_token


def test_public_login_rate_limit_blocks_sixth_attempt(client, create_parent):
    create_parent(email="rate.limit.parent@example.com", password="Password123!")

    payload = {
        "email": "rate.limit.parent@example.com",
        "password": "WrongPassword123!",
    }

    for _ in range(5):
        response = client.post("/auth/login", json=payload)
        assert response.status_code == 401

    blocked = client.post("/auth/login", json=payload)
    assert blocked.status_code == 429
    detail = blocked.json()["detail"]
    assert detail["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.headers["Retry-After"] == "300"


def test_register_accepts_snake_case_confirm_password(client):
    response = client.post(
        "/auth/register",
        json={
            "name": "Snake Parent",
            "email": "snake.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "snake.parent@example.com"
    assert body["access_token"]
    assert body["refresh_token"]


def test_register_schema_rejects_blank_confirm_password_after_trim():
    from schemas.auth import RegisterIn

    with pytest.raises(ValidationError) as exc_info:
        RegisterIn.model_validate(
            {
                "name": "Blank Confirm",
                "email": "blank.confirm@example.com",
                "password": "Password123!",
                "confirm_password": "   ",
            }
        )

    errors = exc_info.value.errors()
    assert any(error["msg"] == "Value error, value must not be blank" for error in errors)


def test_change_password_revokes_existing_refresh_token(client):
    register = client.post(
        "/auth/register",
        json={
            "name": "Refresh Parent",
            "email": "refresh.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )
    assert register.status_code == 200
    register_body = register.json()

    change = client.post(
        "/auth/change-password",
        json={
            "current_password": "Password123!",
            "new_password": "NewPassword123!",
            "confirm_password": "NewPassword123!",
        },
        headers={"Authorization": f"Bearer {register_body['access_token']}"},
    )
    assert change.status_code == 200

    refresh = client.post(
        "/auth/refresh",
        json={"refresh_token": register_body["refresh_token"]},
    )
    assert refresh.status_code == 401
    assert refresh.json()["detail"] == "Invalid refresh token"


def test_auth_me_rejects_admin_token(
    client,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="boundary.admin@example.com", role_names=["super_admin"])

    response = client.get("/auth/me", headers=admin_headers(admin))
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid token type"


def test_children_endpoints_reject_child_session_token(client, create_parent, create_child):
    parent = create_parent(email="child.boundary.parent@example.com")
    child = create_child(parent_id=parent.id, name="Boundary Kid")

    login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert login.status_code == 200

    token = login.json()["session_token"]
    response = client.get("/children", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid token type"


def test_child_change_password_accepts_camelcase_aliases(client, create_parent, create_child):
    parent = create_parent(email="child.alias.parent@example.com")
    child = create_child(parent_id=parent.id, name="Alias Kid")

    change = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child.id,
            "name": child.name,
            "currentPicturePassword": ["cat", "dog", "apple"],
            "newPicturePassword": ["tree", "book", "fish"],
        },
    )
    assert change.status_code == 200
    assert change.json()["success"] is True

    old_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
        },
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["tree", "book", "fish"],
        },
    )
    assert new_login.status_code == 200


def test_child_register_schema_rejects_blank_picture_password_entries():
    from schemas.auth import ChildRegisterIn

    with pytest.raises(ValidationError) as exc_info:
        ChildRegisterIn.model_validate(
            {
                "name": "Validation Kid",
                "picture_password": ["cat", " ", "apple"],
                "parent_email": "child.validation.parent@example.com",
                "age": 8,
            }
        )

    errors = exc_info.value.errors()
    assert any(
        error["msg"] == "Value error, picture_password entries must be non-empty strings"
        for error in errors
    )


def test_admin_logout_revokes_existing_access_token(
    client, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="logout.admin@example.com", role_names=["super_admin"])
    headers = admin_headers(admin)

    logout = client.post("/admin/auth/logout", headers=headers)
    assert logout.status_code == 200
    assert logout.json()["success"] is True

    me = client.get("/admin/auth/me", headers=headers)
    assert me.status_code == 401
    assert me.json()["detail"] == "Admin token has been revoked"


def test_admin_refresh_rejects_parent_refresh_token(client, create_parent):
    parent = create_parent(email="wrong.refresh.parent@example.com")
    parent_refresh_token = create_refresh_token(str(parent.id), getattr(parent, "token_version", 0))

    response = client.post(
        "/admin/auth/refresh",
        json={"refresh_token": parent_refresh_token},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid refresh token type"
