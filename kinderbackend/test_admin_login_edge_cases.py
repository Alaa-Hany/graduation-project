"""Admin login failure/edge-case flows.

Covers the disabled-account, invalid-credential, and lockout branches of the
admin auth service that the happy-path tests don't reach.
"""


def test_admin_login_rejects_unknown_email(client):
    resp = client.post(
        "/admin/auth/login",
        json={"email": "nobody@example.com", "password": "whatever"},
    )
    assert resp.status_code == 401


def test_admin_login_rejects_wrong_password(client, create_admin):
    admin = create_admin(email="wrongpass.admin@example.com")
    resp = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "definitely-not-it"},
    )
    assert resp.status_code == 401


def test_admin_login_blocks_disabled_account(client, create_admin):
    admin = create_admin(email="disabled.admin@example.com", is_active=False)
    resp = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert resp.status_code == 403
    detail = resp.json().get("detail", {})
    if isinstance(detail, dict):
        assert detail.get("code") == "ADMIN_DISABLED"


def test_repeated_failed_admin_logins_lock_account(client, create_admin):
    admin = create_admin(email="lockme.admin@example.com")

    # Default policy: 5 failed attempts -> temporary lock (>=3 flags suspicious).
    statuses = []
    for _ in range(5):
        resp = client.post(
            "/admin/auth/login",
            json={"email": admin.email, "password": "wrong-password"},
        )
        statuses.append(resp.status_code)

    assert all(code == 401 for code in statuses)

    # The account is now locked: even the correct password is rejected with 423.
    locked = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert locked.status_code == 423
    detail = locked.json().get("detail", {})
    if isinstance(detail, dict):
        assert detail.get("code") == "ADMIN_TEMP_LOCKED"
