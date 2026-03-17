from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from models import Notification, SupportTicket, User
from serializers import notification_to_json
from services.premium_behavior_service import premium_behavior_service


class NotificationService:
    def create_notification(
        self,
        db: Session,
        *,
        user_id: int,
        type: str,
        title: str,
        body: str,
        child_id: int | None = None,
    ) -> Notification:
        notification = Notification(
            user_id=user_id,
            child_id=child_id,
            type=type,
            title=title,
            body=body,
            is_read=False,
        )
        db.add(notification)
        db.flush()
        return notification

    def notify_support_ticket_updated(
        self,
        db: Session,
        *,
        ticket: SupportTicket,
        title: str,
        body: str,
    ) -> Notification | None:
        if ticket.user_id is None:
            return None
        return self.create_notification(
            db,
            user_id=ticket.user_id,
            type="SUPPORT_TICKET_UPDATE",
            title=title,
            body=body,
        )

    def notify_subscription_changed(
        self,
        db: Session,
        *,
        user: User,
        old_plan: str,
        new_plan: str,
        source: str,
    ) -> Notification | None:
        if old_plan == new_plan:
            return None
        return self.create_notification(
            db,
            user_id=user.id,
            type="SUBSCRIPTION_UPDATED",
            title="Subscription updated",
            body=f"Your plan changed from {old_plan} to {new_plan} via {source}.",
        )

    def list_notifications(
        self,
        *,
        db: Session,
        user: User,
        limit: int,
        offset: int,
    ) -> dict:
        base_query = db.query(Notification).filter(Notification.user_id == user.id)
        query = base_query.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
        unread_count = base_query.filter(Notification.is_read.is_(False)).count()
        return {
            "notifications": [notification_to_json(n) for n in query.all()],
            "summary": {
                "unread_count": unread_count,
            },
        }

    def mark_all_read(self, *, db: Session, user: User) -> dict:
        db.query(Notification).filter(Notification.user_id == user.id).update({"is_read": True})
        db.commit()
        return {"success": True}

    def mark_read(self, *, db: Session, user: User, notification_id: int) -> dict:
        notification = (
            db.query(Notification)
            .filter(Notification.id == notification_id, Notification.user_id == user.id)
            .first()
        )
        if not notification:
            raise HTTPException(status_code=404, detail="Notification not found")
        notification.is_read = True
        db.add(notification)
        db.commit()
        return {"success": True}

    def get_basic_feature_notifications(self, *, db: Session, user: User) -> dict:
        return premium_behavior_service.build_basic_notifications(db=db, user=user)

    def get_smart_feature_notifications(self, *, db: Session, user: User) -> dict:
        return premium_behavior_service.build_smart_notifications(db=db, user=user)


notification_service = NotificationService()
