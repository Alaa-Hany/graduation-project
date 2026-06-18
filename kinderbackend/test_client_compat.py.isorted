from __future__ import annotations

from typing import Any

import httpx
from starlette.testclient import TestClient as StarletteTestClient
from starlette.testclient import _AsyncBackend, _is_asgi3, _TestClientTransport, _WrapASGI2


class TestClient(StarletteTestClient):
    def __init__(
        self,
        app: Any,
        base_url: str = "http://testserver",
        raise_server_exceptions: bool = True,
        root_path: str = "",
        backend: str = "asyncio",
        backend_options: dict[str, Any] | None = None,
        cookies: httpx._types.CookieTypes | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.async_backend = _AsyncBackend(
            backend=backend,
            backend_options=backend_options or {},
        )
        self.portal = None
        if _is_asgi3(app):
            asgi_app = app
        else:
            asgi_app = _WrapASGI2(app)
        self.app = asgi_app
        self.app_state: dict[str, Any] = {}
        transport = _TestClientTransport(
            self.app,
            portal_factory=self._portal_factory,
            raise_server_exceptions=raise_server_exceptions,
            root_path=root_path,
            app_state=self.app_state,
        )
        resolved_headers = dict(headers or {})
        resolved_headers.setdefault("user-agent", "testclient")
        httpx.Client.__init__(
            self,
            base_url=base_url,
            headers=resolved_headers,
            transport=transport,
            follow_redirects=True,
            cookies=cookies,
        )
