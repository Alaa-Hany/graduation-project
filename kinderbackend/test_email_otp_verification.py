from datetime import timedelta

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
        "/auth/register",
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
        "/auth/login",
        json={"email": "otp.parent@example.com", "password": "Password123!"},
    )
    assert blocked_login.status_code == 403
    assert blocked_login.json()["detail"]["code"] == "EMAIL_VERIFICATION_REQUIRED"

    verify = client.post(
        "/auth/verify-email-otp",
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


def test_resend_email_otp_enforces_cooldown(client, db, monkeypatch):
    monkeypatch.setattr(auth_service, "_generate_email_otp", lambda: "654321")
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: None,
    )

    client.post(
        "/auth/register",
        json={
            "name": "Cooldown Parent",
            "email": "cooldown.parent@example.com",
            "password": "Password123!",
            "confirm_password": "Password123!",
        },
    )

    resend_too_soon = client.post(
        "/auth/resend-email-otp",
        json={"email": "cooldown.parent@example.com"},
    )
    assert resend_too_soon.status_code == 429
    assert resend_too_soon.json()["detail"]["code"] == "OTP_RESEND_COOLDOWN"

    user = db.query(User).filter(User.email == "cooldown.parent@example.com").one()
    user.email_otp_last_sent_at = db_utc_now() - timedelta(seconds=61)
    db.add(user)
    db.commit()

    resend_ok = client.post(
        "/auth/resend-email-otp",
        json={"email": "cooldown.parent@example.com"},
    )
    assert resend_ok.status_code == 200
    assert resend_ok.json()["success"] is True
