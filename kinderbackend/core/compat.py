"""
Backward-compatibility helpers for the response envelope.

After the global EnvelopeMiddleware was introduced (wrapping all successful
JSON responses in ``{"data": ..., "meta": {...}}``), existing code that
accessed top-level keys directly (e.g. ``body["items"]``, ``body["token"]``)
started failing.

``unwrap_response`` is the single source of truth for stripping the envelope:
it returns ``response["data"]`` when the envelope is present, otherwise it
returns the dict unchanged.  This makes callers forward-compatible with both
the old flat shape and the new wrapped shape.

Usage
-----
    from core.compat import unwrap_response

    body = unwrap_response(response.json())
    assert body["items"][0]["id"] == expected_id
"""
from __future__ import annotations

from typing import Any


def unwrap_response(response: Any) -> Any:
    """Return the inner payload from an enveloped response dict.

    * If *response* is a ``dict`` that contains a ``"data"`` key alongside a
      ``"meta"`` key (i.e. it matches the envelope shape), return
      ``response["data"]``.
    * Otherwise return *response* unchanged so that callers work with both
      the legacy flat shape and the current enveloped shape.

    Args:
        response: Parsed JSON body (typically ``httpx_response.json()``).

    Returns:
        The unwrapped payload or the original value if no envelope is found.
    """
    if isinstance(response, dict) and "data" in response and "meta" in response:
        return response["data"]
    return response
