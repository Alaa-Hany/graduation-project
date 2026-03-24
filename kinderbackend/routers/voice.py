"""
Voice Router for AI Buddy - ASR and TTS endpoints
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from services.voice_service import voice_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/voice", tags=["voice"])


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
    text: str
    language: str = "en"
    voice: Optional[str] = None
    speed: float = Field(default=1.0, ge=0.5, le=2.0)


class TTSResponse(BaseModel):
    audio_base64: str
    content_type: str
    success: bool = True
    error: Optional[str] = None


@router.post("/transcribe", response_model=ASRResponse)
async def transcribe_audio(
    request: ASRRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    try:
        result = await voice_service.transcribe(
            audio_base64=request.audio_base64, language=request.language
        )
        return ASRResponse(
            text=result.text, language=result.language, confidence=result.confidence, success=True
        )
    except Exception as exc:
        logger.error("ASR failed: %s", str(exc))
        return ASRResponse(
            text="", language=request.language, confidence=0.0, success=False, error=str(exc)
        )


@router.post("/synthesize", response_model=TTSResponse)
async def synthesize_speech(
    request: TTSRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)
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
    except Exception as exc:
        logger.error("TTS failed: %s", str(exc))
        return TTSResponse(audio_base64="", content_type="audio/mp3", success=False, error=str(exc))


@router.get("/languages")
async def get_supported_languages():
    return {
        "languages": [
            {"code": "en", "name": "English"},
            {"code": "ar", "name": "Arabic", "native_name": "العربية"},
        ]
    }
