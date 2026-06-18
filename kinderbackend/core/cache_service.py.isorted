from __future__ import annotations

import json
import logging
from typing import Any

from core.settings import settings

logger = logging.getLogger(__name__)

try:
    import redis
except Exception:  # pragma: no cover - optional dependency
    redis = None  # type: ignore[assignment]


class CacheService:
    def __init__(self) -> None:
        self._client: Any | None = None
        self._initialization_attempted = False

    def is_enabled(self) -> bool:
        return settings.cache_enabled and bool(settings.redis_url)

    def _get_client(self) -> Any | None:
        if not self.is_enabled():
            return None
        if self._initialization_attempted:
            return self._client

        self._initialization_attempted = True
        if redis is None:
            logger.warning("Redis cache enabled in settings, but redis package is not installed.")
            return None

        try:
            self._client = redis.Redis.from_url(settings.redis_url, decode_responses=True)
            self._client.ping()
        except Exception as exc:  # pragma: no cover - depends on runtime Redis availability
            logger.warning("Redis cache unavailable; continuing without cache: %s", exc)
            self._client = None
        return self._client

    def get_json(self, key: str) -> dict[str, Any] | list[Any] | None:
        client = self._get_client()
        if client is None:
            return None
        try:
            raw_value = client.get(key)
        except Exception as exc:  # pragma: no cover - depends on runtime Redis availability
            logger.warning("Redis cache read failed for key %s: %s", key, exc)
            return None
        if not raw_value:
            return None
        try:
            value = json.loads(raw_value)
        except json.JSONDecodeError:
            logger.warning("Ignoring invalid cached JSON for key %s", key)
            return None
        if isinstance(value, (dict, list)):
            return value
        return None

    def set_json(self, key: str, value: dict[str, Any] | list[Any], *, ttl_seconds: int) -> None:
        client = self._get_client()
        if client is None:
            return
        try:
            client.setex(key, max(ttl_seconds, 1), json.dumps(value, separators=(",", ":")))
        except Exception as exc:  # pragma: no cover - depends on runtime Redis availability
            logger.warning("Redis cache write failed for key %s: %s", key, exc)

    def clear_key(self, key: str) -> None:
        client = self._get_client()
        if client is None:
            return
        try:
            client.delete(key)
        except Exception as exc:  # pragma: no cover - depends on runtime Redis availability
            logger.warning("Redis cache delete failed for key %s: %s", key, exc)

    def reset_for_tests(self) -> None:
        self._client = None
        self._initialization_attempted = False


cache_service = CacheService()
