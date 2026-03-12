from __future__ import annotations

from models import Notification, SupportTicket, User


def create_notification(
    db,
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
    db,
    *,
    ticket: SupportTicket,
    title: str,
    body: str,
) -> Notification | None:
    if ticket.user_id is None:
        return None
    return create_notification(
        db,
        user_id=ticket.user_id,
        type="SUPPORT_TICKET_UPDATE",
        title=title,
        body=body,
    )


def notify_subscription_changed(
    db,
    *,
    user: User,
    old_plan: str,
    new_plan: str,
    source: str,
) -> Notification | None:
    if old_plan == new_plan:
        return None
    return create_notification(
        db,
        user_id=user.id,
        type="SUBSCRIPTION_UPDATED",
        title="Subscription updated",
        body=f"Your plan changed from {old_plan} to {new_plan} via {source}.",
    )
