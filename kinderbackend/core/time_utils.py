from __future__ import annotations

from datetime import date, datetime, time, timezone

UTC = timezone.utc


def utc_now() -> datetime:
    return datetime.now(UTC)


def ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def db_utc_now() -> datetime:
    return utc_now()


def to_db_utc(value: datetime) -> datetime:
    return ensure_utc(value)


def utc_today() -> date:
    return utc_now().date()


def utc_start_of_day(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=UTC)


def utc_end_of_day(day: date) -> datetime:
    return datetime.combine(day, time.max, tzinfo=UTC)
