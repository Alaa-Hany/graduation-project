"""Unit tests for services.ai_buddy_response_generator.

Covers the internal fallback backend (all intents, EN + AR), the enhanced
provider backend's provider_state branches (with a fake provider), and the
top-level AiBuddyResponseGenerator fallback orchestration.
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest

import services.ai_buddy_response_generator as rg_module
from services.ai_buddy_response_generator import (
    AiBuddyResponseGenerator,
    _EnhancedAiBuddyBackend,
    _InternalFallbackAiBuddyBackend,
)


class _FakeContentService:
    def __init__(self, activities=None):
        self._activities = activities or []

    def get_activities_for_age(self, age):
        return self._activities


_ACTIVITIES = [
    {
        "title_en": "Counting Fun",
        "category_title_en": "Educational",
        "slug": "counting-fun",
        "category": "educational",
    },
    {
        "title_en": "Hide and Seek",
        "category_title_en": "Entertainment",
        "slug": "hide-seek",
        "category": "entertainment",
    },
]


@pytest.fixture
def patch_settings():
    from core.settings import settings

    saved: dict = {}

    def _set(**fields):
        for name, value in fields.items():
            saved.setdefault(name, getattr(settings, name))
            object.__setattr__(settings, name, value)

    yield _set
    for name, value in saved.items():
        object.__setattr__(settings, name, value)


# ---------------------------------------------------------------------------
# _InternalFallbackAiBuddyBackend
# ---------------------------------------------------------------------------


@pytest.fixture
def fallback():
    return _InternalFallbackAiBuddyBackend(content_service=_FakeContentService(_ACTIVITIES))


def test_fallback_provider_state(fallback):
    state = fallback.provider_state()
    assert state.mode == "internal_fallback"
    assert state.status == "fallback"
    assert state.supports_activity_suggestions is True


def test_fallback_greeting_with_and_without_name(fallback):
    named = fallback.greeting(child_name="Lina")
    assert "Lina" in named.content
    assert named.intent == "greeting"
    anon = fallback.greeting()
    assert "learning buddy" in anon.content


@pytest.mark.parametrize(
    "message,expected_intent",
    [
        ("let's do some math counting", "recommend_lesson"),
        ("tell me a story adventure", "tell_story"),
        ("I want to play a fun game", "suggest_game"),
        ("I feel sad and tired", "motivation"),
        ("explain why the sky is blue", "fun_fact"),
        ("hello there", "general_help"),
    ],
)
def test_fallback_infer_intent(fallback, message, expected_intent):
    assert fallback._infer_intent(message.lower()) == expected_intent


@pytest.mark.parametrize(
    "intent",
    ["recommend_lesson", "suggest_game", "tell_story", "fun_fact", "motivation", "general_help"],
)
def test_fallback_generate_english_intents(fallback, intent):
    response = fallback.generate(
        child_name="Sam",
        child_age=7,
        message="hello",
        quick_action=intent,
        recent_messages=[],
    )
    assert response.content
    assert response.intent == intent
    assert response.metadata_json["language"] == "en"


def test_fallback_generate_question_branch(fallback):
    response = fallback.generate(
        child_name="Sam",
        child_age=7,
        message="hmm",
        quick_action="general_help",
        recent_messages=["is this right?"],
    )
    assert "help" in response.content.lower()


def test_fallback_generate_general_quote_branch():
    # No activities → recommended_activity returns None, hits the plain branches.
    backend = _InternalFallbackAiBuddyBackend(content_service=_FakeContentService([]))
    response = backend.generate(
        child_name=None,
        child_age=None,
        message="just chatting about my day",
        quick_action="general_help",
        recent_messages=[],
    )
    assert "I heard you say" in response.content


@pytest.mark.parametrize(
    "intent",
    ["recommend_lesson", "suggest_game", "tell_story", "fun_fact", "motivation", "general_help"],
)
def test_fallback_generate_arabic_intents(fallback, intent):
    response = fallback.generate(
        child_name="نور",
        child_age=6,
        message="مرحبا، أريد أن ألعب",
        quick_action=intent,
        recent_messages=[],
    )
    assert response.content
    assert response.metadata_json["language"] == "ar"


@pytest.mark.parametrize(
    "locale,texts,expected",
    [
        # Locale wins over message content (the app-language contract).
        ("ar", ("hello world",), True),
        ("ar_EG", ("hi",), True),
        ("en", ("مرحبا",), False),
        ("en_US", ("مرحبا",), False),
        # No locale → fall back to sniffing the text.
        (None, ("مرحبا",), True),
        (None, ("hello",), False),
        ("", ("hello",), False),
    ],
)
def test_resolve_is_arabic_prefers_locale(locale, texts, expected):
    assert rg_module._resolve_is_arabic(locale, *texts) is expected


def test_fallback_generate_uses_locale_over_message_language(fallback):
    # English message but Arabic app locale → reply must be Arabic.
    response = fallback.generate(
        child_name="Alaa",
        child_age=6,
        message="Hi, my name is Alaa",
        quick_action="general_help",
        recent_messages=[],
        locale="ar",
    )
    assert response.metadata_json["language"] == "ar"

    # Arabic message but English app locale → reply must be English.
    response_en = fallback.generate(
        child_name="علاء",
        child_age=6,
        message="مرحبا اسمي علاء",
        quick_action="general_help",
        recent_messages=[],
        locale="en",
    )
    assert response_en.metadata_json["language"] == "en"


def test_fallback_greeting_uses_locale(fallback):
    # Latin name but Arabic locale → Arabic greeting template.
    ar_greeting = fallback.greeting(child_name="Alaa", locale="ar")
    assert "مرحب" in ar_greeting.content
    assert "Hello" not in ar_greeting.content
    # Arabic name but English locale → English greeting template.
    en_greeting = fallback.greeting(child_name="Alaa", locale="en")
    assert "Hello" in en_greeting.content
    assert "مرحب" not in en_greeting.content


def test_fallback_recommended_activity_paths(fallback):
    # Preferred category match (educational).
    lesson = fallback._recommended_activity(intent="recommend_lesson", child_age=7)
    assert lesson["category"] == "educational"
    # Intent without a category mapping → first activity.
    other = fallback._recommended_activity(intent="motivation", child_age=7)
    assert other == _ACTIVITIES[0]
    # No activities → None.
    empty = _InternalFallbackAiBuddyBackend(content_service=_FakeContentService([]))
    assert empty._recommended_activity(intent="recommend_lesson", child_age=7) is None


def test_fallback_with_reason(fallback):
    base = fallback.greeting(child_name="Lina")
    assert fallback.with_reason(base, reason=None) is base
    with_reason = fallback.with_reason(base, reason="provider down")
    assert with_reason.metadata_json["fallback_reason"] == "provider down"
    assert with_reason.provider_state.reason == "provider down"


# ---------------------------------------------------------------------------
# _EnhancedAiBuddyBackend.provider_state branches
# ---------------------------------------------------------------------------


class _FakeProvider:
    def __init__(self, *, configured=True, runtime_error=None):
        self._configured = configured
        self._runtime_error = runtime_error

    def is_configured(self):
        return self._configured

    def ensure_runtime_ready(self):
        if self._runtime_error is not None:
            raise self._runtime_error

    def generate_greeting(self, *, child_name, is_arabic):
        return SimpleNamespace(
            content=f"Hi {child_name or 'friend'}",
            model="gpt-test",
            tokens_used=12,
            finish_reason="stop",
        )

    def generate(self, **kwargs):
        return SimpleNamespace(
            content="generated reply",
            intent=kwargs.get("quick_action") or "general_help",
            model="gpt-test",
            tokens_used=20,
            finish_reason="stop",
            suggested_activities=["counting-fun"],
        )


def _enhanced(provider):
    return _EnhancedAiBuddyBackend(
        provider=provider, content_service=_FakeContentService(_ACTIVITIES)
    )


def test_enhanced_state_fallback_mode(patch_settings):
    patch_settings(ai_provider_mode="fallback")
    state = _enhanced(_FakeProvider()).provider_state()
    assert state.mode == "internal_fallback"
    assert state.status == "fallback"


def test_enhanced_state_unconfigured(patch_settings):
    patch_settings(ai_provider_mode="openai")
    state = _enhanced(_FakeProvider(configured=False)).provider_state()
    assert state.status == "unavailable"
    assert "API key is missing" in state.reason


def test_enhanced_state_runtime_not_ready(patch_settings):
    patch_settings(ai_provider_mode="openai")
    backend = _enhanced(_FakeProvider(runtime_error=RuntimeError("SDK missing")))
    state = backend.provider_state()
    assert state.status == "unavailable"
    assert "SDK missing" in state.reason


def test_enhanced_state_ready(patch_settings):
    patch_settings(ai_provider_mode="openai")
    state = _enhanced(_FakeProvider()).provider_state()
    assert state.status == "ready"
    assert state.provider_key == "openai"


def test_enhanced_greeting(patch_settings):
    patch_settings(ai_provider_mode="openai")
    response = _enhanced(_FakeProvider()).greeting(child_name="Lina")
    assert response.content == "Hi Lina"
    assert response.metadata_json["tokens_used"] == 12


def test_enhanced_generate(patch_settings):
    patch_settings(ai_provider_mode="openai")
    response = _enhanced(_FakeProvider()).generate(
        child_name="Lina",
        child_age=7,
        message="hello",
        quick_action="suggest_game",
        recent_messages=["hi"],
    )
    assert response.content == "generated reply"
    assert response.metadata_json["available_activity_slugs"] == ["counting-fun", "hide-seek"]


# ---------------------------------------------------------------------------
# AiBuddyResponseGenerator orchestration
# ---------------------------------------------------------------------------


class _StubBackend:
    def __init__(self, state, response=None, raise_exc=None):
        self._state = state
        self._response = response
        self._raise = raise_exc

    def provider_state(self):
        return self._state

    def greeting(self, *, child_name=None, locale=None):
        if self._raise:
            raise self._raise
        return self._response

    def generate(self, **kwargs):
        if self._raise:
            raise self._raise
        return self._response


def _state(status, *, reason=None):
    return rg_module.AiBuddyProviderState(
        configured=status == "ready",
        mode="openai",
        status=status,
        reason=reason,
        provider_key="openai",
        model="gpt-test",
    )


def _response(source="provider_openai"):
    return rg_module.AiBuddyGeneratedResponse(
        content="x",
        intent="greeting",
        response_source=source,
        status="completed",
        safety_status="allowed",
        provider_state=_state("ready"),
    )


def test_generator_provider_state_ready():
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(content_service=_FakeContentService()),
        provider_backend=_StubBackend(_state("ready")),
    )
    assert gen.provider_state().status == "ready"


def test_generator_provider_state_fallback_with_reason():
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(content_service=_FakeContentService()),
        provider_backend=_StubBackend(_state("unavailable", reason="no key")),
    )
    state = gen.provider_state()
    assert state.status == "fallback"
    assert state.reason == "no key"


def test_generator_uses_provider_when_ready():
    provider_response = _response()
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(content_service=_FakeContentService()),
        provider_backend=_StubBackend(_state("ready"), response=provider_response),
    )
    result = gen.greeting(child_name="Sam")
    assert result is provider_response


def test_generator_falls_back_when_provider_raises():
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(
            content_service=_FakeContentService(_ACTIVITIES)
        ),
        provider_backend=_StubBackend(_state("ready"), raise_exc=RuntimeError("boom")),
    )
    result = gen.generate(
        child_name="Sam",
        child_age=7,
        message="hello",
        quick_action="suggest_game",
        recent_messages=[],
    )
    # Fell back to internal backend, annotated with a fallback reason.
    assert result.response_source == "internal_fallback"
    assert "fallback_reason" in result.metadata_json


def test_generator_falls_back_when_provider_not_ready():
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(
            content_service=_FakeContentService(_ACTIVITIES)
        ),
        provider_backend=_StubBackend(_state("unavailable", reason="no key")),
    )
    result = gen.greeting(child_name="Sam")
    assert result.response_source == "internal_fallback"
    assert result.metadata_json["fallback_reason"] == "no key"


def test_generator_fallback_generate_directly():
    gen = AiBuddyResponseGenerator(
        fallback_backend=_InternalFallbackAiBuddyBackend(
            content_service=_FakeContentService(_ACTIVITIES)
        ),
        provider_backend=_StubBackend(_state("ready")),
    )
    result = gen.fallback_generate(
        child_name="Sam",
        child_age=7,
        message="hello",
        quick_action="tell_story",
        recent_messages=[],
        reason="forced",
    )
    assert result.response_source == "internal_fallback"
    assert result.metadata_json["fallback_reason"] == "forced"
