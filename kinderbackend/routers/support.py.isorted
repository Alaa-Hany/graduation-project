from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from rate_limit import support_write_rate_limit
from schemas.common import SuccessResponse
from services.support_ticket_service import support_ticket_service

router = APIRouter(tags=["support"])
support_write_rate_limit_check = Depends(support_write_rate_limit())


class SupportRequest(BaseModel):
    subject: str = Field(..., description="Short summary shown in support ticket lists.")
    message: str = Field(..., description="Detailed support request from the parent user.")
    category: str = Field(
        "general_inquiry",
        description="Support category used for routing and prioritization.",
    )
    email: Optional[EmailStr] = Field(
        None,
        description="Optional contact email. Defaults to the authenticated parent's email.",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "subject": "Unable to access billing settings",
                "message": "I upgraded recently, but the premium settings screen still appears locked.",
                "category": "billing_issue",
                "email": "parent@example.com",
            }
        }
    )


class SupportReplyRequest(BaseModel):
    message: str = Field(..., description="Reply text appended to the support ticket thread.")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "message": "I can reproduce this issue on Android and iPad. Please advise on the next step.",
            }
        }
    )


class SupportTicketAuthorOut(BaseModel):
    id: int | None = None
    email: str | None = None
    name: str | None = None


class SupportTicketThreadMessageOut(BaseModel):
    id: int | str
    ticket_id: int
    message: str
    author_type: str
    author: SupportTicketAuthorOut | None = None
    created_at: str | None = None


class SupportTicketOut(BaseModel):
    id: int
    user_id: int | None = None
    subject: str
    message: str
    email: str | None = None
    category: str
    status: str
    deleted_at: str | None = None
    assigned_admin_id: int | None = None
    assigned_admin: SupportTicketAuthorOut | None = None
    requester: SupportTicketAuthorOut | None = None
    created_at: str | None = None
    updated_at: str | None = None
    closed_at: str | None = None
    reply_count: int
    last_message_at: str | None = None
    preview: str
    priority_level: str
    priority_score: int | float
    priority_reason: str
    thread: list[SupportTicketThreadMessageOut] | None = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": 42,
                "user_id": 7,
                "subject": "Unable to access billing settings",
                "message": "I upgraded recently, but the premium settings screen still appears locked.",
                "email": "parent@example.com",
                "category": "billing_issue",
                "status": "open",
                "deleted_at": None,
                "assigned_admin_id": None,
                "assigned_admin": None,
                "requester": {
                    "id": 7,
                    "email": "parent@example.com",
                    "name": "Parent User",
                },
                "created_at": "2026-03-24T12:00:00Z",
                "updated_at": "2026-03-24T12:00:00Z",
                "closed_at": None,
                "reply_count": 1,
                "last_message_at": "2026-03-24T12:00:00Z",
                "preview": "I upgraded recently, but the premium settings screen still appears locked.",
                "priority_level": "normal",
                "priority_score": 10,
                "priority_reason": "Default priority",
                "thread": [
                    {
                        "id": "root-42",
                        "ticket_id": 42,
                        "message": "I upgraded recently, but the premium settings screen still appears locked.",
                        "author_type": "user",
                        "author": {
                            "id": 7,
                            "email": "parent@example.com",
                            "name": "Parent User",
                        },
                        "created_at": "2026-03-24T12:00:00Z",
                    }
                ],
            }
        }
    )


class SupportTicketSummaryOut(BaseModel):
    total: int
    open: int
    in_progress: int
    resolved: int
    closed: int


class SupportTicketListResponse(BaseModel):
    items: list[SupportTicketOut]
    summary: SupportTicketSummaryOut


class SupportTicketItemResponse(BaseModel):
    item: SupportTicketOut


class SupportTicketMutationResponse(BaseModel):
    success: bool
    item: SupportTicketOut


@router.post(
    "/support/contact",
    response_model=SupportTicketMutationResponse,
    summary="Create Support Ticket",
    description="Create a new support ticket for the authenticated parent and start the ticket thread with the submitted message.",
    response_description="Created support ticket including the initial thread entry.",
)
def contact_support(
    payload: SupportRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    rate_limit_check: None = support_write_rate_limit_check,
):
    return support_ticket_service.create_contact_ticket(payload=payload, user=user, db=db)


@router.get(
    "/support/tickets",
    response_model=SupportTicketListResponse,
    summary="List My Support Tickets",
    description="Return the authenticated parent's support tickets with a lightweight status summary.",
    response_description="Support ticket list for the current parent account.",
)
def list_my_support_tickets(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.list_user_tickets(user=user, db=db)


@router.get(
    "/support/tickets/{ticket_id}",
    response_model=SupportTicketItemResponse,
    summary="Get Support Ticket",
    description="Return a single support ticket owned by the authenticated parent, including the full reply thread.",
    response_description="Requested support ticket including thread messages.",
)
def get_my_support_ticket(
    ticket_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.get_user_ticket(ticket_id=ticket_id, user=user, db=db)


@router.delete(
    "/support/tickets/{ticket_id}",
    response_model=SuccessResponse,
    summary="Delete Support Ticket",
    description="Soft-delete a support ticket owned by the authenticated parent. Deleted tickets are hidden from normal lists but retained for history and admin visibility.",
    response_description="Soft-delete result.",
)
def delete_my_support_ticket(
    ticket_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return support_ticket_service.soft_delete_as_user(ticket_id=ticket_id, user=user, db=db)


@router.post(
    "/support/tickets/{ticket_id}/reply",
    response_model=SupportTicketMutationResponse,
    summary="Reply To Support Ticket",
    description="Append a new parent-authored reply to an existing support ticket thread.",
    response_description="Updated support ticket including the refreshed thread.",
)
def reply_to_my_support_ticket(
    ticket_id: int,
    payload: SupportReplyRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    rate_limit_check: None = support_write_rate_limit_check,
):
    return support_ticket_service.reply_as_user(
        ticket_id=ticket_id,
        payload=payload,
        user=user,
        db=db,
    )
