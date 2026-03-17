from __future__ import annotations

import re
import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class AiBuddyModerationDecision:
    classification: str
    topic: str
    reason: str
    language: str
    matched_rules: tuple[str, ...] = ()
    safe_response: str | None = None
    metadata_json: dict[str, object] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class _SafetyRule:
    name: str
    topic: str
    classification: str
    reason: str
    keywords: tuple[str, ...]


class AiBuddyModerationService:
    _arabic_pattern = re.compile(r"[\u0600-\u06ff]")
    _rules = (
        _SafetyRule(
            name="self_harm",
            topic="self_harm",
            classification="needs_refusal",
            reason="Self-harm content is not appropriate for child-facing AI support.",
            keywords=(
                "kill myself",
                "hurt myself",
                "suicide",
                "cut myself",
                "انتحار",
                "أقتل نفسي",
                "اقتل نفسي",
                "أؤذي نفسي",
                "اؤذي نفسي",
            ),
        ),
        _SafetyRule(
            name="violence",
            topic="violence",
            classification="needs_refusal",
            reason="Violent or weapon-related content is blocked for age-appropriate responses.",
            keywords=(
                "kill",
                "stab",
                "gun",
                "knife",
                "bomb",
                "blood",
                "shoot",
                "weapon",
                "سلاح",
                "سكين",
                "دم",
                "قتل",
                "قنبلة",
                "مسدس",
            ),
        ),
        _SafetyRule(
            name="sexual_content",
            topic="sexual_content",
            classification="needs_refusal",
            reason="Sexual or explicit content is not appropriate for child-facing AI support.",
            keywords=(
                "sex",
                "naked",
                "porn",
                "kiss me",
                "bedroom",
                "جنس",
                "عاري",
                "إباحي",
                "اباحي",
                "قبلني",
            ),
        ),
        _SafetyRule(
            name="personal_data",
            topic="personal_data",
            classification="needs_safe_redirect",
            reason="Personal data sharing should be redirected to a safer topic.",
            keywords=(
                "my address",
                "address is",
                "phone number",
                "my phone",
                "where i live",
                "password",
                "عنواني",
                "رقم تليفوني",
                "رقم هاتفي",
                "كلمة السر",
                "اين اعيش",
                "أين أعيش",
            ),
        ),
        _SafetyRule(
            name="bullying_or_hate",
            topic="bullying_or_hate",
            classification="needs_safe_redirect",
            reason="Bullying and hate requests should be redirected to kinder alternatives.",
            keywords=(
                "i hate",
                "bully",
                "make fun of",
                "mean to",
                "أكره",
                "تنمر",
                "اسخر من",
                "أضايق",
            ),
        ),
    )

    def moderate_input(self, *, text: str) -> AiBuddyModerationDecision:
        decision = self._moderate(text=text, source="input")
        logger.info(
            "ai_buddy_moderation_input classification=%s topic=%s",
            decision.classification,
            decision.topic,
        )
        return decision

    def moderate_output(self, *, text: str) -> AiBuddyModerationDecision:
        decision = self._moderate(text=text, source="output")
        logger.info(
            "ai_buddy_moderation_output classification=%s topic=%s",
            decision.classification,
            decision.topic,
        )
        return decision

    def _moderate(self, *, text: str, source: str) -> AiBuddyModerationDecision:
        normalized = (text or "").strip()
        lowered = normalized.lower()
        language = "ar" if self._arabic_pattern.search(normalized) else "en"

        for rule in self._rules:
            hits = [keyword for keyword in rule.keywords if keyword in lowered]
            if not hits:
                continue
            return AiBuddyModerationDecision(
                classification=rule.classification,
                topic=rule.topic,
                reason=rule.reason,
                language=language,
                matched_rules=tuple(hits),
                safe_response=self._safe_response(
                    language=language,
                    classification=rule.classification,
                    topic=rule.topic,
                ),
                metadata_json={
                    "moderation_source": source,
                    "matched_rules": hits,
                    "topic": rule.topic,
                    "classification": rule.classification,
                },
            )

        return AiBuddyModerationDecision(
            classification="allowed",
            topic="general",
            reason="No unsafe patterns detected.",
            language=language,
            metadata_json={
                "moderation_source": source,
                "matched_rules": [],
                "topic": "general",
                "classification": "allowed",
            },
        )

    def _safe_response(self, *, language: str, classification: str, topic: str) -> str:
        if language == "ar":
            if classification == "needs_refusal":
                return (
                    "لا أستطيع المساعدة في هذا الموضوع. إذا كان هناك شيء يقلقك، تحدث مع والدك أو مع شخص بالغ موثوق. "
                    "يمكنني بدلًا من ذلك أن أقترح نشاطًا هادئًا أو قصة قصيرة."
                )
            return (
                "لنحافظ على الحديث آمنًا ومناسبًا. لا تشارك معلومات خاصة، وتعال نختار شيئًا آمنًا مثل قصة قصيرة أو لعبة تعليمية."
            )

        if classification == "needs_refusal":
            return (
                "I can't help with that topic. Please talk to a parent or another trusted grown-up if you need help. "
                "I can switch to a calm story, a simple lesson, or a safe game instead."
            )
        return (
            "Let's keep things safe and private. Please do not share personal information. "
            "We can switch to a story, a learning idea, or a fun game instead."
        )


ai_buddy_moderation_service = AiBuddyModerationService()
