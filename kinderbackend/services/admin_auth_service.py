from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import HTTPException, Request, status
from jose import JWTError
from sqlalchemy.orm import Session

from admin_auth import (
    REFRESH_TOKEN_TYPE,
    create_admin_access_token,
    create_admin_refresh_token,
    decode_admin_token,
)
from admin_utils import build_admin_payload, write_audit_log
from auth import decode_token, verify_password
from core.message_catalog import AdminAuthMessages
from core.settings import settings
from core.time_utils import db_utc_now, ensure_utc, utc_now
from services.two_factor_service import two_factor_service

logger = logging.getLogger(__name__)


class AdminAuthService:
    def login(self, *, payload, request: Request, db: Session) -> dict:
        from admin_models import AdminUser

        email = payload.email.strip().lower()
        admin = db.query(AdminUser).filter(AdminUser.email == email).first()
        now = db_utc_now()
        client_host = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent")

        if admin and admin.locked_until and ensure_utc(admin.locked_until) > utc_now():
            write_audit_log(
                db=db,
                request=request,
                admin=admin,
                action="admin_auth.login_locked",
                entity_type="admin_user",
                entity_id=admin.id,
                before_json=None,
                after_json={
                    "email": email,
                    "locked_until": ensure_utc(admin.locked_until).isoformat(),
                    "failed_login_attempts": int(admin.failed_login_attempts or 0),
                },
            )
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_423_LOCKED,
                detail={
                    "code": "ADMIN_TEMP_LOCKED",
                    "message": AdminAuthMessages.ADMIN_TEMP_LOCKED,
                    "locked_until": ensure_utc(admin.locked_until).isoformat(),
                },
            )

        password_ok = verify_password(payload.password, admin.password_hash) if admin else False
        if not admin or not password_ok:
            logger.warning("Failed admin login attempt for email: %s", email)
            failure_entity_type = "admin_auth"
            failure_entity_id = email

            if admin is not None:
                admin.failed_login_attempts = int(admin.failed_login_attempts or 0) + 1
                admin.last_failed_login_at = now
                admin.last_failed_login_ip = client_host
                admin.last_failed_login_user_agent = user_agent

                if admin.failed_login_attempts >= settings.admin_suspicious_failed_threshold:
                    admin.suspicious_access_count = int(admin.suspicious_access_count or 0) + 1
                    admin.is_flagged_suspicious = True

                if admin.failed_login_attempts >= settings.admin_auth_max_failed_attempts:
                    admin.locked_until = now + timedelta(
                        minutes=settings.admin_auth_lockout_minutes
                    )

                admin.updated_at = now
                db.add(admin)
                failure_entity_type = "admin_user"
                failure_entity_id = str(admin.id)

            write_audit_log(
                db=db,
                request=request,
                admin=admin,
                action="admin_auth.login_failed",
                entity_type=failure_entity_type,
                entity_id=failure_entity_id,
                before_json=None,
                after_json={
                    "email": email,
                    "ip_address": client_host,
                    "user_agent": user_agent,
                    "failed_login_attempts": int(getattr(admin, "failed_login_attempts", 0) or 0),
                    "locked_until": (
                        ensure_utc(admin.locked_until).isoformat()
                        if admin is not None and admin.locked_until
                        else None
                    ),
                },
            )
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.INVALID_EMAIL_OR_PASSWORD,
            )

        if not admin.is_active:
            logger.warning("Disabled admin login attempt: %s (id=%s)", admin.email, admin.id)
            write_audit_log(
                db=db,
                request=request,
                admin=admin,
                action="admin_auth.login_disabled",
                entity_type="admin_user",
                entity_id=admin.id,
                before_json=None,
                after_json={"id": admin.id, "email": admin.email, "is_active": admin.is_active},
            )
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "ADMIN_DISABLED",
                    "message": AdminAuthMessages.ADMIN_DISABLED_CONTACT_SUPER_ADMIN,
                },
            )

        two_factor_service.require_admin_login_code(account=admin, code=payload.two_factor_code)
        suspicious_ip_change = bool(
            admin.last_login_ip and client_host and admin.last_login_ip != client_host
        )
        if suspicious_ip_change:
            admin.suspicious_access_count = int(admin.suspicious_access_count or 0) + 1
            admin.is_flagged_suspicious = True

        admin.last_login_at = now
        admin.last_login_ip = client_host
        admin.last_login_user_agent = user_agent
        admin.failed_login_attempts = 0
        admin.locked_until = None
        admin.updated_at = now
        db.add(admin)
        db.commit()
        db.refresh(admin)

        logger.info("Admin login success: %s (id=%s)", admin.email, admin.id)
        write_audit_log(
            db=db,
            request=request,
            admin=admin,
            action="admin_auth.login",
            entity_type="admin_user",
            entity_id=admin.id,
            before_json=None,
            after_json={"id": admin.id, "email": admin.email, "is_active": admin.is_active},
        )
        if suspicious_ip_change:
            write_audit_log(
                db=db,
                request=request,
                admin=admin,
                action="admin_auth.suspicious_ip_change",
                entity_type="admin_user",
                entity_id=admin.id,
                before_json=None,
                after_json={
                    "id": admin.id,
                    "email": admin.email,
                    "last_login_ip": admin.last_login_ip,
                    "suspicious_access_count": int(admin.suspicious_access_count or 0),
                },
            )
        db.commit()
        db.refresh(admin)

        return {
            "access_token": create_admin_access_token(admin.id, admin.token_version),
            "refresh_token": create_admin_refresh_token(admin.id, admin.token_version),
            "token_type": "bearer",
            "admin": build_admin_payload(admin, db),
        }

    def refresh(self, *, payload, db: Session) -> dict:
        from admin_models import AdminUser

        try:
            decoded = decode_admin_token(payload.refresh_token)
        except Exception as exc:
            logger.warning("Admin refresh token decode failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.INVALID_OR_EXPIRED_REFRESH_TOKEN,
            )

        if decoded.get("role") != "admin" or decoded.get("type") != REFRESH_TOKEN_TYPE:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.INVALID_REFRESH_TOKEN_TYPE,
            )

        admin_id_str = decoded.get("sub")
        stored_version = decoded.get("token_version", 0)
        try:
            admin_id = int(admin_id_str)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.INVALID_REFRESH_TOKEN_PAYLOAD,
            )

        admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.ADMIN_ACCOUNT_NOT_FOUND,
            )

        try:
            stored_version_value = int(stored_version)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.INVALID_REFRESH_TOKEN_PAYLOAD,
            )

        if stored_version_value != int(admin.token_version or 0):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=AdminAuthMessages.REFRESH_TOKEN_REVOKED,
            )

        if not admin.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "ADMIN_DISABLED",
                    "message": AdminAuthMessages.ADMIN_DISABLED,
                },
            )

        return {
            "access_token": create_admin_access_token(admin.id, admin.token_version),
            "token_type": "bearer",
        }

    def logout(self, *, request: Request, admin, db: Session) -> dict:
        previous_version = int(admin.token_version or 0)
        admin.token_version = previous_version + 1
        admin.updated_at = db_utc_now()
        db.add(admin)
        write_audit_log(
            db=db,
            request=request,
            admin=admin,
            action="admin_auth.logout",
            entity_type="admin_user",
            entity_id=admin.id,
            before_json={"id": admin.id, "token_version": previous_version},
            after_json={"id": admin.id, "token_version": admin.token_version},
        )
        db.commit()

        logger.info("Admin logout: %s (id=%s)", admin.email, admin.id)
        return {"success": True, "message": AdminAuthMessages.LOGGED_OUT_SUCCESSFULLY}

    def current_profile(self, *, admin, db: Session) -> dict:
        return {"admin": build_admin_payload(admin, db)}

    def two_factor_status(self, *, admin) -> dict:
        return two_factor_service.status_payload(account=admin)

    def two_factor_setup(self, *, admin, db: Session) -> dict:
        payload = two_factor_service.setup_totp(account=admin)
        admin.updated_at = db_utc_now()
        db.add(admin)
        db.commit()
        db.refresh(admin)
        return payload

    def enable_two_factor(self, *, admin, code: str | None, db: Session) -> dict:
        payload = two_factor_service.enable_totp(account=admin, code=code)
        admin.updated_at = db_utc_now()
        db.add(admin)
        db.commit()
        db.refresh(admin)
        return payload

    def disable_two_factor(self, *, admin, db: Session) -> dict:
        payload = two_factor_service.disable_two_factor(account=admin)
        admin.updated_at = db_utc_now()
        db.add(admin)
        db.commit()
        db.refresh(admin)
        return payload


admin_auth_service = AdminAuthService()
