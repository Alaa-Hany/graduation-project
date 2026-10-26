"""
Voice Router for AI Buddy - ASR and TTS endpoints
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from deps import AiBuddyPrincipal, get_ai_buddy_principal, get_db
from rate_limit import voice_rate_limit
from services.voice_service import voice_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/voice", tags=["voice"])

# Decoded audio cap for /transcribe (~5 MB is well over a typical child
# utterance and keeps a single request from becoming a large provider bill).
MAX_AUDIO_BYTES = 5 * 1024 * 1024
MAX_TTS_TEXT_LENGTH = 1000

_ASR_FAILED_MESSAGE = "Could not transcribe audio. Please try again."
_TTS_FAILED_MESSAGE = "Could not generate speech. Please try again."


class ASRRequest(BaseModel):
    audio_base64: str
    language: str = "auto"
    child_id: Optional[int] = None


class ASRResponse(BaseModel):
    text: str
    language: str
    confidence: float
    success: bool = True
    error: Optional[str] = None


class TTSRequest(BaseModel):
    text: str = Field(..., max_length=MAX_TTS_TEXT_LENGTH)
    language: str = "en"
    voice: Optional[str] = None
    speed: float = Field(default=1.0, ge=0.5, le=2.0)


class TTSResponse(BaseModel):
    audio_base64: str
    content_type: str
    success: bool = True
    error: Optional[str] = None


def _decoded_base64_size(value: str) -> int:
    """Byte length the base64 payload decodes to, computed without decoding it."""
    data = value.split(",", 1)[1] if value.startswith("data:") else value
    data = data.strip()
    padding = len(data) - len(data.rstrip("="))
    return (len(data) * 3) // 4 - padding


@router.post("/transcribe", response_model=ASRResponse)
async def transcribe_audio(
    request: ASRRequest,
    db: Session = Depends(get_db),
    principal: AiBuddyPrincipal = Depends(get_ai_buddy_principal),
    _: None = Depends(voice_rate_limit()),
):
    if _decoded_base64_size(request.audio_base64) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=413,
            detail={
                "code": "AUDIO_TOO_LARGE",
                "message": f"Audio must be at most {MAX_AUDIO_BYTES // (1024 * 1024)} MB.",
            },
        )
    try:
        result = await voice_service.transcribe(
            audio_base64=request.audio_base64, language=request.language
        )
        return ASRResponse(
            text=result.text, language=result.language, confidence=result.confidence, success=True
        )
    except Exception:
        # Provider errors can carry request ids, model names or key hints; keep
        # them in the logs and give the client a generic message.
        logger.exception("ASR failed")
        return ASRResponse(
            text="",
            language=request.language,
            confidence=0.0,
            success=False,
            error=_ASR_FAILED_MESSAGE,
        )


@router.post("/synthesize", response_model=TTSResponse)
async def synthesize_speech(
    request: TTSRequest,
    db: Session = Depends(get_db),
    principal: AiBuddyPrincipal = Depends(get_ai_buddy_principal),
    _: None = Depends(voice_rate_limit()),
):
    try:
        language = request.language
        if language == "auto":
            language = voice_service.detect_language_from_text(request.text)

        result = await voice_service.synthesize(
            text=request.text, language=language, speed=request.speed
        )
        return TTSResponse(
            audio_base64=result.audio_base64, content_type=result.content_type, success=True
        )
    except Exception:
        logger.exception("TTS failed")
        return TTSResponse(
            audio_base64="",
            content_type="audio/mp3",
            success=False,
            error=_TTS_FAILED_MESSAGE,
        )


class LanguageOption(BaseModel):
    code: str
    name: str
    native_name: Optional[str] = None


class LanguageListResponse(BaseModel):
    languages: list[LanguageOption]


@router.get("/languages", response_model=LanguageListResponse)
async def get_supported_languages():
    return {
        "languages": [
            {"code": "en", "name": "English"},
            {"code": "ar", "name": "Arabic", "native_name": "العربية"},
        ]
    }
