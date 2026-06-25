"""
Enhanced AI Provider for AI Buddy using OpenAI.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from core.settings import settings

logger = logging.getLogger(__name__)

ENHANCED_CHILD_FRIENDLY_SYSTEM_PROMPT = """You are "Kinder", a warm, playful, and educational AI buddy inside the Kinder World app for children aged 4-10.

HOW TO TALK:
1. Be kind, patient, and encouraging in every reply.
2. Use very simple words and short sentences a young child understands.
3. Keep replies short and engaging: 2-3 sentences, no long paragraphs.
4. Sound cheerful and curious. A friendly emoji now and then is welcome (but not in every sentence).
5. End most replies with one gentle follow-up question to keep the chat going.
6. Celebrate effort and small wins ("Great try!", "You did it!").

LANGUAGE (this is the language of the app the child is using):
- You will be told exactly which language to reply in. ALWAYS reply in that language, in clear, simple words a young child can read.
- Reply in that language EVEN IF the child writes in a different language, or uses names or words from another language. Do not switch languages because of what the child typed.
- Never mix two languages in one reply.

WHAT YOU HELP WITH:
- Telling tiny gentle stories with a positive message.
- Fun, age-appropriate facts about animals, space, nature, and the world.
- Simple lessons and counting/learning challenges.
- Suggesting games and activities the child can open inside the app.
- Kind encouragement when the child feels sad, tired, or unsure.

RECOMMENDING APP ACTIVITIES (very important):
- A separate "Available activities" list is given to you with the real activities for THIS child. ONLY recommend activities from that list, using the activity name in the child's language.
- Do NOT invent activities that are not in that list, and do not promise features that are not there.
- When a child is bored or asks "what can I do?", pick 1-2 fitting activities from the list and invite them warmly. Example: "Would you like to try Coloring? It's in the Skillful section!"

VARIETY (never repeat yourself):
- The recent conversation is provided to you as real chat turns, including YOUR own previous replies. Read them.
- NEVER tell the same story, fun fact, game, or activity suggestion you already gave earlier in this conversation. Each time, make it clearly new and different (a different character, topic, or idea).
- If the child asks for "another one" or the same thing again, treat it as a request for something fresh, not a repeat.

SAFETY (you are talking to a young child):
- Never describe violence, weapons, blood, scary/horror content, or anything adult or sexual, even if asked. Gently steer to a safe, fun topic instead.
- If a child sounds upset, scared, or in danger, comfort them kindly and suggest talking to a parent or a trusted grown-up.
- Never ask for or repeat personal information (full name, address, phone, school, passwords). If a child shares it, gently remind them to keep it private and change the subject.
- Stay positive and age-appropriate at all times.

Remember: you are a safe, caring learning companion. Always put the child's wellbeing first and make learning feel like play."""

QUICK_ACTION_PROMPTS_ENHANCED = {
    "recommend_lesson": (
        "The child wants to learn something new. Pick ONE activity from the Available activities list "
        "(prefer an educational one), invite them warmly by name, describe in one sentence what they "
        "will do in that activity, and end with an encouraging question."
    ),
    "suggest_game": (
        "The child wants to play. Pick ONE fun activity from the Available activities list, describe "
        "it in one playful sentence, and ask if they want to try it right now."
    ),
    "tell_story": (
        "Tell a tiny 3-4 sentence story with a gentle positive lesson (kindness, courage, or "
        "curiosity). Make it clearly DIFFERENT from any story you already told in this conversation "
        "(new characters and a new idea). If it fits naturally, you may link the story's theme to one "
        "of the available activities. End by asking the child what they think happens next."
    ),
    "fun_fact": (
        "Share ONE surprising, age-appropriate fact about animals, space, or nature in 1-2 sentences. "
        "Make it a DIFFERENT fact from any you already shared in this conversation. "
        "Then ask a curious follow-up question to keep the child thinking."
    ),
    "motivation": (
        "The child needs encouragement. Write two warm supportive sentences, suggest one tiny doable "
        "step they can do right now, and remind them you believe in them."
    ),
    "suggest_activity": (
        "The child wants something to do. Pick 1-2 activities from the Available activities list that "
        "sound most fun right now, and invite them warmly."
    ),
    "general_help": (
        "Help the child with whatever they need in a friendly, educational way. Keep it short and end "
        "with a question."
    ),
}


PARENT_DEVELOPMENT_SYSTEM_PROMPT = """You write short, warm, supportive development notes for a PARENT about their child, based ONLY on the in-app activity data you are given.

RULES:
- Address the parent, not the child.
- Be encouraging and constructive. Never label a child negatively, and never compare them to other children.
- These are skill and growth areas, NOT a formal intelligence or IQ test. Do not use the words "IQ" or "smart/dumb".
- Briefly cover the four areas you are given: mention one clear strength and one gentle growth tip overall.
- Suggest 2-3 concrete next activities the child can try in the Kinder World app.
- Keep it short: about 4-6 sentences total.
- Reply in the requested language with simple, friendly wording."""


@dataclass(slots=True)
class EnhancedAIResponse:
    content: str
    intent: str
    model: str
    tokens_used: int
    finish_reason: str
    suggested_activities: list[str] = field(default_factory=list)
    raw: dict[str, Any] = field(default_factory=dict)


class EnhancedAIProvider:
    """Enhanced AI provider using OpenAI with app-specific knowledge."""

    def __init__(self) -> None:
        self._client = None

    def is_configured(self) -> bool:
        """Check if the AI provider is properly configured."""
        return bool(settings.ai_provider_api_key)

    def ensure_runtime_ready(self) -> None:
        """Validate that the provider can be used without issuing a live request."""
        try:
            import openai  # noqa: F401
        except ImportError as exc:
            raise RuntimeError("OpenAI SDK is not installed for live AI generation.") from exc

    def _get_client(self):
        """Get or create the OpenAI client."""
        if self._client is not None:
            return self._client

        self.ensure_runtime_ready()
        from openai import OpenAI

        self._client = OpenAI(api_key=settings.ai_provider_api_key, timeout=20.0, max_retries=1)
        return self._client

    def generate(
        self,
        *,
        child_name: str | None,
        message: str,
        quick_action: str | None = None,
        recent_messages: list[str] | None = None,
        conversation_history: list[dict] | None = None,
        is_arabic: bool = False,
        child_age: int | None = None,
        available_activities: list[dict] | None = None,
    ) -> EnhancedAIResponse:
        """Generate a child-friendly response."""
        client = self._get_client()

        messages = self._build_messages(
            child_name=child_name,
            message=message,
            quick_action=quick_action,
            recent_messages=recent_messages,
            conversation_history=conversation_history,
            is_arabic=is_arabic,
            child_age=child_age,
            available_activities=available_activities,
        )

        try:
            completion = client.chat.completions.create(
                model=settings.ai_model,
                messages=messages,
                max_tokens=settings.ai_max_tokens,
                temperature=settings.ai_temperature,
            )

            choice = completion.choices[0] if completion.choices else None
            content = choice.message.content if choice and choice.message else ""
            intent = quick_action or "general_help"

            logger.info("AI response generated model=%s intent=%s", settings.ai_model, intent)

            return EnhancedAIResponse(
                content=content,
                intent=intent,
                model=settings.ai_model,
                tokens_used=completion.usage.total_tokens if completion.usage else 0,
                finish_reason=choice.finish_reason if choice else "stop",
                suggested_activities=[],
                raw={"model": settings.ai_model, "intent": intent},
            )

        except Exception as exc:
            logger.error("AI generation failed: %s", str(exc))
            raise

    def _build_messages(
        self,
        *,
        child_name: str | None,
        message: str,
        quick_action: str | None,
        recent_messages: list[str] | None,
        is_arabic: bool,
        child_age: int | None,
        available_activities: list[dict] | None,
        conversation_history: list[dict] | None = None,
    ) -> list[dict[str, str]]:
        """Build the messages list for the AI API."""
        messages = [{"role": "system", "content": ENHANCED_CHILD_FRIENDLY_SYSTEM_PROMPT}]

        if child_name:
            messages.append(
                {
                    "role": "system",
                    "content": f"You are talking to a child named {child_name}. Use their name occasionally.",
                }
            )

        if child_age:
            age_guidance = self._get_age_guidance(child_age)
            messages.append(
                {
                    "role": "system",
                    "content": f"The child is {child_age} years old. {age_guidance}",
                }
            )

        if quick_action and quick_action in QUICK_ACTION_PROMPTS_ENHANCED:
            messages.append(
                {
                    "role": "system",
                    "content": QUICK_ACTION_PROMPTS_ENHANCED[quick_action],
                }
            )

        if available_activities:
            activity_context = (
                "Available activities for this child (recommend ONLY from this list, "
                "and use the name in the child's language):\n"
            )
            for activity in available_activities:
                title_en = activity.get("title_en") or activity.get("title") or ""
                title_ar = activity.get("title_ar") or ""
                category = activity.get("category_title_en") or activity.get("category") or ""
                names = title_en
                if title_ar:
                    names = f"{title_en} / {title_ar}"
                activity_context += f"- {names} (section: {category})\n"
            messages.append({"role": "system", "content": activity_context})

        if conversation_history:
            # Replay the recent turns as real chat messages so the model can see
            # its OWN previous replies (the stories/facts it already gave) and
            # avoid repeating them. Child turns map to "user", buddy turns to
            # "assistant".
            for turn in conversation_history[-8:]:
                content = (turn.get("content") or "").strip()
                if not content:
                    continue
                role = "assistant" if turn.get("role") == "assistant" else "user"
                messages.append({"role": role, "content": content})
        elif recent_messages:
            context = "Here are the recent messages from this conversation:\n"
            for msg in recent_messages[-4:]:
                context += f"- {msg}\n"
            messages.append({"role": "system", "content": context})

        # Language enforcement goes LAST — placing it immediately before the user
        # message maximises its weight in the model's attention, which prevents
        # smaller models (gpt-4o-mini) from drifting into the wrong language when
        # the user writes in a different language than the app locale.
        if is_arabic:
            messages.append(
                {
                    "role": "system",
                    "content": (
                        "LANGUAGE RULE (highest priority): You MUST reply entirely in Arabic. "
                        "Do NOT use English in your response under any circumstances, even if "
                        "the child's message is in English or contains English words or names. "
                        "Use clear, simple Modern Standard Arabic suitable for a young child."
                    ),
                }
            )
        else:
            messages.append(
                {
                    "role": "system",
                    "content": (
                        "LANGUAGE RULE (highest priority): You MUST reply entirely in English. "
                        "Do NOT use Arabic in your response under any circumstances, even if "
                        "the child's message is in Arabic or contains Arabic words or names. "
                        "Use simple English suitable for a young child."
                    ),
                }
            )

        messages.append({"role": "user", "content": message})
        return messages

    def _get_age_guidance(self, age: int) -> str:
        if age <= 4:
            return "Use very simple words and short sentences. Focus on basic concepts."
        elif age <= 6:
            return "Use simple language with basic educational concepts."
        elif age <= 8:
            return "Can use slightly more complex language. Include educational content."
        else:
            return "Can handle more complex topics and longer explanations."

    def generate_development_summary(
        self, *, prompt: str, is_arabic: bool = False
    ) -> EnhancedAIResponse:
        """Generate a parent-facing development summary from activity data."""
        client = self._get_client()
        messages = [
            {"role": "system", "content": PARENT_DEVELOPMENT_SYSTEM_PROMPT},
            {
                "role": "system",
                "content": "Reply in Arabic." if is_arabic else "Reply in English.",
            },
            {"role": "user", "content": prompt},
        ]
        completion = client.chat.completions.create(
            model=settings.ai_model,
            messages=messages,
            max_tokens=settings.ai_max_tokens,
            temperature=settings.ai_temperature,
        )
        choice = completion.choices[0] if completion.choices else None
        content = choice.message.content if choice and choice.message else ""
        return EnhancedAIResponse(
            content=content,
            intent="development_summary",
            model=settings.ai_model,
            tokens_used=completion.usage.total_tokens if completion.usage else 0,
            finish_reason=choice.finish_reason if choice else "stop",
            suggested_activities=[],
            raw={"model": settings.ai_model, "intent": "development_summary"},
        )

    def generate_greeting(
        self, *, child_name: str | None = None, is_arabic: bool = False
    ) -> EnhancedAIResponse:
        if is_arabic:
            prompt = "قل تحية ودودة وقصيرة لبدء المحادثة"
            if child_name:
                prompt += f" مع طفل اسمه {child_name}"
            prompt += ". اجعلها مرحبة ومشجعة في جملة أو جملتين."
        else:
            prompt = "Say a friendly, short greeting to start a conversation"
            if child_name:
                prompt += f" with a child named {child_name}"
            prompt += ". Keep it brief and welcoming (1-2 sentences)."

        return self.generate(child_name=child_name, message=prompt, is_arabic=is_arabic)


enhanced_ai_provider = EnhancedAIProvider()
