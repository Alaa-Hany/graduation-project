"""
Rate limiting dependencies for FastAPI.

Uses Redis-backed INCR + EXPIRE counters (fixed-window approximation) when
REDIS_URL is configured.  Falls back to a single-process in-memory store for
local development / tests — NOT safe across multiple workers.
"""

import logging
import time
from collections import defaultdict
from typing import Dict

from fastapi import Depends, HTTPException, Request
from starlette.status import HTTP_429_TOO_MANY_REQUESTS

from core.redis_client import get_redis_client

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Fallback in-memory limiter (development / tests only)
# ---------------------------------------------------------------------------


class _InMemoryFallback:
    """Single-process sliding-window store used when Redis is unavailable."""

    def __init__(self) -> None:
        self.requests: Dict[str, list] = defaultdict(list)

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = time.time()
        window_start = now - window_seconds
        self.requests[key] = [t for t in self.requests[key] if t > window_start]
        if len(self.requests[key]) >= max_requests:
            return False
        self.requests[key].append(now)
        return True


_fallback = _InMemoryFallback()


class _RateLimitRequestsProxy:
    def clear(self) -> None:
        _fallback.requests.clear()
        rc = get_redis_client()
        if hasattr(rc, "clear"):
            rc.clear()


# ---------------------------------------------------------------------------
# Redis-backed limiter
# ---------------------------------------------------------------------------


class RedisRateLimiter:
    """Rate limiter backed by Redis INCR + EXPIRE (fixed-window counter).

    Key schema: ``ratelimit:{caller_key}``
    On first request in a window, INCR creates the key and EXPIRE (NX) sets
    the TTL equal to ``window_seconds``.  Subsequent requests within the same
    window only increment the counter; the TTL is not reset, so the window
    slides naturally as old keys expire.
    """

    @property
    def requests(self):
        return _RateLimitRequestsProxy()

    def is_allowed(
        self, key: str, max_requests: int, window_seconds: int, *, fail_open: bool = True
    ) -> bool:
        rc = get_redis_client()
        if rc is None:
            return _fallback.is_allowed(key, max_requests, window_seconds)

        full_key = f"ratelimit:{key}"
        try:
            pipe = rc.pipeline()
            pipe.incr(full_key)
            pipe.expire(full_key, window_seconds, nx=True)
            count, _ = pipe.execute()
            return int(count) <= max_requests
        except Exception as exc:
            if fail_open:
                logger.error("Redis rate-limit check failed (%s); allowing request", exc)
                return True  # fail open to avoid blocking all traffic on Redis outage
            # Authentication-scoped limiters must not silently lose brute-force
            # protection on a Redis outage. Degrade to the per-process in-memory
            # limiter instead of either allowing every request or blocking all of
            # them outright.
            logger.error(
                "Redis rate-limit check failed (%s); degrading to in-memory limiter "
                "for security-sensitive scope",
                exc,
            )
            return _fallback.is_allowed(key, max_requests, window_seconds)


rate_limiter = RedisRateLimiter()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _rate_limit_detail(
    *,
    code: str,
    message: str,
    retry_after: int,
    scope: str,
) -> dict[str, object]:
    return {
        "code": code,
        "message": message,
        "retry_after": retry_after,
        "scope": scope,
    }


# ---------------------------------------------------------------------------
# FastAPI dependency factories
# ---------------------------------------------------------------------------


def rate_limit(
    max_requests: int = 100,
    window_seconds: int = 60,
    *,
    code: str = "RATE_LIMIT_EXCEEDED",
    message: str | None = None,
    scope: str = "ip",
    fail_open: bool = True,
):
    """IP + path keyed rate-limit dependency.

    ``fail_open`` controls behavior when Redis is unreachable: general API
    limiters fail open (allow the request) to avoid blocking all traffic on
    a Redis outage, while authentication-sensitive limiters should pass
    ``fail_open=False`` so brute-force protection degrades to a per-process
    in-memory limiter instead of disappearing entirely.

    Usage::

        @app.get("/api/endpoint")
        def endpoint(_: None = Depends(rate_limit(10, 60))):
            return {"message": "ok"}
    """

    def check_rate_limit(request: Request) -> None:
        client_ip = _client_ip(request)
        key = f"ip:{client_ip}:{request.url.path}"
        resolved_message = (
            message or f"Too many requests. Limit: {max_requests} per {window_seconds} seconds"
        )

        if not rate_limiter.is_allowed(key, max_requests, window_seconds, fail_open=fail_open):
            raise HTTPException(
                status_code=HTTP_429_TOO_MANY_REQUESTS,
                detail=_rate_limit_detail(
                    code=code,
                    message=resolved_message,
                    retry_after=window_seconds,
                    scope=scope,
                ),
                headers={"Retry-After": str(window_seconds)},
            )

    return check_rate_limit


def user_rate_limit(
    max_requests: int = 5,
    window_seconds: int = 300,
    *,
    code: str = "RATE_LIMIT_EXCEEDED",
    message: str | None = None,
    scope: str = "user",
    fail_open: bool = True,
):
    """Per-authenticated-user + path keyed rate-limit dependency.

    See :func:`rate_limit` for the meaning of ``fail_open``.
    """

    from deps import get_current_user

    def check_rate_limit(request: Request, user=Depends(get_current_user)) -> None:
        user_id = getattr(user, "id", "unknown")
        key = f"user:{user_id}:{request.url.path}"
        resolved_message = (
            message or f"Too many requests. Limit: {max_requests} per {window_seconds} seconds"
        )

        if not rate_limiter.is_allowed(key, max_requests, window_seconds, fail_open=fail_open):
            raise HTTPException(
                status_code=HTTP_429_TOO_MANY_REQUESTS,
                detail=_rate_limit_detail(
                    code=code,
                    message=resolved_message,
                    retry_after=window_seconds,
                    scope=scope,
                ),
                headers={"Retry-After": str(window_seconds)},
            )

    return check_rate_limit


# ---------------------------------------------------------------------------
# Pre-configured limiters
# ---------------------------------------------------------------------------


def auth_rate_limit():
    """Stricter rate limiting for authentication endpoints."""
    return rate_limit(max_requests=5, window_seconds=300, scope="authentication", fail_open=False)


def api_rate_limit():
    """Standard rate limiting for API endpoints."""
    return rate_limit(max_requests=100, window_seconds=60)


def admin_rate_limit():
    """Rate limiting for admin endpoints."""
    return rate_limit(max_requests=200, window_seconds=60)


def password_change_rate_limit():
    """Per-user throttling for password change attempts."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many password change attempts. Please try again later.",
        scope="password_change",
        fail_open=False,
    )


def parent_pin_mutation_rate_limit():
    """Per-user throttling for parent PIN creation, change, and reset requests."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many parent PIN attempts. Please try again later.",
        scope="parent_pin",
        fail_open=False,
    )


def parent_pin_verify_rate_limit():
    """Per-user throttling for parent PIN verification without masking lockout behavior."""
    return user_rate_limit(
        max_requests=10,
        window_seconds=300,
        message="Too many parent PIN attempts. Please try again later.",
        scope="parent_pin",
        fail_open=False,
    )


def support_write_rate_limit():
    """Per-user throttling for support ticket creation and replies."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many support actions. Please try again later.",
        scope="support_write",
    )


def email_otp_verify_rate_limit():
    """IP-based throttling for email OTP verification."""
    return rate_limit(
        max_requests=10,
        window_seconds=300,
        message="Too many OTP verification attempts. Please try again later.",
        scope="email_otp_verify",
        fail_open=False,
    )


def email_otp_resend_rate_limit():
    """IP-based throttling for email OTP resend requests."""
    return rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many OTP resend requests. Please try again later.",
        scope="email_otp_resend",
        fail_open=False,
    )


def password_reset_rate_limit():
    """IP-based throttling for password reset requests."""
    return rate_limit(
        max_requests=5,
        window_seconds=600,
        message="Too many password reset requests. Please try again later.",
        scope="password_reset",
        fail_open=False,
    )
