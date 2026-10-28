from datetime import timedelta

from auth import hash_password
from core.time_utils import db_utc_now
from models import User
from services.auth_service import auth_service


def test_parent_registration_requires_email_otp_before_activation(client, db, monkeypatch):
    sent_messages: list[dict[str, str]] = []

    monkeypatch.setattr(auth_service, "_generate_email_otp", lambda: "123456")
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda *, to_email, subject, body, html_body=None: sent_messages.append(
            {"to_email": to_email, "subject": subject, "body": body}
        ),
    )

    register = client.post(
        "/api/v1/auth/register",
        json={
            "name": "OTP Parent",
            "email": "otp.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )

    assert register.status_code == 200
    register_body = register.json()
    assert register_body["verification_required"] is True
    assert register_body["email"] == "otp.parent@example.com"
    assert sent_messages and sent_messages[0]["to_email"] == "otp.parent@example.com"
    assert "123456" in sent_messages[0]["body"]

    pending_user = db.query(User).filter(User.email == "otp.parent@example.com").one()
    assert pending_user.is_active is False
    assert pending_user.email_verified is False

    blocked_login = client.post(
        "/api/v1/auth/login",
        json={"email": "otp.parent@example.com", "password": "Password123!"},
    )
    assert blocked_login.status_code == 403
    assert blocked_login.json()["detail"]["code"] == "EMAIL_VERIFICATION_REQUIRED"

    verify = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": "otp.parent@example.com", "otp": "123456"},
    )
    assert verify.status_code == 200
    verify_body = verify.json()
    assert verify_body["access_token"]
    assert verify_body["refresh_token"]
    assert verify_body["user"]["email_verified"] is True
    assert verify_body["user"]["is_active"] is True

    verified_user = db.query(User).filter(User.email == "otp.parent@example.com").one()
    assert verified_user.is_active is True
    assert verified_user.email_verified is True
    assert verified_user.email_otp_hash is None


def _assert_already_verified_without_tokens(response) -> None:
    assert response.status_code == 409
    body = response.json()
    assert body["detail"]["code"] == "EMAIL_ALREADY_VERIFIED"
    assert "access_token" not in body
    assert "refresh_token" not in body


def test_verified_parent_with_wrong_otp_gets_no_tokens(client, db, create_parent):
    # Regression: verify-email-otp used to hand out tokens for any already
    # verified email without checking the OTP (account takeover + 2FA bypass).
    parent = create_parent(email="verified.wrong.otp@example.com")

    response = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": "verified.wrong.otp@example.com", "otp": "000000"},
    )

    _assert_already_verified_without_tokens(response)
    db.refresh(parent)
    assert parent.refresh_token_hash is None


def test_verified_parent_with_matching_otp_gets_no_tokens(client, db, create_parent):
    # Even a code that matches a leftover OTP hash must not log the user in:
    # verified accounts have to go through /auth/login (password + 2FA).
    parent = create_parent(email="verified.match.otp@example.com")
    parent.email_otp_hash = hash_password("123456")
    parent.email_otp_expires_at = db_utc_now() + timedelta(minutes=5)
    db.add(parent)
    db.commit()

    response = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": "verified.match.otp@example.com", "otp": "123456"},
    )

    _assert_already_verified_without_tokens(response)
    db.refresh(parent)
    assert parent.refresh_token_hash is None


def test_verify_email_otp_cannot_be_replayed_after_success(client, monkeypatch):
    monkeypatch.setattr(auth_service, "_generate_email_otp", lambda: "246810")
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: None,
    )
    client.post(
        "/api/v1/auth/register",
        json={
            "name": "Replay Parent",
            "email": "replay.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )
    first = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": "replay.parent@example.com", "otp": "246810"},
    )
    assert first.status_code == 200

    replay = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": "replay.parent@example.com", "otp": "246810"},
    )
    _assert_already_verified_without_tokens(replay)


def test_resend_email_otp_enforces_cooldown(client, db, monkeypatch):
    monkeypatch.setattr(auth_service, "_generate_email_otp", lambda: "654321")
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: None,
    )

    client.post(
        "/api/v1/auth/register",
        json={
            "name": "Cooldown Parent",
            "email": "cooldown.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )

    resend_too_soon = client.post(
        "/api/v1/auth/resend-email-otp",
        json={"email": "cooldown.parent@example.com"},
    )
    assert resend_too_soon.status_code == 429
    assert resend_too_soon.json()["detail"]["code"] == "OTP_RESEND_COOLDOWN"

    user = db.query(User).filter(User.email == "cooldown.parent@example.com").one()
    user.email_otp_last_sent_at = db_utc_now() - timedelta(seconds=61)
    db.add(user)
    db.commit()

    resend_ok = client.post(
        "/api/v1/auth/resend-email-otp",
        json={"email": "cooldown.parent@example.com"},
    )
    assert resend_ok.status_code == 200
    assert resend_ok.json()["success"] is True
