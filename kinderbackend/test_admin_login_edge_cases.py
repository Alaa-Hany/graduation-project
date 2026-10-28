"""Admin login failure/edge-case flows.

Covers the disabled-account, invalid-credential, and lockout branches of the
admin auth service that the happy-path tests don't reach.
"""

from rate_limit import rate_limiter


def test_admin_login_rejects_unknown_email(client):
    resp = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "nobody@example.com", "password": "whatever"},
    )
    assert resp.status_code == 401


def test_admin_login_rejects_wrong_password(client, create_admin):
    admin = create_admin(email="wrongpass.admin@example.com")
    resp = client.post(
        "/api/v1/admin/auth/login",
        json={"email": admin.email, "password": "definitely-not-it"},
    )
    assert resp.status_code == 401


def test_admin_login_blocks_disabled_account(client, create_admin):
    admin = create_admin(email="disabled.admin@example.com", is_active=False)
    resp = client.post(
        "/api/v1/admin/auth/login",
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
            "/api/v1/admin/auth/login",
            json={"email": admin.email, "password": "wrong-password"},
        )
        statuses.append(resp.status_code)

    assert all(code == 401 for code in statuses)

    # The per-IP limiter would now answer 429; reset it to simulate the next
    # attempt coming from another client, which must still hit the account lock.
    rate_limiter.requests.clear()

    # The account is now locked: even the correct password is rejected with 423.
    locked = client.post(
        "/api/v1/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert locked.status_code == 423
    detail = locked.json().get("detail", {})
    if isinstance(detail, dict):
        assert detail.get("code") == "ADMIN_TEMP_LOCKED"


def test_admin_login_is_rate_limited_per_client(client, create_admin):
    # Regression: admin auth used Depends(auth_rate_limit) (the factory, not
    # the dependency), so the limiter never ran and 12+ bad logins all got 401.
    # Different emails each time: the limit is per client, not per account.
    create_admin(email="ratelimit.admin@example.com")
    for attempt in range(5):
        resp = client.post(
            "/api/v1/admin/auth/login",
            json={"email": f"guess{attempt}.admin@example.com", "password": "wrong-password"},
        )
        assert resp.status_code == 401

    blocked = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "ratelimit.admin@example.com", "password": "AdminPass123!"},
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.json()["detail"]["scope"] == "authentication"
    assert blocked.headers["Retry-After"] == "300"


def test_admin_refresh_is_rate_limited(client):
    statuses = [
        client.post("/api/v1/admin/auth/refresh", json={"refresh_token": "bad"}).status_code
        for _ in range(6)
    ]
    assert 429 not in statuses[:5]
    assert statuses[5] == 429
