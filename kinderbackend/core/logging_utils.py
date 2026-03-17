from __future__ import annotations

import logging

from core.request_context import get_request_id
from core.settings import Settings


class RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = get_request_id()
        return True


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
            logging.Formatter(
                fmt=("%(asctime)s %(levelname)s %(name)s " "request_id=%(request_id)s %(message)s")
            )
        )

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(_coerce_log_level(settings.app_log_level))
    for handler in handlers:
        root.addHandler(handler)
