from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from services.support_ticket_service import support_ticket_service

router = APIRouter(tags=["support"])


class SupportRequest(BaseModel):
    subject: str
    message: str
    category: str = "general_inquiry"
    email: Optional[EmailStr] = None


class SupportReplyRequest(BaseModel):
    message: str


@router.post("/support/contact")
def contact_support(
    payload: SupportRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.create_contact_ticket(payload=payload, user=user, db=db)


@router.get("/support/tickets")
def list_my_support_tickets(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.list_user_tickets(user=user, db=db)


@router.get("/support/tickets/{ticket_id}")
def get_my_support_ticket(
    ticket_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.get_user_ticket(ticket_id=ticket_id, user=user, db=db)


@router.post("/support/tickets/{ticket_id}/reply")
def reply_to_my_support_ticket(
    ticket_id: int,
    payload: SupportReplyRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.reply_as_user(
        ticket_id=ticket_id,
        payload=payload,
        user=user,
        db=db,
    )
