"""
Rate limiting dependencies for FastAPI.

This provides simple in-memory rate limiting to prevent abuse.
For production, consider Redis-based rate limiting.
"""

import time
from collections import defaultdict
from typing import Dict

from fastapi import HTTPException, Request
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


def rate_limit(max_requests: int = 100, window_seconds: int = 60):
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
        # Use client IP as key (in production, consider user ID for authenticated endpoints)
        client_ip = request.client.host if request.client else "unknown"
        key = f"{client_ip}:{request.url.path}"

        if not rate_limiter.is_allowed(key, max_requests, window_seconds):
            raise HTTPException(
                status_code=HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": f"Too many requests. Limit: {max_requests} per {window_seconds} seconds",
                    "retry_after": window_seconds,
                },
                headers={"Retry-After": str(window_seconds)},
            )

    return check_rate_limit


# Pre-configured rate limiters for common use cases
def auth_rate_limit():
    """Stricter rate limiting for authentication endpoints."""
    return rate_limit(max_requests=5, window_seconds=300)  # 5 requests per 5 minutes


def api_rate_limit():
    """Standard rate limiting for API endpoints."""
    return rate_limit(max_requests=100, window_seconds=60)  # 100 requests per minute


def admin_rate_limit():
    """Rate limiting for admin endpoints."""
    return rate_limit(max_requests=200, window_seconds=60)  # 200 requests per minute
