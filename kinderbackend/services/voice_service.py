"""
Voice Service for AI Buddy - ASR and TTS
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Any, TypeAlias

from core.settings import settings

logger = logging.getLogger(__name__)

OpenAIClient: TypeAlias = Any

# Steers the TTS voice towards a warm, calm, child-friendly delivery. Only the
# ``gpt-4o-mini-tts`` model honours the ``instructions`` parameter; older models
# such as ``tts-1`` ignore voice steering entirely, so we omit it for them.
_CHILD_TTS_INSTRUCTIONS = (
    "Speak in a very warm, gentle, and calm pace. "
    "You are talking to a young child aged 4-10. "
    "Use a nurturing and encouraging tone, like a kind teacher or a caring older friend. "
    "Pause naturally between sentences. "
    "Sound happy and curious, never rushed or robotic. "
    "If the text is in Arabic, speak clearly and gently in a child-friendly way."
)

# The only TTS model that supports the ``instructions`` steering parameter.
_INSTRUCTABLE_TTS_MODEL = "gpt-4o-mini-tts"


@dataclass(slots=True)
class ASRResult:
    text: str
    language: str
    confidence: float
    duration_seconds: float | None = None
    raw: dict[str, Any] | None = None


@dataclass(slots=True)
class TTSResult:
    audio_base64: str
    content_type: str
    duration_seconds: float | None = None
    raw: dict[str, Any] | None = None


class VoiceService:
    """Service for voice interactions."""

    def __init__(self) -> None:
        self._client: OpenAIClient | None = None

    def _get_client(self) -> OpenAIClient:
        """Get or create the OpenAI client for audio."""
        if self._client is not None:
            return self._client

        try:
            from openai import OpenAI

            self._client = OpenAI(
                api_key=settings.ai_provider_api_key, timeout=20.0, max_retries=1
            )
            return self._client
        except ImportError:
            raise RuntimeError("OpenAI SDK is not installed")
        except Exception as exc:
            logger.error("Failed to initialize voice client: %s", str(exc))
            raise

    async def transcribe(self, *, audio_base64: str, language: str = "auto") -> ASRResult:
        """Transcribe audio to text using OpenAI Whisper."""
        try:
            import base64
            import os
            import tempfile

            client = self._get_client()

            # Decode base64 to audio file
            audio_bytes: bytes = base64.b64decode(audio_base64)

            # Write to temp file (OpenAI needs a file)
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
                tmp.write(audio_bytes)
                tmp_path: str = tmp.name

            try:
                with open(tmp_path, "rb") as audio_file:
                    transcript = client.audio.transcriptions.create(
                        model="whisper-1",
                        file=audio_file,
                        language=None if language == "auto" else language,
                    )

                return ASRResult(
                    text=transcript.text,
                    language=language,
                    confidence=0.9,
                    raw={"model": "whisper-1"},
                )
            finally:
                os.unlink(tmp_path)

        except Exception as exc:
            logger.error("ASR failed: %s", str(exc))
            raise

    async def synthesize(
        self, *, text: str, language: str = "en", voice: str | None = None, speed: float = 1.0
    ) -> TTSResult:
        """Synthesize text to speech using OpenAI TTS."""
        try:
            import base64

            client = self._get_client()

            # Pick a child-friendly voice: an explicit request wins, otherwise
            # use the voice configured for the language in settings.
            voice_id: str = voice or self._voice_for_language(language)
            model = settings.tts_model

            # Voice steering is only honoured by gpt-4o-mini-tts; passing it to
            # other models (e.g. tts-1) would be rejected, so guard on the model.
            create_kwargs: dict[str, Any] = {
                "model": model,
                "voice": voice_id,
                "input": text,
                "speed": speed,
            }
            if model == _INSTRUCTABLE_TTS_MODEL:
                create_kwargs["instructions"] = _CHILD_TTS_INSTRUCTIONS

            response = client.audio.speech.create(**create_kwargs)

            audio_content: bytes = response.content
            audio_base64_value = base64.b64encode(audio_content).decode("utf-8")

            return TTSResult(
                audio_base64=audio_base64_value,
                content_type="audio/mp3",
                raw={"model": model, "voice": voice_id, "language": language},
            )
        except Exception as exc:
            logger.error("TTS failed: %s", str(exc))
            raise

    def _voice_for_language(self, language: str) -> str:
        """Return the configured child-friendly voice for the given language."""
        if (language or "").lower().startswith("ar"):
            return settings.tts_voice_ar
        return settings.tts_voice_en

    def detect_language_from_text(self, text: str) -> str:
        """Detect if text contains Arabic characters."""
        arabic_pattern = re.compile(r"[\u0600-\u06ff]")
        return "ar" if arabic_pattern.search(text) else "en"


voice_service = VoiceService()
