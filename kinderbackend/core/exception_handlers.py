import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from core.errors import AppException

logger = logging.getLogger(__name__)


def _normalize_validation_errors(errors: list[dict[str, Any]]) -> list[dict[str, Any]]:
    def _normalize(value: Any) -> Any:
        if isinstance(value, dict):
            return {str(key): _normalize(item) for key, item in value.items()}
        if isinstance(value, (list, tuple)):
            return [_normalize(item) for item in value]
        if isinstance(value, (str, int, float, bool)) or value is None:
            return value
        return str(value)

    return [_normalize(error) for error in errors]


def register_exception_handlers(app: FastAPI) -> None:
    def _request_id_headers(request: Request) -> dict[str, str]:
        request_id = getattr(request.state, "request_id", None)
        if not request_id:
            return {}
        return {"X-Request-ID": str(request_id)}

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.to_detail()},
            headers=_request_id_headers(request),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        headers = dict(exc.headers or {})
        headers.update(_request_id_headers(request))
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
            headers=headers,
        )

    @app.exception_handler(RequestValidationError)
    async def request_validation_handler(request: Request, exc: RequestValidationError):
        normalized_errors = _normalize_validation_errors(exc.errors())
        return JSONResponse(
            status_code=422,
            content={"detail": normalized_errors},
            headers=_request_id_headers(request),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception(
            "unhandled_exception method=%s path=%s",
            request.method,
            request.url.path,
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
            headers=_request_id_headers(request),
        )
