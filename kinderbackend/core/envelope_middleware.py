"""
EnvelopeMiddleware - wraps successful JSON responses in the standard envelope:

    {"data": <original body>, "meta": {"request_id": "...", "timestamp": "..."}}

Versioning contract
-------------------
  - /api/v2/*   → envelope ALWAYS applied (new standard)
  - /api/v1/*   → raw responses, no envelope (backward-compatible)
  - bare paths  → raw responses, no envelope (legacy / test compatibility)
  - /health*    → raw (load-balancer probes)
  - /webhooks*  → raw (payment provider callbacks; shape must not change)
  - /docs, /redoc, /openapi.json → raw (Swagger UI)

Error responses (non-2xx) are never wrapped so that the existing
ErrorResponse / HTTPException shape is preserved for all clients.

Implementation note: BaseHTTPMiddleware buffers the full response body in
memory, which is fine for this API (all responses are small JSON payloads).
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from core.request_context import get_request_id

# Only paths under this prefix receive the response envelope.
_ENVELOPE_PREFIX = "/api/v2"


def _should_envelope(path: str, status_code: int) -> bool:
    # Envelope is exclusively a v2 contract.
    if not path.startswith(_ENVELOPE_PREFIX):
        return False
    # Only wrap successful responses; let error bodies through unchanged.
    if status_code < 200 or status_code >= 300:
        return False
    return True


def _utc_now_iso() -> str:
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"


class EnvelopeMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)

        content_type = response.headers.get("content-type", "")
        if not content_type.startswith("application/json"):
            return response

        if not _should_envelope(request.url.path, response.status_code):
            return response

        # Buffer and re-wrap the body.
        body_bytes = b""
        async for chunk in response.body_iterator:
            body_bytes += chunk

        try:
            original = json.loads(body_bytes)
        except (json.JSONDecodeError, ValueError):
            # Body is not valid JSON - return as-is.
            return Response(
                content=body_bytes,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=content_type,
            )

        wrapped = {
            "data": original,
            "meta": {
                "request_id": get_request_id(),
                "timestamp": _utc_now_iso(),
            },
        }
        wrapped_bytes = json.dumps(wrapped, ensure_ascii=False).encode("utf-8")

        # Rebuild headers, updating Content-Length to match the new body.
        headers = dict(response.headers)
        headers["content-length"] = str(len(wrapped_bytes))

        return Response(
            content=wrapped_bytes,
            status_code=response.status_code,
            headers=headers,
            media_type="application/json",
        )
