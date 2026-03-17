from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from schemas.ai_buddy import (
    AiBuddyConversationOut,
    AiBuddyDeleteHistoryOut,
    AiBuddySendMessageIn,
    AiBuddySendMessageOut,
    AiBuddyStartSessionIn,
    AiBuddyVisibilitySummaryOut,
)
from services.ai_buddy_service import ai_buddy_service

router = APIRouter(prefix="/ai-buddy", tags=["ai-buddy"])


@router.post("/sessions", response_model=AiBuddyConversationOut)
def start_ai_buddy_session(
    payload: AiBuddyStartSessionIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.start_session(
        db=db,
        parent=user,
        child_id=payload.child_id,
        force_new=payload.force_new,
        title=payload.title,
    )


@router.get("/sessions/current", response_model=AiBuddyConversationOut)
def get_current_ai_buddy_session(
    child_id: int = Query(..., ge=1),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.get_current_session(
        db=db,
        parent=user,
        child_id=child_id,
    )


@router.get("/sessions/{session_id}", response_model=AiBuddyConversationOut)
def get_ai_buddy_session(
    session_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.get_session(
        db=db,
        parent=user,
        session_id=session_id,
    )


@router.post("/sessions/{session_id}/messages", response_model=AiBuddySendMessageOut)
def send_ai_buddy_message(
    session_id: int,
    payload: AiBuddySendMessageIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.send_message(
        db=db,
        parent=user,
        session_id=session_id,
        child_id=payload.child_id,
        content=payload.content,
        client_message_id=payload.client_message_id,
        quick_action=payload.quick_action,
    )


@router.get("/children/{child_id}/visibility", response_model=AiBuddyVisibilitySummaryOut)
def get_ai_buddy_visibility_summary(
    child_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.get_parent_visibility_summary(
        db=db,
        parent=user,
        child_id=child_id,
    )


@router.delete("/children/{child_id}/history", response_model=AiBuddyDeleteHistoryOut)
def delete_ai_buddy_history(
    child_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return ai_buddy_service.delete_child_history(
        db=db,
        parent=user,
        child_id=child_id,
    )
