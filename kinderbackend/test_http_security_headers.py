from __future__ import annotations

from types import SimpleNamespace

import main


def test_api_responses_include_security_headers(client) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["permissions-policy"] == (
        "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
        "magnetometer=(), microphone=(), payment=(), usb=()"
    )
    assert response.headers["content-security-policy"] == (
        "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
    )
    assert "strict-transport-security" not in response.headers


def test_docs_html_skips_api_csp_but_keeps_other_headers(client) -> None:
    response = client.get("/docs")

    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert "content-security-policy" not in response.headers


def test_production_https_requests_receive_hsts(client, monkeypatch) -> None:
    original_settings = main.settings
    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(is_production=True),
    )
    try:
        response = client.get("/", headers={"X-Forwarded-Proto": "https"})
    finally:
        monkeypatch.setattr(main, "settings", original_settings)

    assert response.status_code == 200
    assert response.headers["strict-transport-security"] == ("max-age=63072000; includeSubDomains")
