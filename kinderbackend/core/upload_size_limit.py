"""Reject oversized upload bodies before the app buffers them.

FastAPI parses a multipart body (spooling it to disk) before the route
handler runs, so a size check inside the handler only fires after the whole
file has already been received. This ASGI middleware stops the request early:
it refuses a declared ``Content-Length`` over the limit straight away and, for
chunked bodies without one, counts bytes as they arrive and answers 413 once
the limit is crossed.
"""

from __future__ import annotations

import json
from typing import Callable, Iterable

# Room for the multipart boundaries and the small form fields sent with a file.
MULTIPART_OVERHEAD_BYTES = 1024 * 1024


def _too_large_body(limit_bytes: int) -> bytes:
    limit_mb = max(1, (limit_bytes - MULTIPART_OVERHEAD_BYTES) // (1024 * 1024))
    return json.dumps(
        {
            "detail": {
                "code": "UPLOAD_TOO_LARGE",
                "message": f"Uploaded file exceeds the {limit_mb} MB limit",
            }
        }
    ).encode("utf-8")


class UploadSizeLimitMiddleware:
    def __init__(
        self,
        app,
        *,
        path_suffixes: Iterable[str],
        max_bytes: Callable[[], int],
    ) -> None:
        self.app = app
        self.path_suffixes = tuple(path_suffixes)
        self.max_bytes = max_bytes

    async def _send_413(self, send, limit: int) -> None:
        body = _too_large_body(limit)
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode("ascii")),
                    (b"connection", b"close"),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})

    async def __call__(self, scope, receive, send):
        if (
            scope.get("type") != "http"
            or scope.get("method") != "POST"
            or not str(scope.get("path", "")).endswith(self.path_suffixes)
        ):
            await self.app(scope, receive, send)
            return

        limit = int(self.max_bytes()) + MULTIPART_OVERHEAD_BYTES
        for name, value in scope.get("headers") or []:
            if name == b"content-length":
                try:
                    declared = int(value)
                except ValueError:
                    break
                if declared > limit:
                    await self._send_413(send, limit)
                    return
                break

        state = {"received": 0, "exceeded": False, "replied": False}

        async def limited_receive():
            if state["exceeded"]:
                # Stop feeding the parser; it treats this as a dropped client.
                return {"type": "http.disconnect"}
            message = await receive()
            if message.get("type") == "http.request":
                state["received"] += len(message.get("body", b""))
                if state["received"] > limit:
                    state["exceeded"] = True
                    return {"type": "http.disconnect"}
            return message

        async def guarded_send(message):
            if not state["exceeded"]:
                await send(message)
                return
            # The app is answering a body we cut off; replace it with a 413.
            if message.get("type") == "http.response.start" and not state["replied"]:
                state["replied"] = True
                await self._send_413(send, limit)

        try:
            await self.app(scope, limited_receive, guarded_send)
        except Exception:
            if not state["exceeded"]:
                raise
        if state["exceeded"] and not state["replied"]:
            state["replied"] = True
            await self._send_413(send, limit)
