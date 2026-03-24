from __future__ import annotations

import json
import logging
import os
import time
from collections import deque
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock
from typing import Any, Iterable

from core.request_context import get_request_id

logger = logging.getLogger("observability")

_MAX_EVENTS = max(int(os.getenv("OBSERVABILITY_EVENT_BUFFER", "500")), 50)
_EVENTS: deque[dict[str, Any]] = deque(maxlen=_MAX_EVENTS)
_LOCK = Lock()
_METRICS: dict[tuple[str, str, str, tuple[tuple[str, str], ...]], dict[str, Any]] = {}

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


def _stringify_tag(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _normalize_tags(fields: dict[str, Any]) -> dict[str, str]:
    return {key: _stringify_tag(value) for key, value in _filter_fields(fields).items()}


def _metric_key(
    metric_type: str,
    name: str,
    category: str,
    tags: dict[str, str],
) -> tuple[str, str, str, tuple[tuple[str, str], ...]]:
    return (
        metric_type,
        name,
        category,
        tuple(sorted(tags.items())),
    )


def emit_event(
    name: str,
    *,
    category: str,
    severity: str | None = None,
    **fields: Any,
) -> ObservabilityEvent:
    normalized_severity = _normalize_severity(severity)
    request_id = get_request_id()
    event_fields = dict(fields)
    if request_id and request_id != "-" and "request_id" not in event_fields:
        event_fields["request_id"] = request_id
    event = ObservabilityEvent(
        name=name,
        category=category,
        severity=normalized_severity,
        timestamp=_utc_now_iso(),
        fields=_filter_fields(event_fields),
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


def record_counter(
    name: str,
    *,
    category: str,
    value: int = 1,
    **tags: Any,
) -> None:
    normalized_tags = _normalize_tags(tags)
    key = _metric_key("counter", name, category, normalized_tags)
    with _LOCK:
        entry = _METRICS.setdefault(
            key,
            {
                "type": "counter",
                "name": name,
                "category": category,
                "tags": normalized_tags,
                "value": 0,
            },
        )
        entry["value"] += int(value)
        entry["updated_at"] = _utc_now_iso()


def record_timing(
    name: str,
    duration_ms: int,
    *,
    category: str,
    **tags: Any,
) -> None:
    normalized_tags = _normalize_tags(tags)
    key = _metric_key("timing", name, category, normalized_tags)
    with _LOCK:
        entry = _METRICS.setdefault(
            key,
            {
                "type": "timing",
                "name": name,
                "category": category,
                "tags": normalized_tags,
                "count": 0,
                "total_ms": 0,
                "min_ms": None,
                "max_ms": None,
                "last_ms": None,
            },
        )
        entry["count"] += 1
        entry["total_ms"] += int(duration_ms)
        entry["last_ms"] = int(duration_ms)
        entry["min_ms"] = (
            int(duration_ms)
            if entry["min_ms"] is None
            else min(int(entry["min_ms"]), int(duration_ms))
        )
        entry["max_ms"] = (
            int(duration_ms)
            if entry["max_ms"] is None
            else max(int(entry["max_ms"]), int(duration_ms))
        )
        entry["updated_at"] = _utc_now_iso()


@contextmanager
def observe_duration(name: str, *, category: str, **tags: Any):
    started = time.perf_counter()
    try:
        yield
    except Exception:
        duration_ms = int((time.perf_counter() - started) * 1000)
        record_counter(name=f"{name}.count", category=category, outcome="error", **tags)
        record_timing(
            name=f"{name}.duration_ms",
            duration_ms=duration_ms,
            category=category,
            outcome="error",
            **tags,
        )
        raise
    else:
        duration_ms = int((time.perf_counter() - started) * 1000)
        record_counter(name=f"{name}.count", category=category, outcome="success", **tags)
        record_timing(
            name=f"{name}.duration_ms",
            duration_ms=duration_ms,
            category=category,
            outcome="success",
            **tags,
        )


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


def get_metrics(
    *,
    limit: int = 200,
    category: str | None = None,
    name_prefix: str | None = None,
) -> list[dict[str, Any]]:
    normalized_category = (category or "").strip().lower() or None
    normalized_prefix = (name_prefix or "").strip().lower() or None

    with _LOCK:
        items = [dict(item) for item in _METRICS.values()]

    filtered: list[dict[str, Any]] = []
    for item in items:
        if normalized_category and str(item.get("category") or "").lower() != normalized_category:
            continue
        if normalized_prefix and not str(item.get("name") or "").lower().startswith(
            normalized_prefix
        ):
            continue
        if item.get("type") == "timing":
            count = int(item.get("count") or 0)
            total_ms = int(item.get("total_ms") or 0)
            item["avg_ms"] = round(total_ms / count, 2) if count else 0
        filtered.append(item)

    filtered.sort(
        key=lambda item: (
            str(item.get("category") or ""),
            str(item.get("name") or ""),
            json.dumps(item.get("tags") or {}, sort_keys=True),
        )
    )
    return filtered[:limit]


def summarize_metrics(metrics: Iterable[dict[str, Any]]) -> dict[str, Any]:
    by_category: dict[str, int] = {}
    by_type: dict[str, int] = {}
    total = 0
    for item in metrics:
        category = str(item.get("category") or "unknown")
        metric_type = str(item.get("type") or "unknown")
        by_category[category] = by_category.get(category, 0) + 1
        by_type[metric_type] = by_type.get(metric_type, 0) + 1
        total += 1
    return {
        "by_category": dict(sorted(by_category.items())),
        "by_type": dict(sorted(by_type.items())),
        "total": total,
    }


def clear_events() -> None:
    with _LOCK:
        _EVENTS.clear()


def clear_metrics() -> None:
    with _LOCK:
        _METRICS.clear()
