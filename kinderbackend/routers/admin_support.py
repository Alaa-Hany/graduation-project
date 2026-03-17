from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from admin_deps import require_permission
from deps import get_db
from services.support_ticket_service import support_ticket_service

router = APIRouter(prefix="/admin/support/tickets", tags=["Admin Support"])


class SupportReplyRequest(BaseModel):
    message: str


class SupportAssignRequest(BaseModel):
    admin_user_id: Optional[int] = None


@router.get("")
def list_support_tickets(
    status: str = Query("", description="Filter by open, in_progress, resolved, closed"),
    category: str = Query("", description="Filter by ticket category"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.view")),
):
    return support_ticket_service.list_admin_tickets(
        status=status,
        category=category,
        page=page,
        page_size=page_size,
        db=db,
    )


@router.get("/{ticket_id}")
def get_support_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.view")),
):
    return support_ticket_service.get_admin_ticket(ticket_id=ticket_id, db=db)


@router.post("/{ticket_id}/reply")
def reply_to_support_ticket(
    ticket_id: int,
    payload: SupportReplyRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.reply")),
):
    return support_ticket_service.reply_as_admin(
        ticket_id=ticket_id,
        payload=payload,
        request=request,
        admin=admin,
        db=db,
    )


@router.post("/{ticket_id}/resolve")
def resolve_support_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.close")),
):
    return support_ticket_service.resolve_as_admin(
        ticket_id=ticket_id,
        request=request,
        admin=admin,
        db=db,
    )


@router.post("/{ticket_id}/close")
def close_support_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.close")),
):
    return support_ticket_service.close_as_admin(
        ticket_id=ticket_id,
        request=request,
        admin=admin,
        db=db,
    )


@router.post("/{ticket_id}/assign")
def assign_support_ticket(
    ticket_id: int,
    payload: SupportAssignRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin=Depends(require_permission("admin.support.reply")),
):
    return support_ticket_service.assign_as_admin(
        ticket_id=ticket_id,
        payload=payload,
        request=request,
        admin=admin,
        db=db,
    )
