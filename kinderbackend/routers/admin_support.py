from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload

from admin_deps import require_permission
from admin_utils import (
    build_pagination_payload,
    serialize_support_ticket,
    write_audit_log,
)
from deps import get_db
from models import SupportTicket, SupportTicketMessage
from notification_service import notify_support_ticket_updated

router = APIRouter(prefix="/admin/support/tickets", tags=["Admin Support"])
VALID_SUPPORT_STATUSES = {"open", "in_progress", "resolved", "closed"}
VALID_SUPPORT_CATEGORIES = {
    "login_issue",
    "billing_issue",
    "child_content_issue",
    "technical_issue",
    "general_inquiry",
}


class SupportReplyRequest(BaseModel):
    message: str


class SupportAssignRequest(BaseModel):
    admin_user_id: Optional[int] = None


def _ticket_query(db: Session):
    return db.query(SupportTicket).options(
        joinedload(SupportTicket.user),
        joinedload(SupportTicket.assigned_admin),
        joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.admin_user),
        joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.user),
    )


def _get_ticket_or_404(ticket_id: int, db: Session) -> SupportTicket:
    ticket = _ticket_query(db).filter(SupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Support ticket not found")
    return ticket


@router.get("")
def list_support_tickets(
    status: str = Query("", description="Filter by open, in_progress, resolved, closed"),
    category: str = Query("", description="Filter by ticket category"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.view")),
):
    query = _ticket_query(db)
    normalized_status = status.strip().lower()
    if normalized_status:
        if normalized_status not in VALID_SUPPORT_STATUSES:
            raise HTTPException(status_code=422, detail="Invalid support status filter")
        query = query.filter(SupportTicket.status == normalized_status)
    normalized_category = category.strip().lower()
    if normalized_category:
        if normalized_category not in VALID_SUPPORT_CATEGORIES:
            raise HTTPException(status_code=422, detail="Invalid support category filter")
        query = query.filter(SupportTicket.category == normalized_category)

    total = query.count()
    items = (
        query.order_by(SupportTicket.updated_at.desc(), SupportTicket.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [serialize_support_ticket(ticket) for ticket in items],
        "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
        "filters": {"status": normalized_status, "category": normalized_category},
    }


@router.get("/{ticket_id}")
def get_support_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.view")),
):
    ticket = _get_ticket_or_404(ticket_id, db)
    return {"item": serialize_support_ticket(ticket, include_thread=True)}


@router.post("/{ticket_id}/reply")
def reply_to_support_ticket(
    ticket_id: int,
    payload: SupportReplyRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.reply")),
):
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Reply message is required")

    ticket = _get_ticket_or_404(ticket_id, db)
    if ticket.status == "closed":
        raise HTTPException(status_code=400, detail="Closed tickets cannot receive replies")
    before = serialize_support_ticket(ticket, include_thread=True)

    reply = SupportTicketMessage(
        ticket_id=ticket.id,
        admin_user_id=admin.id,
        message=message,
    )
    db.add(reply)
    ticket.status = "in_progress"
    ticket.updated_at = datetime.utcnow()
    db.add(ticket)
    db.flush()
    notify_support_ticket_updated(
        db,
        ticket=ticket,
        title="Support ticket updated",
        body=f"New reply on ticket '{ticket.subject}'.",
    )

    refreshed_ticket = _get_ticket_or_404(ticket_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="support.reply",
        entity_type="support_ticket",
        entity_id=ticket.id,
        before_json=before,
        after_json=serialize_support_ticket(refreshed_ticket, include_thread=True),
    )
    db.commit()
    return {"success": True, "item": serialize_support_ticket(refreshed_ticket, include_thread=True)}


@router.post("/{ticket_id}/resolve")
def resolve_support_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.close")),
):
    ticket = _get_ticket_or_404(ticket_id, db)
    if ticket.status == "closed":
        raise HTTPException(status_code=400, detail="Closed tickets cannot be resolved")
    before = serialize_support_ticket(ticket, include_thread=True)

    ticket.status = "resolved"
    ticket.closed_at = None
    ticket.updated_at = datetime.utcnow()
    db.add(ticket)
    db.flush()
    notify_support_ticket_updated(
        db,
        ticket=ticket,
        title="Support ticket resolved",
        body=f"Ticket '{ticket.subject}' was marked as resolved.",
    )

    refreshed_ticket = _get_ticket_or_404(ticket_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="support.resolve",
        entity_type="support_ticket",
        entity_id=ticket.id,
        before_json=before,
        after_json=serialize_support_ticket(refreshed_ticket, include_thread=True),
    )
    db.commit()
    return {"success": True, "item": serialize_support_ticket(refreshed_ticket, include_thread=True)}


@router.post("/{ticket_id}/close")
def close_support_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.close")),
):
    ticket = _get_ticket_or_404(ticket_id, db)
    if ticket.status == "closed":
        raise HTTPException(status_code=400, detail="Ticket is already closed")
    before = serialize_support_ticket(ticket, include_thread=True)

    ticket.status = "closed"
    ticket.closed_at = datetime.utcnow()
    ticket.updated_at = ticket.closed_at
    db.add(ticket)
    db.flush()
    notify_support_ticket_updated(
        db,
        ticket=ticket,
        title="Support ticket closed",
        body=f"Ticket '{ticket.subject}' was closed.",
    )

    refreshed_ticket = _get_ticket_or_404(ticket_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="support.close",
        entity_type="support_ticket",
        entity_id=ticket.id,
        before_json=before,
        after_json=serialize_support_ticket(refreshed_ticket, include_thread=True),
    )
    db.commit()
    return {"success": True, "item": serialize_support_ticket(refreshed_ticket, include_thread=True)}


@router.post("/{ticket_id}/assign")
def assign_support_ticket(
    ticket_id: int,
    payload: SupportAssignRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.reply")),
):
    from admin_models import AdminUser

    ticket = _get_ticket_or_404(ticket_id, db)
    before = serialize_support_ticket(ticket, include_thread=True)

    assigned_admin_id = payload.admin_user_id or admin.id
    assigned_admin = db.query(AdminUser).filter(AdminUser.id == assigned_admin_id).first()
    if not assigned_admin:
        raise HTTPException(status_code=404, detail="Admin assignee not found")
    if not assigned_admin.is_active:
        raise HTTPException(status_code=400, detail="Admin assignee is inactive")

    ticket.assigned_admin_id = assigned_admin.id
    if ticket.status == "open":
        ticket.status = "in_progress"
    ticket.updated_at = datetime.utcnow()
    db.add(ticket)
    db.flush()
    notify_support_ticket_updated(
        db,
        ticket=ticket,
        title="Support ticket in progress",
        body=f"Ticket '{ticket.subject}' is now being handled by the support team.",
    )

    refreshed_ticket = _get_ticket_or_404(ticket_id, db)
    write_audit_log(
        db=db,
        request=request,
        admin=admin,
        action="support.assign",
        entity_type="support_ticket",
        entity_id=ticket.id,
        before_json=before,
        after_json=serialize_support_ticket(refreshed_ticket, include_thread=True),
    )
    db.commit()
    return {"success": True, "item": serialize_support_ticket(refreshed_ticket, include_thread=True)}
