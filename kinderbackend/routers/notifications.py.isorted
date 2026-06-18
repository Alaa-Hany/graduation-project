from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from schemas.common import SuccessResponse
from services.notification_service import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationOut(BaseModel):
    id: int
    type: str
    title: str
    body: str
    child_id: int | None = None
    is_read: bool
    created_at: str | None = None


class NotificationSummaryOut(BaseModel):
    unread_count: int = Field(..., description="Total unread notifications for the current user.")


class NotificationListResponse(BaseModel):
    notifications: list[NotificationOut]
    summary: NotificationSummaryOut

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "notifications": [
                    {
                        "id": 101,
                        "type": "SUPPORT_TICKET_UPDATE",
                        "title": "Support ticket updated",
                        "body": "New reply on ticket 'Unable to access billing settings'.",
                        "child_id": None,
                        "is_read": False,
                        "created_at": "2026-03-24T12:00:00Z",
                    }
                ],
                "summary": {
                    "unread_count": 3,
                },
            }
        }
    )


@router.get(
    "",
    response_model=NotificationListResponse,
    summary="List Notifications",
    description="Return the authenticated user's notifications ordered from newest to oldest, along with the unread count.",
    response_description="Notification list and unread summary for the current user.",
)
def list_notifications(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return notification_service.list_notifications(
        db=db,
        user=user,
        limit=limit,
        offset=offset,
    )


@router.post(
    "/mark-all-read",
    response_model=SuccessResponse,
    summary="Mark All Notifications Read",
    description="Mark every notification for the authenticated user as read.",
    response_description="Success status for the bulk read operation.",
)
def mark_all_read(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return notification_service.mark_all_read(db=db, user=user)


@router.post(
    "/{notification_id}/read",
    response_model=SuccessResponse,
    summary="Mark Notification Read",
    description="Mark a single notification owned by the authenticated user as read.",
    response_description="Success status for the notification update.",
)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return notification_service.mark_read(
        db=db,
        user=user,
        notification_id=notification_id,
    )
