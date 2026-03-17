"""
Admin seed router.

Provides a single idempotent endpoint:
  POST /admin/seed?secret=kinder_admin_seed_2024

It seeds:
  - permissions
  - roles
  - role-permission mappings
  - one default super admin
"""

import os

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import hash_password
from core.admin_rbac import PERMISSION_DEFS, ROLE_DEFS
from core.time_utils import db_utc_now
from deps import get_db

router = APIRouter(prefix="/admin", tags=["Admin Seed"])

SEED_ENABLED = os.getenv("ENABLE_ADMIN_SEED_ENDPOINT", "").strip().lower() in {
    "1",
    "true",
    "yes",
}
SEED_SECRET = os.getenv("ADMIN_SEED_SECRET", "").strip()

DEFAULT_ADMIN_EMAIL = os.getenv("ADMIN_SEED_EMAIL", "admin@kinderworld.app").strip()
DEFAULT_ADMIN_PASSWORD = os.getenv("ADMIN_SEED_PASSWORD", "").strip()
DEFAULT_ADMIN_NAME = os.getenv("ADMIN_SEED_NAME", "Super Admin").strip() or "Super Admin"


@router.post("/seed", summary="Seed admin roles, permissions, and default super admin")
def seed_admin_system(secret: str, db: Session = Depends(get_db)):
    if not SEED_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin seed endpoint is disabled",
        )
    if not SEED_SECRET:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin seed secret is not configured",
        )
    if not DEFAULT_ADMIN_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin seed password is not configured",
        )
    if secret != SEED_SECRET:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid seed secret",
        )

    from admin_models import AdminUser, AdminUserRole, Permission, Role, RolePermission

    created_permissions = 0
    created_roles = 0
    created_role_permissions = 0
    removed_role_permissions = 0
    created_admins = 0
    created_admin_role_links = 0
    updated_admins = 0

    permission_by_name: dict[str, Permission] = {}
    for permission_name, description in PERMISSION_DEFS:
        permission = db.query(Permission).filter(Permission.name == permission_name).first()
        if permission is None:
            permission = Permission(name=permission_name, description=description)
            db.add(permission)
            db.flush()
            created_permissions += 1
        elif permission.description != description:
            permission.description = description
            db.add(permission)
        permission_by_name[permission_name] = permission

    role_by_name: dict[str, Role] = {}
    for role_name, permission_names in ROLE_DEFS.items():
        role = db.query(Role).filter(Role.name == role_name).first()
        if role is None:
            role = Role(
                name=role_name,
                description=f"Built-in role: {role_name}",
            )
            db.add(role)
            db.flush()
            created_roles += 1
        elif role.description != f"Built-in role: {role_name}":
            role.description = f"Built-in role: {role_name}"
            db.add(role)
        role_by_name[role_name] = role

        expected_permission_ids = {
            permission_by_name[permission_name].id for permission_name in permission_names
        }
        existing_mappings = db.query(RolePermission).filter(RolePermission.role_id == role.id).all()
        for mapping in existing_mappings:
            if mapping.permission_id not in expected_permission_ids:
                db.delete(mapping)
                removed_role_permissions += 1

        for permission_name in permission_names:
            permission = permission_by_name[permission_name]
            mapping = (
                db.query(RolePermission)
                .filter(
                    RolePermission.role_id == role.id,
                    RolePermission.permission_id == permission.id,
                )
                .first()
            )
            if mapping is None:
                db.add(
                    RolePermission(
                        role_id=role.id,
                        permission_id=permission.id,
                    )
                )
                created_role_permissions += 1

    admin = db.query(AdminUser).filter(AdminUser.email == DEFAULT_ADMIN_EMAIL).first()

    if admin is None:
        now = db_utc_now()
        admin = AdminUser(
            email=DEFAULT_ADMIN_EMAIL,
            password_hash=hash_password(DEFAULT_ADMIN_PASSWORD),
            name=DEFAULT_ADMIN_NAME,
            is_active=True,
            token_version=0,
            created_at=now,
            updated_at=now,
        )
        db.add(admin)
        db.flush()
        created_admins += 1
    else:
        admin_changed = False
        if not admin.is_active:
            admin.is_active = True
            admin_changed = True
        if not admin.name:
            admin.name = DEFAULT_ADMIN_NAME
            admin_changed = True
        if admin_changed:
            admin.updated_at = db_utc_now()
            db.add(admin)
            updated_admins += 1

    super_admin_role = role_by_name["super_admin"]
    admin_role_link = (
        db.query(AdminUserRole)
        .filter(
            AdminUserRole.admin_user_id == admin.id,
            AdminUserRole.role_id == super_admin_role.id,
        )
        .first()
    )
    if admin_role_link is None:
        db.add(AdminUserRole(admin_user_id=admin.id, role_id=super_admin_role.id))
        created_admin_role_links += 1

    db.commit()

    return {
        "success": True,
        "message": "Admin seed completed",
        "summary": {
            "permissions_created": created_permissions,
            "roles_created": created_roles,
            "role_permission_mappings_created": created_role_permissions,
            "role_permission_mappings_removed": removed_role_permissions,
            "admins_created": created_admins,
            "admin_role_links_created": created_admin_role_links,
            "admins_updated": updated_admins,
        },
        "default_admin": {
            "email": DEFAULT_ADMIN_EMAIL,
            "password_set": created_admins > 0,
            "is_active": True,
        },
    }
