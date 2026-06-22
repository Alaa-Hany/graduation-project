"""Tests for services.voice_service (ASR/TTS wrapper around the OpenAI client).

The OpenAI network client is always replaced with a fake so these tests stay
deterministic and offline.
"""

import asyncio
import base64
from types import SimpleNamespace

import pytest

from services.voice_service import ASRResult, TTSResult, VoiceService


class _FakeTranscriptions:
    def __init__(self, recorder):
        self._recorder = recorder

    def create(self, **kwargs):
        self._recorder["transcribe_kwargs"] = kwargs
        return SimpleNamespace(text="hello world")


class _FakeSpeech:
    def __init__(self, recorder):
        self._recorder = recorder

    def create(self, **kwargs):
        self._recorder["speech_kwargs"] = kwargs
        return SimpleNamespace(content=b"RAW_AUDIO_BYTES")


class _FakeClient:
    def __init__(self, recorder):
        self.audio = SimpleNamespace(
            transcriptions=_FakeTranscriptions(recorder),
            speech=_FakeSpeech(recorder),
        )


# ---------------------------------------------------------------------------
# detect_language_from_text
# ---------------------------------------------------------------------------


def test_detect_language_arabic():
    service = VoiceService()
    assert service.detect_language_from_text("مرحبا بك") == "ar"


def test_detect_language_english():
    service = VoiceService()
    assert service.detect_language_from_text("hello there") == "en"


def test_detect_language_mixed_treated_as_arabic():
    service = VoiceService()
    assert service.detect_language_from_text("hello مرحبا") == "ar"


# ---------------------------------------------------------------------------
# _get_client
# ---------------------------------------------------------------------------


def test_get_client_is_cached():
    service = VoiceService()
    sentinel = object()
    service._client = sentinel
    assert service._get_client() is sentinel


def test_get_client_propagates_init_failure(monkeypatch):
    service = VoiceService()

    class _Boom:
        def __init__(self, *args, **kwargs):
            raise RuntimeError("bad key")

    import openai

    monkeypatch.setattr(openai, "OpenAI", _Boom)
    with pytest.raises(RuntimeError, match="bad key"):
        service._get_client()


# ---------------------------------------------------------------------------
# transcribe
# ---------------------------------------------------------------------------


def test_transcribe_returns_asr_result():
    service = VoiceService()
    recorder: dict = {}
    service._client = _FakeClient(recorder)

    audio_b64 = base64.b64encode(b"fake-audio").decode("utf-8")
    result = asyncio.run(service.transcribe(audio_base64=audio_b64, language="ar"))

    assert isinstance(result, ASRResult)
    assert result.text == "hello world"
    assert result.language == "ar"
    assert result.confidence == pytest.approx(0.9)
    # An explicit language is forwarded to Whisper.
    assert recorder["transcribe_kwargs"]["language"] == "ar"


def test_transcribe_auto_language_sends_none():
    service = VoiceService()
    recorder: dict = {}
    service._client = _FakeClient(recorder)

    audio_b64 = base64.b64encode(b"fake-audio").decode("utf-8")
    asyncio.run(service.transcribe(audio_base64=audio_b64, language="auto"))

    assert recorder["transcribe_kwargs"]["language"] is None


def test_transcribe_reraises_on_failure():
    service = VoiceService()

    class _Failing:
        @property
        def audio(self):
            raise RuntimeError("api down")

    service._client = _Failing()
    audio_b64 = base64.b64encode(b"fake-audio").decode("utf-8")
    with pytest.raises(RuntimeError, match="api down"):
        asyncio.run(service.transcribe(audio_base64=audio_b64))


# ---------------------------------------------------------------------------
# synthesize
# ---------------------------------------------------------------------------


def test_synthesize_returns_tts_result():
    service = VoiceService()
    recorder: dict = {}
    service._client = _FakeClient(recorder)

    result = asyncio.run(service.synthesize(text="hi", language="en"))

    assert isinstance(result, TTSResult)
    assert result.content_type == "audio/mp3"
    assert base64.b64decode(result.audio_base64) == b"RAW_AUDIO_BYTES"
    # Defaults to the child-friendly "nova" voice.
    assert recorder["speech_kwargs"]["voice"] == "nova"
    assert result.raw == {"model": "tts-1", "voice": "nova"}


def test_synthesize_uses_custom_voice_and_speed():
    service = VoiceService()
    recorder: dict = {}
    service._client = _FakeClient(recorder)

    result = asyncio.run(
        service.synthesize(text="hi", voice="echo", speed=1.5)
    )

    assert recorder["speech_kwargs"]["voice"] == "echo"
    assert recorder["speech_kwargs"]["speed"] == 1.5
    assert result.raw["voice"] == "echo"


def test_synthesize_reraises_on_failure():
    service = VoiceService()

    class _Failing:
        @property
        def audio(self):
            raise RuntimeError("tts down")

    service._client = _Failing()
    with pytest.raises(RuntimeError, match="tts down"):
        asyncio.run(service.synthesize(text="hi"))
