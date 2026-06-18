from __future__ import annotations

from types import SimpleNamespace

import pytest

from routers import admin_analytics


class _FakeCacheService:
    def __init__(self) -> None:
        self.values: dict[str, object] = {}
        self.set_calls: list[tuple[str, int]] = []

    def get_json(self, key: str):
        return self.values.get(key)

    def set_json(self, key: str, value, *, ttl_seconds: int) -> None:
        self.values[key] = value
        self.set_calls.append((key, ttl_seconds))


def test_admin_analytics_overview_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_cache = _FakeCacheService()
    calls = {"count": 0}

    def fake_build(*, db):
        calls["count"] += 1
        return {"kpis": {"total_users": 7}}

    monkeypatch.setattr(admin_analytics, "cache_service", fake_cache)
    monkeypatch.setattr(
        admin_analytics,
        "settings",
        SimpleNamespace(admin_analytics_cache_ttl_seconds=45),
    )
    monkeypatch.setattr(admin_analytics, "_build_analytics_overview_payload", fake_build)

    first = admin_analytics.get_analytics_overview(db=object(), admin=object())
    second = admin_analytics.get_analytics_overview(db=object(), admin=object())

    assert first == {"kpis": {"total_users": 7}}
    assert second == first
    assert calls["count"] == 1
    assert fake_cache.set_calls[0][1] == 45


def test_admin_analytics_usage_uses_range_specific_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    fake_cache = _FakeCacheService()
    calls: list[str] = []

    def fake_build(*, db, range_name: str):
        calls.append(range_name)
        return {"range": range_name, "points": []}

    monkeypatch.setattr(admin_analytics, "cache_service", fake_cache)
    monkeypatch.setattr(
        admin_analytics,
        "settings",
        SimpleNamespace(admin_analytics_cache_ttl_seconds=20),
    )
    monkeypatch.setattr(admin_analytics, "_build_analytics_usage_payload", fake_build)

    week_first = admin_analytics.get_analytics_usage(range_name="week", db=object(), admin=object())
    week_second = admin_analytics.get_analytics_usage(
        range_name="week", db=object(), admin=object()
    )
    month_value = admin_analytics.get_analytics_usage(
        range_name="month", db=object(), admin=object()
    )

    assert week_first == {"range": "week", "points": []}
    assert week_second == week_first
    assert month_value == {"range": "month", "points": []}
    assert calls == ["week", "month"]
