from __future__ import annotations

from collections import Counter
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.time_utils import db_utc_now
from models import AiBuddyMessage, AiBuddySession, ChildProfile, User
from services.ai_buddy_persistence import ai_buddy_persistence_service
from services.ai_buddy_response_generator import (
    AiBuddyProviderState,
    ai_buddy_response_generator,
)


class AiBuddyVisibilityService:
    visibility_mode = "summary_and_metrics"
    retention_days = 30

    def update_session_summary(
        self,
        *,
        session: AiBuddySession,
        child_name: str | None,
        messages: list[AiBuddyMessage],
    ) -> None:
        child_messages = [item for item in messages if item.role == "child"]
        assistant_messages = [item for item in messages if item.role == "assistant"]
        safety_counts = Counter(item.safety_status or "allowed" for item in assistant_messages)
        recent_intents = [
            item.intent
            for item in assistant_messages[-4:]
            if item.intent and item.intent not in {"greeting", "safety_response"}
        ]
        intent_phrase = ", ".join(dict.fromkeys(recent_intents)) if recent_intents else "general_help"
        name = (child_name or "The child").strip() or "The child"
        if safety_counts.get("needs_refusal", 0) > 0 or safety_counts.get("needs_safe_redirect", 0) > 0:
            summary = (
                f"{name} used AI Buddy with safety interventions. "
                f"Topics were redirected toward safer activities. Focus areas: {intent_phrase}."
            )
        else:
            summary = (
                f"{name} used AI Buddy for age-appropriate help. "
                f"Recent focus areas: {intent_phrase}. No safety interventions were needed."
            )
        session.visibility_mode = self.visibility_mode
        session.parent_summary = summary[:500]
        metadata = dict(session.metadata_json or {})
        metadata["parental_visibility_mode"] = self.visibility_mode
        metadata["transcript_visible_to_parent"] = False
        metadata["message_retention_days"] = self.retention_days
        session.metadata_json = metadata

    def build_parent_summary(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> dict[str, Any]:
        child = ai_buddy_persistence_service.get_child_for_parent(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        sessions = self._list_child_sessions(db=db, child_id=child.id)
        provider_state = ai_buddy_response_generator.provider_state()
        return self._build_summary_payload(
            child=child,
            sessions=sessions,
            provider_state=provider_state,
        )

    def build_admin_summary(
        self,
        *,
        db: Session,
        child_id: int,
    ) -> dict[str, Any]:
        child = (
            db.query(ChildProfile)
            .filter(ChildProfile.id == child_id, ChildProfile.deleted_at.is_(None))
            .first()
        )
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")
        sessions = self._list_child_sessions(db=db, child_id=child.id)
        provider_state = ai_buddy_response_generator.provider_state()
        payload = self._build_summary_payload(
            child=child,
            sessions=sessions,
            provider_state=provider_state,
        )
        payload["parent"] = {
            "id": child.parent_id,
            "email": child.parent.email if child.parent is not None else None,
        }
        return payload

    def delete_child_history(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> dict[str, Any]:
        child = ai_buddy_persistence_service.get_child_for_parent(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        sessions = self._list_child_sessions(db=db, child_id=child.id)
        session_count = len(sessions)
        message_count = sum(len(session.messages or []) for session in sessions)
        for session in sessions:
            db.delete(session)
        db.flush()
        return {
            "child_id": child.id,
            "deleted_sessions": session_count,
            "deleted_messages": message_count,
            "deleted_at": db_utc_now().isoformat(),
        }

    def _list_child_sessions(self, *, db: Session, child_id: int) -> list[AiBuddySession]:
        return (
            db.query(AiBuddySession)
            .filter(
                AiBuddySession.child_id == child_id,
                AiBuddySession.archived_at.is_(None),
            )
            .order_by(AiBuddySession.started_at.desc(), AiBuddySession.id.desc())
            .all()
        )

    def _build_summary_payload(
        self,
        *,
        child: ChildProfile,
        sessions: list[AiBuddySession],
        provider_state: AiBuddyProviderState,
    ) -> dict[str, Any]:
        messages = [
            message
            for session in sessions
            for message in (session.messages or [])
            if message.archived_at is None
        ]
        child_messages = [item for item in messages if item.role == "child"]
        assistant_messages = [item for item in messages if item.role == "assistant"]
        safety_counter = Counter(item.safety_status or "allowed" for item in assistant_messages)
        current_session = next((item for item in sessions if item.status == "active"), None)
        recent_flags: list[dict[str, Any]] = []
        for item in assistant_messages:
            if item.safety_status == "allowed":
                continue
            metadata = dict(item.metadata_json or {})
            recent_flags.append(
                {
                    "message_id": item.id,
                    "occurred_at": item.created_at.isoformat() if item.created_at else None,
                    "classification": item.safety_status,
                    "topic": metadata.get("topic"),
                    "reason": metadata.get("moderation_reason"),
                    "action": metadata.get("action_taken"),
                }
            )
        recent_flags = recent_flags[-5:]

        safe_topics = [
            item.intent
            for item in assistant_messages
            if item.intent and item.intent not in {"greeting", "safety_response"}
        ]
        summary_text = (
            current_session.parent_summary
            if current_session is not None and current_session.parent_summary
            else self._build_fallback_summary(
                child_name=child.name,
                intents=safe_topics,
                safety_counter=safety_counter,
            )
        )
        if provider_state.status != "ready":
            summary_text = (
                f"{summary_text} AI Buddy is running in safe fallback mode with no external AI provider."
            )

        return {
            "child_id": child.id,
            "child_name": child.name,
            "visibility_mode": self.visibility_mode,
            "transcript_access": False,
            "parent_summary": summary_text,
            "provider": {
                "configured": provider_state.configured,
                "mode": provider_state.mode,
                "status": provider_state.status,
                "reason": provider_state.reason,
            },
            "retention_policy": {
                "messages_retained_days": self.retention_days,
                "auto_archive": True,
                "delete_supported": True,
            },
            "usage_metrics": {
                "sessions_count": len(sessions),
                "messages_count": len(messages),
                "child_messages_count": len(child_messages),
                "assistant_messages_count": len(assistant_messages),
                "last_session_at": (
                    current_session.last_message_at.isoformat()
                    if current_session is not None and current_session.last_message_at
                    else (sessions[0].last_message_at.isoformat() if sessions and sessions[0].last_message_at else None)
                ),
                "allowed_count": safety_counter.get("allowed", 0),
                "refusal_count": safety_counter.get("needs_refusal", 0),
                "safe_redirect_count": safety_counter.get("needs_safe_redirect", 0),
            },
            "current_session": (
                {
                    "id": current_session.id,
                    "status": current_session.status,
                    "provider_status": current_session.provider_status,
                    "provider_mode": current_session.provider_mode,
                    "last_message_at": (
                        current_session.last_message_at.isoformat()
                        if current_session.last_message_at
                        else None
                    ),
                    "parent_summary": current_session.parent_summary,
                }
                if current_session is not None
                else None
            ),
            "recent_flags": recent_flags,
        }

    def _build_fallback_summary(
        self,
        *,
        child_name: str | None,
        intents: list[str],
        safety_counter: Counter[str],
    ) -> str:
        name = (child_name or "The child").strip() or "The child"
        if safety_counter.get("needs_refusal", 0) or safety_counter.get("needs_safe_redirect", 0):
            return (
                f"{name} used AI Buddy with safety interventions. "
                "Parents can review summary metrics only; full transcripts are hidden by default."
            )
        if intents:
            return (
                f"{name} used AI Buddy for age-appropriate support. "
                f"Recent safe topics: {', '.join(dict.fromkeys(intents[:4]))}."
            )
        return (
            f"{name} has no AI Buddy history yet. "
            "Parents will see summary metrics only when activity starts."
        )


ai_buddy_visibility_service = AiBuddyVisibilityService()
