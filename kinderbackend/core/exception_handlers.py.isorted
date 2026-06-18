import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from core.errors import AppException
from core.logging_utils import log_with_context
from core.message_catalog import AdminAuthMessages, AuthMessages
from core.observability import emit_event, record_counter

logger = logging.getLogger(__name__)

_ERROR_CODE_BY_MESSAGE = {
    AuthMessages.AUTHENTICATION_REQUIRED: "AUTHENTICATION_REQUIRED",
    AuthMessages.INVALID_TOKEN: "INVALID_TOKEN",
    AuthMessages.INVALID_TOKEN_TYPE: "INVALID_TOKEN_TYPE",
    AuthMessages.INVALID_TOKEN_PAYLOAD: "INVALID_TOKEN_PAYLOAD",
    AuthMessages.TOKEN_REVOKED: "TOKEN_REVOKED",
    AuthMessages.USER_NOT_FOUND: "USER_NOT_FOUND",
    AdminAuthMessages.AUTHENTICATION_REQUIRED: "ADMIN_AUTHENTICATION_REQUIRED",
    AdminAuthMessages.INVALID_OR_EXPIRED_ADMIN_TOKEN: "INVALID_ADMIN_TOKEN",
    AdminAuthMessages.INVALID_ADMIN_TOKEN_TYPE: "INVALID_ADMIN_TOKEN_TYPE",
    AdminAuthMessages.INVALID_ADMIN_TOKEN_PAYLOAD: "INVALID_ADMIN_TOKEN_PAYLOAD",
    AdminAuthMessages.ADMIN_ACCOUNT_NOT_FOUND: "ADMIN_ACCOUNT_NOT_FOUND",
    AdminAuthMessages.ADMIN_TOKEN_REVOKED: "ADMIN_TOKEN_REVOKED",
    AuthMessages.INVALID_REFRESH_TOKEN: "INVALID_REFRESH_TOKEN",
    AdminAuthMessages.INVALID_OR_EXPIRED_REFRESH_TOKEN: "INVALID_REFRESH_TOKEN",
    AdminAuthMessages.INVALID_REFRESH_TOKEN_TYPE: "INVALID_REFRESH_TOKEN_TYPE",
    AdminAuthMessages.INVALID_REFRESH_TOKEN_PAYLOAD: "INVALID_REFRESH_TOKEN_PAYLOAD",
    AdminAuthMessages.REFRESH_TOKEN_REVOKED: "REFRESH_TOKEN_REVOKED",
    "Internal server error": "INTERNAL_SERVER_ERROR",
}


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


def _default_error_message(status_code: int) -> str:
    if status_code == 401:
        return "Authentication failed"
    if status_code == 403:
        return "Access denied"
    if status_code == 404:
        return "Resource not found"
    if status_code == 422:
        return "Request validation failed"
    if status_code == 429:
        return "Too many requests"
    if status_code >= 500:
        return "Internal server error"
    return "Request failed"


def _error_type(status_code: int) -> str:
    if status_code == 401:
        return "authentication_error"
    if status_code == 403:
        return "authorization_error"
    if status_code == 404:
        return "not_found_error"
    if status_code == 422:
        return "validation_error"
    if status_code == 429:
        return "rate_limit_error"
    if status_code >= 500:
        return "server_error"
    return "request_error"


def _error_message(detail: Any, *, status_code: int) -> str:
    if isinstance(detail, dict):
        message = detail.get("message")
        if isinstance(message, str) and message.strip():
            return message
    if isinstance(detail, str) and detail.strip():
        return detail
    return _default_error_message(status_code)


def _error_code(detail: Any, *, status_code: int, message: str) -> str:
    if isinstance(detail, dict):
        code = detail.get("code")
        if isinstance(code, str) and code.strip():
            return code
    if isinstance(detail, list):
        return "VALIDATION_ERROR"
    if message in _ERROR_CODE_BY_MESSAGE:
        return _ERROR_CODE_BY_MESSAGE[message]
    if status_code == 401:
        return "UNAUTHORIZED"
    if status_code == 403:
        return "FORBIDDEN"
    if status_code == 404:
        return "NOT_FOUND"
    if status_code == 422:
        return "VALIDATION_ERROR"
    if status_code == 429:
        return "RATE_LIMIT_EXCEEDED"
    if status_code >= 500:
        return "INTERNAL_SERVER_ERROR"
    return "REQUEST_ERROR"


def build_error_body(*, status_code: int, detail: Any) -> dict[str, Any]:
    message = _error_message(detail, status_code=status_code)
    code = _error_code(detail, status_code=status_code, message=message)
    error: dict[str, Any] = {
        "message": message,
        "code": code,
        "type": _error_type(status_code),
    }
    return {
        "detail": detail,
        "error": error,
    }


def register_exception_handlers(app: FastAPI) -> None:
    def _request_id_headers(request: Request) -> dict[str, str]:
        request_id = getattr(request.state, "request_id", None)
        if not request_id:
            return {}
        return {"X-Request-ID": str(request_id)}

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        record_counter(
            "http.errors.total",
            category="http",
            status_code=exc.status_code,
            error_type="app_exception",
        )
        log_with_context(
            logger,
            logging.WARNING if exc.status_code < 500 else logging.ERROR,
            "app_exception_handled",
            event="app_exception_handled",
            category="http",
            method=request.method,
            path=request.url.path,
            status_code=exc.status_code,
            error_code=getattr(exc, "code", None),
            outcome="handled",
        )
        return JSONResponse(
            status_code=exc.status_code,
            content=build_error_body(status_code=exc.status_code, detail=exc.to_detail()),
            headers=_request_id_headers(request),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        record_counter(
            "http.errors.total",
            category="http",
            status_code=exc.status_code,
            error_type="http_exception",
        )
        detail_body = build_error_body(status_code=exc.status_code, detail=exc.detail)
        log_with_context(
            logger,
            logging.WARNING if exc.status_code < 500 else logging.ERROR,
            "http_exception_handled",
            event="http_exception_handled",
            category="http",
            method=request.method,
            path=request.url.path,
            status_code=exc.status_code,
            error_code=detail_body["error"]["code"],
            outcome="handled",
        )
        headers = dict(exc.headers or {})
        headers.update(_request_id_headers(request))
        return JSONResponse(
            status_code=exc.status_code,
            content=detail_body,
            headers=headers,
        )

    @app.exception_handler(RequestValidationError)
    async def request_validation_handler(request: Request, exc: RequestValidationError):
        record_counter(
            "http.errors.total",
            category="http",
            status_code=422,
            error_type="validation_error",
        )
        normalized_errors = _normalize_validation_errors(exc.errors())
        log_with_context(
            logger,
            logging.WARNING,
            "request_validation_failed",
            event="request_validation_failed",
            category="http",
            method=request.method,
            path=request.url.path,
            status_code=422,
            error_code="VALIDATION_ERROR",
            outcome="handled",
        )
        return JSONResponse(
            status_code=422,
            content=build_error_body(status_code=422, detail=normalized_errors),
            headers=_request_id_headers(request),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        record_counter(
            "http.errors.total",
            category="http",
            status_code=500,
            error_type="unhandled_exception",
        )
        emit_event(
            "http.exception.unhandled",
            category="http",
            severity="error",
            method=request.method,
            path=request.url.path,
            exception_type=type(exc).__name__,
        )
        logger.exception(
            "unhandled_exception",
            extra={
                "event": "unhandled_exception",
                "category": "http",
                "method": request.method,
                "path": request.url.path,
                "status_code": 500,
                "exception_type": type(exc).__name__,
                "outcome": "error",
            },
        )
        return JSONResponse(
            status_code=500,
            content=build_error_body(status_code=500, detail="Internal server error"),
            headers=_request_id_headers(request),
        )
