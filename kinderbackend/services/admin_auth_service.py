from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import HTTPException, Request, status
from jose import JWTError
from sqlalchemy.orm import Session

from admin_auth import ADMIN_TOKEN_TYPE, create_admin_access_token, create_admin_refresh_token
from admin_utils import build_admin_payload, write_audit_log
from auth import decode_token, verify_password
from core.settings import settings
from core.time_utils import db_utc_now, ensure_utc, utc_now

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
                    "message": "Too many failed login attempts. Try again later.",
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
                detail="Invalid email or password",
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
                    "message": "This admin account has been disabled. Contact a super admin.",
                },
            )

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
            decoded = decode_token(payload.refresh_token)
        except JWTError as exc:
            logger.warning("Admin refresh token decode failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token",
            )

        if decoded.get("token_type") != ADMIN_TOKEN_TYPE:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token type",
            )

        admin_id_str = decoded.get("sub")
        stored_version = decoded.get("token_version", 0)
        try:
            admin_id = int(admin_id_str)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token payload",
            )

        admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Admin not found",
            )

        try:
            stored_version_value = int(stored_version)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token payload",
            )

        if stored_version_value != int(admin.token_version or 0):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token has been revoked",
            )

        if not admin.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "ADMIN_DISABLED",
                    "message": "This admin account has been disabled",
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
        return {"success": True, "message": "Logged out successfully"}

    def current_profile(self, *, admin, db: Session) -> dict:
        return {"admin": build_admin_payload(admin, db)}


admin_auth_service = AdminAuthService()
