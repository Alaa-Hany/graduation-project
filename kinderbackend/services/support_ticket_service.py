from __future__ import annotations

from typing import TYPE_CHECKING, Protocol

from fastapi import HTTPException, Request
from sqlalchemy.orm import Session, joinedload

from admin_utils import build_pagination_payload, serialize_support_ticket, write_audit_log
from core.time_utils import db_utc_now
from models import SupportTicket, SupportTicketMessage, User
from notification_service import notify_support_ticket_updated
from services.premium_behavior_service import premium_behavior_service

if TYPE_CHECKING:
    from admin_models import AdminUser

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


class SupportTicketCreatePayload(Protocol):
    subject: str
    message: str
    category: str
    email: str | None


class SupportTicketReplyPayload(Protocol):
    message: str


class SupportTicketAssignPayload(Protocol):
    admin_user_id: int | None


class SupportTicketService:
    def ticket_query(self, db: Session):
        return db.query(SupportTicket).options(
            joinedload(SupportTicket.user),
            joinedload(SupportTicket.assigned_admin),
            joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.admin_user),
            joinedload(SupportTicket.thread_messages).joinedload(SupportTicketMessage.user),
        )

    def normalize_category(self, value: str) -> str:
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

    def validate_support_text(self, subject: str, message: str) -> tuple[str, str]:
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

    def get_user_ticket_or_404(self, *, ticket_id: int, user_id: int, db: Session) -> SupportTicket:
        ticket = (
            self.ticket_query(db)
            .filter(SupportTicket.id == ticket_id, SupportTicket.user_id == user_id)
            .first()
        )
        if ticket is None:
            raise HTTPException(status_code=404, detail="Support ticket not found")
        return ticket

    def get_ticket_or_404(self, *, ticket_id: int, db: Session) -> SupportTicket:
        ticket = self.ticket_query(db).filter(SupportTicket.id == ticket_id).first()
        if not ticket:
            raise HTTPException(status_code=404, detail="Support ticket not found")
        return ticket

    def create_contact_ticket(
        self,
        *,
        payload: SupportTicketCreatePayload,
        user: User,
        db: Session,
    ) -> dict[str, object]:
        subject, message = self.validate_support_text(payload.subject, payload.message)
        category = self.normalize_category(payload.category)
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

    def list_user_tickets(self, *, user: User, db: Session) -> dict[str, object]:
        items = (
            self.ticket_query(db)
            .filter(SupportTicket.user_id == user.id)
            .all()
        )
        ranked = premium_behavior_service.rank_support_tickets(items)
        return {
            "items": [serialize_support_ticket(item["ticket"]) for item in ranked],
            "summary": {
                "total": len(ranked),
                "open": sum(1 for item in ranked if item["ticket"].status == "open"),
                "in_progress": sum(
                    1 for item in ranked if item["ticket"].status == "in_progress"
                ),
                "resolved": sum(1 for item in ranked if item["ticket"].status == "resolved"),
                "closed": sum(1 for item in ranked if item["ticket"].status == "closed"),
            },
        }

    def get_user_ticket(self, *, ticket_id: int, user: User, db: Session) -> dict[str, object]:
        ticket = self.get_user_ticket_or_404(ticket_id=ticket_id, user_id=user.id, db=db)
        return {"item": serialize_support_ticket(ticket, include_thread=True)}

    def reply_as_user(
        self,
        *,
        ticket_id: int,
        payload: SupportTicketReplyPayload,
        user: User,
        db: Session,
    ) -> dict[str, object]:
        message = payload.message.strip()
        if len(message) < 3:
            raise HTTPException(
                status_code=422,
                detail={
                    "code": "REPLY_TOO_SHORT",
                    "message": "Reply must be at least 3 characters long",
                },
            )

        ticket = self.get_user_ticket_or_404(ticket_id=ticket_id, user_id=user.id, db=db)
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
        ticket.updated_at = db_utc_now()
        db.add(ticket)
        db.commit()

        refreshed_ticket = self.get_user_ticket_or_404(
            ticket_id=ticket_id,
            user_id=user.id,
            db=db,
        )
        return {
            "success": True,
            "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
        }

    def list_admin_tickets(
        self,
        *,
        status: str,
        category: str,
        page: int,
        page_size: int,
        db: Session,
    ) -> dict[str, object]:
        query = self.ticket_query(db)
        normalized_status = status.strip().lower()
        if normalized_status:
            if normalized_status not in SUPPORT_TICKET_STATUSES:
                raise HTTPException(status_code=422, detail="Invalid support status filter")
            query = query.filter(SupportTicket.status == normalized_status)
        normalized_category = category.strip().lower()
        if normalized_category:
            if normalized_category not in SUPPORT_TICKET_CATEGORIES:
                raise HTTPException(status_code=422, detail="Invalid support category filter")
            query = query.filter(SupportTicket.category == normalized_category)

        ranked = premium_behavior_service.rank_support_tickets(query.all())
        total = len(ranked)
        window = ranked[(page - 1) * page_size : page * page_size]
        return {
            "items": [serialize_support_ticket(item["ticket"]) for item in window],
            "pagination": build_pagination_payload(page=page, page_size=page_size, total=total),
            "filters": {"status": normalized_status, "category": normalized_category},
        }

    def get_admin_ticket(self, *, ticket_id: int, db: Session) -> dict[str, object]:
        ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
        return {"item": serialize_support_ticket(ticket, include_thread=True)}

    def reply_as_admin(
        self,
        *,
        ticket_id: int,
        payload: SupportTicketReplyPayload,
        request: Request,
        admin: AdminUser,
        db: Session,
    ) -> dict[str, object]:
        message = payload.message.strip()
        if not message:
            raise HTTPException(status_code=400, detail="Reply message is required")

        ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        ticket.updated_at = db_utc_now()
        db.add(ticket)
        db.flush()
        notify_support_ticket_updated(
            db,
            ticket=ticket,
            title="Support ticket updated",
            body=f"New reply on ticket '{ticket.subject}'.",
        )

        refreshed_ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        return {
            "success": True,
            "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
        }

    def resolve_as_admin(
        self,
        *,
        ticket_id: int,
        request: Request,
        admin: AdminUser,
        db: Session,
    ) -> dict[str, object]:
        ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
        if ticket.status == "closed":
            raise HTTPException(status_code=400, detail="Closed tickets cannot be resolved")
        before = serialize_support_ticket(ticket, include_thread=True)

        ticket.status = "resolved"
        ticket.closed_at = None
        ticket.updated_at = db_utc_now()
        db.add(ticket)
        db.flush()
        notify_support_ticket_updated(
            db,
            ticket=ticket,
            title="Support ticket resolved",
            body=f"Ticket '{ticket.subject}' was marked as resolved.",
        )

        refreshed_ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        return {
            "success": True,
            "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
        }

    def close_as_admin(
        self,
        *,
        ticket_id: int,
        request: Request,
        admin: AdminUser,
        db: Session,
    ) -> dict[str, object]:
        ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
        if ticket.status == "closed":
            raise HTTPException(status_code=400, detail="Ticket is already closed")
        before = serialize_support_ticket(ticket, include_thread=True)

        ticket.status = "closed"
        ticket.closed_at = db_utc_now()
        ticket.updated_at = ticket.closed_at
        db.add(ticket)
        db.flush()
        notify_support_ticket_updated(
            db,
            ticket=ticket,
            title="Support ticket closed",
            body=f"Ticket '{ticket.subject}' was closed.",
        )

        refreshed_ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        return {
            "success": True,
            "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
        }

    def assign_as_admin(
        self,
        *,
        ticket_id: int,
        payload: SupportTicketAssignPayload,
        request: Request,
        admin: AdminUser,
        db: Session,
    ) -> dict[str, object]:
        from admin_models import AdminUser

        ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        ticket.updated_at = db_utc_now()
        db.add(ticket)
        db.flush()
        notify_support_ticket_updated(
            db,
            ticket=ticket,
            title="Support ticket in progress",
            body=f"Ticket '{ticket.subject}' is now being handled by the support team.",
        )

        refreshed_ticket = self.get_ticket_or_404(ticket_id=ticket_id, db=db)
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
        return {
            "success": True,
            "item": serialize_support_ticket(refreshed_ticket, include_thread=True),
        }


support_ticket_service = SupportTicketService()
