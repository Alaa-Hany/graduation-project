from __future__ import annotations

from datetime import timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.time_utils import db_utc_now
from models import AiBuddyMessage, AiBuddySession, ChildProfile, User


class AiBuddyPersistenceService:
    _retention_days = 30

    def get_child_for_parent(self, *, db: Session, parent: User, child_id: int) -> ChildProfile:
        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == child_id,
                ChildProfile.parent_id == parent.id,
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")
        return child

    def get_current_session(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> AiBuddySession | None:
        return (
            db.query(AiBuddySession)
            .filter(
                AiBuddySession.parent_user_id == parent.id,
                AiBuddySession.child_id == child_id,
                AiBuddySession.archived_at.is_(None),
                AiBuddySession.status == "active",
            )
            .order_by(AiBuddySession.updated_at.desc(), AiBuddySession.id.desc())
            .first()
        )

    def get_session_for_parent(
        self,
        *,
        db: Session,
        parent: User,
        session_id: int,
    ) -> AiBuddySession:
        session = (
            db.query(AiBuddySession)
            .filter(
                AiBuddySession.id == session_id,
                AiBuddySession.parent_user_id == parent.id,
                AiBuddySession.archived_at.is_(None),
            )
            .first()
        )
        if session is None:
            raise HTTPException(status_code=404, detail="AI Buddy session not found")
        return session

    def create_session(
        self,
        *,
        db: Session,
        parent: User,
        child: ChildProfile,
        title: str | None,
        provider_mode: str,
        provider_status: str,
        unavailable_reason: str | None,
        metadata_json: dict | None = None,
    ) -> AiBuddySession:
        now = db_utc_now()
        current = self.get_current_session(db=db, parent=parent, child_id=child.id)
        if current is not None:
            current.status = "ended"
            current.ended_at = now
            db.add(current)

        session = AiBuddySession(
            child_id=child.id,
            parent_user_id=parent.id,
            status="active",
            title=(title or child.name or "AI Buddy Session").strip()[:120],
            provider_mode=provider_mode,
            provider_status=provider_status,
            unavailable_reason=unavailable_reason,
            started_at=now,
            last_message_at=now,
            retention_expires_at=now + timedelta(days=self._retention_days),
            metadata_json=metadata_json or {},
        )
        db.add(session)
        db.flush()
        return session

    def add_message(
        self,
        *,
        db: Session,
        session: AiBuddySession,
        role: str,
        content: str,
        intent: str | None,
        response_source: str,
        status: str,
        safety_status: str,
        client_message_id: str | None = None,
        metadata_json: dict | None = None,
    ) -> AiBuddyMessage:
        message = AiBuddyMessage(
            session_id=session.id,
            child_id=session.child_id,
            role=role,
            content=content.strip(),
            intent=intent,
            response_source=response_source,
            status=status,
            client_message_id=client_message_id,
            safety_status=safety_status,
            metadata_json=metadata_json or {},
            retention_expires_at=db_utc_now() + timedelta(days=self._retention_days),
        )
        session.last_message_at = db_utc_now()
        db.add(session)
        db.add(message)
        db.flush()
        return message

    def list_messages(
        self,
        *,
        db: Session,
        session: AiBuddySession,
        limit: int = 100,
    ) -> list[AiBuddyMessage]:
        return (
            db.query(AiBuddyMessage)
            .filter(
                AiBuddyMessage.session_id == session.id,
                AiBuddyMessage.archived_at.is_(None),
            )
            .order_by(AiBuddyMessage.created_at.asc(), AiBuddyMessage.id.asc())
            .limit(max(limit, 1))
            .all()
        )


ai_buddy_persistence_service = AiBuddyPersistenceService()
