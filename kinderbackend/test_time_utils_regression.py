from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone

from core.time_utils import db_utc_now, ensure_utc, to_db_utc, utc_now


def test_utc_now_returns_timezone_aware_utc_datetime() -> None:
    value = utc_now()

    assert value.tzinfo == UTC
    assert value.utcoffset() == timedelta(0)


def test_ensure_utc_attaches_utc_to_legacy_naive_datetime() -> None:
    naive = datetime(2026, 3, 15, 12, 30, 0)

    normalized = ensure_utc(naive)

    assert normalized == datetime(2026, 3, 15, 12, 30, 0, tzinfo=UTC)
    assert normalized.tzinfo == UTC


def test_ensure_utc_converts_aware_datetime_to_utc() -> None:
    aware = datetime(2026, 3, 15, 15, 30, 0, tzinfo=timezone(timedelta(hours=3)))

    normalized = ensure_utc(aware)

    assert normalized == datetime(2026, 3, 15, 12, 30, 0, tzinfo=UTC)
    assert normalized.tzinfo == UTC


def test_db_utc_now_returns_timezone_aware_value_after_migration() -> None:
    value = db_utc_now()

    assert value.tzinfo == UTC
    assert value.utcoffset() == timedelta(0)


def test_to_db_utc_preserves_naive_utc_semantics_for_legacy_values() -> None:
    naive = datetime(2026, 3, 15, 12, 30, 0)

    normalized = to_db_utc(naive)

    assert normalized == datetime(2026, 3, 15, 12, 30, 0, tzinfo=UTC)
    assert normalized.tzinfo == UTC


def test_to_db_utc_preserves_absolute_time_for_offset_values() -> None:
    aware = datetime(2026, 3, 15, 14, 30, 0, tzinfo=timezone(timedelta(hours=2)))

    normalized = to_db_utc(aware)

    assert normalized == datetime(2026, 3, 15, 12, 30, 0, tzinfo=UTC)
    assert normalized.tzinfo == UTC
