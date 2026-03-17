import logging
from datetime import timedelta
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
from core.system_settings import require_registration_enabled
from core.time_utils import db_utc_now, ensure_utc, utc_now
from core.validators import normalize_email, validate_email_domain
from core.validators import validate_password_policy as core_validate_password_policy
from core.validators import validate_pin_format
from models import SupportTicket, User
from plan_service import PLAN_FREE
from schemas.auth import LoginIn, RefreshIn, RegisterIn
from serializers import user_to_json

logger = logging.getLogger(__name__)

PARENT_PIN_LENGTH = 4
PARENT_PIN_MAX_ATTEMPTS = 5
PARENT_PIN_LOCKOUT_MINUTES = 5


class AuthService:
    def register_parent(self, payload: RegisterIn, db: Session) -> dict:
        require_registration_enabled(db)
        normalized_email = normalize_email(payload.email)
        validate_email_domain(normalized_email)

        if payload.password != payload.confirm_password:
            raise HTTPException(status_code=400, detail="Passwords do not match")

        if db.query(User).filter(func.lower(User.email) == normalized_email).first():
            raise HTTPException(status_code=400, detail="Email already registered")

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
        user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if not user or not verify_password(payload.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Invalid credentials")

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

    def refresh_parent_access_token(self, payload: RefreshIn, db: Session) -> dict:
        try:
            decoded = decode_token(payload.refresh_token)
            user_id = decoded.get("sub")
            token_version = decoded.get("token_version", 0)
        except JWTError:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        user = db.query(User).filter(User.id == int(user_id)).first()
        if not user:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        if int(token_version) != int(getattr(user, "token_version", 0)):
            raise HTTPException(status_code=401, detail="Invalid refresh token")

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
            raise HTTPException(status_code=500, detail="Failed to update profile")

    def change_password(self, *, payload: Any, db: Session, user: User) -> dict:
        user_id = user.id
        logger.debug("Change password request from user %s", user_id)

        try:
            if not verify_password(payload.current_password, user.password_hash):
                logger.warning("Invalid current password attempt for user %s", user_id)
                raise HTTPException(
                    status_code=401,
                    detail="Current password is incorrect",
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
                    detail="New password and confirmation do not match",
                )

            user.password_hash = hash_password(payload.new_password)
            user.token_version = (user.token_version or 0) + 1
            db.add(user)
            db.commit()
            db.refresh(user)

            logger.info("Password changed successfully for user %s", user_id)
            return {
                "success": True,
                "message": "Password changed successfully",
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
                detail="Failed to change password. Please try again later.",
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
            raise HTTPException(status_code=500, detail="Failed to logout")

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
                detail="Parent PIN already exists. Use change PIN instead.",
            )

        self._validate_parent_pin_format(payload.pin)
        self._validate_parent_pin_format(payload.confirm_pin)
        if payload.pin != payload.confirm_pin:
            raise HTTPException(status_code=400, detail="PIN confirmation does not match")

        try:
            user.parent_pin_hash = hash_password(payload.pin)
            user.parent_pin_updated_at = db_utc_now()
            self._reset_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)
            return {
                "success": True,
                "message": "Parent PIN created successfully",
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error setting parent PIN for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to set parent PIN")

    def verify_parent_pin(self, *, payload: Any, db: Session, user: User) -> dict:
        self._validate_parent_pin_format(payload.pin)

        if not getattr(user, "parent_pin_hash", None):
            raise HTTPException(status_code=404, detail="Parent PIN is not configured")

        if self._is_parent_pin_locked(user):
            raise HTTPException(
                status_code=423,
                detail={
                    "message": "Parent PIN is temporarily locked",
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
                        "message": "Too many invalid PIN attempts",
                        "locked_until": locked_until,
                    },
                )

            raise HTTPException(status_code=401, detail="Incorrect PIN")
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
            raise HTTPException(status_code=500, detail="Failed to verify parent PIN")

    def change_parent_pin(self, *, payload: Any, db: Session, user: User) -> dict:
        if not getattr(user, "parent_pin_hash", None):
            raise HTTPException(status_code=404, detail="Parent PIN is not configured")

        self._validate_parent_pin_format(payload.current_pin)
        self._validate_parent_pin_format(payload.new_pin)
        self._validate_parent_pin_format(payload.confirm_pin)
        if payload.new_pin != payload.confirm_pin:
            raise HTTPException(status_code=400, detail="PIN confirmation does not match")
        if payload.current_pin == payload.new_pin:
            raise HTTPException(status_code=400, detail="New PIN must be different")
        if not verify_password(payload.current_pin, user.parent_pin_hash):
            raise HTTPException(status_code=401, detail="Current PIN is incorrect")

        try:
            user.parent_pin_hash = hash_password(payload.new_pin)
            user.parent_pin_updated_at = db_utc_now()
            self._reset_parent_pin_failures(user)
            db.add(user)
            db.commit()
            db.refresh(user)
            return {
                "success": True,
                "message": "Parent PIN changed successfully",
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error changing parent PIN for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to change parent PIN")

    def request_parent_pin_reset(self, *, payload: Any, db: Session, user: User) -> dict:
        note = (payload.note or "").strip()
        message = "Parent PIN reset requested."
        if note:
            message = f"{message}\n\nParent note: {note}"

        try:
            ticket = SupportTicket(
                user_id=user.id,
                subject="Parent PIN reset request",
                message=message,
                email=user.email,
                status="open",
            )
            db.add(ticket)
            db.commit()
            db.refresh(ticket)
            return {
                "success": True,
                "message": "Support request created for Parent PIN reset",
            }
        except Exception as exc:
            db.rollback()
            logger.error(
                "Error creating parent PIN reset request for user %s: %s",
                user.id,
                exc,
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to request PIN reset")


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
