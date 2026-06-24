from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

from services.ai_buddy_openai_moderation import openai_moderation_service

logger = logging.getLogger(__name__)

# Normalize Arabic letter variants (alef/yaa/taa-marbuta forms) so a keyword
# like "اقتل" also matches "أقتل"/"إقتل" without having to list every spelling.
_ARABIC_ALEF = re.compile(r"[أإآ]")

# Arabic clitics that legitimately attach to the front of a word
# (e.g. "ال" the, "و" and, "بـ" with, "لـ" for). Allowing these lets a rule
# keyword like "دم" still match "الدم"/"ودم" while NOT matching the unrelated
# word "عندما" (where the letters د+م merely appear in the middle).
_ARABIC_PREFIXES = "و|ف|ب|ك|ل|س|ال|وال|فال|بال|كال|لل"
# Common Arabic suffixes (pronoun/plural/feminine endings).
_ARABIC_SUFFIXES = "ها|هم|هن|ه|كم|ك|نا|ي|ون|ين|ات|ة"
# English inflections so "gun" also matches "guns", "kill" matches "killing".
_ENGLISH_SUFFIXES = "es|s|ed|ing|er"

# Strip tatweel and Arabic diacritics so they don't break word matching.
_ARABIC_NOISE = re.compile(r"[ـً-ْٰ]")


def _keyword_matches(keyword: str, text: str) -> bool:
    """Return True when ``keyword`` appears in ``text`` as a whole word.

    Multi-word phrases ("phone number", "kill myself") are matched as a plain
    substring because they are long enough to be safe. Single words are matched
    on word boundaries so short keywords like "دم" or "kill" no longer trigger
    on innocent words such as "عندما" (when) or "skill".
    """
    if " " in keyword:
        return keyword in text
    if _arabic_pattern_module.search(keyword):
        pattern = rf"\b(?:{_ARABIC_PREFIXES})?{re.escape(keyword)}(?:{_ARABIC_SUFFIXES})?\b"
    else:
        pattern = rf"\b{re.escape(keyword)}(?:{_ENGLISH_SUFFIXES})?\b"
    return re.search(pattern, text) is not None


_arabic_pattern_module = re.compile(r"[؀-ۿ]")


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
    # OpenAI's own `flagged` boolean over-triggers the violence category on
    # perfectly innocent kid prompts ("tell me a story" / "\u0627\u062d\u0643 \u0644\u064a \u0642\u0635\u0629" score
    # ~0.35), while genuinely unsafe content scores >= ~0.85 in whichever
    # category it trips. We therefore ignore the raw `flagged` boolean and only
    # treat a category as a real hit once its calibrated score clears this
    # threshold, which sits comfortably between the false-positive (~0.35) and
    # the true-positive (~0.85+) bands.
    _openai_score_threshold = 0.5
    # OpenAI moderation category prefix -> (classification, topic). Ordered so
    # the most serious mapping wins when several categories are flagged at once.
    _openai_category_map = (
        ("sexual", "needs_refusal", "sexual_content"),
        ("violence", "needs_refusal", "violence"),
        ("illicit/violent", "needs_refusal", "violence"),
        ("self-harm", "needs_safe_redirect", "self_harm"),
        ("harassment", "needs_safe_redirect", "bullying_or_hate"),
        ("hate", "needs_safe_redirect", "bullying_or_hate"),
    )
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

    def _normalize_arabic(self, text: str) -> str:
        """Normalize Arabic letter variants before matching."""
        text = _ARABIC_ALEF.sub("ا", text)
        text = text.replace("ة", "ه")
        text = text.replace("ى", "ي")
        return text

    def _moderate(self, *, text: str, source: str) -> AiBuddyModerationDecision:
        normalized = (text or "").strip()
        lowered = _ARABIC_NOISE.sub("", self._normalize_arabic(normalized.lower()))
        language = "ar" if self._arabic_pattern.search(normalized) else "en"

        for rule in self._rules:
            hits = [
                keyword
                for keyword in rule.keywords
                if _keyword_matches(self._normalize_arabic(keyword), lowered)
            ]
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
                    "moderation_layer": "keyword",
                },
            )

        # Keyword rules found nothing — ask the OpenAI moderation API as a second
        # layer to catch semantic cases the keyword lists miss.
        ai_decision = self._moderate_with_openai(text=normalized, language=language, source=source)
        if ai_decision is not None:
            return ai_decision

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

    def _map_openai_categories(
        self, category_scores: dict[str, float]
    ) -> tuple[str | None, str | None, list[str]]:
        # Only categories whose calibrated score clears the threshold count as a
        # real hit, so a low-confidence violence score on a benign prompt does
        # not trigger a refusal. (Booleans pass through fine: True >= 0.5.)
        active = [
            name
            for name, score in category_scores.items()
            if score >= self._openai_score_threshold
        ]
        if not active:
            return None, None, []
        for prefix, classification, topic in self._openai_category_map:
            matched = [name for name in active if name.startswith(prefix)]
            if matched:
                return classification, topic, matched
        return None, None, []

    def _moderate_with_openai(
        self, *, text: str, language: str, source: str
    ) -> AiBuddyModerationDecision | None:
        result = openai_moderation_service.moderate(text)
        if result is None or not result.flagged:
            return None
        classification, topic, matched = self._map_openai_categories(result.category_scores)
        if classification is None or topic is None:
            return None
        logger.info(
            "ai_buddy_openai_moderation source=%s flagged=True classification=%s topic=%s categories=%s",
            source,
            classification,
            topic,
            matched,
        )
        return AiBuddyModerationDecision(
            classification=classification,
            topic=topic,
            reason="Flagged by the OpenAI moderation layer.",
            language=language,
            matched_rules=tuple(matched),
            safe_response=self._safe_response(
                language=language,
                classification=classification,
                topic=topic,
            ),
            metadata_json={
                "moderation_source": source,
                "matched_rules": matched,
                "topic": topic,
                "classification": classification,
                "moderation_layer": "openai",
            },
        )

    def _safe_response(self, *, language: str, classification: str, topic: str) -> str:
        if language == "ar":
            if classification == "needs_refusal":
                return (
                    "لا أستطيع المساعدة في هذا الموضوع. إذا كان هناك شيء يقلقك، تحدث مع والدك أو مع شخص بالغ موثوق. "
                    "يمكنني بدلًا من ذلك أن أقترح نشاطًا هادئًا أو قصة قصيرة."
                )
            return "لنحافظ على الحديث آمنًا ومناسبًا. لا تشارك معلومات خاصة، وتعال نختار شيئًا آمنًا مثل قصة قصيرة أو لعبة تعليمية."

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
