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

            self._client = OpenAI(api_key=settings.ai_provider_api_key)
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

            # Use a child-friendly voice
            voice_id: str = voice or "nova"

            response = client.audio.speech.create(
                model="tts-1",
                voice=voice_id,
                input=text,
                speed=speed,
            )

            audio_content: bytes = response.content
            audio_base64_value = base64.b64encode(audio_content).decode("utf-8")

            return TTSResult(
                audio_base64=audio_base64_value,
                content_type="audio/mp3",
                raw={"model": "tts-1", "voice": voice_id},
            )
        except Exception as exc:
            logger.error("TTS failed: %s", str(exc))
            raise

    def detect_language_from_text(self, text: str) -> str:
        """Detect if text contains Arabic characters."""
        arabic_pattern = re.compile(r"[\u0600-\u06ff]")
        return "ar" if arabic_pattern.search(text) else "en"


voice_service = VoiceService()
