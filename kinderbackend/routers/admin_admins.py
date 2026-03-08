from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import (
    build_admin_payload,
    build_pagination_payload,
    permission_group_name,
    serialize_admin_user,
    serialize_permission,
    serialize_role,
    write_audit_log,
)
from auth import hash_password
from deps import get_db
from routers.admin_seed import ROLE_DEFS

from admin_models import AdminUser, AdminUserRole, Permission, Role, RolePermission

router = APIRouter(prefix="/admin", tags=["Admin RBAC"])

BUILT_IN_ROLE_NAMES = set(ROLE_DEFS.keys())


class AdminUserCreateRequest(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None
    role_ids: list[int] = []


class AdminUserUpdateRequest(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    password: Optional[str] = None


class RoleAssignmentRequest(BaseModel):
    role_id: int


class RoleCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None


class RoleUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class RolePermissionsUpdateRequest(BaseModel):
    permission_ids: list[int]


def _admin_query(db: Session):
    return db.query(AdminUser).options(
        joinedload(AdminUser.admin_user_roles)
        .joinedload(AdminUserRole.role)
        .joinedload(Role.role_permissions)
        .joinedload(RolePermission.permission)
    )


def _roles_query(db: Session):
    return db.query(Role).options(
        joinedload(Role.role_permissions).joinedload(RolePermission.permission),
        joinedload(Role.admin_user_roles),
    )


def _permissions_query(db: Session):
    return db.query(Permission)


def _get_admin_user_or_404(admin_user_id: int, db: Session) -> AdminUser:
    item = _admin_query(db).filter(AdminUser.id == admin_user_id).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Admin user not found")
    return item


def _get_role_or_404(role_id: int, db: Session) -> Role:
    role = _roles_query(db).filter(Role.id == role_id).first()
    if role is None:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


def _get_permission_or_404(permission_id: int, db: Session) -> Permission:
    permission = _permissions_query(db).filter(Permission.id == permission_id).first()
    if permission is None:
        raise HTTPException(status_code=404, detail="Permission not found")
    return permission


def _admin_has_role(admin: AdminUser, role_name: str) -> bool:
    return any(link.role and link.role.name == role_name for link in (admin.admin_user_roles or []))


def _active_super_admin_count(db: Session) -> int:
    return (
        db.query(func.count(AdminUser.id))
        .join(AdminUserRole, AdminUserRole.admin_user_id == AdminUser.id)
        .join(Role, Role.id == AdminUserRole.role_id)
        .filter(AdminUser.is_active.is_(True), Role.name == "super_admin")
        .scalar()
        or 0
    )


def _ensure_not_last_super_admin(target: AdminUser, db: Session):
    if _admin_has_role(target, "super_admin") and _active_super_admin_count(db) <= 1:
        raise HTTPException(
            status_code=400,
            detail="The last active super admin cannot be disabled or stripped of the super_admin role",
        )


def _ensure_unique_admin_email(email: str, db: Session, *, exclude_admin_id: int | None = None):
    query = db.query(AdminUser).filter(func.lower(AdminUser.email) == email.strip().lower())
    if exclude_admin_id is not None:
        query = query.filter(AdminUser.id != exclude_admin_id)
    if query.first() is not None:
        raise HTTPException(status_code=400, detail="Admin email already in use")


@router.get("/admin-users")
def list_admin_users(
    search: str = Query(""),
    status_filter: str = Query("all", alias="status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    query = _admin_query(db)

    if search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(AdminUser.email).like(term)
            | func.lower(func.coalesce(AdminUser.name, "")).like(term)
        )

    normalized_status = status_filter.strip().lower()
    if normalized_status == "active":
        query = query.filter(AdminUser.is_active.is_(True))
    elif normalized_status in {"disabled", "inactive"}:
        query = query.filter(AdminUser.is_active.is_(False))

    total = query.count()
    items = (
        query.order_by(AdminUser.created_at.desc(), AdminUser.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_admin_user(item, db) for item in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {"search": search, "status": normalized_status},
    }


@router.get("/admin-users/{admin_user_id}")
def get_admin_user(
    admin_user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    return {"item": serialize_admin_user(item, db)}


@router.post("/admin-users")
def create_admin_user(
    payload: AdminUserCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    if len(payload.password.strip()) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")

    normalized_email = payload.email.strip().lower()
    _ensure_unique_admin_email(normalized_email, db)

    role_ids = sorted({role_id for role_id in payload.role_ids})
    roles = [_get_role_or_404(role_id, db) for role_id in role_ids]

    item = AdminUser(
        email=normalized_email,
        password_hash=hash_password(payload.password),
        name=(payload.name or "").strip() or None,
        is_active=True,
        token_version=0,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(item)
    db.flush()

    for role in roles:
        db.add(AdminUserRole(admin_user_id=item.id, role_id=role.id))

    db.flush()
    db.expire_all()
    created = _get_admin_user_or_404(item.id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.create",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=None,
        after_json=serialize_admin_user(created, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(created, db)}


@router.patch("/admin-users/{admin_user_id}")
def update_admin_user(
    admin_user_id: int,
    payload: AdminUserUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    before = serialize_admin_user(item, db)

    if payload.email is not None:
        normalized_email = payload.email.strip().lower()
        _ensure_unique_admin_email(normalized_email, db, exclude_admin_id=item.id)
        item.email = normalized_email

    if payload.name is not None:
        item.name = payload.name.strip() or None

    if payload.password is not None:
        if len(payload.password.strip()) < 8:
            raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
        item.password_hash = hash_password(payload.password)
        item.token_version = (item.token_version or 0) + 1

    item.updated_at = datetime.utcnow()
    db.add(item)
    db.flush()
    db.expire_all()
    refreshed = _get_admin_user_or_404(admin_user_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.update",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=before,
        after_json=serialize_admin_user(refreshed, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(refreshed, db)}


@router.post("/admin-users/{admin_user_id}/disable")
def disable_admin_user(
    admin_user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    if item.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot disable your own admin account")
    _ensure_not_last_super_admin(item, db)
    before = serialize_admin_user(item, db)
    item.is_active = False
    item.token_version = (item.token_version or 0) + 1
    item.updated_at = datetime.utcnow()
    db.add(item)
    db.flush()
    db.expire_all()
    refreshed = _get_admin_user_or_404(admin_user_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.disable",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=before,
        after_json=serialize_admin_user(refreshed, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(refreshed, db)}


@router.post("/admin-users/{admin_user_id}/enable")
def enable_admin_user(
    admin_user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    before = serialize_admin_user(item, db)
    item.is_active = True
    item.updated_at = datetime.utcnow()
    db.add(item)
    db.flush()
    db.expire_all()
    refreshed = _get_admin_user_or_404(admin_user_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.enable",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=before,
        after_json=serialize_admin_user(refreshed, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(refreshed, db)}


@router.post("/admin-users/{admin_user_id}/assign-role")
def assign_admin_role(
    admin_user_id: int,
    payload: RoleAssignmentRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    role = _get_role_or_404(payload.role_id, db)
    before = serialize_admin_user(item, db)

    mapping = (
        db.query(AdminUserRole)
        .filter(AdminUserRole.admin_user_id == item.id, AdminUserRole.role_id == role.id)
        .first()
    )
    if mapping is None:
        db.add(AdminUserRole(admin_user_id=item.id, role_id=role.id))
        item.updated_at = datetime.utcnow()
        db.add(item)

    db.flush()
    db.expire_all()
    refreshed = _get_admin_user_or_404(admin_user_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.assign_role",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=before,
        after_json=serialize_admin_user(refreshed, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(refreshed, db)}


@router.post("/admin-users/{admin_user_id}/remove-role")
def remove_admin_role(
    admin_user_id: int,
    payload: RoleAssignmentRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    item = _get_admin_user_or_404(admin_user_id, db)
    role = _get_role_or_404(payload.role_id, db)
    if item.id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot remove your own roles")
    if role.name == "super_admin":
        _ensure_not_last_super_admin(item, db)

    mapping = (
        db.query(AdminUserRole)
        .filter(AdminUserRole.admin_user_id == item.id, AdminUserRole.role_id == role.id)
        .first()
    )
    if mapping is None:
        raise HTTPException(status_code=404, detail="Role assignment not found")

    before = serialize_admin_user(item, db)
    db.delete(mapping)
    item.updated_at = datetime.utcnow()
    db.add(item)
    db.flush()
    db.expire_all()
    refreshed = _get_admin_user_or_404(admin_user_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="admin_user.remove_role",
        entity_type="admin_user",
        entity_id=item.id,
        before_json=before,
        after_json=serialize_admin_user(refreshed, db),
    )
    db.commit()
    return {"success": True, "item": serialize_admin_user(refreshed, db)}


@router.get("/roles")
def list_roles(
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    items = _roles_query(db).order_by(Role.name.asc()).all()
    return {"items": [serialize_role(item) for item in items]}


@router.get("/roles/{role_id}")
def get_role(
    role_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    role = _get_role_or_404(role_id, db)
    return {"item": serialize_role(role, include_permissions=True)}


@router.post("/roles")
def create_role(
    payload: RoleCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Role name is required")
    if db.query(Role).filter(func.lower(Role.name) == name.lower()).first() is not None:
        raise HTTPException(status_code=400, detail="Role name already exists")

    role = Role(name=name, description=(payload.description or "").strip() or None)
    db.add(role)
    db.flush()
    db.expire_all()
    created = _get_role_or_404(role.id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="role.create",
        entity_type="role",
        entity_id=role.id,
        before_json=None,
        after_json=serialize_role(created, include_permissions=True),
    )
    db.commit()
    return {"success": True, "item": serialize_role(created, include_permissions=True)}


@router.patch("/roles/{role_id}")
def update_role(
    role_id: int,
    payload: RoleUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    role = _get_role_or_404(role_id, db)
    before = serialize_role(role, include_permissions=True)

    if payload.name is not None:
        if role.name in BUILT_IN_ROLE_NAMES and payload.name.strip() != role.name:
            raise HTTPException(status_code=400, detail="Built-in role names cannot be changed")
        updated_name = payload.name.strip()
        if not updated_name:
            raise HTTPException(status_code=400, detail="Role name is required")
        duplicate = (
            db.query(Role)
            .filter(func.lower(Role.name) == updated_name.lower(), Role.id != role.id)
            .first()
        )
        if duplicate is not None:
            raise HTTPException(status_code=400, detail="Role name already exists")
        role.name = updated_name

    if payload.description is not None:
        role.description = payload.description.strip() or None

    db.add(role)
    db.flush()
    db.expire_all()
    refreshed = _get_role_or_404(role_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="role.update",
        entity_type="role",
        entity_id=role.id,
        before_json=before,
        after_json=serialize_role(refreshed, include_permissions=True),
    )
    db.commit()
    return {"success": True, "item": serialize_role(refreshed, include_permissions=True)}


@router.get("/permissions")
def list_permissions(
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    items = _permissions_query(db).order_by(Permission.name.asc()).all()
    serialized = [serialize_permission(item) for item in items]
    groups: dict[str, list[dict]] = {}
    for item in serialized:
        groups.setdefault(item["group"], []).append(item)
    return {"items": serialized, "groups": groups}


@router.patch("/roles/{role_id}/permissions")
def update_role_permissions(
    role_id: int,
    payload: RolePermissionsUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.admins.manage")),
):
    role = _get_role_or_404(role_id, db)
    before = serialize_role(role, include_permissions=True)

    permission_ids = sorted({permission_id for permission_id in payload.permission_ids})
    for permission_id in permission_ids:
        _get_permission_or_404(permission_id, db)

    existing = (
        db.query(RolePermission)
        .filter(RolePermission.role_id == role.id)
        .all()
    )
    existing_permission_ids = {item.permission_id for item in existing}
    desired_permission_ids = set(permission_ids)

    for item in existing:
        if item.permission_id not in desired_permission_ids:
            db.delete(item)

    for permission_id in desired_permission_ids - existing_permission_ids:
        db.add(RolePermission(role_id=role.id, permission_id=permission_id))

    db.flush()
    db.expire_all()
    refreshed = _get_role_or_404(role_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="role.update_permissions",
        entity_type="role",
        entity_id=role.id,
        before_json=before,
        after_json=serialize_role(refreshed, include_permissions=True),
    )
    db.commit()
    return {"success": True, "item": serialize_role(refreshed, include_permissions=True)}
