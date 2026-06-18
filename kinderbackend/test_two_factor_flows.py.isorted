from __future__ import annotations

from core.two_factor import generate_totp_code


def test_parent_two_factor_setup_enable_login_and_disable(
    client,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="parent.2fa@example.com", password="Password123!")
    headers = auth_headers(parent)

    status = client.get("/auth/2fa/status", headers=headers)
    assert status.status_code == 200
    assert status.json() == {
        "enabled": False,
        "method": None,
        "confirmed_at": None,
    }

    setup = client.post("/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    setup_payload = setup.json()
    assert setup_payload["enabled"] is False
    assert setup_payload["method"] == "totp"
    assert setup_payload["secret"]
    assert setup_payload["manual_entry_key"] == setup_payload["secret"]
    assert "otpauth://totp/" in setup_payload["provisioning_uri"]

    code = generate_totp_code(setup_payload["secret"])
    enable = client.post("/auth/2fa/enable", json={"code": code}, headers=headers)
    assert enable.status_code == 200
    enable_payload = enable.json()
    assert enable_payload["enabled"] is True
    assert enable_payload["method"] == "totp"
    assert enable_payload["success"] is True

    missing_code = client.post(
        "/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert missing_code.status_code == 401
    assert missing_code.json()["detail"] == {
        "code": "PARENT_TWO_FACTOR_REQUIRED",
        "message": "Two-factor authentication code is required",
        "two_factor_method": "totp",
    }

    bad_code = client.post(
        "/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
            "two_factor_code": "000000",
        },
    )
    assert bad_code.status_code == 401
    assert bad_code.json()["detail"]["code"] == "PARENT_INVALID_TWO_FACTOR_CODE"

    login = client.post(
        "/auth/login",
        json={
            "email": parent.email,
            "password": "Password123!",
            "two_factor_code": generate_totp_code(setup_payload["secret"]),
        },
    )
    assert login.status_code == 200
    assert login.json()["user"]["two_factor_enabled"] is True
    assert login.json()["user"]["two_factor_method"] == "totp"

    disable = client.post("/auth/2fa/disable", headers=headers)
    assert disable.status_code == 200
    assert disable.json()["enabled"] is False
    assert disable.json()["success"] is True

    login_without_code = client.post(
        "/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert login_without_code.status_code == 200


def test_admin_two_factor_setup_enable_login_and_disable(
    client,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="admin.2fa@example.com", role_names=["super_admin"])
    headers = admin_headers(admin)

    status = client.get("/admin/auth/2fa/status", headers=headers)
    assert status.status_code == 200
    assert status.json() == {
        "enabled": False,
        "method": None,
        "confirmed_at": None,
    }

    setup = client.post("/admin/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    setup_payload = setup.json()
    assert setup_payload["method"] == "totp"
    assert setup_payload["secret"]

    enable = client.post(
        "/admin/auth/2fa/enable",
        json={"code": generate_totp_code(setup_payload["secret"])},
        headers=headers,
    )
    assert enable.status_code == 200
    assert enable.json()["enabled"] is True

    missing_code = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert missing_code.status_code == 401
    assert missing_code.json()["detail"] == {
        "code": "ADMIN_TWO_FACTOR_REQUIRED",
        "message": "Two-factor authentication code is required",
        "two_factor_method": "totp",
    }

    login = client.post(
        "/admin/auth/login",
        json={
            "email": admin.email,
            "password": "AdminPass123!",
            "two_factor_code": generate_totp_code(setup_payload["secret"]),
        },
    )
    assert login.status_code == 200
    assert login.json()["admin"]["two_factor_enabled"] is True
    assert login.json()["admin"]["two_factor_method"] == "totp"

    disable = client.post("/admin/auth/2fa/disable", headers=headers)
    assert disable.status_code == 200
    assert disable.json()["enabled"] is False


def test_parent_two_factor_enable_requires_setup(client, create_parent, auth_headers):
    parent = create_parent(email="parent.2fa.missing@example.com")

    response = client.post(
        "/auth/2fa/enable",
        json={"code": "123456"},
        headers=auth_headers(parent),
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "TWO_FACTOR_SETUP_REQUIRED"
