"""
Shared pytest fixtures for the tests/ package.

Inherits all fixtures from the root-level conftest.py (pytest picks them up
automatically via the package hierarchy).

Key addition: the ``api`` fixture, which exposes a thin helper that
auto-unwraps the global response envelope introduced in the EnvelopeMiddleware
so that test assertions can access ``items``, ``item``, ``access_token``, etc.
directly — without needing to touch ``response["data"]`` everywhere.

Usage in a test
---------------
    def test_something(client, api):
        resp = client.get("/api/v1/some/endpoint")
        body = api.parse(resp)           # unwraps envelope if present
        assert body["items"][0]["id"] == 1

    # Or when you only need a single key:
        token = api.parse(client.post("/api/v1/auth/login", json={...}))["access_token"]
"""
from __future__ import annotations

import pytest

from core.compat import unwrap_response


class _ApiHelper:
    """Lightweight test-time API helper attached to the ``api`` fixture."""

    def parse(self, response) -> dict:
        """Parse *response* and unwrap the envelope if present.

        Accepts any object with a ``.json()`` method (TestClient / httpx
        Response) **or** a plain ``dict`` (already-parsed body).

        Returns the inner payload dict (``response["data"]`` when the global
        EnvelopeMiddleware is active, or the raw dict when it is not).
        """
        body = response.json() if hasattr(response, "json") else response
        return unwrap_response(body)


@pytest.fixture
def api() -> _ApiHelper:
    """Return an :class:`_ApiHelper` instance for the current test.

    Provides ``api.parse(response)`` — the primary compatibility shim that
    strips the global response envelope so tests can access top-level keys
    (``items``, ``item``, ``access_token``, ``session``, ``success``, etc.)
    exactly as they did before the envelope was introduced.
    """
    return _ApiHelper()
