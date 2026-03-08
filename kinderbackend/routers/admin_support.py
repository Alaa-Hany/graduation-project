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

router = APIRouter(prefix="/admin/support/tickets", tags=["Admin Support"])


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
    status: str = Query("", description="Filter by open, in_progress, closed"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.view")),
):
    query = _ticket_query(db)
    normalized_status = status.strip().lower()
    if normalized_status:
        query = query.filter(SupportTicket.status == normalized_status)

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
        "filters": {"status": normalized_status},
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


@router.post("/{ticket_id}/close")
def close_support_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.close")),
):
    ticket = _get_ticket_or_404(ticket_id, db)
    before = serialize_support_ticket(ticket, include_thread=True)

    ticket.status = "closed"
    ticket.closed_at = datetime.utcnow()
    ticket.updated_at = ticket.closed_at
    db.add(ticket)
    db.flush()

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
