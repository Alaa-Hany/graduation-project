from __future__ import annotations

from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

import main
from core.settings import Settings


def test_run_startup_checks_skips_schema_verification_when_flag_enabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    called = False

    def fake_verify(*args, **kwargs) -> None:
        nonlocal called
        called = True

    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(skip_schema_verify=True, auto_run_migrations=False),
    )
    monkeypatch.setattr(main, "verify_database_schema", fake_verify)

    main._run_startup_checks()

    assert called is False


def test_run_startup_checks_invokes_schema_verification_with_auto_upgrade_setting(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}

    def fake_verify(engine, logger, *, auto_upgrade: bool) -> None:
        captured["engine"] = engine
        captured["logger"] = logger
        captured["auto_upgrade"] = auto_upgrade

    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(skip_schema_verify=False, auto_run_migrations=True),
    )
    monkeypatch.setattr(main, "verify_database_schema", fake_verify)

    main._run_startup_checks()

    assert captured["engine"] is main.engine
    assert captured["logger"] is main.logger
    assert captured["auto_upgrade"] is True


def test_lifespan_runs_startup_checks_once_on_app_start(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []

    def fake_startup_checks() -> None:
        calls.append("startup")

    monkeypatch.setattr(main, "_run_startup_checks", fake_startup_checks)

    with TestClient(main.app):
        pass

    assert calls == ["startup"]


def test_cors_config_uses_explicit_allowed_origins_from_settings(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(
            allowed_origins=("https://app.example.com", "https://admin.example.com"),
            allowed_origin_regex=None,
            cors_allow_credentials=True,
            environment="production",
            is_production=True,
        ),
    )

    config = main._cors_config()

    assert config == {
        "allow_origins": ["https://app.example.com", "https://admin.example.com"],
        "allow_origin_regex": None,
        "allow_credentials": True,
    }


def test_cors_config_uses_localhost_regex_fallback_in_development(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(
            allowed_origins=(),
            allowed_origin_regex=None,
            cors_allow_credentials=True,
            environment="development",
            is_production=False,
        ),
    )

    config = main._cors_config()

    assert config["allow_origins"] == []
    assert config["allow_origin_regex"] == main._DEV_CORS_ORIGIN_REGEX
    assert config["allow_credentials"] is True


def test_cors_config_does_not_fallback_to_regex_in_production(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(
            allowed_origins=(),
            allowed_origin_regex=None,
            cors_allow_credentials=False,
            environment="production",
            is_production=True,
        ),
    )

    config = main._cors_config()

    assert config["allow_origins"] == []
    assert config["allow_origin_regex"] is None
    assert config["allow_credentials"] is False


def test_settings_from_env_parses_cors_and_runtime_flags(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("APP_LOG_LEVEL", "debug")
    monkeypatch.setenv("ALLOWED_ORIGINS", "https://app.example.com, https://admin.example.com")
    monkeypatch.setenv("ALLOWED_ORIGIN_REGEX", r"^https://preview-\d+\.example\.com$")
    monkeypatch.setenv("CORS_ALLOW_CREDENTIALS", "false")
    monkeypatch.setenv("KINDER_JWT_SECRET", "super-secret")
    monkeypatch.setenv("AUTO_RUN_MIGRATIONS", "true")
    monkeypatch.setenv("SKIP_SCHEMA_VERIFY", "true")

    settings = Settings.from_env()

    assert settings.environment == "production"
    assert settings.app_log_level == "DEBUG"
    assert settings.allowed_origins == (
        "https://app.example.com",
        "https://admin.example.com",
    )
    assert settings.allowed_origin_regex == r"^https://preview-\d+\.example\.com$"
    assert settings.cors_allow_credentials is False
    assert settings.auto_run_migrations is True
    assert settings.skip_schema_verify is True


def test_settings_rejects_invalid_allowed_origin(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("KINDER_JWT_SECRET", "super-secret")
    monkeypatch.setenv("ALLOWED_ORIGINS", "not-a-url")

    with pytest.raises(ValueError, match="Invalid origin"):
        Settings.from_env()


def test_settings_rejects_wildcard_with_credentials(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("KINDER_JWT_SECRET", "super-secret")
    monkeypatch.setenv("ALLOWED_ORIGINS", "*")
    monkeypatch.setenv("CORS_ALLOW_CREDENTIALS", "true")

    with pytest.raises(ValueError, match="wildcard origins cannot be used with credentials"):
        Settings.from_env()


def test_settings_allows_wildcard_without_credentials_in_dev(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("KINDER_JWT_SECRET", "super-secret")
    monkeypatch.setenv("ALLOWED_ORIGINS", "*")
    monkeypatch.setenv("CORS_ALLOW_CREDENTIALS", "false")

    settings = Settings.from_env()
    assert settings.allowed_origins == ("*",)
    assert settings.cors_allow_credentials is False


def test_settings_rejects_permissive_origin_regex_in_production(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("KINDER_JWT_SECRET", "super-secret")
    monkeypatch.setenv("ALLOWED_ORIGIN_REGEX", ".*")

    with pytest.raises(ValueError, match="too permissive"):
        Settings.from_env()


def _cors_behavior_client(
    monkeypatch: pytest.MonkeyPatch,
    *,
    environment: str,
    allowed_origins: tuple[str, ...] = (),
    allowed_origin_regex: str | None = None,
    allow_credentials: bool = True,
) -> TestClient:
    monkeypatch.setattr(
        main,
        "settings",
        SimpleNamespace(
            allowed_origins=allowed_origins,
            allowed_origin_regex=allowed_origin_regex,
            cors_allow_credentials=allow_credentials,
            environment=environment,
            is_production=environment == "production",
        ),
    )

    config = main._cors_config()
    app = FastAPI()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config["allow_origins"],
        allow_origin_regex=config["allow_origin_regex"],
        allow_credentials=bool(config["allow_credentials"]),
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "Accept",
            "X-Requested-With",
            "X-CSRF-Token",
            "X-Request-ID",
        ],
        expose_headers=["X-Request-ID"],
        max_age=86400,
    )

    @app.get("/probe")
    def probe() -> dict[str, bool]:
        return {"ok": True}

    return TestClient(app)


def test_dev_cors_allows_localhost_origin_with_credentials(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(monkeypatch, environment="development") as client:
        response = client.get(
            "/probe",
            headers={"Origin": "http://localhost:3000"},
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"
    assert response.headers["access-control-allow-credentials"] == "true"
    assert response.headers["vary"] == "Origin"


def test_dev_cors_allows_lan_origin_with_preflight(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(monkeypatch, environment="development") as client:
        response = client.options(
            "/probe",
            headers={
                "Origin": "http://192.168.1.50:5173",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "Authorization",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://192.168.1.50:5173"
    assert response.headers["access-control-allow-credentials"] == "true"
    assert "Authorization" in response.headers["access-control-allow-headers"]


def test_dev_cors_denies_non_local_origin_when_using_dev_fallback(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(monkeypatch, environment="development") as client:
        response = client.get(
            "/probe",
            headers={"Origin": "https://evil.example.com"},
        )

    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers
    # Starlette may still emit allow-credentials on simple responses, but the
    # browser blocks the response because no allow-origin header is present.
    assert response.headers["access-control-allow-credentials"] == "true"


def test_production_cors_allows_only_configured_exact_origins(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(
        monkeypatch,
        environment="production",
        allowed_origins=("https://app.example.com",),
        allow_credentials=True,
    ) as client:
        allowed = client.get("/probe", headers={"Origin": "https://app.example.com"})
        denied = client.get("/probe", headers={"Origin": "https://admin.example.com"})

    assert allowed.headers["access-control-allow-origin"] == "https://app.example.com"
    assert allowed.headers["access-control-allow-credentials"] == "true"
    assert "access-control-allow-origin" not in denied.headers


def test_production_cors_supports_regex_origins(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(
        monkeypatch,
        environment="production",
        allowed_origin_regex=r"^https://preview-\d+\.example\.com$",
        allow_credentials=True,
    ) as client:
        allowed = client.get("/probe", headers={"Origin": "https://preview-42.example.com"})
        denied = client.get("/probe", headers={"Origin": "https://preview-admin.example.com"})

    assert allowed.headers["access-control-allow-origin"] == "https://preview-42.example.com"
    assert allowed.headers["access-control-allow-credentials"] == "true"
    assert "access-control-allow-origin" not in denied.headers


def test_cors_omits_credentials_header_when_disabled(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(
        monkeypatch,
        environment="production",
        allowed_origins=("https://app.example.com",),
        allow_credentials=False,
    ) as client:
        response = client.get(
            "/probe",
            headers={"Origin": "https://app.example.com"},
        )

    assert response.headers["access-control-allow-origin"] == "https://app.example.com"
    assert "access-control-allow-credentials" not in response.headers


def test_production_without_configured_origins_denies_cross_origin_browser_access(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with _cors_behavior_client(
        monkeypatch,
        environment="production",
        allow_credentials=True,
    ) as client:
        response = client.options(
            "/probe",
            headers={
                "Origin": "https://app.example.com",
                "Access-Control-Request-Method": "GET",
            },
        )

    assert response.status_code == 400
    assert "access-control-allow-origin" not in response.headers
