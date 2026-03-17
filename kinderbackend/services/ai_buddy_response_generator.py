from __future__ import annotations

import re
import logging
from dataclasses import dataclass, field
from typing import Iterable

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class AiBuddyProviderState:
    configured: bool
    mode: str
    status: str
    reason: str | None = None


@dataclass(slots=True)
class AiBuddyGeneratedResponse:
    content: str
    intent: str
    response_source: str
    status: str
    safety_status: str
    provider_state: AiBuddyProviderState
    metadata_json: dict[str, object] = field(default_factory=dict)


class AiBuddyResponseGenerator:
    _arabic_pattern = re.compile(r"[\u0600-\u06ff]")

    def provider_state(self) -> AiBuddyProviderState:
        state = AiBuddyProviderState(
            configured=False,
            mode="internal_fallback",
            status="fallback",
            reason=(
                "AI Buddy is running in safe fallback mode. "
                "No external AI provider is configured yet."
            ),
        )
        logger.info(
            "ai_provider_state configured=%s mode=%s status=%s",
            state.configured,
            state.mode,
            state.status,
        )
        return state

    def greeting(self, *, child_name: str | None = None) -> AiBuddyGeneratedResponse:
        name = (child_name or "").strip()
        if name:
            content = (
                f"Hello {name}! I am your learning buddy in safe mode. "
                "Ask me for a lesson idea, a fun game, or a short story."
            )
        else:
            content = (
                "Hello! I am your learning buddy in safe mode. "
                "Ask me for a lesson idea, a fun game, or a short story."
            )
        response = AiBuddyGeneratedResponse(
            content=content,
            intent="greeting",
            response_source="internal_fallback",
            status="completed",
            safety_status="allowed",
            provider_state=self.provider_state(),
            metadata_json={
                "generation_mode": "greeting",
                "experience_mode": "fallback_only",
            },
        )
        logger.info(
            "ai_buddy_greeting response_source=%s safety_status=%s",
            response.response_source,
            response.safety_status,
        )
        return response

    def generate(
        self,
        *,
        child_name: str | None,
        message: str,
        quick_action: str | None,
        recent_messages: Iterable[str],
    ) -> AiBuddyGeneratedResponse:
        normalized = message.strip()
        normalized_lower = normalized.lower()
        is_arabic = bool(self._arabic_pattern.search(normalized))
        intent = quick_action or self._infer_intent(normalized_lower)
        content = self._build_response(
            child_name=child_name,
            message=normalized,
            intent=intent,
            is_arabic=is_arabic,
            recent_messages=recent_messages,
        )
        response = AiBuddyGeneratedResponse(
            content=content,
            intent=intent,
            response_source="internal_fallback",
            status="completed",
            safety_status="allowed",
            provider_state=self.provider_state(),
            metadata_json={
                "generation_mode": "internal_fallback",
                "experience_mode": "fallback_only",
                "language": "ar" if is_arabic else "en",
                "recent_turns_used": min(sum(1 for _ in recent_messages), 6),
            },
        )
        logger.info(
            "ai_buddy_generate intent=%s response_source=%s safety_status=%s",
            response.intent,
            response.response_source,
            response.safety_status,
        )
        return response

    def _infer_intent(self, lowered: str) -> str:
        if any(token in lowered for token in ("math", "number", "count")):
            return "recommend_lesson"
        if any(token in lowered for token in ("story", "read", "adventure")):
            return "tell_story"
        if any(token in lowered for token in ("game", "play", "fun")):
            return "suggest_game"
        if any(token in lowered for token in ("sad", "upset", "angry", "tired")):
            return "motivation"
        if any(token in lowered for token in ("fact", "why", "how")):
            return "fun_fact"
        return "general_help"

    def _build_response(
        self,
        *,
        child_name: str | None,
        message: str,
        intent: str,
        is_arabic: bool,
        recent_messages: Iterable[str],
    ) -> str:
        if is_arabic:
            return self._build_arabic_response(
                child_name=child_name,
                intent=intent,
                message=message,
            )
        return self._build_english_response(
            child_name=child_name,
            intent=intent,
            message=message,
            recent_messages=recent_messages,
        )

    def _build_english_response(
        self,
        *,
        child_name: str | None,
        intent: str,
        message: str,
        recent_messages: Iterable[str],
    ) -> str:
        prefix = f"{child_name}, " if child_name else ""
        if intent == "recommend_lesson":
            return (
                f"{prefix}let's try a short lesson challenge: count five things around you, "
                "then tell me which one is the biggest."
            )
        if intent == "suggest_game":
            return (
                f"{prefix}here is a simple game: find one red thing, one blue thing, and one soft thing. "
                "When you finish, tell me what you found."
            )
        if intent == "tell_story":
            return (
                "Here is a tiny story: A brave little star felt scared of the dark sky, "
                "but it kept shining until other stars joined in. Soon the whole sky looked friendly."
            )
        if intent == "fun_fact":
            return (
                "Fun fact: octopuses have three hearts. If you want, I can give you another fact about animals or space."
            )
        if intent == "motivation":
            return (
                f"{prefix}it is okay to feel tired or sad sometimes. Take one deep breath, wiggle your shoulders, "
                "and try one small step. I can stay with you and help."
            )
        if any("?" in item for item in recent_messages):
            return (
                f"{prefix}I can help with that. Tell me if you want a lesson idea, a game, a story, or a fun fact."
            )
        return (
            f"{prefix}I heard you say: \"{message[:80]}\". I can help with learning, stories, games, and kind encouragement."
        )

    def _build_arabic_response(
        self,
        *,
        child_name: str | None,
        intent: str,
        message: str,
    ) -> str:
        prefix = f"{child_name}، " if child_name else ""
        if intent == "recommend_lesson":
            return (
                f"{prefix}هيا نجرب نشاطا صغيرا: عد خمس أشياء حولك، ثم أخبرني أي شيء هو الأكبر."
            )
        if intent == "suggest_game":
            return (
                f"{prefix}لعبة سريعة: ابحث عن شيء أحمر وشيء أزرق وشيء ناعم، ثم أخبرني ماذا وجدت."
            )
        if intent == "tell_story":
            return (
                "قصة قصيرة: كان هناك نجم صغير خائف من السماء المظلمة، لكنه استمر في اللمعان حتى ظهرت نجوم أخرى، فأصبحت السماء أجمل وأهدأ."
            )
        if intent == "fun_fact":
            return "معلومة لطيفة: للأخطبوط ثلاثة قلوب. إذا أردت، أستطيع أن أعطيك معلومة أخرى."
        if intent == "motivation":
            return (
                f"{prefix}من الطبيعي أن تشعر بالتعب أو الحزن أحيانا. خذ نفسا عميقا، وحرك كتفيك قليلا، ثم نبدأ خطوة صغيرة معا."
            )
        return (
            f"{prefix}أنا هنا لأساعدك. يمكنني أن أقترح درسا بسيطا أو لعبة ممتعة أو قصة قصيرة أو معلومة جديدة."
        )


ai_buddy_response_generator = AiBuddyResponseGenerator()
