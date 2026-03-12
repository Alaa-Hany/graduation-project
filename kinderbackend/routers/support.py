from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session, joinedload

from admin_utils import serialize_support_ticket
from deps import get_current_user, get_db
from models import SupportTicket, SupportTicketMessage, User

router = APIRouter(tags=["support"])

SUPPORT_TICKET_CATEGORIES = {
    "login_issue",
    "billing_issue",
    "child_content_issue",
    "technical_issue",
    "general_inquiry",
}
SUPPORT_TICKET_STATUSES = {
    "open",
    "in_progress",
    "resolved",
    "closed",
}


class SupportRequest(BaseModel):
    subject: str
    message: str
    category: str = "general_inquiry"
    email: Optional[EmailStr] = None


class SupportReplyRequest(BaseModel):
    message: str


def _normalize_category(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in SUPPORT_TICKET_CATEGORIES:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "INVALID_SUPPORT_CATEGORY",
                "message": "Support category is invalid",
                "allowed_categories": sorted(SUPPORT_TICKET_CATEGORIES),
            },
        )
    return normalized


def _validate_support_text(subject: str, message: str) -> tuple[str, str]:
    normalized_subject = subject.strip()
    normalized_message = message.strip()
    if len(normalized_subject) < 3:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "SUBJECT_TOO_SHORT",
                "message": "Subject must be at least 3 characters long",
            },
        )
    if len(normalized_subject) > 120:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "SUBJECT_TOO_LONG",
                "message": "Subject must not exceed 120 characters",
            },
        )
    if len(normalized_message) < 10:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "MESSAGE_TOO_SHORT",
                "message": "Message must be at least 10 characters long",
            },
        )
    if len(normalized_message) > 2000:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "MESSAGE_TOO_LONG",
                "message": "Message must not exceed 2000 characters",
            },
        )
    return normalized_subject, normalized_message


def _ticket_query(db: Session):
    return db.query(SupportTicket).options(
        joinedload(SupportTicket.user),
        joinedload(SupportTicket.assigned_admin),
        joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.admin_user),
        joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.user),
    )


def _get_user_ticket_or_404(ticket_id: int, user_id: int, db: Session) -> SupportTicket:
    ticket = (
        _ticket_query(db)
        .filter(SupportTicket.id == ticket_id, SupportTicket.user_id == user_id)
        .first()
    )
    if ticket is None:
        raise HTTPException(status_code=404, detail="Support ticket not found")
    return ticket


@router.post("/support/contact")
def contact_support(
    payload: SupportRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject, message = _validate_support_text(payload.subject, payload.message)
    category = _normalize_category(payload.category)
    email = payload.email or user.email

    ticket = SupportTicket(
        user_id=user.id,
        subject=subject,
        message=message,
        email=email,
        category=category,
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return {
        "success": True,
        "item": serialize_support_ticket(ticket, include_thread=True),
    }


@router.get("/support/tickets")
def list_my_support_tickets(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = (
        _ticket_query(db)
        .filter(SupportTicket.user_id == user.id)
        .order_by(SupportTicket.updated_at.desc(), SupportTicket.created_at.desc())
        .all()
    )
    return {
        "items": [serialize_support_ticket(ticket) for ticket in items],
        "summary": {
            "total": len(items),
            "open": sum(1 for ticket in items if ticket.status == "open"),
            "in_progress": sum(1 for ticket in items if ticket.status == "in_progress"),
            "resolved": sum(1 for ticket in items if ticket.status == "resolved"),
            "closed": sum(1 for ticket in items if ticket.status == "closed"),
        },
    }


@router.get("/support/tickets/{ticket_id}")
def get_my_support_ticket(
    ticket_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ticket = _get_user_ticket_or_404(ticket_id, user.id, db)
    return {"item": serialize_support_ticket(ticket, include_thread=True)}


@router.post("/support/tickets/{ticket_id}/reply")
def reply_to_my_support_ticket(
    ticket_id: int,
    payload: SupportReplyRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    message = payload.message.strip()
    if len(message) < 3:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "REPLY_TOO_SHORT",
                "message": "Reply must be at least 3 characters long",
            },
        )

    ticket = _get_user_ticket_or_404(ticket_id, user.id, db)
    if ticket.status == "closed":
        raise HTTPException(
            status_code=400,
            detail={
                "code": "TICKET_CLOSED",
                "message": "Closed tickets cannot receive new replies",
            },
        )

    reply = SupportTicketMessage(
        ticket_id=ticket.id,
        user_id=user.id,
        message=message,
    )
    db.add(reply)
    ticket.status = "open" if ticket.status == "resolved" else ticket.status
    ticket.updated_at = datetime.utcnow()
    db.add(ticket)
    db.commit()

    refreshed_ticket = _get_user_ticket_or_404(ticket_id, user.id, db)
    return {
        "success": True,
        "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
    }
