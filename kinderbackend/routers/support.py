from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import SupportTicket, User

router = APIRouter(tags=["support"])


class SupportRequest(BaseModel):
    subject: str
    message: str
    email: Optional[EmailStr] = None


@router.post("/support/contact")
def contact_support(
    payload: SupportRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ticket = SupportTicket(
        user_id=user.id,
        subject=payload.subject,
        message=payload.message,
        email=payload.email,
        status="open",
    )
    db.add(ticket)
    db.commit()
    return {"success": True}
