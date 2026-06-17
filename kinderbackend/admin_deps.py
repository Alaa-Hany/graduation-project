"""
Admin RBAC dependencies — secure and isolated from normal user auth.
"""

import logging
from typing import Set

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from admin_auth import (
    decode_admin_token,
    ACCESS_TOKEN_TYPE,
)
from core.message_catalog import AdminAuthMessages
from deps import get_db

logger = logging.getLogger(__name__)

_admin_security = HTTPBearer(auto_error=False, bearerFormat="JWT")


# =========================================
# Get Current Admin
# =========================================

def get_current_admin(
    creds: HTTPAuthorizationCredentials = Depends(_admin_security),
    db: Session = Depends(get_db),
):
    from admin_models import AdminUser

    if creds is None or not creds.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.AUTHENTICATION_REQUIRED,
        )

    token = creds.credentials

    # 🔥 Use admin-specific decode
    try:
        payload = decode_admin_token(token)
    except Exception as exc:
        logger.warning("Admin token decode failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.INVALID_OR_EXPIRED_ADMIN_TOKEN,
        )

    # ✅ Ensure it's ACCESS token
    if payload.get("type") != ACCESS_TOKEN_TYPE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type (access required)",
        )

    # ✅ Ensure role
    if payload.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not an admin token",
        )

    admin_id = payload.get("sub")
    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.INVALID_ADMIN_TOKEN_PAYLOAD,
        )

    try:
        admin_id = int(admin_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.INVALID_ADMIN_TOKEN_PAYLOAD,
        )

    admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.ADMIN_ACCOUNT_NOT_FOUND,
        )

    # ✅ Token version check (logout support)
    if int(payload.get("token_version", -1)) != int(admin.token_version or 0):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=AdminAuthMessages.ADMIN_TOKEN_REVOKED,
        )

    # ✅ Active check
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=AdminAuthMessages.ADMIN_DISABLED,
        )

    return admin


# =========================================
# Simple Admin Guard
# =========================================

def require_admin():
    def _check(admin=Depends(get_current_admin)):
        return admin

    return _check


# =========================================
# Permissions
# =========================================

def _get_admin_permissions(admin_id: int, db: Session) -> Set[str]:
    from admin_models import AdminUserRole, Permission, RolePermission

    rows = (
        db.query(Permission.name)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(AdminUserRole, AdminUserRole.role_id == RolePermission.role_id)
        .filter(AdminUserRole.admin_user_id == admin_id)
        .all()
    )

    return {r[0] for r in rows}


def require_permission(permission_name: str):
    def _check(
        admin=Depends(get_current_admin),
        db: Session = Depends(get_db),
    ):
        permissions = _get_admin_permissions(admin.id, db)

        if permission_name not in permissions:
            logger.warning(
                "Admin %s denied (missing %s)",
                admin.email,
                permission_name,
            )

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "PERMISSION_DENIED",
                    "required": permission_name,
                },
            )

        return admin

    return _check


# =========================================
# Runtime Check
# =========================================

def ensure_permission(*, admin, db: Session, permission_name: str) -> None:
    permissions = _get_admin_permissions(admin.id, db)

    if permission_name not in permissions:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "PERMISSION_DENIED",
                "required": permission_name,
            },
        )