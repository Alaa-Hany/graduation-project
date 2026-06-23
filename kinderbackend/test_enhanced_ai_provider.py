"""Tests for services.ai_providers.enhanced_ai_provider.

The OpenAI client is mocked throughout; no live API calls are made.
"""

from types import SimpleNamespace

import pytest

import services.ai_providers.enhanced_ai_provider as eap_module
from services.ai_providers.enhanced_ai_provider import (
    QUICK_ACTION_PROMPTS_ENHANCED,
    EnhancedAIProvider,
    EnhancedAIResponse,
)


def _fake_settings():
    return SimpleNamespace(
        ai_provider_api_key="sk-test",
        ai_model="gpt-test",
        ai_max_tokens=128,
        ai_temperature=0.7,
    )


@pytest.fixture
def provider(monkeypatch):
    monkeypatch.setattr(eap_module, "settings", _fake_settings())
    return EnhancedAIProvider()


def _fake_completion(content="Hi there!", total_tokens=15, finish_reason="stop"):
    message = SimpleNamespace(content=content)
    choice = SimpleNamespace(message=message, finish_reason=finish_reason)
    usage = SimpleNamespace(total_tokens=total_tokens)
    return SimpleNamespace(choices=[choice], usage=usage)


class _FakeClient:
    def __init__(self, completion):
        self._completion = completion
        self.captured = {}

        def create(**kwargs):
            self.captured.update(kwargs)
            return self._completion

        self.chat = SimpleNamespace(completions=SimpleNamespace(create=create))


# ---------------------------------------------------------------------------
# is_configured / ensure_runtime_ready / _get_client
# ---------------------------------------------------------------------------


def test_is_configured_true(provider):
    assert provider.is_configured() is True


def test_is_configured_false(monkeypatch):
    settings = _fake_settings()
    settings.ai_provider_api_key = None
    monkeypatch.setattr(eap_module, "settings", settings)
    assert EnhancedAIProvider().is_configured() is False


def test_ensure_runtime_ready_ok(provider):
    # openai is installed in the test env, so this must not raise.
    provider.ensure_runtime_ready()


def test_ensure_runtime_ready_missing_sdk(provider, monkeypatch):
    import builtins

    real_import = builtins.__import__

    def fake_import(name, *args, **kwargs):
        if name == "openai":
            raise ImportError("no openai")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", fake_import)
    with pytest.raises(RuntimeError, match="OpenAI SDK is not installed"):
        provider.ensure_runtime_ready()


def test_get_client_is_cached(provider):
    sentinel = object()
    provider._client = sentinel
    assert provider._get_client() is sentinel


def test_get_client_creates_openai(provider, monkeypatch):
    created = {}

    def fake_openai(api_key, **kwargs):
        created["api_key"] = api_key
        created["kwargs"] = kwargs
        return SimpleNamespace(name="client")

    import openai

    monkeypatch.setattr(openai, "OpenAI", fake_openai)
    client = provider._get_client()
    assert client.name == "client"
    assert created["api_key"] == "sk-test"
    assert created["kwargs"]["timeout"] == 20.0
    assert created["kwargs"]["max_retries"] == 1


# ---------------------------------------------------------------------------
# _get_age_guidance
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "age,expected_fragment",
    [
        (3, "very simple words"),
        (4, "very simple words"),
        (5, "simple language"),
        (6, "simple language"),
        (7, "slightly more complex"),
        (8, "slightly more complex"),
        (10, "more complex topics"),
    ],
)
def test_age_guidance(provider, age, expected_fragment):
    assert expected_fragment in provider._get_age_guidance(age)


# ---------------------------------------------------------------------------
# _build_messages
# ---------------------------------------------------------------------------


def test_build_messages_minimal(provider):
    messages = provider._build_messages(
        child_name=None,
        message="hello",
        quick_action=None,
        recent_messages=None,
        is_arabic=False,
        child_age=None,
        available_activities=None,
    )
    assert messages[0]["role"] == "system"
    assert messages[-1] == {"role": "user", "content": "hello"}


def test_build_messages_all_branches(provider):
    messages = provider._build_messages(
        child_name="Lina",
        message="play",
        quick_action="suggest_game",
        recent_messages=["m1", "m2", "m3", "m4", "m5"],
        is_arabic=True,
        child_age=5,
        available_activities=[{"name": "x"}],
    )
    serialized = " ".join(m["content"] for m in messages)
    assert "Arabic" in serialized
    assert "Lina" in serialized
    assert "5 years old" in serialized
    assert QUICK_ACTION_PROMPTS_ENHANCED["suggest_game"] in serialized
    # Only the last 4 recent messages are included.
    assert "m1" not in serialized
    assert "m5" in serialized


def test_build_messages_ignores_unknown_quick_action(provider):
    messages = provider._build_messages(
        child_name=None,
        message="hi",
        quick_action="does_not_exist",
        recent_messages=None,
        is_arabic=False,
        child_age=None,
        available_activities=None,
    )
    # No quick-action system message should be present.
    assert all("does_not_exist" not in m["content"] for m in messages)


# ---------------------------------------------------------------------------
# generate / generate_greeting
# ---------------------------------------------------------------------------


def test_generate_returns_response(provider):
    fake = _FakeClient(_fake_completion(content="Hello kiddo", total_tokens=22))
    provider._client = fake

    result = provider.generate(child_name="Sam", message="hi", quick_action="tell_story")

    assert isinstance(result, EnhancedAIResponse)
    assert result.content == "Hello kiddo"
    assert result.intent == "tell_story"
    assert result.model == "gpt-test"
    assert result.tokens_used == 22
    assert result.finish_reason == "stop"
    assert fake.captured["model"] == "gpt-test"
    assert fake.captured["max_tokens"] == 128


def test_generate_defaults_intent_to_general_help(provider):
    provider._client = _FakeClient(_fake_completion())
    result = provider.generate(child_name=None, message="hi")
    assert result.intent == "general_help"


def test_generate_handles_empty_choices(provider):
    empty = SimpleNamespace(choices=[], usage=None)
    provider._client = _FakeClient(empty)
    result = provider.generate(child_name=None, message="hi")
    assert result.content == ""
    assert result.tokens_used == 0
    assert result.finish_reason == "stop"


def test_generate_reraises_on_client_error(provider):
    class _BoomClient:
        def __init__(self):
            def create(**kwargs):
                raise RuntimeError("api error")

            self.chat = SimpleNamespace(completions=SimpleNamespace(create=create))

    provider._client = _BoomClient()
    with pytest.raises(RuntimeError, match="api error"):
        provider.generate(child_name=None, message="hi")


def test_generate_greeting_uses_generate(provider):
    fake = _FakeClient(_fake_completion(content="Welcome!"))
    provider._client = fake
    result = provider.generate_greeting(child_name="Noor", is_arabic=True)
    assert result.content == "Welcome!"
    # The greeting prompt mentions the child's name and Arabic instruction.
    user_msg = fake.captured["messages"][-1]["content"]
    assert "Noor" in user_msg
    assert "Arabic" in user_msg


def test_enhanced_ai_response_defaults():
    resp = EnhancedAIResponse(
        content="x", intent="i", model="m", tokens_used=1, finish_reason="stop"
    )
    assert resp.suggested_activities == []
    assert resp.raw == {}
