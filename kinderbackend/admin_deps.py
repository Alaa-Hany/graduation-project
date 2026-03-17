"""
Admin RBAC dependencies — fully separate from parent/child deps.py.

Usage in routers:
    # Require any active admin
    @router.get("/admin/something")
    def endpoint(admin = Depends(get_current_admin)):
        ...

    # Require a specific permission
    @router.get("/admin/users")
    def endpoint(admin = Depends(require_permission("admin.users.view"))):
        ...
"""

import logging
from typing import Set

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from admin_auth import ADMIN_TOKEN_TYPE
from auth import decode_token
from deps import get_db

logger = logging.getLogger(__name__)

# Separate HTTPBearer instance for admin — keeps Swagger UI clean
_admin_security = HTTPBearer(auto_error=False, bearerFormat="JWT")


def get_current_admin(
    creds: HTTPAuthorizationCredentials = Depends(_admin_security),
    db: Session = Depends(get_db),
):
    """
    Validate an admin JWT and return the AdminUser row.

    Raises 401 if:
      - No token provided
      - Token is invalid / expired
      - token_type claim is not 'admin'
      - Admin row not found

    Raises 403 if:
      - Admin account is disabled (is_active=False)
    """
    # Import here to avoid circular imports at module load time
    from admin_models import AdminUser

    if creds is None or not creds.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authentication required",
        )

    token = creds.credentials
    try:
        payload = decode_token(token)
    except JWTError as exc:
        logger.warning("Admin JWT decode failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired admin token",
        )

    # Enforce token_type separation — admin tokens must carry token_type='admin'
    if payload.get("token_type") != ADMIN_TOKEN_TYPE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token type",
        )

    admin_id_str = payload.get("sub")
    if not admin_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    try:
        admin_id = int(admin_id_str)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    admin = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin account not found",
        )

    token_version = payload.get("token_version")
    try:
        token_version_value = int(token_version)
    except (TypeError, ValueError):
        token_version_value = None
    if token_version_value is None or token_version_value != int(admin.token_version or 0):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin token has been revoked",
        )

    # Disabled admins are blocked even with a valid token
    if not admin.is_active:
        logger.warning("Disabled admin %s attempted access", admin.email)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "ADMIN_DISABLED",
                "message": "This admin account has been disabled",
            },
        )

    return admin


def require_admin():
    """
    Dependency that simply ensures the caller is an active admin.
    Equivalent to Depends(get_current_admin) but expressed as a factory
    for consistency with require_permission().

    Usage:
        @router.get("/admin/dashboard")
        def dashboard(admin = Depends(require_admin())):
            ...
    """

    def _check(admin=Depends(get_current_admin)):
        return admin

    return _check


def _get_admin_permissions(admin_id: int, db: Session) -> Set[str]:
    """
    Return the full set of permission names granted to an admin via their roles.
    Results are NOT cached — suitable for per-request RBAC checks.
    """
    from admin_models import AdminUserRole, Permission, Role, RolePermission

    rows = (
        db.query(Permission.name)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(Role, Role.id == RolePermission.role_id)
        .join(AdminUserRole, AdminUserRole.role_id == Role.id)
        .filter(AdminUserRole.admin_user_id == admin_id)
        .all()
    )
    return {row.name for row in rows}


def require_permission(permission_name: str):
    """
    Dependency factory that checks whether the authenticated admin holds a
    specific permission (via any of their assigned roles).

    Usage:
        @router.get("/admin/users")
        def list_users(admin = Depends(require_permission("admin.users.view"))):
            ...

    Raises:
        401 — if not authenticated as admin
        403 — if authenticated but missing the required permission
    """

    def _check(
        admin=Depends(get_current_admin),
        db: Session = Depends(get_db),
    ):
        permissions = _get_admin_permissions(admin.id, db)
        if permission_name not in permissions:
            logger.warning(
                "Admin %s (id=%s) denied — missing permission '%s'",
                admin.email,
                admin.id,
                permission_name,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "PERMISSION_DENIED",
                    "message": f"Permission '{permission_name}' is required",
                    "required_permission": permission_name,
                },
            )
        return admin

    return _check


def ensure_permission(*, admin, db: Session, permission_name: str) -> None:
    """
    Runtime permission check for conditional admin actions.
    Mirrors require_permission() behavior without FastAPI dependency wiring.
    """
    permissions = _get_admin_permissions(admin.id, db)
    if permission_name not in permissions:
        logger.warning(
            "Admin %s (id=%s) denied - missing permission '%s'",
            admin.email,
            admin.id,
            permission_name,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "PERMISSION_DENIED",
                "message": f"Permission '{permission_name}' is required",
                "required_permission": permission_name,
            },
        )
