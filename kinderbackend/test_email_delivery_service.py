"""Tests for services.email_delivery_service.

Covers Brevo (HTTPS) and SMTP delivery branches plus their configuration
guards. All network/SMTP I/O is mocked.

Note: the project conftest installs an autouse ``stub_email_delivery`` fixture
that replaces the *singleton's* ``send_email``. These tests instantiate fresh
``EmailDeliveryService`` objects (after setting env), so they exercise the real
methods rather than the stub.
"""

from types import SimpleNamespace

import pytest

import services.email_delivery_service as email_module
from services.email_delivery_service import EmailDeliveryService


def _clear_email_env(monkeypatch):
    for key in (
        "BREVO_API_KEY",
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_USERNAME",
        "SMTP_PASSWORD",
        "SMTP_FROM_EMAIL",
        "SMTP_FROM_NAME",
        "SMTP_USE_SSL",
        "SMTP_USE_TLS",
        "EMAIL_TIMEOUT_SECONDS",
    ):
        monkeypatch.delenv(key, raising=False)


# ---------------------------------------------------------------------------
# Construction / defaults
# ---------------------------------------------------------------------------


def test_defaults_when_env_absent(monkeypatch):
    _clear_email_env(monkeypatch)
    service = EmailDeliveryService()
    assert service.host == "smtp.gmail.com"
    assert service.port == 465
    assert service.use_ssl is True
    assert service.use_tls is False
    assert service.from_name == "Kinder World"
    assert service.timeout == 10.0


# ---------------------------------------------------------------------------
# send_email routing
# ---------------------------------------------------------------------------


def test_send_email_routes_to_brevo_when_key_present(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("BREVO_API_KEY", "brevo-key")
    service = EmailDeliveryService()

    calls = {}
    monkeypatch.setattr(
        service, "_send_via_brevo", lambda **kwargs: calls.setdefault("brevo", kwargs)
    )
    monkeypatch.setattr(
        service, "_send_via_smtp", lambda **kwargs: calls.setdefault("smtp", kwargs)
    )

    service.send_email(to_email="a@b.com", subject="Hi", body="Body")
    assert "brevo" in calls
    assert "smtp" not in calls


def test_send_email_routes_to_smtp_when_no_key(monkeypatch):
    _clear_email_env(monkeypatch)
    service = EmailDeliveryService()

    calls = {}
    monkeypatch.setattr(
        service, "_send_via_brevo", lambda **kwargs: calls.setdefault("brevo", kwargs)
    )
    monkeypatch.setattr(
        service, "_send_via_smtp", lambda **kwargs: calls.setdefault("smtp", kwargs)
    )

    service.send_email(to_email="a@b.com", subject="Hi", body="Body")
    assert "smtp" in calls
    assert "brevo" not in calls


# ---------------------------------------------------------------------------
# Brevo branch
# ---------------------------------------------------------------------------


def test_send_via_brevo_posts_expected_payload(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("BREVO_API_KEY", "brevo-key")
    monkeypatch.setenv("SMTP_FROM_EMAIL", "sender@kinder.world")
    service = EmailDeliveryService()

    captured = {}

    def fake_post(url, json, headers, timeout):
        captured["url"] = url
        captured["json"] = json
        captured["headers"] = headers
        return SimpleNamespace(status_code=201, text="ok")

    monkeypatch.setattr(email_module.httpx, "post", fake_post)

    service.send_email(
        to_email="kid@home.com", subject="Welcome", body="Plain", html_body="<b>HTML</b>"
    )

    assert captured["url"] == email_module.BREVO_API_URL
    assert captured["json"]["sender"]["email"] == "sender@kinder.world"
    assert captured["json"]["to"] == [{"email": "kid@home.com"}]
    assert captured["json"]["subject"] == "Welcome"
    assert captured["json"]["textContent"] == "Plain"
    assert captured["json"]["htmlContent"] == "<b>HTML</b>"
    assert captured["headers"]["api-key"] == "brevo-key"


def test_send_via_brevo_without_html_omits_html_content(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("BREVO_API_KEY", "brevo-key")
    monkeypatch.setenv("SMTP_FROM_EMAIL", "sender@kinder.world")
    service = EmailDeliveryService()

    captured = {}
    monkeypatch.setattr(
        email_module.httpx,
        "post",
        lambda url, json, headers, timeout: captured.update(json=json)
        or SimpleNamespace(status_code=200, text="ok"),
    )

    service.send_email(to_email="kid@home.com", subject="S", body="B")
    assert "htmlContent" not in captured["json"]


def test_send_via_brevo_missing_sender_raises(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("BREVO_API_KEY", "brevo-key")
    service = EmailDeliveryService()
    service.from_email = ""  # simulate unverified/blank sender
    with pytest.raises(RuntimeError, match="Brevo sender is not configured"):
        service.send_email(to_email="kid@home.com", subject="S", body="B")


def test_send_via_brevo_http_error_raises(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("BREVO_API_KEY", "brevo-key")
    monkeypatch.setenv("SMTP_FROM_EMAIL", "sender@kinder.world")
    service = EmailDeliveryService()

    monkeypatch.setattr(
        email_module.httpx,
        "post",
        lambda *a, **k: SimpleNamespace(status_code=400, text="bad request"),
    )
    with pytest.raises(RuntimeError, match="Brevo API rejected"):
        service.send_email(to_email="kid@home.com", subject="S", body="B")


# ---------------------------------------------------------------------------
# SMTP branch
# ---------------------------------------------------------------------------


def test_send_via_smtp_missing_credentials_raises(monkeypatch):
    _clear_email_env(monkeypatch)
    service = EmailDeliveryService()  # no username/password
    with pytest.raises(RuntimeError, match="SMTP credentials are not configured"):
        service.send_email(to_email="kid@home.com", subject="S", body="B")


class _FakeSMTP:
    instances = []

    def __init__(self, host, port, timeout):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.started_tls = False
        self.logged_in = None
        self.sent_message = None
        _FakeSMTP.instances.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def starttls(self):
        self.started_tls = True

    def login(self, username, password):
        self.logged_in = (username, password)

    def send_message(self, message):
        self.sent_message = message


def test_send_via_smtp_ssl(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("SMTP_USERNAME", "user@gmail.com")
    monkeypatch.setenv("SMTP_PASSWORD", "app-pass")
    service = EmailDeliveryService()  # use_ssl defaults to true

    _FakeSMTP.instances.clear()
    monkeypatch.setattr(email_module.smtplib, "SMTP_SSL", _FakeSMTP)

    service.send_email(to_email="kid@home.com", subject="Hi", body="Body", html_body="<i>x</i>")

    sent = _FakeSMTP.instances[-1]
    assert sent.logged_in == ("user@gmail.com", "app-pass")
    assert sent.sent_message["To"] == "kid@home.com"
    assert sent.sent_message["Subject"] == "Hi"


def test_send_via_smtp_starttls(monkeypatch):
    _clear_email_env(monkeypatch)
    monkeypatch.setenv("SMTP_USERNAME", "user@gmail.com")
    monkeypatch.setenv("SMTP_PASSWORD", "app-pass")
    monkeypatch.setenv("SMTP_USE_SSL", "false")
    monkeypatch.setenv("SMTP_USE_TLS", "true")
    service = EmailDeliveryService()

    _FakeSMTP.instances.clear()
    monkeypatch.setattr(email_module.smtplib, "SMTP", _FakeSMTP)

    service.send_email(to_email="kid@home.com", subject="Hi", body="Body")

    sent = _FakeSMTP.instances[-1]
    assert sent.started_tls is True
    assert sent.logged_in == ("user@gmail.com", "app-pass")
