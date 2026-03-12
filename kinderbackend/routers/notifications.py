from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import Notification, User
from serializers import notification_to_json

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
def list_notifications(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    base_query = db.query(Notification).filter(Notification.user_id == user.id)
    query = (
        base_query
        .order_by(Notification.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    unread_count = base_query.filter(Notification.is_read.is_(False)).count()
    return {
        "notifications": [notification_to_json(n) for n in query.all()],
        "summary": {
            "unread_count": unread_count,
        },
    }


@router.post("/mark-all-read")
def mark_all_read(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    db.query(Notification).filter(Notification.user_id == user.id).update({"is_read": True})
    db.commit()
    return {"success": True}


@router.post("/{notification_id}/read")
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
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
