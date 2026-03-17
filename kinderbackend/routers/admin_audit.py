from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_models import AuditLog
from admin_utils import build_pagination_payload, parse_optional_date, serialize_audit_log
from core.time_utils import utc_end_of_day, utc_start_of_day
from deps import get_db

router = APIRouter(prefix="/admin/audit-logs", tags=["Admin Audit"])


@router.get("")
def list_audit_logs(
    admin_id: Optional[int] = Query(None),
    action: Optional[str] = Query(None),
    entity_type: Optional[str] = Query(None),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.audit.view")),
):
    query = db.query(AuditLog).options(joinedload(AuditLog.admin_user))

    if admin_id is not None:
        query = query.filter(AuditLog.admin_user_id == admin_id)
    if action:
        query = query.filter(AuditLog.action == action)
    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)

    parsed_from = parse_optional_date(date_from)
    if parsed_from is not None:
        query = query.filter(AuditLog.created_at >= utc_start_of_day(parsed_from))

    parsed_to = parse_optional_date(date_to)
    if parsed_to is not None:
        query = query.filter(AuditLog.created_at <= utc_end_of_day(parsed_to))

    total = query.count()
    items = (
        query.order_by(AuditLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_audit_log(item) for item in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {
            "admin_id": admin_id,
            "action": action,
            "entity_type": entity_type,
            "date_from": date_from,
            "date_to": date_to,
        },
    }
