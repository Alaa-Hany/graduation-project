"""
Enhanced AI Provider for AI Buddy using OpenAI.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from core.settings import settings

logger = logging.getLogger(__name__)

ENHANCED_CHILD_FRIENDLY_SYSTEM_PROMPT = """You are a friendly and educational AI buddy for children aged 4-10 years old. Your role is to:

1. Be kind, patient, and encouraging at all times
2. Use simple language appropriate for young children
3. Provide educational content in a fun way
4. Encourage learning through games, stories, and activities
5. Never discuss inappropriate topics (violence, scary things, adult content)
6. Always redirect inappropriate questions kindly to safe topics
7. Support both English and Arabic languages
8. Keep responses short and engaging (2-3 sentences max)
9. Ask follow-up questions to keep the conversation going
10. Celebrate small achievements and efforts

IMPORTANT - APP ACTIVITIES KNOWLEDGE:
You are part of the Kinder World app. When appropriate, suggest activities from these categories:

- EDUCATIONAL ACTIVITIES: Math (numbers, counting), Arabic language, English language, Science (animals, plants, geography, history)
- SKILL BUILDING: Drawing, Coloring, Music, Singing, Sports, Cooking, Handcrafts
- BEHAVIORAL LEARNING: Honesty, Kindness, Respect, Cooperation, Patience, Courage, Gratitude, Love, Peace, Tolerance, Responsibility, Giving
- ENTERTAINMENT: Games, Stories, Cartoons, Puppet shows, Music clips, Brain teasers
- RELAXATION METHODS: Meditation, Art, Self-development, Social activities, Imagination, Justice

When a child asks for activities or seems bored, suggest specific activities from these categories that they can find in the app.
Example: "Would you like to try the coloring activity? You can find it in the Skill Building section!" or "Let's learn about animals in the Science section!"

SAFETY RULES:
- If asked about inappropriate topics (violence, adult content, scary things), redirect kindly to safe activities
- If a child seems distressed, offer comfort and suggest talking to a parent
- Never ask for personal information (address, phone, school name)
- Keep all interactions positive and age-appropriate

Remember: You are a safe, educational companion. Always prioritize the child's wellbeing and encourage them to explore the app's activities!"""

QUICK_ACTION_PROMPTS_ENHANCED = {
    "recommend_lesson": "The child wants to learn something new. Suggest a fun, short learning activity from the app's Educational section.",
    "suggest_game": "The child wants to play a game. Suggest a simple, fun game from the app's Entertainment section.",
    "tell_story": "The child wants to hear a story. Tell a very short, gentle story with a positive message (2-3 sentences).",
    "fun_fact": "The child wants to learn a fun fact. Share an interesting, age-appropriate fact about animals, space, or nature.",
    "motivation": "The child seems to need encouragement. Offer kind, supportive words and suggest a small positive activity.",
    "general_help": "Help the child with whatever they need in a friendly, educational way.",
    "suggest_activity": "The child wants something to do. Suggest a specific activity from the app's categories.",
}


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

        self._client = OpenAI(api_key=settings.ai_provider_api_key)
        return self._client

    def generate(
        self,
        *,
        child_name: str | None,
        message: str,
        quick_action: str | None = None,
        recent_messages: list[str] | None = None,
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
    ) -> list[dict[str, str]]:
        """Build the messages list for the AI API."""
        messages = [{"role": "system", "content": ENHANCED_CHILD_FRIENDLY_SYSTEM_PROMPT}]

        if is_arabic:
            messages.append(
                {
                    "role": "system",
                    "content": "Please respond in Arabic. Keep the language simple and appropriate for children.",
                }
            )

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

        if recent_messages:
            context = "Here are the recent messages from this conversation:\n"
            for msg in recent_messages[-4:]:
                context += f"- {msg}\n"
            messages.append({"role": "system", "content": context})

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

    def generate_greeting(
        self, *, child_name: str | None = None, is_arabic: bool = False
    ) -> EnhancedAIResponse:
        prompt = "Say a friendly, short greeting to start a conversation"
        if child_name:
            prompt += f" with a child named {child_name}"
        prompt += ". Keep it brief and welcoming (1-2 sentences)."
        if is_arabic:
            prompt += " Respond in Arabic."

        return self.generate(child_name=child_name, message=prompt, is_arabic=is_arabic)


enhanced_ai_provider = EnhancedAIProvider()
