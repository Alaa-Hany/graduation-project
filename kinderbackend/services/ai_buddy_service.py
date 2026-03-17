from __future__ import annotations

import logging
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from core.observability import emit_event
from core.system_settings import require_ai_buddy_enabled
from models import AiBuddyMessage, AiBuddySession, AiInteraction, ChildProfile, User
from services.ai_buddy_moderation import ai_buddy_moderation_service
from services.ai_buddy_persistence import ai_buddy_persistence_service
from services.ai_buddy_response_generator import (
    AiBuddyProviderState,
    ai_buddy_response_generator,
)
from services.ai_buddy_visibility import ai_buddy_visibility_service


logger = logging.getLogger(__name__)


class AiBuddyService:
    def start_session(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
        force_new: bool = False,
        title: str | None = None,
    ) -> dict[str, Any]:
        require_ai_buddy_enabled(db)
        child = ai_buddy_persistence_service.get_child_for_parent(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        session = None if force_new else ai_buddy_persistence_service.get_current_session(
            db=db,
            parent=parent,
            child_id=child.id,
        )
        provider_state = ai_buddy_response_generator.provider_state()

        if session is None:
            session = ai_buddy_persistence_service.create_session(
                db=db,
                parent=parent,
                child=child,
                title=title,
                provider_mode=provider_state.mode,
                provider_status=provider_state.status,
                unavailable_reason=provider_state.reason,
                metadata_json={
                    "message_persistence_policy": "stored_for_30_days",
                    "parental_visibility_mode": ai_buddy_visibility_service.visibility_mode,
                    "transcript_visible_to_parent": False,
                    "experience_mode": provider_state.mode,
                    "experience_status": provider_state.status,
                },
            )
            greeting = ai_buddy_response_generator.greeting(child_name=child.name)
            ai_buddy_persistence_service.add_message(
                db=db,
                session=session,
                role="assistant",
                content=greeting.content,
                intent=greeting.intent,
                response_source=greeting.response_source,
                status=greeting.status,
                safety_status=greeting.safety_status,
                metadata_json=greeting.metadata_json,
            )
            ai_buddy_visibility_service.update_session_summary(
                session=session,
                child_name=child.name,
                messages=ai_buddy_persistence_service.list_messages(db=db, session=session),
            )
            self._record_ai_interaction(
                db=db,
                child=child,
                interaction_type="session_started",
                intent=greeting.intent,
                input_preview=None,
                response_category="greeting",
                safety_status="allowed",
                safety_flags_json={
                    "visibility_mode": ai_buddy_visibility_service.visibility_mode,
                },
                metadata_json={
                    "session_id": session.id,
                    "provider_mode": provider_state.mode,
                },
            )
            db.commit()
            db.refresh(session)
            emit_event(
                "ai.session.started",
                category="ai",
                user_id=parent.id,
                child_id=child.id,
                session_id=session.id,
                provider_mode=provider_state.mode,
                provider_status=provider_state.status,
            )
            logger.info(
                "ai_buddy_session_started parent_id=%s child_id=%s session_id=%s provider_mode=%s",
                parent.id,
                child.id,
                session.id,
                provider_state.mode,
            )

        messages = ai_buddy_persistence_service.list_messages(db=db, session=session)
        return self._serialize_conversation(
            session=session,
            messages=messages,
            provider_state=provider_state,
        )

    def get_current_session(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> dict[str, Any]:
        require_ai_buddy_enabled(db)
        ai_buddy_persistence_service.get_child_for_parent(db=db, parent=parent, child_id=child_id)
        provider_state = ai_buddy_response_generator.provider_state()
        session = ai_buddy_persistence_service.get_current_session(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        if session is None:
            return self._serialize_conversation(
                session=None,
                messages=[],
                provider_state=provider_state,
            )
        messages = ai_buddy_persistence_service.list_messages(db=db, session=session)
        return self._serialize_conversation(
            session=session,
            messages=messages,
            provider_state=provider_state,
        )

    def get_session(
        self,
        *,
        db: Session,
        parent: User,
        session_id: int,
    ) -> dict[str, Any]:
        require_ai_buddy_enabled(db)
        session = ai_buddy_persistence_service.get_session_for_parent(
            db=db,
            parent=parent,
            session_id=session_id,
        )
        provider_state = ai_buddy_response_generator.provider_state()
        messages = ai_buddy_persistence_service.list_messages(db=db, session=session)
        return self._serialize_conversation(
            session=session,
            messages=messages,
            provider_state=provider_state,
        )

    def send_message(
        self,
        *,
        db: Session,
        parent: User,
        session_id: int,
        child_id: int,
        content: str,
        client_message_id: str | None = None,
        quick_action: str | None = None,
    ) -> dict[str, Any]:
        require_ai_buddy_enabled(db)
        child = ai_buddy_persistence_service.get_child_for_parent(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        session = ai_buddy_persistence_service.get_session_for_parent(
            db=db,
            parent=parent,
            session_id=session_id,
        )
        if session.child_id != child.id:
            raise HTTPException(status_code=400, detail="Session does not belong to requested child")

        moderation = ai_buddy_moderation_service.moderate_input(text=content)
        logger.info(
            "ai_buddy_input_moderated parent_id=%s child_id=%s session_id=%s status=%s",
            parent.id,
            child.id,
            session.id,
            moderation.classification,
        )
        emit_event(
            "ai.moderation.input",
            category="ai",
            user_id=parent.id,
            child_id=child.id,
            session_id=session.id,
            classification=moderation.classification,
            topic=moderation.topic,
            action_taken=(
                "continue"
                if moderation.classification == "allowed"
                else "intercept_before_generation"
            ),
        )
        user_metadata = {
            "quick_action": quick_action,
            "topic": moderation.topic,
            "moderation_reason": moderation.reason,
            "moderation_flags": list(moderation.matched_rules),
            "action_taken": (
                "continue"
                if moderation.classification == "allowed"
                else "intercept_before_generation"
            ),
        }
        user_message = ai_buddy_persistence_service.add_message(
            db=db,
            session=session,
            role="child",
            content=content,
            intent=quick_action,
            response_source="client",
            status="completed",
            safety_status=moderation.classification,
            client_message_id=client_message_id,
            metadata_json=user_metadata,
        )
        recent_messages = [
            item.content
            for item in ai_buddy_persistence_service.list_messages(db=db, session=session, limit=6)
            if item.role == "child"
        ]

        provider_state = ai_buddy_response_generator.provider_state()
        assistant_response_source = "internal_fallback"
        assistant_status = "completed"
        assistant_intent = quick_action or "general_help"
        assistant_safety_status = moderation.classification
        assistant_metadata: dict[str, Any] = {
            "topic": moderation.topic,
            "moderation_reason": moderation.reason,
            "moderation_flags": list(moderation.matched_rules),
        }
        assistant_content = moderation.safe_response or ""

        if moderation.classification == "allowed":
            generated = ai_buddy_response_generator.generate(
                child_name=child.name,
                message=content,
                quick_action=quick_action,
                recent_messages=recent_messages,
            )
            output_moderation = ai_buddy_moderation_service.moderate_output(text=generated.content)
            logger.info(
                "ai_buddy_output_moderated parent_id=%s child_id=%s session_id=%s status=%s",
                parent.id,
                child.id,
                session.id,
                output_moderation.classification,
            )
            emit_event(
                "ai.moderation.output",
                category="ai",
                user_id=parent.id,
                child_id=child.id,
                session_id=session.id,
                classification=output_moderation.classification,
                topic=output_moderation.topic,
            )
            provider_state = generated.provider_state
            if output_moderation.classification == "allowed":
                assistant_content = generated.content
                assistant_response_source = generated.response_source
                assistant_status = generated.status
                assistant_intent = generated.intent
                assistant_safety_status = generated.safety_status
                assistant_metadata = {
                    **generated.metadata_json,
                    "topic": output_moderation.topic,
                    "moderation_reason": output_moderation.reason,
                    "moderation_flags": list(output_moderation.matched_rules),
                    "action_taken": "generated_response",
                }
            else:
                assistant_content = output_moderation.safe_response or moderation.safe_response or ""
                assistant_response_source = "safety_policy"
                assistant_intent = "safety_response"
                assistant_safety_status = output_moderation.classification
                assistant_metadata = {
                    **generated.metadata_json,
                    "topic": output_moderation.topic,
                    "moderation_reason": output_moderation.reason,
                    "moderation_flags": list(output_moderation.matched_rules),
                    "action_taken": "replace_generated_response",
                }
        else:
            assistant_response_source = "safety_policy"
            assistant_intent = "safety_response"
            assistant_metadata["action_taken"] = "refusal" if moderation.classification == "needs_refusal" else "safe_redirect"
            logger.warning(
                "ai_buddy_input_blocked parent_id=%s child_id=%s session_id=%s classification=%s",
                parent.id,
                child.id,
                session.id,
                moderation.classification,
            )
            emit_event(
                "ai.safety.blocked",
                category="ai",
                severity="warn",
                user_id=parent.id,
                child_id=child.id,
                session_id=session.id,
                classification=moderation.classification,
                topic=moderation.topic,
            )

        session.provider_mode = provider_state.mode
        session.provider_status = provider_state.status
        session.unavailable_reason = provider_state.reason
        db.add(session)
        assistant_message = ai_buddy_persistence_service.add_message(
            db=db,
            session=session,
            role="assistant",
            content=assistant_content,
            intent=assistant_intent,
            response_source=assistant_response_source,
            status=assistant_status,
            safety_status=assistant_safety_status,
            metadata_json=assistant_metadata,
        )
        ai_buddy_visibility_service.update_session_summary(
            session=session,
            child_name=child.name,
            messages=ai_buddy_persistence_service.list_messages(db=db, session=session),
        )
        if provider_state.status != "ready":
            logger.warning(
                "ai_buddy_fallback parent_id=%s child_id=%s session_id=%s reason=%s",
                parent.id,
                child.id,
                session.id,
                provider_state.reason,
            )
            emit_event(
                "ai.fallback",
                category="ai",
                severity="warn",
                user_id=parent.id,
                child_id=child.id,
                session_id=session.id,
                provider_mode=provider_state.mode,
                provider_status=provider_state.status,
                reason=provider_state.reason,
            )
        self._record_ai_interaction(
            db=db,
            child=child,
            interaction_type=(
                "safety_intervention"
                if assistant_safety_status != "allowed"
                else "conversation_turn"
            ),
            intent=assistant_intent,
            input_preview=content[:180],
            response_category=assistant_intent,
            safety_status=assistant_safety_status,
            safety_flags_json={
                "input_classification": moderation.classification,
                "topic": assistant_metadata.get("topic"),
                "action_taken": assistant_metadata.get("action_taken"),
            },
            metadata_json={
                "session_id": session.id,
                "user_message_id": user_message.id,
                "assistant_message_id": assistant_message.id,
                "provider_mode": provider_state.mode,
                "provider_status": provider_state.status,
            },
        )
        db.commit()
        db.refresh(session)
        emit_event(
            "ai.message.completed",
            category="ai",
            user_id=parent.id,
            child_id=child.id,
            session_id=session.id,
            safety_status=assistant_safety_status,
            response_source=assistant_response_source,
            intent=assistant_intent,
        )
        return {
            "session": self._serialize_session(session),
            "user_message": self._serialize_message(user_message),
            "assistant_message": self._serialize_message(assistant_message),
            "provider": self._serialize_provider(provider_state),
        }

    def get_parent_visibility_summary(
        self,
        *,
        db: Session,
        parent: User,
        child_id: int,
    ) -> dict[str, Any]:
        return ai_buddy_visibility_service.build_parent_summary(
            db=db,
            parent=parent,
            child_id=child_id,
        )

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
        payload = ai_buddy_visibility_service.delete_child_history(
            db=db,
            parent=parent,
            child_id=child_id,
        )
        emit_event(
            "ai.history.deleted",
            category="ai",
            user_id=parent.id,
            child_id=child.id,
            session_id=payload.get("session_id"),
        )
        self._record_ai_interaction(
            db=db,
            child=child,
            interaction_type="history_deleted",
            intent=None,
            input_preview=None,
            response_category="deletion",
            safety_status="allowed",
            safety_flags_json={"action": "delete_child_history"},
            metadata_json=payload,
        )
        db.commit()
        return payload

    def _record_ai_interaction(
        self,
        *,
        db: Session,
        child: ChildProfile,
        interaction_type: str,
        intent: str | None,
        input_preview: str | None,
        response_category: str | None,
        safety_status: str,
        safety_flags_json: dict[str, Any] | None,
        metadata_json: dict[str, Any] | None,
    ) -> None:
        interaction = AiInteraction(
            child_id=child.id,
            interaction_type=interaction_type,
            intent=intent,
            input_preview=input_preview,
            response_category=response_category,
            safety_status=safety_status,
            source="ai_buddy",
            safety_flags_json=safety_flags_json or {},
            metadata_json=metadata_json or {},
        )
        db.add(interaction)
        db.flush()

    def _serialize_conversation(
        self,
        *,
        session: AiBuddySession | None,
        messages: list[AiBuddyMessage],
        provider_state: AiBuddyProviderState,
    ) -> dict[str, Any]:
        return {
            "session": self._serialize_session(session) if session is not None else None,
            "messages": [self._serialize_message(item) for item in messages],
            "provider": self._serialize_provider(provider_state),
        }

    def _serialize_provider(self, provider_state: AiBuddyProviderState) -> dict[str, Any]:
        return {
            "configured": provider_state.configured,
            "mode": provider_state.mode,
            "status": provider_state.status,
            "reason": provider_state.reason,
        }

    def _serialize_session(self, session: AiBuddySession) -> dict[str, Any]:
        return {
            "id": session.id,
            "child_id": session.child_id,
            "parent_user_id": session.parent_user_id,
            "status": session.status,
            "title": session.title,
            "provider_mode": session.provider_mode,
            "provider_status": session.provider_status,
            "unavailable_reason": session.unavailable_reason,
            "visibility_mode": session.visibility_mode,
            "parent_summary": session.parent_summary,
            "started_at": session.started_at.isoformat() if session.started_at else None,
            "last_message_at": session.last_message_at.isoformat() if session.last_message_at else None,
            "ended_at": session.ended_at.isoformat() if session.ended_at else None,
            "retention_expires_at": (
                session.retention_expires_at.isoformat() if session.retention_expires_at else None
            ),
            "metadata_json": session.metadata_json or {},
            "messages_count": len(session.messages or []),
        }

    def _serialize_message(self, message: AiBuddyMessage) -> dict[str, Any]:
        return {
            "id": message.id,
            "session_id": message.session_id,
            "child_id": message.child_id,
            "role": message.role,
            "content": message.content,
            "intent": message.intent,
            "response_source": message.response_source,
            "status": message.status,
            "client_message_id": message.client_message_id,
            "safety_status": message.safety_status,
            "metadata_json": message.metadata_json or {},
            "retention_expires_at": (
                message.retention_expires_at.isoformat() if message.retention_expires_at else None
            ),
            "archived_at": message.archived_at.isoformat() if message.archived_at else None,
            "created_at": message.created_at.isoformat() if message.created_at else None,
        }


ai_buddy_service = AiBuddyService()
