"""Phase 3 security tests: #12 2FA lockout, #26 2FA setup password,
#5 admin bootstrap, #8 plan expiry, #6 per-device refresh sessions."""

from __future__ import annotations

from datetime import timedelta

import pytest

from core.settings import settings
from core.time_utils import db_utc_now
from core.two_factor import generate_totp_code, generate_totp_secret
from models import ParentRefreshSession, SubscriptionProfile
from plan_service import PLAN_FREE, PLAN_PREMIUM, get_user_plan

PASSWORD = "Password123!"


def _login(client, email, code=None):
    body = {"email": email, "password": PASSWORD}
    if code is not None:
        body["two_factor_code"] = code
    return client.post("/api/v1/auth/login", json=body)


def _enable_2fa(db, parent) -> str:
    secret = generate_totp_secret()
    parent.two_factor_enabled = True
    parent.two_factor_method = "totp"
    parent.two_factor_secret = secret
    db.add(parent)
    db.commit()
    return secret


# ── #12: wrong 2FA codes count toward the login lockout ────────────────────


def test_wrong_2fa_codes_lock_the_account(client, db, create_parent, monkeypatch):
    monkeypatch.setenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "3")
    parent = create_parent(email="p3.lock@example.com")
    secret = _enable_2fa(db, parent)

    statuses = [_login(client, parent.email, code="000000").status_code for _ in range(4)]
    assert statuses[:3] == [401, 401, 401]
    assert statuses[3] == 423

    # Even the right code is refused while locked.
    locked = _login(client, parent.email, code=generate_totp_code(secret))
    assert locked.status_code == 423


def test_missing_2fa_code_is_not_counted_and_right_code_logs_in(
    client, db, create_parent, monkeypatch
):
    monkeypatch.setenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "2")
    parent = create_parent(email="p3.ok2fa@example.com")
    secret = _enable_2fa(db, parent)

    for _ in range(4):  # step one of the 2FA flow, repeated
        first_step = _login(client, parent.email)
        assert first_step.status_code == 401
        assert first_step.json()["detail"]["code"] == "PARENT_TWO_FACTOR_REQUIRED"

    ok = _login(client, parent.email, code=generate_totp_code(secret))
    assert ok.status_code == 200


# ── #26: 2FA setup needs the current password ──────────────────────────────


def test_parent_2fa_setup_requires_current_password(client, create_parent, auth_headers):
    parent = create_parent(email="p3.setup@example.com")
    headers = auth_headers(parent)

    missing = client.post("/api/v1/auth/2fa/setup", json={}, headers=headers)
    assert missing.status_code == 422
    wrong = client.post("/api/v1/auth/2fa/setup", json={"password": "nope"}, headers=headers)
    assert wrong.status_code == 401
    ok = client.post("/api/v1/auth/2fa/setup", json={"password": PASSWORD}, headers=headers)
    assert ok.status_code == 200
    assert ok.json()["secret"]


def test_admin_2fa_setup_requires_current_password(
    client, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="p3.admin2fa@example.com", role_names=["super_admin"])
    headers = admin_headers(admin)
    wrong = client.post("/api/v1/admin/auth/2fa/setup", json={"password": "nope"}, headers=headers)
    assert wrong.status_code == 401
    ok = client.post(
        "/api/v1/admin/auth/2fa/setup", json={"password": "AdminPass123!"}, headers=headers
    )
    assert ok.status_code == 200


# ── #5: admin bootstrap is closed in production ────────────────────────────


@pytest.fixture
def production(monkeypatch):
    monkeypatch.setattr(type(settings), "is_production", property(lambda self: True))


_BOOTSTRAP = {"email": "first.admin@example.com", "password": "BootstrapPass1!"}


def test_bootstrap_closed_in_production_without_secret(client, production, monkeypatch):
    monkeypatch.delenv("ADMIN_BOOTSTRAP_SECRET", raising=False)
    status = client.get("/api/v1/admin/auth/bootstrap/status")
    assert status.json()["can_bootstrap"] is False
    response = client.post("/api/v1/admin/auth/bootstrap", json=_BOOTSTRAP)
    assert response.status_code == 404


def test_bootstrap_in_production_needs_matching_secret(client, production, monkeypatch):
    monkeypatch.setenv("ADMIN_BOOTSTRAP_SECRET", "s3cret-bootstrap-value")
    wrong = client.post(
        "/api/v1/admin/auth/bootstrap",
        json=_BOOTSTRAP,
        headers={"X-Admin-Bootstrap-Secret": "guess"},
    )
    assert wrong.status_code == 403
    ok = client.post(
        "/api/v1/admin/auth/bootstrap",
        json=_BOOTSTRAP,
        headers={"X-Admin-Bootstrap-Secret": "s3cret-bootstrap-value"},
    )
    assert ok.status_code == 200


def test_bootstrap_still_works_in_development(client, monkeypatch):
    monkeypatch.delenv("ADMIN_BOOTSTRAP_SECRET", raising=False)
    assert client.get("/api/v1/admin/auth/bootstrap/status").json()["can_bootstrap"] is True
    assert client.post("/api/v1/admin/auth/bootstrap", json=_BOOTSTRAP).status_code == 200


# ── #8: an expired paid plan stops granting access ─────────────────────────


def _premium_with_expiry(db, create_parent, email, expires_at):
    parent = create_parent(email=email, plan=PLAN_PREMIUM)
    db.add(
        SubscriptionProfile(
            user_id=parent.id,
            current_plan_id=PLAN_PREMIUM,
            status="active",
            last_payment_status="succeeded",
            provider="stripe",
            provider_subscription_id="sub_p3",
            expires_at=expires_at,
        )
    )
    db.commit()
    db.refresh(parent)
    return parent


def test_expired_subscription_counts_as_free(db, create_parent):
    expired = _premium_with_expiry(
        db, create_parent, "p3.expired@example.com", db_utc_now() - timedelta(days=10)
    )
    assert get_user_plan(expired) == PLAN_FREE


def test_subscription_within_grace_or_active_keeps_premium(db, create_parent):
    in_grace = _premium_with_expiry(
        db, create_parent, "p3.grace@example.com", db_utc_now() - timedelta(hours=10)
    )
    active = _premium_with_expiry(
        db, create_parent, "p3.active@example.com", db_utc_now() + timedelta(days=20)
    )
    assert get_user_plan(in_grace) == PLAN_PREMIUM
    assert get_user_plan(active) == PLAN_PREMIUM


def test_expired_plan_is_reported_as_free_by_api(client, db, create_parent, auth_headers):
    parent = _premium_with_expiry(
        db, create_parent, "p3.apiexpired@example.com", db_utc_now() - timedelta(days=10)
    )
    me = client.get("/api/v1/auth/me", headers=auth_headers(parent))
    assert me.status_code == 200
    assert me.json()["user"]["plan"] == PLAN_FREE


# ── #6: one refresh session per device ─────────────────────────────────────


def test_second_device_login_keeps_first_device_signed_in(client, create_parent):
    parent = create_parent(email="p3.devices@example.com")
    phone = _login(client, parent.email).json()
    tablet = _login(client, parent.email).json()

    for device in (phone, tablet):
        refreshed = client.post(
            "/api/v1/auth/refresh", json={"refresh_token": device["refresh_token"]}
        )
        assert refreshed.status_code == 200


def test_logout_signs_out_only_that_device(client, create_parent):
    parent = create_parent(email="p3.logout@example.com")
    phone = _login(client, parent.email).json()
    tablet = _login(client, parent.email).json()

    out = client.post(
        "/api/v1/auth/logout", headers={"Authorization": f"Bearer {phone['access_token']}"}
    )
    assert out.status_code == 200

    # The phone's access and refresh tokens are dead immediately...
    assert (
        client.get(
            "/api/v1/auth/me", headers={"Authorization": f"Bearer {phone['access_token']}"}
        ).status_code
        == 401
    )
    assert (
        client.post(
            "/api/v1/auth/refresh", json={"refresh_token": phone["refresh_token"]}
        ).status_code
        == 401
    )
    # ...the tablet is untouched.
    assert (
        client.get(
            "/api/v1/auth/me", headers={"Authorization": f"Bearer {tablet['access_token']}"}
        ).status_code
        == 200
    )


def test_password_change_signs_out_every_device(client, create_parent):
    parent = create_parent(email="p3.pwchange@example.com")
    phone = _login(client, parent.email).json()
    tablet = _login(client, parent.email).json()

    change = client.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": PASSWORD,
            "new_password": "NewPassword123!",
            "confirm_password": "NewPassword123!",
        },
        headers={"Authorization": f"Bearer {phone['access_token']}"},
    )
    assert change.status_code == 200
    for device in (phone, tablet):
        assert (
            client.post(
                "/api/v1/auth/refresh", json={"refresh_token": device["refresh_token"]}
            ).status_code
            == 401
        )


def test_sessions_per_parent_are_capped(db, create_parent):
    from services.auth_service import MAX_REFRESH_SESSIONS_PER_USER, auth_service

    parent = create_parent(email="p3.cap@example.com")
    for _ in range(MAX_REFRESH_SESSIONS_PER_USER + 3):
        auth_service._issue_refresh_token(db=db, user=parent)
        db.commit()
    live = (
        db.query(ParentRefreshSession)
        .filter(
            ParentRefreshSession.user_id == parent.id,
            ParentRefreshSession.revoked_at.is_(None),
        )
        .count()
    )
    assert live == MAX_REFRESH_SESSIONS_PER_USER
