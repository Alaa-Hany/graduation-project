from __future__ import annotations

import logging
from typing import Any

from core.request_context import get_request_id
from core.settings import Settings

_STRUCTURED_FIELDS = (
    "event",
    "category",
    "method",
    "path",
    "route",
    "status_code",
    "status_family",
    "duration_ms",
    "client_ip",
    "user_id",
    "admin_user_id",
    "child_id",
    "session_id",
    "subscription_profile_id",
    "provider",
    "event_id",
    "event_type",
    "outcome",
    "reason",
    "error_code",
    "exception_type",
    "environment",
    "allowed_origins_count",
    "has_origin_regex",
    "allow_credentials",
)


class RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        request_id = get_request_id()
        record.request_id = request_id
        record.correlation_id = request_id
        return True


class StructuredFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        rendered = super().format(record)
        extra_parts: list[str] = []
        for field in _STRUCTURED_FIELDS:
            value = getattr(record, field, None)
            if value is None:
                continue
            extra_parts.append(f"{field}={value}")
        if not extra_parts:
            return rendered
        return f"{rendered} {' '.join(extra_parts)}"


def log_with_context(
    logger: logging.Logger,
    level: int,
    message: str,
    /,
    **fields: Any,
) -> None:
    logger.log(
        level,
        message,
        extra={key: value for key, value in fields.items() if value is not None},
    )


def _coerce_log_level(level_name: str) -> int:
    return getattr(logging, level_name.upper(), logging.INFO)


def configure_logging(settings: Settings) -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler()]
    if settings.app_log_file:
        handlers.insert(0, logging.FileHandler(settings.app_log_file))

    request_filter = RequestContextFilter()
    for handler in handlers:
        handler.addFilter(request_filter)
        handler.setFormatter(
            StructuredFormatter(
                fmt=("%(asctime)s %(levelname)s %(name)s " "request_id=%(request_id)s %(message)s")
            )
        )

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(_coerce_log_level(settings.app_log_level))
    for handler in handlers:
        root.addHandler(handler)
