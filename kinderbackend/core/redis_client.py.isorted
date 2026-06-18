from __future__ import annotations

import logging
from functools import lru_cache

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_redis_client():
    """Return a connected Redis client, or None if REDIS_URL is not configured.

    The client is created once and cached for the process lifetime.
    Callers must handle None when Redis is unavailable (development / tests).
    """
    from core.settings import settings  # local import avoids circular dep at module load

    if not settings.redis_url:
        logger.warning(
            "REDIS_URL is not set — rate limiting will fall back to in-process memory. "
            "This is unsafe in multi-worker deployments."
        )
        return None

    try:
        import redis

        client = redis.Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        client.ping()
        logger.info("Redis connected: %s", settings.redis_url)
        return client
    except Exception as exc:  # pragma: no cover
        logger.error("Redis connection failed (%s) — rate limiting degraded to in-memory", exc)
        return None
