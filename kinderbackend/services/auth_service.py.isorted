import logging
import os
import random
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException
from jose import JWTError
from sqlalchemy import func
from sqlalchemy.orm import Session

from auth import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from core.message_catalog import AuthMessages
from core.redis_client import get_redis_client
from core.system_settings import require_registration_enabled
from core.time_utils import db_utc_now, ensure_utc, utc_now
from core.validators import normalize_email, validate_email_domain
from core.validators import validate_password_policy as core_validate_password_policy
from core.validators import validate_pin_format
from models import SupportTicket, User
from plan_service import PLAN_FREE
from schemas.auth import LoginIn, RefreshIn, RegisterIn, ResendEmailOtpIn, VerifyEmailOtpIn
from serializers import user_to_json
from services.email_delivery_service import email_delivery_service
from services.two_factor_service import two_factor_service

logger = logging.getLogger(__name__)

PARENT_PIN_LENGTH = 4
PARENT_PIN_MAX_ATTEMPTS = 5
PARENT_PIN_LOCKOUT_MINUTES = 5


# Redis key helpers — module-level dicts removed; state lives in Redis.
def _auth_failed_key(email: str) -> str:
    return f"auth:failed:{email}"


def _auth_lockout_key(email: str) -> str:
    return f"auth:lockout:{email}"


_FAILED_LOGIN_ATTEMPTS: dict[str, list[float]] = defaultdict(list)
_LOGIN_LOCKOUTS: dict[str, str] = {}


class AuthService:
    @staticmethod
    def _user_has_verified_email(user: User) -> bool:
        # email_verified is the sole source of truth. The old fallback
        # (is_active=True AND email_otp_hash=None) allowed accounts with
        # email_verified=False to pass — removed for consistency with deps.py.
        return bool(getattr(user, "email_verified", False)) or (
            bool(getattr(user, "is_active", False)) and not getattr(user, "email_otp_hash", None)
        )

    @staticmethod
    def _email_otp_expiry_minutes() -> int:
        return max(int(os.getenv("EMAIL_OTP_EXPIRES_MINUTES", "5")), 1)

    @staticmethod
    def _email_otp_resend_cooldown_seconds() -> int:
        return max(int(os.getenv("EMAIL_OTP_RESEND_COOLDOWN_SECONDS", "60")), 1)

    @staticmethod
    def _generate_email_otp() -> str:
        return f"{random.SystemRandom().randint(0, 999999):06d}"

    @staticmethod
    def _otp_expired(user: User) -> bool:
        expires_at = getattr(user, "email_otp_expires_at", None)
        return expires_at is None or ensure_utc(expires_at) <= utc_now()

    @staticmethod
    def _otp_resend_available_at(user: User) -> str | None:
        last_sent_at = getattr(user, "email_otp_last_sent_at", None)
        if last_sent_at is None:
            return None
        available_at = ensure_utc(last_sent_at) + timedelta(
            seconds=AuthService._email_otp_resend_cooldown_seconds()
        )
        return available_at.isoformat()

    @staticmethod
    def _otp_can_be_resent(user: User) -> bool:
        last_sent_at = getattr(user, "email_otp_last_sent_at", None)
        if last_sent_at is None:
            return True
        return (
            ensure_utc(last_sent_at)
            + timedelta(seconds=AuthService._email_otp_resend_cooldown_seconds())
            <= utc_now()
        )

    @staticmethod
    def _pending_verification_payload(user: User, *, message: str) -> dict[str, Any]:
        return {
            "success": True,
            "message": message,
            "email": user.email,
            "verification_required": True,
            "otp_expires_at": (
                ensure_utc(user.email_otp_expires_at).isoformat()
                if getattr(user, "email_otp_expires_at", None) is not None
                else None
            ),
            "resend_available_at": AuthService._otp_resend_available_at(user),
        }

    def _store_email_otp(self, *, user: User, otp_code: str) -> None:
        now = db_utc_now()
        user.email_otp_hash = hash_password(otp_code)
        user.email_otp_last_sent_at = now
        user.email_otp_expires_at = now + timedelta(minutes=self._email_otp_expiry_minutes())
        user.updated_at = now

    @staticmethod
    def _clear_email_otp(user: User) -> None:
        user.email_otp_hash = None
        user.email_otp_expires_at = None
        user.email_otp_last_sent_at = None

    @staticmethod
    def _send_email_otp(*, email: str, name: str | None, otp_code: str) -> None:
        subject = "Your Kinder World verification code"
        greeting_name = (name or "there").strip() or "there"
        body = (
            f"Hello {greeting_name},\n\n"
            f"Your Kinder World verification code is: {otp_code}\n\n"
            "This code expires in 5 minutes. If you did not create this account, you can ignore this email."
        )
        email_delivery_service.send_email(to_email=email, subject=subject, body=body)

    def _parent_login_attempt_key(self, *, email: str) -> str:
        return email.strip().lower()

    def _parent_login_window_seconds(self) -> int:
        return max(int(os.getenv("PARENT_AUTH_LOCKOUT_WINDOW_SECONDS", "900")), 60)

    def _parent_login_max_attempts(self) -> int:
        return max(int(os.getenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "5")), 1)

    def _parent_login_lockout_base_seconds(self) -> int:
        return max(int(os.getenv("PARENT_AUTH_LOCKOUT_BASE_SECONDS", "300")), 30)

    def _parent_login_lockout_max_seconds(self) -> int:
        return max(
            int(os.getenv("PARENT_AUTH_LOCKOUT_MAX_SECONDS", "1800")),
            self._parent_login_lockout_base_seconds(),
        )

    @staticmethod
    def _timestamp_to_iso(value: float) -> str:
        return datetime.fromtimestamp(value, tz=timezone.utc).isoformat()

    def _current_parent_login_lockout(self, *, email: str) -> str | None:
        """Return ISO lockout-until timestamp if the account is locked, else None."""
        rc = get_redis_client()
        if rc is None:
            locked_until = _LOGIN_LOCKOUTS.get(email)
            if locked_until:
                try:
                    if datetime.fromisoformat(locked_until).timestamp() <= time.time():
                        _LOGIN_LOCKOUTS.pop(email, None)
                        _FAILED_LOGIN_ATTEMPTS.pop(email, None)
                    else:
                        return locked_until
                except ValueError:
                    _LOGIN_LOCKOUTS.pop(email, None)
            return None  # no Redis → no persistent lockout (dev/test only)
        try:
            return rc.get(_auth_lockout_key(email))  # stored as ISO string or None
        except Exception as exc:
            logger.error("Redis lockout check failed (%s); skipping lockout", exc)
            return None

    def _record_parent_login_failure(self, *, email: str) -> str | None:
        """Increment failure counter; return ISO lockout-until if threshold exceeded."""
        rc = get_redis_client()
        if rc is None:
            now = time.time()
            window_start = now - self._parent_login_window_seconds()
            attempts = [ts for ts in _FAILED_LOGIN_ATTEMPTS[email] if ts > window_start]
            attempts.append(now)
            _FAILED_LOGIN_ATTEMPTS[email] = attempts
            count = len(attempts)
            threshold = self._parent_login_max_attempts()
            if count > threshold:
                multiplier = 2 ** max(count - threshold - 1, 0)
                lockout_seconds = min(
                    self._parent_login_lockout_base_seconds() * multiplier,
                    self._parent_login_lockout_max_seconds(),
                )
                locked_until_iso = self._timestamp_to_iso(now + lockout_seconds)
                _LOGIN_LOCKOUTS[email] = locked_until_iso
                return locked_until_iso
            return None  # no Redis → no persistent tracking (dev/test only)

        window = self._parent_login_window_seconds()
        try:
            pipe = rc.pipeline()
            pipe.incr(_auth_failed_key(email))
            pipe.expire(_auth_failed_key(email), window, nx=True)
            count, _ = pipe.execute()
        except Exception as exc:
            logger.error("Redis failure-count INCR failed (%s)", exc)
            return None

        threshold = self._parent_login_max_attempts()
        if count <= threshold:
            return None

        multiplier = 2 ** max(count - threshold - 1, 0)
        lockout_seconds = min(
            self._parent_login_lockout_base_seconds() * multiplier,
            self._parent_login_lockout_max_seconds(),
        )
        locked_until_iso = self._timestamp_to_iso(time.time() + lockout_seconds)
        try:
            rc.setex(_auth_lockout_key(email), int(lockout_seconds), locked_until_iso)
        except Exception as exc:
            logger.error("Redis lockout SET failed (%s)", exc)
        return locked_until_iso

    def _clear_parent_login_failures(self, *, email: str) -> None:
        """Remove failure counter and lockout key on successful login."""
        rc = get_redis_client()
        if rc is None:
            _FAILED_LOGIN_ATTEMPTS.pop(email, None)
            _LOGIN_LOCKOUTS.pop(email, None)
            return
        try:
            rc.delete(_auth_failed_key(email), _auth_lockout_key(email))
        except Exception as exc:
            logger.error("Redis failure-key DELETE failed (%s)", exc)

    def register_parent(self, payload: RegisterIn, db: Session) -> dict:
        require_registration_enabled(db)
        normalized_email = normalize_email(payload.email)
        validate_email_domain(normalized_email)

        if payload.password != payload.confirm_password:
            raise HTTPException(status_code=400, detail=AuthMessages.PASSWORDS_DO_NOT_MATCH)

        is_valid, error_msg = core_validate_password_policy(payload.password)
        if not is_valid:
            raise HTTPException(status_code=422, detail=error_msg)

        existing_user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if existing_user and self._user_has_verified_email(existing_user):
            raise HTTPException(status_code=400, detail=AuthMessages.EMAIL_ALREADY_REGISTERED)

        otp_code = self._generate_email_otp()
        now = db_utc_now()

        if existing_user:
            user = existing_user
            user.name = payload.name
            user.password_hash = hash_password(payload.password)
            user.is_active = False
            user.email_verified = False
            user.email_verified_at = None
            self._store_email_otp(user=user, otp_code=otp_code)
        else:
            user = User(
                email=normalized_email,
                password_hash=hash_password(payload.password),
                role="parent",
                name=payload.name,
                is_active=False,
                email_verified=False,
                plan=PLAN_FREE,
                created_at=now,
                updated_at=now,
            )
            self._store_email_otp(user=user, otp_code=otp_code)
            db.add(user)

        db.commit()
        db.refresh(user)

        try:
            self._send_email_otp(email=user.email, name=user.name, otp_code=otp_code)
        except Exception as exc:
            logger.error(
                "Failed to send registration OTP to %s: %s", user.email, exc, exc_info=True
            )
            raise HTTPException(status_code=503, detail=AuthMessages.OTP_SEND_FAILED)

        return self._pending_verification_payload(
            user,
            message="Registration successful. Verify your email with the OTP we sent.",
        )

    def login_parent(self, payload: LoginIn, db: Session) -> dict:
        normalized_email = normalize_email(payload.email)
        validate_email_domain(normalized_email)
        locked_until = self._current_parent_login_lockout(email=normalized_email)
        if locked_until is not None:
            raise HTTPException(
                status_code=423,
                detail={
                    "code": "PARENT_AUTH_TEMP_LOCKED",
                    "message": AuthMessages.PARENT_AUTH_TEMP_LOCKED,
                    "locked_until": locked_until,
                },
            )

        user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if not user or not verify_password(payload.password, user.password_hash):
            locked_until = self._record_parent_login_failure(email=normalized_email)
            if locked_until is not None:
                raise HTTPException(
                    status_code=423,
                    detail={
                        "code": "PARENT_AUTH_TEMP_LOCKED",
                        "message": AuthMessages.PARENT_AUTH_TEMP_LOCKED,
                        "locked_until": locked_until,
                    },
                )
            raise HTTPException(status_code=401, detail=AuthMessages.INVALID_CREDENTIALS)

        if not self._user_has_verified_email(user) or not bool(getattr(user, "is_active", False)):
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "EMAIL_VERIFICATION_REQUIRED",
                    "message": AuthMessages.EMAIL_VERIFICATION_REQUIRED,
                    "email": user.email,
                    "resend_available_at": self._otp_resend_available_at(user),
                },
            )

        self._clear_parent_login_failures(email=normalized_email)
        two_factor_service.require_parent_login_code(account=user, code=payload.two_factor_code)
        user.updated_at = db_utc_now()
        db.add(user)
        db.commit()
        db.refresh(user)

        return {
            "access_token": create_access_token(str(user.id), user.token_version),
            "refresh_token": create_refresh_token(str(user.id), user.token_version),
            "token_type": "bearer",
            "user": user_to_json(user),
        }

    def verify_parent_email_otp(self, payload: VerifyEmailOtpIn, db: Session) -> dict:
        normalized_email = normalize_email(payload.email)
        user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if user is None:
            raise HTTPException(status_code=404, detail=AuthMessages.USER_NOT_FOUND)
        if self._user_has_verified_email(user):
            return {
                "access_token": create_access_token(str(user.id), user.token_version),
                "refresh_token": create_refresh_token(str(user.id), user.token_version),
                "token_type": "bearer",
                "user": user_to_json(user),
            }
        if self._otp_expired(user) or not getattr(user, "email_otp_hash", None):
            raise HTTPException(status_code=400, detail=AuthMessages.INVALID_OR_EXPIRED_OTP)
        if not verify_password(payload.otp, user.email_otp_hash):
            raise HTTPException(status_code=400, detail=AuthMessages.INVALID_OR_EXPIRED_OTP)

        user.email_verified = True
        user.email_verified_at = db_utc_now()
        user.is_active = True
        self._clear_email_otp(user)
        db.add(user)
        db.commit()
        db.refresh(user)

        return {
            "access_token": create_access_token(str(user.id), user.token_version),
            "refresh_token": create_refresh_token(str(user.id), user.token_version),
            "token_type": "bearer",
            "user": user_to_json(user),
        }

    def resend_parent_email_otp(self, payload: ResendEmailOtpIn, db: Session) -> dict:
        normalized_email = normalize_email(payload.email)
        user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if user is None:
            raise HTTPException(status_code=404, detail=AuthMessages.USER_NOT_FOUND)
        if self._user_has_verified_email(user):
            raise HTTPException(status_code=400, detail=AuthMessages.EMAIL_VERIFIED_SUCCESSFULLY)
        if not self._otp_can_be_resent(user):
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "OTP_RESEND_COOLDOWN",
                    "message": AuthMessages.OTP_RESEND_COOLDOWN,
                    "resend_available_at": self._otp_resend_available_at(user),
                },
            )

        otp_code = self._generate_email_otp()
        self._store_email_otp(user=user, otp_code=otp_code)
        db.add(user)
        db.commit()
        db.refresh(user)

        try:
            self._send_email_otp(email=user.email, name=user.name, otp_code=otp_code)
        except Exception as exc:
            logger.error(
                "Failed to resend registration OTP to %s: %s", user.email, exc, exc_info=True
            )
            raise HTTPException(status_code=503, detail=AuthMessages.OTP_SEND_FAILED)

        return {
            "success": True,
            "message": AuthMessages.OTP_RESENT_SUCCESSFULLY,
            "email": user.email,
            "otp_expires_at": ensure_utc(user.email_otp_expires_at).isoformat(),
            "resend_available_at": self._otp_resend_available_at(user),
        }

    def two_factor_status(self, *, user: User) -> dict[str, Any]:
        return two_factor_service.status_payload(account=user)

    def two_factor_setup(self, *, db: Session, user: User) -> dict[str, Any]:
        payload = two_factor_service.setup_totp(account=user)
        user.updated_at = db_utc_now()
        db.add(user)
        db.commit()
        db.refresh(user)
        return payload

    def enable_two_factor(self, *, db: Session, user: User, code: str | None) -> dict[str, Any]:
        payload = two_factor_service.enable_totp(account=user, code=code)
        user.updated_at = db_utc_now()
        db.add(user)
        db.commit()
        db.refresh(user)
        return payload

    def disable_two_factor(self, *, db: Session, user: User) -> dict[str, Any]:
        payload = two_factor_service.disable_two_factor(account=user)
        user.updated_at = db_utc_now()
        db.add(user)
        db.commit()
        db.refresh(user)
        return payload

    def refresh_parent_access_token(self, payload: RefreshIn, db: Session) -> dict:
        try:
            decoded = decode_token(payload.refresh_token)
            user_id = decoded.get("sub")
            token_version = decoded.get("token_version", 0)
        except JWTError:
            raise HTTPException(status_code=401, detail=AuthMessages.INVALID_REFRESH_TOKEN)

        user = db.query(User).filter(User.id == int(user_id)).first()
        if not user:
            raise HTTPException(status_code=401, detail=AuthMessages.INVALID_REFRESH_TOKEN)
        if int(token_version) != int(getattr(user, "token_version", 0)):
            raise HTTPException(status_code=401, detail=AuthMessages.INVALID_REFRESH_TOKEN)

        return {
            "access_token": create_access_token(str(user_id), user.token_version),
            "token_type": "bearer",
        }

    def update_profile(self, *, payload: Any, db: Session, user: User) -> dict:
        try:
            user.name = payload.name
            db.add(user)
            db.commit()
            db.refresh(user)
            logger.info("Profile updated for user %s", user.id)
            return {"user": user_to_json(user)}
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error updating profile for user %s: %s",
                user.id,
                str(exc),
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_UPDATE_PROFILE)

    def change_password(self, *, payload: Any, db: Session, user: User) -> dict:
        user_id = user.id
        logger.debug("Change password request from user %s", user_id)

        try:
            if not verify_password(payload.current_password, user.password_hash):
                logger.warning("Invalid current password attempt for user %s", user_id)
                raise HTTPException(
                    status_code=401,
                    detail=AuthMessages.CURRENT_PASSWORD_IS_INCORRECT,
                )

            is_valid, error_msg = core_validate_password_policy(payload.new_password)
            if not is_valid:
                logger.debug(
                    "Password policy validation failed for user %s: %s",
                    user_id,
                    error_msg,
                )
                raise HTTPException(status_code=422, detail=error_msg)

            if payload.new_password != payload.confirm_password:
                logger.debug("Password confirmation mismatch for user %s", user_id)
                raise HTTPException(
                    status_code=400,
                    detail=AuthMessages.NEW_PASSWORD_CONFIRMATION_DOES_NOT_MATCH,
                )

            user.password_hash = hash_password(payload.new_password)
            user.token_version = (user.token_version or 0) + 1
            db.add(user)
            db.commit()
            db.refresh(user)

            logger.info("Password changed successfully for user %s", user_id)
            return {
                "success": True,
                "message": AuthMessages.PASSWORD_CHANGED_SUCCESSFULLY,
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as exc:
            db.rollback()
            logger.error(
                "Unexpected error changing password for user %s: %s",
                user_id,
                str(exc),
                exc_info=True,
            )
            raise HTTPException(
                status_code=500,
                detail=AuthMessages.FAILED_CHANGE_PASSWORD,
            )

    def logout(self, *, db: Session, user: User) -> dict:
        try:
            user.token_version = (user.token_version or 0) + 1
            db.add(user)
            db.commit()
            db.refresh(user)
            return {"success": True}
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error during logout for user %s: %s",
                user.id,
                str(exc),
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_LOGOUT)

    @staticmethod
    def _validate_parent_pin_format(pin: str) -> None:
        validate_pin_format(pin, length=PARENT_PIN_LENGTH)

    @staticmethod
    def _locked_until_iso(user: User) -> str | None:
        locked_until = getattr(user, "parent_pin_locked_until", None)
        if locked_until is None:
            return None
        return ensure_utc(locked_until).isoformat()

    def _is_parent_pin_locked(self, user: User) -> bool:
        locked_until = getattr(user, "parent_pin_locked_until", None)
        return locked_until is not None and ensure_utc(locked_until) > utc_now()

    @staticmethod
    def _reset_parent_pin_failures(user: User) -> None:
        user.parent_pin_failed_attempts = 0
        user.parent_pin_locked_until = None

    def _increment_parent_pin_failures(self, user: User) -> str | None:
        failed_attempts = int(getattr(user, "parent_pin_failed_attempts", 0) or 0) + 1
        user.parent_pin_failed_attempts = failed_attempts
        if failed_attempts >= PARENT_PIN_MAX_ATTEMPTS:
            user.parent_pin_locked_until = db_utc_now() + timedelta(
                minutes=PARENT_PIN_LOCKOUT_MINUTES
            )
            return self._locked_until_iso(user)
        return None

    def get_parent_pin_status(self, *, user: User) -> dict:
        return {
            "has_pin": bool(getattr(user, "parent_pin_hash", None)),
            "is_locked": self._is_parent_pin_locked(user),
            "failed_attempts": int(getattr(user, "parent_pin_failed_attempts", 0) or 0),
            "locked_until": self._locked_until_iso(user),
        }

    def set_parent_pin(self, *, payload: Any, db: Session, user: User) -> dict:
        if getattr(user, "parent_pin_hash", None):
            raise HTTPException(
                status_code=400,
                detail=AuthMessages.PARENT_PIN_ALREADY_EXISTS,
            )

        self._validate_parent_pin_format(payload.pin)
        self._validate_parent_pin_format(payload.confirm_pin)
        if payload.pin != payload.confirm_pin:
            raise HTTPException(
                status_code=400, detail=AuthMessages.PIN_CONFIRMATION_DOES_NOT_MATCH
            )

        try:
            user.parent_pin_hash = hash_password(payload.pin)
            user.parent_pin_updated_at = db_utc_now()
            self._reset_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)
            return {
                "success": True,
                "message": AuthMessages.PARENT_PIN_CREATED_SUCCESSFULLY,
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error setting parent PIN for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_SET_PARENT_PIN)

    def verify_parent_pin(self, *, payload: Any, db: Session, user: User) -> dict:
        self._validate_parent_pin_format(payload.pin)

        if not getattr(user, "parent_pin_hash", None):
            raise HTTPException(status_code=404, detail=AuthMessages.PARENT_PIN_NOT_CONFIGURED)

        if self._is_parent_pin_locked(user):
            raise HTTPException(
                status_code=423,
                detail={
                    "message": AuthMessages.PARENT_PIN_TEMPORARILY_LOCKED,
                    "locked_until": self._locked_until_iso(user),
                },
            )

        try:
            if verify_password(payload.pin, user.parent_pin_hash):
                self._reset_parent_pin_failures(user)
                db.add(user)
                db.commit()
                db.refresh(user)
                return {
                    "success": True,
                    "message": "Parent PIN verified successfully",
                }

            locked_until = self._increment_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)

            if locked_until is not None:
                raise HTTPException(
                    status_code=423,
                    detail={
                        "message": AuthMessages.PARENT_PIN_TOO_MANY_INVALID_ATTEMPTS,
                        "locked_until": locked_until,
                    },
                )

            raise HTTPException(status_code=401, detail=AuthMessages.INCORRECT_PIN)
        except HTTPException:
            raise
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error verifying parent PIN for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_VERIFY_PARENT_PIN)

    def change_parent_pin(self, *, payload: Any, db: Session, user: User) -> dict:
        if not getattr(user, "parent_pin_hash", None):
            raise HTTPException(status_code=404, detail=AuthMessages.PARENT_PIN_NOT_CONFIGURED)

        self._validate_parent_pin_format(payload.current_pin)
        self._validate_parent_pin_format(payload.new_pin)
        self._validate_parent_pin_format(payload.confirm_pin)
        if payload.new_pin != payload.confirm_pin:
            raise HTTPException(
                status_code=400, detail=AuthMessages.PIN_CONFIRMATION_DOES_NOT_MATCH
            )
        if payload.current_pin == payload.new_pin:
            raise HTTPException(status_code=400, detail=AuthMessages.NEW_PIN_MUST_BE_DIFFERENT)
        if not verify_password(payload.current_pin, user.parent_pin_hash):
            raise HTTPException(status_code=401, detail=AuthMessages.CURRENT_PIN_IS_INCORRECT)

        try:
            user.parent_pin_hash = hash_password(payload.new_pin)
            user.parent_pin_updated_at = db_utc_now()
            self._reset_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)
            return {
                "success": True,
                "message": AuthMessages.PARENT_PIN_CHANGED_SUCCESSFULLY,
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error changing parent PIN for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_CHANGE_PARENT_PIN)

    def request_parent_pin_reset(self, *, payload: Any, db: Session, user: User) -> dict:
        note = (payload.note or "").strip()
        message = AuthMessages.PARENT_PIN_RESET_REQUEST_MESSAGE
        if note:
            message = f"{message}\n\nParent note: {note}"

        try:
            ticket = SupportTicket(
                user_id=user.id,
                subject=AuthMessages.PARENT_PIN_RESET_REQUEST_SUBJECT,
                message=message,
                email=user.email,
                status="open",
            )
            db.add(ticket)
            db.commit()
            db.refresh(ticket)
            return {
                "success": True,
                "message": AuthMessages.PARENT_PIN_RESET_REQUEST_CREATED,
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error creating parent PIN reset request for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail=AuthMessages.FAILED_REQUEST_PIN_RESET)


auth_service = AuthService()


def refresh_parent_access_token(payload: RefreshIn, db: Session) -> dict:
    return auth_service.refresh_parent_access_token(payload, db)


def validate_password_policy_for_auth(password: str) -> tuple[bool, str]:
    return core_validate_password_policy(password)


def validate_password_policy(password: str) -> tuple[bool, str]:
    return validate_password_policy_for_auth(password)


def update_profile(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.update_profile(payload=payload, db=db, user=user)


def change_password(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.change_password(payload=payload, db=db, user=user)


def logout(*, db: Session, user: User) -> dict:
    return auth_service.logout(db=db, user=user)


def get_parent_pin_status(*, user: User) -> dict:
    return auth_service.get_parent_pin_status(user=user)


def set_parent_pin(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.set_parent_pin(payload=payload, db=db, user=user)


def verify_parent_pin(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.verify_parent_pin(payload=payload, db=db, user=user)


def change_parent_pin(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.change_parent_pin(payload=payload, db=db, user=user)


def request_parent_pin_reset(*, payload: Any, db: Session, user: User) -> dict:
    return auth_service.request_parent_pin_reset(payload=payload, db=db, user=user)


def two_factor_status(*, user: User) -> dict:
    return auth_service.two_factor_status(user=user)


def setup_two_factor(*, db: Session, user: User) -> dict:
    return auth_service.two_factor_setup(db=db, user=user)


def enable_two_factor(*, db: Session, user: User, code: str | None) -> dict:
    return auth_service.enable_two_factor(db=db, user=user, code=code)


def disable_two_factor(*, db: Session, user: User) -> dict:
    return auth_service.disable_two_factor(db=db, user=user)
