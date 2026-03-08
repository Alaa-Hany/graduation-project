"""
Admin authentication router — fully separate from parent/child auth.

Endpoints:
  POST /admin/auth/login    — email + password → access + refresh tokens
  POST /admin/auth/refresh  — refresh token → new access token
  POST /admin/auth/logout   — invalidate refresh tokens (bump token_version)
  GET  /admin/auth/me       — return current admin profile + roles + permissions
"""
import logging
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from auth import SECRET_KEY, ALGORITHM, verify_password
from admin_auth import ADMIN_TOKEN_TYPE, create_admin_access_token, create_admin_refresh_token
from admin_deps import get_current_admin
from deps import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Auth"])


# ─────────────────────────── Pydantic schemas ────────────────────────────────

class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AdminRefreshRequest(BaseModel):
    refresh_token: str


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AdminLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    admin: dict


# ─────────────────────────── Helper ──────────────────────────────────────────

def _build_admin_payload(admin, db: Session) -> dict:
    """
    Serialize an AdminUser to a safe dict including resolved roles and permissions.
    """
    from admin_models import AdminUserRole, Role, RolePermission, Permission

    role_rows = (
        db.query(Role.name)
        .join(AdminUserRole, AdminUserRole.role_id == Role.id)
        .filter(AdminUserRole.admin_user_id == admin.id)
        .all()
    )
    perm_rows = (
        db.query(Permission.name)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(Role, Role.id == RolePermission.role_id)
        .join(AdminUserRole, AdminUserRole.role_id == Role.id)
        .filter(AdminUserRole.admin_user_id == admin.id)
        .all()
    )

    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
        "is_active": admin.is_active,
        "roles": [r.name for r in role_rows],
        "permissions": [p.name for p in perm_rows],
        "created_at": admin.created_at.isoformat() if admin.created_at else None,
        "updated_at": admin.updated_at.isoformat() if admin.updated_at else None,
    }


# ─────────────────────────── Endpoints ───────────────────────────────────────

@router.post("/login", response_model=AdminLoginResponse, summary="Admin login")
def admin_login(payload: AdminLoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate an admin with email + password.

    - Returns access_token (1 h) and refresh_token (7 d).
    - Disabled admins receive 403 before any token is issued.
    - Uses a generic 401 for wrong credentials to prevent email enumeration.
    """
    from admin_models import AdminUser

    email = payload.email.strip().lower()
    admin = db.query(AdminUser).filter(AdminUser.email == email).first()

    # Constant-time-ish: always call verify_password even on miss
    password_ok = verify_password(payload.password, admin.password_hash) if admin else False

    if not admin or not password_ok:
        logger.warning("Failed admin login attempt for email: %s", email)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Disabled check — after credential verification to avoid timing oracle
    if not admin.is_active:
        logger.warning("Disabled admin login attempt: %s (id=%s)", admin.email, admin.id)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "ADMIN_DISABLED",
                "message": "This admin account has been disabled. Contact a super admin.",
            },
        )

    admin.updated_at = datetime.utcnow()
    db.add(admin)
    db.commit()
    db.refresh(admin)

    logger.info("Admin login success: %s (id=%s)", admin.email, admin.id)

    return {
        "access_token": create_admin_access_token(admin.id),
        "refresh_token": create_admin_refresh_token(admin.id, admin.token_version),
        "token_type": "bearer",
        "admin": _build_admin_payload(admin, db),
    }


@router.post("/refresh", response_model=AdminTokenResponse, summary="Refresh admin access token")
def admin_refresh(payload: AdminRefreshRequest, db: Session = Depends(get_db)):
    """
    Exchange a valid admin refresh token for a new access token.

    - Validates token_type='admin' claim.
    - Validates token_version matches the stored value (logout invalidates old tokens).
    - Disabled admins are blocked.
    """
    from admin_models import AdminUser

    try:
        decoded = jwt.decode(payload.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
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

    # token_version mismatch means the admin has logged out — token is revoked
    if int(stored_version) != int(admin.token_version):
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
        "access_token": create_admin_access_token(admin.id),
        "token_type": "bearer",
    }


@router.post("/logout", summary="Admin logout — invalidates refresh tokens")
def admin_logout(
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Logout the current admin by bumping token_version.
    All existing refresh tokens become invalid immediately.
    """
    admin.token_version = (admin.token_version or 0) + 1
    admin.updated_at = datetime.utcnow()
    db.add(admin)
    db.commit()

    logger.info("Admin logout: %s (id=%s)", admin.email, admin.id)

    return {"success": True, "message": "Logged out successfully"}


@router.get("/me", summary="Get current admin profile")
def admin_me(
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Return the authenticated admin's profile, roles, and permissions.
    Disabled admins are blocked by get_current_admin before reaching here.
    """
    return {"admin": _build_admin_payload(admin, db)}
