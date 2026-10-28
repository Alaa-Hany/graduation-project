from __future__ import annotations

from core.two_factor import generate_totp_code


def test_parent_two_factor_setup_enable_login_and_disable(
    client,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="parent.2fa@example.com", password="Password123!")
    headers = auth_headers(parent)

    status = client.get("/api/v1/auth/2fa/status", headers=headers)
    assert status.status_code == 200
    assert status.json() == {
        "enabled": False,
        "method": None,
        "confirmed_at": None,
    }

    setup = client.post("/api/v1/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    setup_payload = setup.json()
    assert setup_payload["enabled"] is False
    assert setup_payload["method"] == "totp"
    assert setup_payload["secret"]
    assert setup_payload["manual_entry_key"] == setup_payload["secret"]
    assert "otpauth://totp/" in setup_payload["provisioning_uri"]

    code = generate_totp_code(setup_payload["secret"])
    enable = client.post("/api/v1/auth/2fa/enable", json={"code": code}, headers=headers)
    assert enable.status_code == 200
    enable_payload = enable.json()
    assert enable_payload["enabled"] is True
    assert enable_payload["method"] == "totp"
    assert enable_payload["success"] is True

    missing_code = client.post(
        "/api/v1/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert missing_code.status_code == 401
    assert missing_code.json()["detail"] == {
        "code": "PARENT_TWO_FACTOR_REQUIRED",
        "message": "Two-factor authentication code is required",
        "two_factor_method": "totp",
    }

    bad_code = client.post(
        "/api/v1/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
            "two_factor_code": "000000",
        },
    )
    assert bad_code.status_code == 401
    assert bad_code.json()["detail"]["code"] == "PARENT_INVALID_TWO_FACTOR_CODE"

    login = client.post(
        "/api/v1/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
            "two_factor_code": generate_totp_code(setup_payload["secret"]),
        },
    )
    assert login.status_code == 200
    assert login.json()["user"]["two_factor_enabled"] is True
    assert login.json()["user"]["two_factor_method"] == "totp"

    disable = client.post(
        "/api/v1/auth/2fa/disable",
        json={"code": generate_totp_code(setup_payload["secret"])},
        headers=headers,
    )
    assert disable.status_code == 200
    assert disable.json()["enabled"] is False
    assert disable.json()["success"] is True

    login_without_code = client.post(
        "/api/v1/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert login_without_code.status_code == 200


def _enable_parent_two_factor(client, headers) -> str:
    setup = client.post("/api/v1/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    secret = setup.json()["secret"]
    enable = client.post(
        "/api/v1/auth/2fa/enable", json={"code": generate_totp_code(secret)}, headers=headers
    )
    assert enable.status_code == 200
    return secret


def _two_factor_enabled(client, headers) -> bool:
    return client.get("/api/v1/auth/2fa/status", headers=headers).json()["enabled"]


def test_parent_two_factor_disable_requires_a_code(client, create_parent, auth_headers):
    # Regression: /auth/2fa/disable used to switch 2FA off with no proof, so a
    # stolen access token was enough to strip 2FA from the account.
    headers = auth_headers(create_parent(email="parent.2fa.nocode@example.com"))
    _enable_parent_two_factor(client, headers)

    no_body = client.post("/api/v1/auth/2fa/disable", headers=headers)
    assert no_body.status_code == 422

    blank = client.post("/api/v1/auth/2fa/disable", json={"code": "  "}, headers=headers)
    assert blank.status_code == 422

    assert _two_factor_enabled(client, headers) is True


def test_parent_two_factor_disable_rejects_wrong_code(client, create_parent, auth_headers):
    headers = auth_headers(create_parent(email="parent.2fa.wrong@example.com"))
    secret = _enable_parent_two_factor(client, headers)
    wrong = "000000" if generate_totp_code(secret) != "000000" else "111111"

    response = client.post("/api/v1/auth/2fa/disable", json={"code": wrong}, headers=headers)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "INVALID_TWO_FACTOR_CODE"
    assert _two_factor_enabled(client, headers) is True


def test_parent_two_factor_disable_when_not_enabled(client, create_parent, auth_headers):
    headers = auth_headers(create_parent(email="parent.2fa.off@example.com"))

    response = client.post("/api/v1/auth/2fa/disable", json={"code": "123456"}, headers=headers)

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "TWO_FACTOR_NOT_ENABLED"


def test_parent_two_factor_disable_is_rate_limited(client, create_parent, auth_headers):
    headers = auth_headers(create_parent(email="parent.2fa.limit@example.com"))
    # two_factor_rate_limit is keyed per user + path, so disable has its own
    # 5-per-5-minutes bucket, separate from enable.
    secret = _enable_parent_two_factor(client, headers)
    wrong = "000000" if generate_totp_code(secret) != "000000" else "111111"

    statuses = [
        client.post("/api/v1/auth/2fa/disable", json={"code": wrong}, headers=headers).status_code
        for _ in range(6)
    ]

    assert statuses[:5] == [422] * 5
    assert statuses[5] == 429
    # Even the right code is refused while the limit is active.
    blocked = client.post(
        "/api/v1/auth/2fa/disable",
        json={"code": generate_totp_code(secret)},
        headers=headers,
    )
    assert blocked.status_code == 429
    assert _two_factor_enabled(client, headers) is True


def test_admin_two_factor_setup_enable_login_and_disable(
    client,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="admin.2fa@example.com", role_names=["super_admin"])
    headers = admin_headers(admin)

    status = client.get("/api/v1/admin/auth/2fa/status", headers=headers)
    assert status.status_code == 200
    assert status.json() == {
        "enabled": False,
        "method": None,
        "confirmed_at": None,
    }

    setup = client.post("/api/v1/admin/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    setup_payload = setup.json()
    assert setup_payload["method"] == "totp"
    assert setup_payload["secret"]

    enable = client.post(
        "/api/v1/admin/auth/2fa/enable",
        json={"code": generate_totp_code(setup_payload["secret"])},
        headers=headers,
    )
    assert enable.status_code == 200
    assert enable.json()["enabled"] is True

    missing_code = client.post(
        "/api/v1/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert missing_code.status_code == 401
    assert missing_code.json()["detail"] == {
        "code": "ADMIN_TWO_FACTOR_REQUIRED",
        "message": "Two-factor authentication code is required",
        "two_factor_method": "totp",
    }

    login = client.post(
        "/api/v1/admin/auth/login",
        json={
            "email": admin.email,
            "password": "AdminPass123!",
            "two_factor_code": generate_totp_code(setup_payload["secret"]),
        },
    )
    assert login.status_code == 200
    assert login.json()["admin"]["two_factor_enabled"] is True
    assert login.json()["admin"]["two_factor_method"] == "totp"

    disable = client.post("/api/v1/admin/auth/2fa/disable", headers=headers)
    assert disable.status_code == 200
    assert disable.json()["enabled"] is False


def test_parent_two_factor_enable_requires_setup(client, create_parent, auth_headers):
    parent = create_parent(email="parent.2fa.missing@example.com")

    response = client.post(
        "/api/v1/auth/2fa/enable",
        json={"code": "123456"},
        headers=auth_headers(parent),
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "TWO_FACTOR_SETUP_REQUIRED"
