"""Unit tests for services.auth_service.AuthService.

These call the service methods directly (bypassing the HTTP layer) to exercise
branches that are awkward to reach end-to-end: lockout fallbacks, OTP/email
failure paths, PIN flows, password-reset token matching, and the thin
module-level wrapper functions.

Redis is mocked by the autouse conftest fixtures; ``stub_email_delivery`` makes
``send_email`` a no-op so the happy paths don't touch the network.
"""

from datetime import timedelta
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

import services.auth_service as auth_module
from auth import create_refresh_token, hash_password
from core.time_utils import db_utc_now
from schemas.auth import (
    ForgotPasswordIn,
    LoginIn,
    RefreshIn,
    RegisterIn,
    ResendEmailOtpIn,
    ResetPasswordIn,
    VerifyEmailOtpIn,
)
from services.auth_service import AuthService

STRONG_PASSWORD = "Password123!"
NEW_PASSWORD = "NewPassword123!"


@pytest.fixture
def service():
    return AuthService()


# ---------------------------------------------------------------------------
# register_parent
# ---------------------------------------------------------------------------


def test_register_parent_success(service, db):
    payload = RegisterIn(
        name="New Parent",
        email="reg-new@example.com",
        password=STRONG_PASSWORD,
        confirm_password=STRONG_PASSWORD,
    )
    result = service.register_parent(payload, db)
    assert result["verification_required"] is True
    assert result["email"] == "reg-new@example.com"


def test_register_parent_password_mismatch(service, db):
    payload = RegisterIn(
        name="P",
        email="reg-mismatch@example.com",
        password=STRONG_PASSWORD,
        confirm_password="Different123!",
    )
    with pytest.raises(HTTPException) as exc:
        service.register_parent(payload, db)
    assert exc.value.status_code == 400


def test_register_parent_weak_password(service, db):
    payload = RegisterIn(
        name="P",
        email="reg-weak@example.com",
        password="weak",
        confirm_password="weak",
    )
    with pytest.raises(HTTPException) as exc:
        service.register_parent(payload, db)
    assert exc.value.status_code == 422


def test_register_parent_existing_verified_rejected(service, db, create_parent):
    create_parent(email="reg-dup@example.com")
    payload = RegisterIn(
        name="P",
        email="reg-dup@example.com",
        password=STRONG_PASSWORD,
        confirm_password=STRONG_PASSWORD,
    )
    with pytest.raises(HTTPException) as exc:
        service.register_parent(payload, db)
    assert exc.value.status_code == 400


def test_register_parent_existing_unverified_overwrites(service, db, create_parent):
    create_parent(email="reg-pending@example.com", is_active=False)
    payload = RegisterIn(
        name="Updated Name",
        email="reg-pending@example.com",
        password=STRONG_PASSWORD,
        confirm_password=STRONG_PASSWORD,
    )
    result = service.register_parent(payload, db)
    assert result["verification_required"] is True


def test_register_parent_otp_send_failure(service, db, monkeypatch):
    monkeypatch.setattr(
        service, "_send_email_otp", lambda **kwargs: (_ for _ in ()).throw(RuntimeError("smtp down"))
    )
    payload = RegisterIn(
        name="P",
        email="reg-otpfail@example.com",
        password=STRONG_PASSWORD,
        confirm_password=STRONG_PASSWORD,
    )
    with pytest.raises(HTTPException) as exc:
        service.register_parent(payload, db)
    assert exc.value.status_code == 503


# ---------------------------------------------------------------------------
# login_parent
# ---------------------------------------------------------------------------


def test_login_parent_success(service, db, create_parent):
    create_parent(email="login-ok@example.com", password=STRONG_PASSWORD)
    payload = LoginIn(email="login-ok@example.com", password=STRONG_PASSWORD)
    result = service.login_parent(payload, db)
    assert result["token_type"] == "bearer"
    assert "access_token" in result


def test_login_parent_wrong_password(service, db, create_parent):
    create_parent(email="login-bad@example.com", password=STRONG_PASSWORD)
    payload = LoginIn(email="login-bad@example.com", password="WrongPass123!")
    with pytest.raises(HTTPException) as exc:
        service.login_parent(payload, db)
    assert exc.value.status_code == 401


def test_login_parent_unverified(service, db, create_parent):
    create_parent(email="login-unverified@example.com", is_active=False)
    payload = LoginIn(email="login-unverified@example.com", password=STRONG_PASSWORD)
    with pytest.raises(HTTPException) as exc:
        service.login_parent(payload, db)
    assert exc.value.status_code == 403


def test_login_parent_in_memory_lockout(service, db, create_parent, monkeypatch):
    # Force the Redis-less fallback path (lines exercising _FAILED_LOGIN_ATTEMPTS).
    monkeypatch.setattr(auth_module, "get_redis_client", lambda: None)
    monkeypatch.setenv("TESTING", "1")
    auth_module._FAILED_LOGIN_ATTEMPTS.clear()
    auth_module._LOGIN_LOCKOUTS.clear()

    create_parent(email="login-lock@example.com", password=STRONG_PASSWORD)
    payload = LoginIn(email="login-lock@example.com", password="WrongPass123!")

    # Default threshold is 5; the 6th failure trips the lockout.
    statuses = []
    for _ in range(7):
        try:
            service.login_parent(payload, db)
        except HTTPException as exc:
            statuses.append(exc.status_code)
    assert 423 in statuses

    # A subsequent attempt is blocked up-front by the active lockout.
    with pytest.raises(HTTPException) as exc:
        service.login_parent(payload, db)
    assert exc.value.status_code == 423


# ---------------------------------------------------------------------------
# verify_parent_email_otp / resend_parent_email_otp
# ---------------------------------------------------------------------------


def test_verify_otp_user_not_found(service, db):
    payload = VerifyEmailOtpIn(email="nobody@example.com", otp="123456")
    with pytest.raises(HTTPException) as exc:
        service.verify_parent_email_otp(payload, db)
    assert exc.value.status_code == 404


def test_verify_otp_already_verified_returns_tokens(service, db, create_parent):
    create_parent(email="verify-done@example.com")
    payload = VerifyEmailOtpIn(email="verify-done@example.com", otp="123456")
    result = service.verify_parent_email_otp(payload, db)
    assert "access_token" in result


def test_verify_otp_expired(service, db, create_parent):
    user = create_parent(email="verify-expired@example.com", is_active=False)
    user.email_verified = False
    user.email_otp_hash = hash_password("123456")
    user.email_otp_expires_at = db_utc_now() - timedelta(minutes=1)
    db.add(user)
    db.commit()
    payload = VerifyEmailOtpIn(email="verify-expired@example.com", otp="123456")
    with pytest.raises(HTTPException) as exc:
        service.verify_parent_email_otp(payload, db)
    assert exc.value.status_code == 400


def test_verify_otp_wrong_code(service, db, create_parent):
    user = create_parent(email="verify-wrong@example.com", is_active=False)
    user.email_verified = False
    user.email_otp_hash = hash_password("111111")
    user.email_otp_expires_at = db_utc_now() + timedelta(minutes=5)
    db.add(user)
    db.commit()
    payload = VerifyEmailOtpIn(email="verify-wrong@example.com", otp="222222")
    with pytest.raises(HTTPException) as exc:
        service.verify_parent_email_otp(payload, db)
    assert exc.value.status_code == 400


def test_verify_otp_success(service, db, create_parent):
    user = create_parent(email="verify-ok@example.com", is_active=False)
    user.email_verified = False
    user.email_otp_hash = hash_password("654321")
    user.email_otp_expires_at = db_utc_now() + timedelta(minutes=5)
    db.add(user)
    db.commit()
    payload = VerifyEmailOtpIn(email="verify-ok@example.com", otp="654321")
    result = service.verify_parent_email_otp(payload, db)
    assert "access_token" in result
    db.refresh(user)
    assert user.email_verified is True


def test_resend_otp_user_not_found(service, db):
    payload = ResendEmailOtpIn(email="ghost@example.com")
    with pytest.raises(HTTPException) as exc:
        service.resend_parent_email_otp(payload, db)
    assert exc.value.status_code == 404


def test_resend_otp_already_verified(service, db, create_parent):
    create_parent(email="resend-verified@example.com")
    payload = ResendEmailOtpIn(email="resend-verified@example.com")
    with pytest.raises(HTTPException) as exc:
        service.resend_parent_email_otp(payload, db)
    assert exc.value.status_code == 400


def test_resend_otp_cooldown(service, db, create_parent):
    user = create_parent(email="resend-cooldown@example.com", is_active=False)
    user.email_verified = False
    user.email_otp_last_sent_at = db_utc_now()  # just sent → cooldown active
    db.add(user)
    db.commit()
    payload = ResendEmailOtpIn(email="resend-cooldown@example.com")
    with pytest.raises(HTTPException) as exc:
        service.resend_parent_email_otp(payload, db)
    assert exc.value.status_code == 429


def test_resend_otp_success(service, db, create_parent):
    user = create_parent(email="resend-ok@example.com", is_active=False)
    user.email_verified = False
    user.email_otp_last_sent_at = db_utc_now() - timedelta(minutes=10)
    db.add(user)
    db.commit()
    payload = ResendEmailOtpIn(email="resend-ok@example.com")
    result = service.resend_parent_email_otp(payload, db)
    assert result["success"] is True


# ---------------------------------------------------------------------------
# refresh_parent_access_token
# ---------------------------------------------------------------------------


def test_refresh_invalid_token(service, db):
    payload = RefreshIn(refresh_token="not-a-jwt")
    with pytest.raises(HTTPException) as exc:
        service.refresh_parent_access_token(payload, db)
    assert exc.value.status_code == 401


def test_refresh_user_not_found(service, db):
    token = create_refresh_token("999999", 0)
    payload = RefreshIn(refresh_token=token)
    with pytest.raises(HTTPException) as exc:
        service.refresh_parent_access_token(payload, db)
    assert exc.value.status_code == 401


def test_refresh_token_version_mismatch(service, db, create_parent):
    user = create_parent(email="refresh-stale@example.com")
    token = create_refresh_token(str(user.id), (user.token_version or 0) + 5)
    payload = RefreshIn(refresh_token=token)
    with pytest.raises(HTTPException) as exc:
        service.refresh_parent_access_token(payload, db)
    assert exc.value.status_code == 401


def test_refresh_success(service, db, create_parent):
    user = create_parent(email="refresh-ok@example.com")
    token = create_refresh_token(str(user.id), user.token_version or 0)
    payload = RefreshIn(refresh_token=token)
    result = service.refresh_parent_access_token(payload, db)
    assert "access_token" in result


# ---------------------------------------------------------------------------
# update_profile / change_password / logout
# ---------------------------------------------------------------------------


def test_update_profile_success(service, db, create_parent):
    user = create_parent(email="profile@example.com")
    result = service.update_profile(payload=SimpleNamespace(name="Renamed"), db=db, user=user)
    assert result["user"]["name"] == "Renamed"


def test_update_profile_db_error(service, db, create_parent, monkeypatch):
    user = create_parent(email="profile-err@example.com")
    monkeypatch.setattr(db, "commit", lambda: (_ for _ in ()).throw(RuntimeError("boom")))
    with pytest.raises(HTTPException) as exc:
        service.update_profile(payload=SimpleNamespace(name="X"), db=db, user=user)
    assert exc.value.status_code == 500


def test_change_password_wrong_current(service, db, create_parent):
    user = create_parent(email="cp-wrong@example.com", password=STRONG_PASSWORD)
    payload = SimpleNamespace(
        current_password="WrongPass123!",
        new_password=NEW_PASSWORD,
        confirm_password=NEW_PASSWORD,
    )
    with pytest.raises(HTTPException) as exc:
        service.change_password(payload=payload, db=db, user=user)
    assert exc.value.status_code == 401


def test_change_password_weak_new(service, db, create_parent):
    user = create_parent(email="cp-weak@example.com", password=STRONG_PASSWORD)
    payload = SimpleNamespace(
        current_password=STRONG_PASSWORD, new_password="weak", confirm_password="weak"
    )
    with pytest.raises(HTTPException) as exc:
        service.change_password(payload=payload, db=db, user=user)
    assert exc.value.status_code == 422


def test_change_password_confirm_mismatch(service, db, create_parent):
    user = create_parent(email="cp-mismatch@example.com", password=STRONG_PASSWORD)
    payload = SimpleNamespace(
        current_password=STRONG_PASSWORD,
        new_password=NEW_PASSWORD,
        confirm_password="Other123!",
    )
    with pytest.raises(HTTPException) as exc:
        service.change_password(payload=payload, db=db, user=user)
    assert exc.value.status_code == 400


def test_change_password_success(service, db, create_parent):
    user = create_parent(email="cp-ok@example.com", password=STRONG_PASSWORD)
    old_version = user.token_version or 0
    payload = SimpleNamespace(
        current_password=STRONG_PASSWORD,
        new_password=NEW_PASSWORD,
        confirm_password=NEW_PASSWORD,
    )
    result = service.change_password(payload=payload, db=db, user=user)
    assert result["success"] is True
    db.refresh(user)
    assert user.token_version == old_version + 1


def test_change_password_db_error(service, db, create_parent, monkeypatch):
    user = create_parent(email="cp-dberr@example.com", password=STRONG_PASSWORD)
    monkeypatch.setattr(db, "commit", lambda: (_ for _ in ()).throw(RuntimeError("boom")))
    payload = SimpleNamespace(
        current_password=STRONG_PASSWORD,
        new_password=NEW_PASSWORD,
        confirm_password=NEW_PASSWORD,
    )
    with pytest.raises(HTTPException) as exc:
        service.change_password(payload=payload, db=db, user=user)
    assert exc.value.status_code == 500


def test_logout_success(service, db, create_parent):
    user = create_parent(email="logout-ok@example.com")
    result = service.logout(db=db, user=user)
    assert result["success"] is True


def test_logout_db_error(service, db, create_parent, monkeypatch):
    user = create_parent(email="logout-err@example.com")
    monkeypatch.setattr(db, "commit", lambda: (_ for _ in ()).throw(RuntimeError("boom")))
    with pytest.raises(HTTPException) as exc:
        service.logout(db=db, user=user)
    assert exc.value.status_code == 500


# ---------------------------------------------------------------------------
# Parent PIN flows
# ---------------------------------------------------------------------------


def test_pin_status_without_pin(service, create_parent):
    user = create_parent(email="pin-status@example.com")
    status = service.get_parent_pin_status(user=user)
    assert status["has_pin"] is False
    assert status["is_locked"] is False


def test_set_pin_success(service, db, create_parent):
    user = create_parent(email="pin-set@example.com")
    payload = SimpleNamespace(pin="1234", confirm_pin="1234")
    result = service.set_parent_pin(payload=payload, db=db, user=user)
    assert result["success"] is True


def test_set_pin_already_exists(service, db, create_parent):
    user = create_parent(email="pin-exists@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(pin="5678", confirm_pin="5678")
    with pytest.raises(HTTPException) as exc:
        service.set_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 400


def test_set_pin_mismatch(service, db, create_parent):
    user = create_parent(email="pin-mismatch@example.com")
    payload = SimpleNamespace(pin="1234", confirm_pin="9999")
    with pytest.raises(HTTPException) as exc:
        service.set_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 400


def test_verify_pin_not_configured(service, db, create_parent):
    user = create_parent(email="pin-noconf@example.com")
    payload = SimpleNamespace(pin="1234")
    with pytest.raises(HTTPException) as exc:
        service.verify_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 404


def test_verify_pin_success(service, db, create_parent):
    user = create_parent(email="pin-verify-ok@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(pin="1234")
    result = service.verify_parent_pin(payload=payload, db=db, user=user)
    assert result["success"] is True


def test_verify_pin_wrong_then_lockout(service, db, create_parent):
    user = create_parent(email="pin-lock@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(pin="0000")

    statuses = []
    for _ in range(6):
        try:
            service.verify_parent_pin(payload=payload, db=db, user=user)
        except HTTPException as exc:
            statuses.append(exc.status_code)
    assert 401 in statuses
    assert 423 in statuses  # lockout after PARENT_PIN_MAX_ATTEMPTS

    # Locked account raises 423 up-front now.
    with pytest.raises(HTTPException) as exc:
        service.verify_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 423


def test_change_pin_not_configured(service, db, create_parent):
    user = create_parent(email="pin-chg-noconf@example.com")
    payload = SimpleNamespace(current_pin="1234", new_pin="5678", confirm_pin="5678")
    with pytest.raises(HTTPException) as exc:
        service.change_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 404


def test_change_pin_confirm_mismatch(service, db, create_parent):
    user = create_parent(email="pin-chg-mismatch@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(current_pin="1234", new_pin="5678", confirm_pin="9999")
    with pytest.raises(HTTPException) as exc:
        service.change_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 400


def test_change_pin_same_as_current(service, db, create_parent):
    user = create_parent(email="pin-chg-same@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(current_pin="1234", new_pin="1234", confirm_pin="1234")
    with pytest.raises(HTTPException) as exc:
        service.change_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 400


def test_change_pin_wrong_current(service, db, create_parent):
    user = create_parent(email="pin-chg-wrong@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(current_pin="0000", new_pin="5678", confirm_pin="5678")
    with pytest.raises(HTTPException) as exc:
        service.change_parent_pin(payload=payload, db=db, user=user)
    assert exc.value.status_code == 401


def test_change_pin_success(service, db, create_parent):
    user = create_parent(email="pin-chg-ok@example.com")
    user.parent_pin_hash = hash_password("1234")
    db.add(user)
    db.commit()
    payload = SimpleNamespace(current_pin="1234", new_pin="5678", confirm_pin="5678")
    result = service.change_parent_pin(payload=payload, db=db, user=user)
    assert result["success"] is True


def test_request_pin_reset_creates_ticket(service, db, create_parent):
    user = create_parent(email="pin-reset@example.com")
    payload = SimpleNamespace(note="Forgot my PIN")
    result = service.request_parent_pin_reset(payload=payload, db=db, user=user)
    assert result["success"] is True


def test_request_pin_reset_db_error(service, db, create_parent, monkeypatch):
    user = create_parent(email="pin-reset-err@example.com")
    monkeypatch.setattr(db, "commit", lambda: (_ for _ in ()).throw(RuntimeError("boom")))
    payload = SimpleNamespace(note="")
    with pytest.raises(HTTPException) as exc:
        service.request_parent_pin_reset(payload=payload, db=db, user=user)
    assert exc.value.status_code == 500


# ---------------------------------------------------------------------------
# Password reset
# ---------------------------------------------------------------------------


def test_request_password_reset_unknown_email_is_generic(service, db):
    payload = ForgotPasswordIn(email="unknown-reset@example.com")
    result = service.request_password_reset(payload, db)
    assert result["success"] is True  # does not leak account existence


def test_request_password_reset_known_user(service, db, create_parent):
    create_parent(email="reset-known@example.com")
    payload = ForgotPasswordIn(email="reset-known@example.com")
    result = service.request_password_reset(payload, db)
    assert result["success"] is True


def test_request_password_reset_send_failure(service, db, create_parent, monkeypatch):
    create_parent(email="reset-sendfail@example.com")
    monkeypatch.setattr(
        service,
        "_send_password_reset_email",
        lambda **kwargs: (_ for _ in ()).throw(RuntimeError("smtp down")),
    )
    payload = ForgotPasswordIn(email="reset-sendfail@example.com")
    with pytest.raises(HTTPException) as exc:
        service.request_password_reset(payload, db)
    assert exc.value.status_code == 503


def test_confirm_password_reset_password_mismatch(service, db):
    payload = ResetPasswordIn(
        token="tok", new_password=NEW_PASSWORD, confirm_password="Other123!"
    )
    with pytest.raises(HTTPException) as exc:
        service.confirm_password_reset(payload, db)
    assert exc.value.status_code == 400


def test_confirm_password_reset_weak_password(service, db):
    payload = ResetPasswordIn(token="tok", new_password="weak", confirm_password="weak")
    with pytest.raises(HTTPException) as exc:
        service.confirm_password_reset(payload, db)
    assert exc.value.status_code == 422


def test_confirm_password_reset_invalid_token(service, db, create_parent):
    create_parent(email="reset-badtoken@example.com")
    payload = ResetPasswordIn(
        token="does-not-match", new_password=NEW_PASSWORD, confirm_password=NEW_PASSWORD
    )
    with pytest.raises(HTTPException) as exc:
        service.confirm_password_reset(payload, db)
    assert exc.value.status_code == 400


def test_confirm_password_reset_expired_token(service, db, create_parent):
    user = create_parent(email="reset-expired@example.com")
    user.password_reset_token_hash = hash_password("rawtoken")
    user.password_reset_token_expires_at = db_utc_now() - timedelta(minutes=1)
    db.add(user)
    db.commit()
    payload = ResetPasswordIn(
        token="rawtoken", new_password=NEW_PASSWORD, confirm_password=NEW_PASSWORD
    )
    with pytest.raises(HTTPException) as exc:
        service.confirm_password_reset(payload, db)
    assert exc.value.status_code == 400


def test_confirm_password_reset_success(service, db, create_parent):
    user = create_parent(email="reset-ok@example.com")
    user.password_reset_token_hash = hash_password("rawtoken")
    user.password_reset_token_expires_at = db_utc_now() + timedelta(minutes=10)
    db.add(user)
    db.commit()
    payload = ResetPasswordIn(
        token="rawtoken", new_password=NEW_PASSWORD, confirm_password=NEW_PASSWORD
    )
    result = service.confirm_password_reset(payload, db)
    assert result["success"] is True
    db.refresh(user)
    assert user.password_reset_token_hash is None


# ---------------------------------------------------------------------------
# Helper functions for password-reset email rendering / 2FA passthrough
# ---------------------------------------------------------------------------


def test_send_password_reset_email_builds_url(service, monkeypatch):
    captured = {}
    monkeypatch.setattr(
        "services.auth_service.email_delivery_service.send_email",
        lambda **kwargs: captured.update(kwargs),
    )
    service._send_password_reset_email(
        email="kid@home.com", name="Sam", token="abc123", app_base_url="https://app.test/"
    )
    assert "token=abc123" in captured["html_body"]
    assert captured["to_email"] == "kid@home.com"


# ---------------------------------------------------------------------------
# Module-level wrapper functions
# ---------------------------------------------------------------------------


def test_module_wrappers_delegate(monkeypatch):
    calls = {}

    def stub(name):
        def _fn(*args, **kwargs):
            calls[name] = (args, kwargs)
            return {"stub": name}

        return _fn

    for name in (
        "refresh_parent_access_token",
        "update_profile",
        "change_password",
        "logout",
        "get_parent_pin_status",
        "set_parent_pin",
        "verify_parent_pin",
        "change_parent_pin",
        "request_parent_pin_reset",
        "two_factor_status",
        "two_factor_setup",
        "enable_two_factor",
        "disable_two_factor",
    ):
        monkeypatch.setattr(auth_module.auth_service, name, stub(name))

    assert auth_module.refresh_parent_access_token("p", "db") == {"stub": "refresh_parent_access_token"}
    assert auth_module.update_profile(payload="p", db="db", user="u")["stub"] == "update_profile"
    assert auth_module.change_password(payload="p", db="db", user="u")["stub"] == "change_password"
    assert auth_module.logout(db="db", user="u")["stub"] == "logout"
    assert auth_module.get_parent_pin_status(user="u")["stub"] == "get_parent_pin_status"
    assert auth_module.set_parent_pin(payload="p", db="db", user="u")["stub"] == "set_parent_pin"
    assert auth_module.verify_parent_pin(payload="p", db="db", user="u")["stub"] == "verify_parent_pin"
    assert auth_module.change_parent_pin(payload="p", db="db", user="u")["stub"] == "change_parent_pin"
    assert (
        auth_module.request_parent_pin_reset(payload="p", db="db", user="u")["stub"]
        == "request_parent_pin_reset"
    )
    assert auth_module.two_factor_status(user="u")["stub"] == "two_factor_status"
    assert auth_module.setup_two_factor(db="db", user="u")["stub"] == "two_factor_setup"
    assert auth_module.enable_two_factor(db="db", user="u", code="1")["stub"] == "enable_two_factor"
    assert auth_module.disable_two_factor(db="db", user="u")["stub"] == "disable_two_factor"


def test_validate_password_policy_wrappers():
    ok, _ = auth_module.validate_password_policy_for_auth(STRONG_PASSWORD)
    assert ok is True
    bad, msg = auth_module.validate_password_policy("weak")
    assert bad is False
    assert msg
