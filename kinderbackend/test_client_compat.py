"""Single import point for the test client used across the backend tests.

This used to rebuild starlette's TestClient from private internals so it
would run on an old httpx. Starlette 1.x's public TestClient already follows
redirects and sends a ``testclient`` user agent, so it is used as-is.
"""

from __future__ import annotations

from starlette.testclient import TestClient

__all__ = ["TestClient"]
