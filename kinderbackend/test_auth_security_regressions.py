from __future__ import annotations


def _assert_validation_payload_is_safe(response_json: dict) -> None:
    detail = response_json["detail"]
    assert isinstance(detail, list)
    assert detail
    for error in detail:
        assert isinstance(error, dict)
        ctx = error.get("ctx")
        if isinstance(ctx, dict) and "error" in ctx:
            assert isinstance(ctx["error"], str)


def test_access_token_is_revoked_after_logout(client, create_parent, auth_headers):
    parent = create_parent(email="logout.revoke.parent@example.com")
    headers = auth_headers(parent)

    before_logout = client.get("/auth/me", headers=headers)
    assert before_logout.status_code == 200

    logout = client.post("/auth/logout", headers=headers)
    assert logout.status_code == 200
    assert logout.json()["success"] is True

    after_logout = client.get("/auth/me", headers=headers)
    assert after_logout.status_code == 401
    assert after_logout.json()["detail"] == "Token has been revoked"


def test_access_token_is_revoked_after_change_password(client):
    register = client.post(
        "/auth/register",
        json={
            "name": "Password Rotate",
            "email": "password.rotate@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )
    assert register.status_code == 200
    access_token = register.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    me_before_change = client.get("/auth/me", headers=headers)
    assert me_before_change.status_code == 200

    change = client.post(
        "/auth/change-password",
        json={
            "current_password": "Password123!",
            "new_password": "NewPassword123!",
            "confirm_password": "NewPassword123!",
        },
        headers=headers,
    )
    assert change.status_code == 200

    me_after_change = client.get("/auth/me", headers=headers)
    assert me_after_change.status_code == 401
    assert me_after_change.json()["detail"] == "Token has been revoked"

    login_again = client.post(
        "/auth/login",
        json={
            "email": "password.rotate@example.com",
            "password": "NewPassword123!",
        },
    )
    assert login_again.status_code == 200

    fresh_me = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {login_again.json()['access_token']}"},
    )
    assert fresh_me.status_code == 200


def test_register_validation_returns_422_instead_of_500_for_trimmed_blank_value(client):
    response = client.post(
        "/auth/register",
        json={
            "name": "Validation Parent",
            "email": "validation.parent@example.com",
            "password": "Password123!",
            "confirm_password": "   ",
        },
    )

    assert response.status_code == 422
    payload = response.json()
    _assert_validation_payload_is_safe(payload)
    assert any(
        error["msg"] == "Value error, value must not be blank" for error in payload["detail"]
    )


def test_child_register_validation_returns_safe_json_errors(client):
    response = client.post(
        "/auth/child/register",
        json={
            "name": "Validation Kid",
            "parent_email": "parent@example.com",
            "age": 8,
            "picture_password": ["cat", " ", "apple"],
        },
    )

    assert response.status_code == 422
    payload = response.json()
    _assert_validation_payload_is_safe(payload)
    assert any(
        error["msg"] == "Value error, picture_password entries must be non-empty strings"
        for error in payload["detail"]
    )
