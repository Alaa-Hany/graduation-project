from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload, selectinload

from admin_deps import ensure_permission, require_permission
from admin_utils import (
    build_pagination_payload,
    build_user_activity,
    serialize_user_detail,
    write_audit_log,
)
from auth import hash_password
from core.admin_security import require_sensitive_action_confirmation
from core.time_utils import db_utc_now
from deps import get_db
from models import User
from services.subscription_service import subscription_service

router = APIRouter(prefix="/admin/users", tags=["Admin Users"])


class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    plan: Optional[str] = None


class UserResetPasswordRequest(BaseModel):
    new_password: Optional[str] = None


def _get_user_or_404(user_id: int, db: Session) -> User:
    user = (
        db.query(User)
        .options(
            joinedload(User.children),
            selectinload(User.notifications),
            selectinload(User.support_tickets),
        )
        .filter(User.id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("")
def list_admin_users(
    search: str = Query("", description="Search by email or name"),
    status_filter: str = Query("all", alias="status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.view")),
):
    query = db.query(User).options(joinedload(User.children))

    if search.strip():
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(User.email).like(term) | func.lower(func.coalesce(User.name, "")).like(term)
        )

    normalized_status = status_filter.strip().lower()
    if normalized_status == "active":
        query = query.filter(User.is_active.is_(True))
    elif normalized_status in {"disabled", "inactive"}:
        query = query.filter(User.is_active.is_(False))

    total = query.count()
    items = (
        query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    )

    return {
        "items": [serialize_user_detail(user) for user in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {"search": search, "status": normalized_status},
    }


@router.get("/{user_id}")
def get_admin_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.view")),
):
    user = _get_user_or_404(user_id, db)
    return {"item": serialize_user_detail(user)}


@router.patch("/{user_id}")
def update_admin_user(
    user_id: int,
    payload: UserUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.edit")),
):
    action = "user.edit"
    if payload.plan is not None:
        require_sensitive_action_confirmation(request, action="user.override_plan")
        ensure_permission(
            admin=admin,
            db=db,
            permission_name="admin.subscription.override",
        )
        action = "user.override_plan"
    user = _get_user_or_404(user_id, db)
    before = serialize_user_detail(user)

    if payload.email is not None:
        normalized_email = payload.email.strip().lower()
        duplicate = (
            db.query(User)
            .filter(func.lower(User.email) == normalized_email, User.id != user.id)
            .first()
        )
        if duplicate:
            raise HTTPException(status_code=400, detail="Email already in use")
        user.email = normalized_email

    if payload.name is not None:
        user.name = payload.name.strip()

    if payload.plan is not None:
        subscription_service.admin_override_subscription(
            db=db,
            user=user,
            plan=payload.plan.strip().upper(),
            source="admin_user_edit",
        )

    user.updated_at = db_utc_now()
    db.add(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action=action,
        entity_type="user",
        entity_id=user.id,
        before_json=before,
        after_json=serialize_user_detail(user),
    )
    db.commit()
    db.refresh(user)
    return {"success": True, "item": serialize_user_detail(user)}


@router.post("/{user_id}/disable")
def disable_admin_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.ban")),
):
    require_sensitive_action_confirmation(request, action="user.disable")
    user = _get_user_or_404(user_id, db)
    before = serialize_user_detail(user)
    user.is_active = False
    user.token_version = (user.token_version or 0) + 1
    user.updated_at = db_utc_now()
    db.add(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="user.disable",
        entity_type="user",
        entity_id=user.id,
        before_json=before,
        after_json=serialize_user_detail(user),
    )
    db.commit()
    db.refresh(user)
    return {"success": True, "item": serialize_user_detail(user)}


@router.post("/{user_id}/enable")
def enable_admin_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.ban")),
):
    require_sensitive_action_confirmation(request, action="user.enable")
    user = _get_user_or_404(user_id, db)
    before = serialize_user_detail(user)
    user.is_active = True
    user.updated_at = db_utc_now()
    db.add(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="user.enable",
        entity_type="user",
        entity_id=user.id,
        before_json=before,
        after_json=serialize_user_detail(user),
    )
    db.commit()
    db.refresh(user)
    return {"success": True, "item": serialize_user_detail(user)}


@router.post("/{user_id}/reset-password")
def reset_admin_user_password(
    user_id: int,
    payload: UserResetPasswordRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.edit")),
):
    require_sensitive_action_confirmation(request, action="user.reset_password")
    user = _get_user_or_404(user_id, db)
    temp_password = payload.new_password or "Temp@123456"
    before = {"id": user.id, "email": user.email}
    user.password_hash = hash_password(temp_password)
    user.token_version = (user.token_version or 0) + 1
    user.updated_at = db_utc_now()
    db.add(user)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="user.reset_password",
        entity_type="user",
        entity_id=user.id,
        before_json=before,
        after_json={"id": user.id, "email": user.email, "password_reset": True},
    )
    db.commit()
    return {
        "success": True,
        "temporary_password": temp_password,
    }


@router.get("/{user_id}/activity")
def get_admin_user_activity(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.users.view")),
):
    from admin_models import AuditLog

    user = _get_user_or_404(user_id, db)
    audit_logs = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "user", AuditLog.entity_id == str(user.id))
        .order_by(AuditLog.created_at.desc())
        .all()
    )
    return build_user_activity(user, audit_logs)
