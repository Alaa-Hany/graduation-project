"""
Helpers for building the standard response envelope.

Usage inside a route (opt-in, for explicit typing):

    from core.response_envelope import envelope
    from schemas.common import EnvelopedResponse

    @router.get("/example", response_model=EnvelopedResponse[MySchema])
    def example():
        data = MySchema(...)
        return envelope(data)

Most routes are wrapped automatically by EnvelopeMiddleware registered in
main.py, so manual use is only needed when you want the OpenAPI schema to
reflect the envelope shape.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.request_context import get_request_id


def _utc_now_iso() -> str:
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"


def envelope(data: Any) -> dict[str, Any]:
    """Return a dict matching the EnvelopedResponse schema."""
    return {
        "data": data,
        "meta": {
            "request_id": get_request_id(),
            "timestamp": _utc_now_iso(),
        },
    }
