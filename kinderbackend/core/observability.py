from __future__ import annotations

import json
import logging
import os
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from typing import Any, Iterable

logger = logging.getLogger("observability")

_MAX_EVENTS = max(int(os.getenv("OBSERVABILITY_EVENT_BUFFER", "500")), 50)
_EVENTS: deque[dict[str, Any]] = deque(maxlen=_MAX_EVENTS)
_LOCK = Lock()

_SEVERITY_ORDER = {
    "debug": 10,
    "info": 20,
    "warn": 30,
    "warning": 30,
    "error": 40,
    "critical": 50,
}


@dataclass(frozen=True)
class ObservabilityEvent:
    name: str
    category: str
    severity: str
    timestamp: str
    fields: dict[str, Any]


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_severity(value: str | None) -> str:
    if not value:
        return "info"
    normalized = value.strip().lower()
    if normalized == "warning":
        return "warn"
    if normalized not in _SEVERITY_ORDER:
        return "info"
    return normalized


def _filter_fields(fields: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in fields.items() if value is not None}


def emit_event(
    name: str,
    *,
    category: str,
    severity: str | None = None,
    **fields: Any,
) -> ObservabilityEvent:
    normalized_severity = _normalize_severity(severity)
    event = ObservabilityEvent(
        name=name,
        category=category,
        severity=normalized_severity,
        timestamp=_utc_now_iso(),
        fields=_filter_fields(fields),
    )
    payload = {
        "name": event.name,
        "category": event.category,
        "severity": event.severity,
        "timestamp": event.timestamp,
        "fields": event.fields,
    }
    with _LOCK:
        _EVENTS.append(payload)

    message = json.dumps(payload, ensure_ascii=True, sort_keys=True)
    if normalized_severity in {"error", "critical"}:
        logger.error("obs_event %s", message)
    elif normalized_severity in {"warn"}:
        logger.warning("obs_event %s", message)
    else:
        logger.info("obs_event %s", message)
    return event


def get_recent_events(
    *,
    limit: int = 100,
    category: str | None = None,
    name_prefix: str | None = None,
    min_severity: str | None = None,
) -> list[dict[str, Any]]:
    normalized_category = (category or "").strip().lower() or None
    normalized_prefix = (name_prefix or "").strip().lower() or None
    normalized_min = _normalize_severity(min_severity)
    min_order = _SEVERITY_ORDER.get(normalized_min, 0)

    with _LOCK:
        items = list(_EVENTS)

    def _match(item: dict[str, Any]) -> bool:
        if normalized_category and item.get("category", "").lower() != normalized_category:
            return False
        if normalized_prefix and not item.get("name", "").lower().startswith(normalized_prefix):
            return False
        severity = _normalize_severity(item.get("severity"))
        if _SEVERITY_ORDER.get(severity, 0) < min_order:
            return False
        return True

    filtered = [item for item in items if _match(item)]
    return filtered[-limit:]


def summarize_events(events: Iterable[dict[str, Any]]) -> dict[str, Any]:
    by_category: dict[str, int] = {}
    by_severity: dict[str, int] = {}
    by_name: dict[str, int] = {}
    for item in events:
        category = str(item.get("category") or "unknown")
        by_category[category] = by_category.get(category, 0) + 1
        severity = _normalize_severity(str(item.get("severity") or "info"))
        by_severity[severity] = by_severity.get(severity, 0) + 1
        name = str(item.get("name") or "unknown")
        by_name[name] = by_name.get(name, 0) + 1
    return {
        "by_category": dict(sorted(by_category.items())),
        "by_severity": dict(sorted(by_severity.items())),
        "by_name": dict(sorted(by_name.items())),
        "total": sum(by_category.values()),
    }


def clear_events() -> None:
    with _LOCK:
        _EVENTS.clear()
