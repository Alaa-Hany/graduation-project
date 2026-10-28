"""Cost/abuse guards on the paid AI endpoints (AI Buddy chat + voice).

AI Buddy runs on the offline internal fallback provider (no OpenAI call), and
the voice service is replaced with fakes so nothing touches the network.
"""

from __future__ import annotations

import base64

import pytest

import routers.voice as voice_router
from core.settings import settings
from services.voice_service import ASRResult, TTSResult


@pytest.fixture
def fake_voice(monkeypatch):
    calls = {"transcribe": 0, "synthesize": 0}

    async def fake_transcribe(*, audio_base64, language="auto"):
        calls["transcribe"] += 1
        return ASRResult(text="hello", language="en", confidence=0.9, raw={})

    async def fake_synthesize(*, text, language="en", voice=None, speed=1.0):
        calls["synthesize"] += 1
        return TTSResult(
            audio_base64=base64.b64encode(b"AUDIO").decode(),
            content_type="audio/mp3",
            raw={},
        )

    monkeypatch.setattr(voice_router.voice_service, "transcribe", fake_transcribe)
    monkeypatch.setattr(voice_router.voice_service, "synthesize", fake_synthesize)
    return calls


def _small_audio() -> str:
    return base64.b64encode(b"fake-audio").decode()


def _start_session(client, headers, child_id) -> int:
    start = client.post("/api/v1/ai-buddy/sessions", json={"child_id": child_id}, headers=headers)
    assert start.status_code == 200
    return start.json()["session"]["id"]


def _send(client, headers, session_id, child_id, n):
    return client.post(
        f"/api/v1/ai-buddy/sessions/{session_id}/messages",
        json={"child_id": child_id, "content": "Tell me a fun fact", "client_message_id": f"m-{n}"},
        headers=headers,
    )


def _assert_rate_limited(response, scope):
    assert response.status_code == 429
    detail = response.json()["detail"]
    assert detail["code"] == "RATE_LIMIT_EXCEEDED"
    assert detail["scope"] == scope
    assert response.headers["Retry-After"] == "60"


# ---------------------------------------------------------------------------
# AI Buddy messages
# ---------------------------------------------------------------------------


def test_ai_buddy_messages_rate_limited_per_parent(
    client, create_parent, create_child, auth_headers
):
    parent = create_parent(email="ai.limit.parent@example.com")
    child = create_child(parent_id=parent.id, name="Lina", age=8)
    headers = auth_headers(parent)
    session_id = _start_session(client, headers, child.id)

    limit = settings.ai_buddy_messages_per_minute
    assert limit == 20
    for n in range(limit):
        assert _send(client, headers, session_id, child.id, n).status_code == 200

    _assert_rate_limited(_send(client, headers, session_id, child.id, limit), "ai_buddy_message")


def test_ai_buddy_rate_limit_is_keyed_by_child_session(
    client, create_parent, create_child, auth_headers
):
    parent = create_parent(email="ai.limit.child@example.com")
    child = create_child(parent_id=parent.id, name="Lina", age=8)

    login = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child.id,
            "name": child.name,
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "tablet-a",
        },
    )
    assert login.status_code == 200
    child_headers = {"Authorization": f"Bearer {login.json()['session_token']}"}
    session_id = _start_session(client, child_headers, child.id)

    limit = settings.ai_buddy_messages_per_minute
    for n in range(limit):
        assert _send(client, child_headers, session_id, child.id, n).status_code == 200
    _assert_rate_limited(
        _send(client, child_headers, session_id, child.id, limit), "ai_buddy_message"
    )

    # The child's bucket is separate from the parent's own bucket.
    parent_headers = auth_headers(parent)
    assert _send(client, parent_headers, session_id, child.id, 999).status_code == 200


# ---------------------------------------------------------------------------
# Voice
# ---------------------------------------------------------------------------


def test_voice_requests_rate_limited_across_both_endpoints(
    client, create_parent, auth_headers, fake_voice
):
    headers = auth_headers(create_parent(email="voice.limit@example.com"))
    limit = settings.voice_requests_per_minute
    assert limit == 10

    for n in range(limit):
        if n % 2:
            response = client.post(
                "/api/v1/voice/transcribe",
                json={"audio_base64": _small_audio()},
                headers=headers,
            )
        else:
            response = client.post("/api/v1/voice/synthesize", json={"text": "hi"}, headers=headers)
        assert response.status_code == 200

    # One shared bucket: switching endpoints does not reset the count.
    _assert_rate_limited(
        client.post(
            "/api/v1/voice/transcribe",
            json={"audio_base64": _small_audio()},
            headers=headers,
        ),
        "voice",
    )
    assert fake_voice["transcribe"] + fake_voice["synthesize"] == limit


def test_transcribe_rejects_audio_over_5mb(client, create_parent, auth_headers, fake_voice):
    headers = auth_headers(create_parent(email="voice.big@example.com"))
    too_big = base64.b64encode(b"\0" * (voice_router.MAX_AUDIO_BYTES + 1)).decode()

    response = client.post(
        "/api/v1/voice/transcribe", json={"audio_base64": too_big}, headers=headers
    )

    assert response.status_code == 413
    assert response.json()["detail"]["code"] == "AUDIO_TOO_LARGE"
    assert fake_voice["transcribe"] == 0


def test_transcribe_accepts_audio_at_5mb(client, create_parent, auth_headers, fake_voice):
    headers = auth_headers(create_parent(email="voice.edge@example.com"))
    at_limit = base64.b64encode(b"\0" * voice_router.MAX_AUDIO_BYTES).decode()

    response = client.post(
        "/api/v1/voice/transcribe", json={"audio_base64": at_limit}, headers=headers
    )

    assert response.status_code == 200
    assert fake_voice["transcribe"] == 1


def test_synthesize_rejects_text_over_1000_chars(client, create_parent, auth_headers, fake_voice):
    headers = auth_headers(create_parent(email="voice.long@example.com"))

    response = client.post("/api/v1/voice/synthesize", json={"text": "a" * 1001}, headers=headers)

    assert response.status_code == 422
    assert fake_voice["synthesize"] == 0
    ok = client.post("/api/v1/voice/synthesize", json={"text": "a" * 1000}, headers=headers)
    assert ok.status_code == 200


def test_voice_errors_do_not_leak_provider_details(
    client, create_parent, auth_headers, monkeypatch
):
    headers = auth_headers(create_parent(email="voice.leak@example.com"))
    secret = "Incorrect API key provided: sk-proj-SECRET123"

    async def boom(**kwargs):
        raise RuntimeError(secret)

    monkeypatch.setattr(voice_router.voice_service, "transcribe", boom)
    monkeypatch.setattr(voice_router.voice_service, "synthesize", boom)

    asr = client.post(
        "/api/v1/voice/transcribe", json={"audio_base64": _small_audio()}, headers=headers
    )
    tts = client.post("/api/v1/voice/synthesize", json={"text": "hi"}, headers=headers)

    for response in (asr, tts):
        assert response.status_code == 200
        body = response.json()
        assert body["success"] is False
        assert "SECRET123" not in response.text
        assert body["error"] in (voice_router._ASR_FAILED_MESSAGE, voice_router._TTS_FAILED_MESSAGE)
