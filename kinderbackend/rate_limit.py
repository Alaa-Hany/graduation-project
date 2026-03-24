"""
Rate limiting dependencies for FastAPI.

This provides simple in-memory rate limiting to prevent abuse.
For production, consider Redis-based rate limiting.
"""

import time
from collections import defaultdict
from typing import Dict

from fastapi import Depends, HTTPException, Request
from starlette.status import HTTP_429_TOO_MANY_REQUESTS


class InMemoryRateLimiter:
    """Simple in-memory rate limiter using sliding window."""

    def __init__(self):
        self.requests: Dict[str, list] = defaultdict(list)

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        """Check if request is allowed under rate limit."""
        now = time.time()
        window_start = now - window_seconds

        # Clean old requests
        self.requests[key] = [
            req_time for req_time in self.requests[key] if req_time > window_start
        ]

        if len(self.requests[key]) >= max_requests:
            return False

        self.requests[key].append(now)
        return True


# Global rate limiter instance
rate_limiter = InMemoryRateLimiter()


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


def rate_limit(
    max_requests: int = 100,
    window_seconds: int = 60,
    *,
    code: str = "RATE_LIMIT_EXCEEDED",
    message: str | None = None,
    scope: str = "ip",
):
    """
    Rate limiting dependency.

    Args:
        max_requests: Maximum requests allowed in the window
        window_seconds: Time window in seconds

    Usage:
        @app.get("/api/endpoint")
        def endpoint(rate_limit_check: None = Depends(rate_limit(10, 60))):
            return {"message": "ok"}
    """

    def check_rate_limit(request: Request):
        client_ip = _client_ip(request)
        key = f"ip:{client_ip}:{request.url.path}"
        resolved_message = (
            message or f"Too many requests. Limit: {max_requests} per {window_seconds} seconds"
        )

        if not rate_limiter.is_allowed(key, max_requests, window_seconds):
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
):
    """
    Rate limiting dependency keyed by authenticated user id and path.

    This is intended for authenticated sensitive mutations where per-user
    throttling is safer than a shared-IP bucket.
    """

    from deps import get_current_user

    def check_rate_limit(request: Request, user=Depends(get_current_user)):
        user_id = getattr(user, "id", "unknown")
        key = f"user:{user_id}:{request.url.path}"
        resolved_message = (
            message or f"Too many requests. Limit: {max_requests} per {window_seconds} seconds"
        )

        if not rate_limiter.is_allowed(key, max_requests, window_seconds):
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


# Pre-configured rate limiters for common use cases
def auth_rate_limit():
    """Stricter rate limiting for authentication endpoints."""
    return rate_limit(
        max_requests=5,
        window_seconds=300,
        scope="authentication",
    )  # 5 requests per 5 minutes


def api_rate_limit():
    """Standard rate limiting for API endpoints."""
    return rate_limit(max_requests=100, window_seconds=60)  # 100 requests per minute


def admin_rate_limit():
    """Rate limiting for admin endpoints."""
    return rate_limit(max_requests=200, window_seconds=60)  # 200 requests per minute


def password_change_rate_limit():
    """Per-user throttling for password change attempts."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many password change attempts. Please try again later.",
        scope="password_change",
    )


def parent_pin_mutation_rate_limit():
    """Per-user throttling for parent PIN creation, change, and reset requests."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many parent PIN attempts. Please try again later.",
        scope="parent_pin",
    )


def parent_pin_verify_rate_limit():
    """Per-user throttling for parent PIN verification without masking lockout behavior."""
    return user_rate_limit(
        max_requests=10,
        window_seconds=300,
        message="Too many parent PIN attempts. Please try again later.",
        scope="parent_pin",
    )


def support_write_rate_limit():
    """Per-user throttling for support ticket creation and replies."""
    return user_rate_limit(
        max_requests=5,
        window_seconds=300,
        message="Too many support actions. Please try again later.",
        scope="support_write",
    )
