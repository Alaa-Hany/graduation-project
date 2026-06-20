"""Redis-backed caching helpers for parent analytics reports.

Report endpoints (``/reports/basic`` and ``/reports/advanced``) run expensive
multi-table aggregations. The payload only changes when new activity/session
events are ingested or a child profile is mutated, so it is safe to cache for a
short window and invalidate on those writes.

All helpers degrade to no-ops when caching is disabled or Redis is unavailable
(see :class:`core.cache_service.CacheService`), so callers always fall through to
the normal DB path without special-casing an outage.
"""

from __future__ import annotations

from typing import Any

from core.cache_service import cache_service

# 5 minutes — short enough that stale data self-heals even if an invalidation
# write is somehow missed, long enough to absorb dashboard refresh bursts.
REPORT_CACHE_TTL_SECONDS = 300


def report_cache_key(
    *,
    user_id: int,
    child_id: int | None,
    report_type: str,
    days: int,
) -> str:
    """Build the cache key for a single report variant.

    ``days`` is part of the key because different windows produce different
    aggregations; the invalidation pattern below still matches every variant.
    """
    return f"report:{user_id}:{child_id}:{report_type}:{days}"


def get_cached_report(key: str) -> dict[str, Any] | None:
    cached = cache_service.get_json(key)
    return cached if isinstance(cached, dict) else None


def cache_report(key: str, payload: dict[str, Any]) -> None:
    cache_service.set_json(key, payload, ttl_seconds=REPORT_CACHE_TTL_SECONDS)


def invalidate_report_cache(user_id: int) -> None:
    """Drop every cached report (all children, types, and windows) for a parent."""
    cache_service.clear_pattern(f"report:{user_id}:*")
