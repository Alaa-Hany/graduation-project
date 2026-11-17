"""Follow-ups after phase 4: pending-signup takeover, admin temp password,
/subscription/me after the grace period."""

from __future__ import annotations

from datetime import timedelta

import pytest

from auth import verify_password
from core.time_utils import db_utc_now
from core.validators import generate_temporary_password, validate_password_policy
from models import SubscriptionProfile, User
from plan_service import PLAN_FREE, PLAN_PREMIUM

OWNER_PASSWORD = "OwnerPass123!"
ATTACKER_PASSWORD = "Attacker123!"


@pytest.fixture
def outbox(monkeypatch):
    sent: list[dict] = []
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    return sent


def _otp_from(message: dict) -> str:
    return next(w for w in message["body"].split() if w.isdigit() and len(w) == 6)


def _register(client, email, password, name):
    return client.post(
        "/api/v1/auth/register",
        json={"name": name, "email": email, "password": password, "confirm_password": password},
    )


def _verify(client, email, otp, token=None):
    body = {"email": email, "otp": otp}
    if token is not None:
        body["registration_token"] = token
    return client.post("/api/v1/auth/verify-email-otp", json=body)


def _login(client, email, password):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


# ── 1. Re-registering a pending email can't set someone else's password ────


def test_second_signup_does_not_overwrite_pending_account(client, db, outbox):
    email = "pending.owner@example.com"
    _register(client, email, OWNER_PASSWORD, "Owner")
    _register(client, email, ATTACKER_PASSWORD, "Attacker")

    user = db.query(User).filter(User.email == email).one()
    assert user.name == "Owner"
    assert verify_password(OWNER_PASSWORD, user.password_hash)
    assert not verify_password(ATTACKER_PASSWORD, user.password_hash)


def test_attacker_signup_on_top_cannot_be_completed_by_owner_code(client, db, outbox):
    """Owner signs up, attacker signs up again on the same email. The owner then
    enters the newest code (sent to the owner's inbox) from the owner's app:
    the attacker's password must not become the account's password."""
    email = "contested@example.com"
    owner_token = _register(client, email, OWNER_PASSWORD, "Owner").json()["registration_token"]
    _register(client, email, ATTACKER_PASSWORD, "Attacker")
    latest_code = _otp_from(outbox[-1])

    # Owner's app (owner's token) and an old app (no token) are both refused.
    assert _verify(client, email, latest_code, owner_token).status_code == 400
    assert _verify(client, email, latest_code).status_code == 400
    assert _login(client, email, ATTACKER_PASSWORD).status_code == 401

    # The owner simply signs up again and completes it normally.
    retry_token = _register(client, email, OWNER_PASSWORD, "Owner").json()["registration_token"]
    done = _verify(client, email, _otp_from(outbox[-1]), retry_token)
    assert done.status_code == 200
    assert _login(client, email, OWNER_PASSWORD).status_code == 200
    assert _login(client, email, ATTACKER_PASSWORD).status_code == 401


def test_attacker_cannot_preclaim_an_email_password(client, db, outbox):
    """Attacker signs up first with the victim's email; the victim then signs up
    and verifies. The victim's password wins, the attacker's never works."""
    email = "preclaimed@example.com"
    _register(client, email, ATTACKER_PASSWORD, "Attacker")
    victim_token = _register(client, email, OWNER_PASSWORD, "Victim").json()["registration_token"]
    done = _verify(client, email, _otp_from(outbox[-1]), victim_token)
    assert done.status_code == 200

    user = db.query(User).filter(User.email == email).one()
    db.refresh(user)
    assert user.name == "Victim"
    assert user.pending_password_hash is None
    assert _login(client, email, OWNER_PASSWORD).status_code == 200
    assert _login(client, email, ATTACKER_PASSWORD).status_code == 401


def test_normal_signup_verifies_with_or_without_token(client, outbox):
    with_token = _register(client, "normal.a@example.com", OWNER_PASSWORD, "A").json()
    assert (
        _verify(
            client, "normal.a@example.com", _otp_from(outbox[-1]), with_token["registration_token"]
        ).status_code
        == 200
    )
    # Older app / came back through the login screen: no token, uncontested.
    _register(client, "normal.b@example.com", OWNER_PASSWORD, "B")
    assert _verify(client, "normal.b@example.com", _otp_from(outbox[-1])).status_code == 200
    assert _login(client, "normal.b@example.com", OWNER_PASSWORD).status_code == 200


def test_wrong_registration_token_is_refused(client, outbox):
    _register(client, "tok.wrong@example.com", OWNER_PASSWORD, "T")
    assert (
        _verify(client, "tok.wrong@example.com", _otp_from(outbox[-1]), "forged-token").status_code
        == 400
    )


# ── 2. Admin reset never uses a fixed password ────────────────────────────


def test_generated_temp_passwords_are_random_and_valid():
    passwords = {generate_temporary_password() for _ in range(50)}
    assert len(passwords) == 50
    assert "Temp@123456" not in passwords
    for password in passwords:
        assert validate_password_policy(password) == (True, "")


def _reset(client, admin_headers, admin, user_id, body):
    headers = {**admin_headers(admin), "X-Admin-Confirm": "true"}
    return client.post(f"/api/v1/admin/users/{user_id}/reset-password", json=body, headers=headers)


def test_admin_reset_without_password_uses_random_one(
    client, seed_builtin_rbac, create_admin, admin_headers, create_parent
):
    seed_builtin_rbac()
    admin = create_admin(email="reset.admin@example.com", role_names=["super_admin"])
    parent = create_parent(email="reset.target@example.com")

    first = _reset(client, admin_headers, admin, parent.id, {})
    second = _reset(client, admin_headers, admin, parent.id, {})
    assert first.status_code == second.status_code == 200
    temp_one = first.json()["temporary_password"]
    temp_two = second.json()["temporary_password"]
    assert temp_one != "Temp@123456"
    assert temp_one != temp_two
    assert _login(client, parent.email, temp_two).status_code == 200


def test_admin_reset_with_chosen_password_still_works_and_is_checked(
    client, seed_builtin_rbac, create_admin, admin_headers, create_parent
):
    seed_builtin_rbac()
    admin = create_admin(email="reset.admin2@example.com", role_names=["super_admin"])
    parent = create_parent(email="reset.target2@example.com")

    weak = _reset(client, admin_headers, admin, parent.id, {"new_password": "123"})
    assert weak.status_code == 422
    ok = _reset(client, admin_headers, admin, parent.id, {"new_password": "ChosenPass123!"})
    assert ok.status_code == 200
    assert ok.json()["temporary_password"] == "ChosenPass123!"


# ── 3. /subscription/me agrees with feature access after the grace period ──


def _premium(db, create_parent, email, expires_at):
    parent = create_parent(email=email, plan=PLAN_PREMIUM)
    db.add(
        SubscriptionProfile(
            user_id=parent.id,
            current_plan_id=PLAN_PREMIUM,
            status="active",
            last_payment_status="succeeded",
            provider="stripe",
            provider_subscription_id="sub_followup",
            expires_at=expires_at,
        )
    )
    db.commit()
    return parent


def test_subscription_me_shows_free_after_grace(client, db, create_parent, auth_headers):
    parent = _premium(
        db, create_parent, "sub.expired@example.com", db_utc_now() - timedelta(days=10)
    )
    body = client.get("/api/v1/subscription/me", headers=auth_headers(parent)).json()
    assert body["current_plan_id"] == PLAN_FREE
    assert body["plan"] == PLAN_FREE
    assert body["lifecycle"]["has_paid_access"] is False
    assert body["lifecycle"]["access_expired"] is True


def test_subscription_me_keeps_premium_while_active_or_in_grace(
    client, db, create_parent, auth_headers
):
    for email, expires_at in (
        ("sub.active@example.com", db_utc_now() + timedelta(days=20)),
        ("sub.grace@example.com", db_utc_now() - timedelta(hours=5)),
    ):
        parent = _premium(db, create_parent, email, expires_at)
        body = client.get("/api/v1/subscription/me", headers=auth_headers(parent)).json()
        assert body["current_plan_id"] == PLAN_PREMIUM
        assert body["lifecycle"]["has_paid_access"] is True
        assert body["lifecycle"]["access_expired"] is False
