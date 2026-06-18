from __future__ import annotations

from types import SimpleNamespace

import pytest

from core import cache_service as cache_module


class _FakeRedisClient:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}
        self.expirations: dict[str, int] = {}
        self.ping_calls = 0

    def ping(self) -> None:
        self.ping_calls += 1

    def get(self, key: str) -> str | None:
        return self.values.get(key)

    def setex(self, key: str, ttl_seconds: int, value: str) -> None:
        self.values[key] = value
        self.expirations[key] = ttl_seconds

    def delete(self, key: str) -> None:
        self.values.pop(key, None)
        self.expirations.pop(key, None)


class _FakeRedisFactory:
    def __init__(self, client: _FakeRedisClient) -> None:
        self.client = client
        self.urls: list[str] = []

    def from_url(self, url: str, decode_responses: bool = True) -> _FakeRedisClient:
        self.urls.append(url)
        assert decode_responses is True
        return self.client


def test_cache_service_round_trips_json(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _FakeRedisClient()
    factory = _FakeRedisFactory(client)
    service = cache_module.CacheService()

    monkeypatch.setattr(
        cache_module,
        "settings",
        SimpleNamespace(cache_enabled=True, redis_url="redis://cache.example/0"),
    )
    monkeypatch.setattr(cache_module, "redis", SimpleNamespace(Redis=factory))

    service.set_json("analytics:key", {"a": 1, "items": [1, 2]}, ttl_seconds=25)

    assert factory.urls == ["redis://cache.example/0"]
    assert client.expirations["analytics:key"] == 25
    assert service.get_json("analytics:key") == {"a": 1, "items": [1, 2]}


def test_cache_service_returns_none_when_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    service = cache_module.CacheService()

    monkeypatch.setattr(
        cache_module,
        "settings",
        SimpleNamespace(cache_enabled=False, redis_url=None),
    )

    assert service.get_json("disabled:key") is None
