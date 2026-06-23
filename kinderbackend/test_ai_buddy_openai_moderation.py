"""Unit tests for the OpenAI moderation second layer and Arabic normalization."""

from __future__ import annotations

import services.ai_buddy_moderation as moderation_module
from services.ai_buddy_moderation import AiBuddyModerationService
from services.ai_buddy_openai_moderation import OpenAIModerationResult

service = AiBuddyModerationService()


def _result(**categories: bool) -> OpenAIModerationResult:
    return OpenAIModerationResult(
        flagged=any(categories.values()),
        categories=dict(categories),
        category_scores={name: 0.99 for name in categories},
    )


def test_map_categories_prefers_refusal_over_redirect():
    classification, topic, matched = service._map_openai_categories(
        {"harassment": True, "sexual": True}
    )
    assert classification == "needs_refusal"
    assert topic == "sexual_content"
    assert "sexual" in matched


def test_map_categories_self_harm_redirects():
    classification, topic, _ = service._map_openai_categories({"self-harm/intent": True})
    assert classification == "needs_safe_redirect"
    assert topic == "self_harm"


def test_map_categories_none_when_unmapped():
    classification, topic, matched = service._map_openai_categories({"other": True})
    assert classification is None and topic is None and matched == []


def test_openai_layer_flags_when_keywords_miss(monkeypatch):
    # A message with no keyword hits but flagged by the OpenAI layer.
    monkeypatch.setattr(
        moderation_module.openai_moderation_service,
        "moderate",
        lambda text: _result(violence=True),
    )
    decision = service.moderate_input(text="please describe a brutal scene")
    assert decision.classification == "needs_refusal"
    assert decision.topic == "violence"
    assert decision.metadata_json["moderation_layer"] == "openai"
    assert decision.safe_response


def test_openai_layer_fails_open(monkeypatch):
    monkeypatch.setattr(
        moderation_module.openai_moderation_service,
        "moderate",
        lambda text: None,
    )
    decision = service.moderate_input(text="let us count to five together")
    assert decision.classification == "allowed"


def test_keyword_layer_runs_before_openai(monkeypatch):
    # Keyword hit should short-circuit and never call the OpenAI layer.
    called = {"hit": False}

    def _should_not_run(text):
        called["hit"] = True
        return None

    monkeypatch.setattr(moderation_module.openai_moderation_service, "moderate", _should_not_run)
    decision = service.moderate_input(text="I want a gun")
    assert decision.classification == "needs_refusal"
    assert decision.metadata_json["moderation_layer"] == "keyword"
    assert called["hit"] is False


def test_arabic_normalization_matches_taa_marbuta_variant(monkeypatch):
    # User typed "كلمه السر" (ه) but the keyword is "كلمة السر" (ة).
    monkeypatch.setattr(
        moderation_module.openai_moderation_service,
        "moderate",
        lambda text: None,
    )
    decision = service.moderate_input(text="ما هي كلمه السر")
    assert decision.classification == "needs_safe_redirect"
    assert decision.topic == "personal_data"
