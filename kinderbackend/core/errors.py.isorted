from __future__ import annotations

from typing import Any

from fastapi import HTTPException


class AppException(Exception):
    def __init__(
        self,
        *,
        status_code: int,
        message: str,
        code: str | None = None,
        extra: dict[str, Any] | None = None,
    ) -> None:
        self.status_code = status_code
        self.message = message
        self.code = code
        self.extra = extra or {}
        super().__init__(message)

    def to_detail(self) -> Any:
        if self.code or self.extra:
            payload: dict[str, Any] = {"message": self.message}
            if self.code:
                payload["code"] = self.code
            payload.update(self.extra)
            return payload
        return self.message


def http_error(
    *,
    status_code: int,
    message: str,
    code: str | None = None,
    extra: dict[str, Any] | None = None,
) -> HTTPException:
    if code or extra:
        payload: dict[str, Any] = {"message": message}
        if code:
            payload["code"] = code
        if extra:
            payload.update(extra)
        return HTTPException(status_code=status_code, detail=payload)
    return HTTPException(status_code=status_code, detail=message)


def bad_request(message: str) -> HTTPException:
    return http_error(status_code=400, message=message)


def unauthorized(message: str) -> HTTPException:
    return http_error(status_code=401, message=message)


def forbidden(message: str) -> HTTPException:
    return http_error(status_code=403, message=message)


def not_found(message: str) -> HTTPException:
    return http_error(status_code=404, message=message)


def unprocessable(message: str) -> HTTPException:
    return http_error(status_code=422, message=message)
