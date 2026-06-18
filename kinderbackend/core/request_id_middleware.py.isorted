from __future__ import annotations

import logging
import time
import uuid
from typing import Callable

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from core.logging_utils import log_with_context
from core.observability import record_counter, record_timing
from core.request_context import reset_request_id, set_request_id

logger = logging.getLogger(__name__)

REQUEST_ID_HEADER = "X-Request-ID"
PROCESS_TIME_HEADER = "X-Process-Time-Ms"


def _request_path_template(request: Request) -> str:
    route = request.scope.get("route")
    route_path = getattr(route, "path", None)
    if isinstance(route_path, str) and route_path:
        return route_path
    return request.url.path


def _status_family(status_code: int) -> str:
    return f"{status_code // 100}xx"


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Response],
    ) -> Response:
        incoming = (request.headers.get(REQUEST_ID_HEADER) or "").strip()
        request_id = incoming[:128] if incoming else str(uuid.uuid4())

        token = set_request_id(request_id)
        request.state.request_id = request_id
        started_at = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            duration_ms = int((time.perf_counter() - started_at) * 1000)
            path_template = _request_path_template(request)
            record_counter(
                "http.requests.total",
                category="http",
                method=request.method,
                path=path_template,
                status_family="5xx",
                outcome="exception",
            )
            record_timing(
                "http.request.duration_ms",
                duration_ms=duration_ms,
                category="http",
                method=request.method,
                path=path_template,
                status_family="5xx",
                outcome="exception",
            )
            logger.exception(
                "http_request_failed",
                extra={
                    "event": "http_request_failed",
                    "category": "http",
                    "method": request.method,
                    "path": request.url.path,
                    "route": path_template,
                    "duration_ms": duration_ms,
                    "client_ip": request.client.host if request.client else "unknown",
                    "outcome": "exception",
                },
            )
            reset_request_id(token)
            raise

        duration_ms = int((time.perf_counter() - started_at) * 1000)
        path_template = _request_path_template(request)
        status_family = _status_family(response.status_code)
        record_counter(
            "http.requests.total",
            category="http",
            method=request.method,
            path=path_template,
            status_family=status_family,
            outcome="completed",
        )
        record_timing(
            "http.request.duration_ms",
            duration_ms=duration_ms,
            category="http",
            method=request.method,
            path=path_template,
            status_family=status_family,
            outcome="completed",
        )
        log_with_context(
            logger,
            logging.INFO,
            "http_request_completed",
            event="http_request_completed",
            category="http",
            method=request.method,
            path=request.url.path,
            route=path_template,
            status_code=response.status_code,
            status_family=status_family,
            duration_ms=duration_ms,
            client_ip=request.client.host if request.client else "unknown",
            outcome="completed",
        )
        response.headers[REQUEST_ID_HEADER] = request_id
        response.headers[PROCESS_TIME_HEADER] = str(duration_ms)
        reset_request_id(token)
        return response
