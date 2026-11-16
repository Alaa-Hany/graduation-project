"""Security tests for rate_limit._client_ip (audit finding #3: IP spoofing)."""

from __future__ import annotations

import pytest
from starlette.requests import Request

from core.settings import settings
from rate_limit import _client_ip


def _request(headers: dict[str, str] | None = None, peer: str = "10.0.0.5") -> Request:
    raw_headers = [(k.lower().encode(), v.encode()) for k, v in (headers or {}).items()]
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": raw_headers,
        "client": (peer, 12345),
    }
    return Request(scope)


@pytest.fixture
def trust_cf(request):
    original = settings.trust_cf_connecting_ip
    object.__setattr__(settings, "trust_cf_connecting_ip", request.param)
    yield
    object.__setattr__(settings, "trust_cf_connecting_ip", original)


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
def test_uses_cf_connecting_ip_when_trusted(trust_cf):
    req = _request({"CF-Connecting-IP": "203.0.113.9", "X-Forwarded-For": "1.1.1.1"})
    assert _client_ip(req) == "203.0.113.9"


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
def test_ignores_x_forwarded_for_spoof(trust_cf):
    # The attacker controls X-Forwarded-For but not CF-Connecting-IP.
    req = _request({"X-Forwarded-For": "6.6.6.6"}, peer="10.0.0.5")
    assert _client_ip(req) == "10.0.0.5"


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
@pytest.mark.parametrize("bad", ["not-an-ip", "1.2.3.4, 5.6.7.8", "999.1.1.1", "<script>"])
def test_malformed_cf_header_falls_back_to_peer(trust_cf, bad):
    req = _request({"CF-Connecting-IP": bad}, peer="10.0.0.7")
    assert _client_ip(req) == "10.0.0.7"


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
def test_ipv6_cf_header_is_normalised(trust_cf):
    req = _request({"CF-Connecting-IP": "2001:DB8::1"})
    assert _client_ip(req) == "2001:db8::1"


@pytest.mark.parametrize("trust_cf", [False], indirect=True)
def test_cf_header_ignored_when_not_trusted(trust_cf):
    # Without Cloudflare in front, anyone could send this header.
    req = _request({"CF-Connecting-IP": "203.0.113.9"}, peer="10.0.0.5")
    assert _client_ip(req) == "10.0.0.5"


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
def test_missing_client_returns_unknown(trust_cf):
    scope = {"type": "http", "method": "GET", "path": "/", "headers": [], "client": None}
    assert _client_ip(Request(scope)) == "unknown"


@pytest.mark.parametrize("trust_cf", [True], indirect=True)
def test_rate_limit_buckets_follow_cf_ip(client, trust_cf):
    """Spoofing X-Forwarded-For must not give a fresh rate-limit bucket."""
    statuses = []
    for i in range(7):
        r = client.post(
            "/api/v1/auth/login",
            json={"email": "nobody@example.com", "password": "wrong-password"},
            headers={"CF-Connecting-IP": "198.51.100.20", "X-Forwarded-For": f"9.9.9.{i}"},
        )
        statuses.append(r.status_code)
    assert 429 in statuses

    # A genuinely different client (different CF IP) is not blocked.
    other = client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "wrong-password"},
        headers={"CF-Connecting-IP": "198.51.100.21"},
    )
    assert other.status_code != 429
