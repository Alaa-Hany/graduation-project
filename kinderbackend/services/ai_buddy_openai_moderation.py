"""OpenAI Moderation API as a second safety layer."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from core.settings import settings

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class OpenAIModerationResult:
    flagged: bool
    categories: dict[str, bool]
    category_scores: dict[str, float]


class OpenAIModerationService:
    def __init__(self) -> None:
        self._client = None

    def is_configured(self) -> bool:
        # Only run the OpenAI moderation layer when the OpenAI provider is
        # actually in use. In "fallback" mode there is no live provider, so we
        # must not make network calls (this also keeps tests offline).
        return settings.ai_provider_mode != "fallback" and bool(
            settings.ai_provider_api_key
        )

    def _get_client(self):
        if self._client is not None:
            return self._client
        from openai import OpenAI

        self._client = OpenAI(
            api_key=settings.ai_provider_api_key, timeout=10.0, max_retries=1
        )
        return self._client

    def moderate(self, text: str) -> OpenAIModerationResult | None:
        """
        Returns None if not configured or on error (fail-open: let keyword rules decide).
        Returns OpenAIModerationResult if moderation ran successfully.
        """
        if not self.is_configured() or not text.strip():
            return None
        try:
            client = self._get_client()
            response = client.moderations.create(
                model="omni-moderation-latest",
                input=text,
            )
            result = response.results[0]
            return OpenAIModerationResult(
                flagged=result.flagged,
                categories=result.categories.model_dump(),
                category_scores=result.category_scores.model_dump(),
            )
        except Exception as exc:
            logger.warning("openai_moderation_failed error=%s", str(exc))
            return None  # fail-open


openai_moderation_service = OpenAIModerationService()
