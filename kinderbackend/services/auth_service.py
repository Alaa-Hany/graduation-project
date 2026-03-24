import logging
import os
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
from core.system_settings import require_registration_enabled
from core.time_utils import db_utc_now, ensure_utc, utc_now
from core.validators import normalize_email, validate_email_domain
from core.validators import validate_password_policy as core_validate_password_policy
from core.validators import validate_pin_format
from models import SupportTicket, User
from plan_service import PLAN_FREE
from schemas.auth import LoginIn, RefreshIn, RegisterIn
from serializers import user_to_json
from services.two_factor_service import two_factor_service

logger = logging.getLogger(__name__)

PARENT_PIN_LENGTH = 4
PARENT_PIN_MAX_ATTEMPTS = 5
PARENT_PIN_LOCKOUT_MINUTES = 5
_PARENT_LOGIN_FAILED_ATTEMPTS: dict[str, list[float]] = defaultdict(list)
_PARENT_LOGIN_LOCKOUT_UNTIL: dict[str, float] = {}


class AuthService:
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

    def _cleanup_parent_login_attempts(self, key: str) -> None:
        now = time.time()
        window_start = now - self._parent_login_window_seconds()
        _PARENT_LOGIN_FAILED_ATTEMPTS[key] = [
            ts for ts in _PARENT_LOGIN_FAILED_ATTEMPTS[key] if ts > window_start
        ]
        locked_until = _PARENT_LOGIN_LOCKOUT_UNTIL.get(key)
        if locked_until is not None and locked_until <= now:
            _PARENT_LOGIN_LOCKOUT_UNTIL.pop(key, None)

    @staticmethod
    def _timestamp_to_iso(value: float) -> str:
        return datetime.fromtimestamp(value, tz=timezone.utc).isoformat()

    def _current_parent_login_lockout(self, *, email: str) -> str | None:
        key = self._parent_login_attempt_key(email=email)
        self._cleanup_parent_login_attempts(key)
        locked_until = _PARENT_LOGIN_LOCKOUT_UNTIL.get(key)
        if locked_until is None:
            return None
        return self._timestamp_to_iso(locked_until)

    def _record_parent_login_failure(self, *, email: str) -> str | None:
        key = self._parent_login_attempt_key(email=email)
        _PARENT_LOGIN_FAILED_ATTEMPTS[key].append(time.time())
        self._cleanup_parent_login_attempts(key)
        attempts = len(_PARENT_LOGIN_FAILED_ATTEMPTS[key])
        threshold = self._parent_login_max_attempts()
        if attempts <= threshold:
            return None

        multiplier = 2 ** max(attempts - threshold - 1, 0)
        lockout_seconds = min(
            self._parent_login_lockout_base_seconds() * multiplier,
            self._parent_login_lockout_max_seconds(),
        )
        locked_until = time.time() + lockout_seconds
        _PARENT_LOGIN_LOCKOUT_UNTIL[key] = locked_until
        return self._timestamp_to_iso(locked_until)

    def _clear_parent_login_failures(self, *, email: str) -> None:
        key = self._parent_login_attempt_key(email=email)
        _PARENT_LOGIN_FAILED_ATTEMPTS.pop(key, None)
        _PARENT_LOGIN_LOCKOUT_UNTIL.pop(key, None)

    def register_parent(self, payload: RegisterIn, db: Session) -> dict:
        require_registration_enabled(db)
        normalized_email = normalize_email(payload.email)
        validate_email_domain(normalized_email)

        if payload.password != payload.confirm_password:
            raise HTTPException(status_code=400, detail=AuthMessages.PASSWORDS_DO_NOT_MATCH)

        if db.query(User).filter(func.lower(User.email) == normalized_email).first():
            raise HTTPException(status_code=400, detail=AuthMessages.EMAIL_ALREADY_REGISTERED)

        now = db_utc_now()
        user = User(
            email=normalized_email,
            password_hash=hash_password(payload.password),
            role="parent",
            name=payload.name,
            is_active=True,
            plan=PLAN_FREE,
            created_at=now,
            updated_at=now,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        return {
            "access_token": create_access_token(str(user.id), user.token_version),
            "refresh_token": create_refresh_token(str(user.id), user.token_version),
            "token_type": "bearer",
            "user": user_to_json(user),
        }

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


def register_parent(payload: RegisterIn, db: Session) -> dict:
    return auth_service.register_parent(payload, db)


def login_parent(payload: LoginIn, db: Session) -> dict:
    return auth_service.login_parent(payload, db)


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
