from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import (
    build_child_activity_log,
    build_child_progress,
    build_pagination_payload,
    parse_optional_date,
    serialize_child_detail,
    write_audit_log,
)
from deps import get_db
from models import ChildProfile

router = APIRouter(prefix="/admin/children", tags=["Admin Children"])


class ChildUpdateRequest(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    avatar: Optional[str] = None
    date_of_birth: Optional[str] = None


def _get_child_or_404(child_id: int, db: Session) -> ChildProfile:
    child = (
        db.query(ChildProfile)
        .options(joinedload(ChildProfile.parent))
        .filter(ChildProfile.id == child_id)
        .first()
    )
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    return child


@router.get("")
def list_admin_children(
    parent_id: Optional[int] = Query(None),
    age: Optional[int] = Query(None),
    active: Optional[bool] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.view")),
):
    query = db.query(ChildProfile).options(joinedload(ChildProfile.parent))

    if parent_id is not None:
        query = query.filter(ChildProfile.parent_id == parent_id)
    if age is not None:
        query = query.filter(ChildProfile.age == age)
    if active is not None and hasattr(ChildProfile, "is_active"):
        query = query.filter(ChildProfile.is_active.is_(active))

    total = query.count()
    items = (
        query.order_by(ChildProfile.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_child_detail(child) for child in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {"parent_id": parent_id, "age": age, "active": active},
    }


@router.get("/{child_id}")
def get_admin_child(
    child_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.view")),
):
    child = _get_child_or_404(child_id, db)
    return {"item": serialize_child_detail(child)}


@router.patch("/{child_id}")
def update_admin_child(
    child_id: int,
    payload: ChildUpdateRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.edit")),
):
    child = _get_child_or_404(child_id, db)
    before = serialize_child_detail(child)

    if payload.name is not None:
        child.name = payload.name.strip()
    if payload.age is not None:
        child.age = payload.age
    if payload.avatar is not None:
        child.avatar = payload.avatar
    if payload.date_of_birth is not None:
        child.date_of_birth = parse_optional_date(payload.date_of_birth)

    child.updated_at = datetime.utcnow()
    db.add(child)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="child.edit",
        entity_type="child",
        entity_id=child.id,
        before_json=before,
        after_json=serialize_child_detail(child),
    )
    db.commit()
    db.refresh(child)
    return {"success": True, "item": serialize_child_detail(child)}


@router.post("/{child_id}/deactivate")
def deactivate_admin_child(
    child_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.delete")),
):
    child = _get_child_or_404(child_id, db)
    before = serialize_child_detail(child)
    if hasattr(child, "is_active"):
        child.is_active = False
    child.updated_at = datetime.utcnow()
    db.add(child)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="child.deactivate",
        entity_type="child",
        entity_id=child.id,
        before_json=before,
        after_json=serialize_child_detail(child),
    )
    db.commit()
    db.refresh(child)
    return {"success": True, "item": serialize_child_detail(child)}


@router.get("/{child_id}/progress")
def get_admin_child_progress(
    child_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.view")),
):
    from admin_models import AuditLog

    child = _get_child_or_404(child_id, db)
    audit_logs = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "child", AuditLog.entity_id == str(child.id))
        .order_by(AuditLog.created_at.desc())
        .all()
    )
    return build_child_progress(child, audit_logs)


@router.get("/{child_id}/activity-log")
def get_admin_child_activity_log(
    child_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.children.view")),
):
    from admin_models import AuditLog

    child = _get_child_or_404(child_id, db)
    audit_logs = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "child", AuditLog.entity_id == str(child.id))
        .order_by(AuditLog.created_at.desc())
        .all()
    )
    return build_child_activity_log(child, audit_logs)
