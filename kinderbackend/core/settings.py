from __future__ import annotations

import os
import re
from dataclasses import dataclass
from urllib.parse import urlparse

from dotenv import load_dotenv

load_dotenv()


def _as_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _as_list(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def _normalize_origin(origin: str) -> str:
    normalized = origin.strip()
    if not normalized:
        raise ValueError("ALLOWED_ORIGINS contains an empty value.")
    if normalized == "*":
        return normalized
    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"Invalid origin '{origin}'. Expected absolute http(s) URL.")
    if parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        raise ValueError(f"Origin '{origin}' must not include path, query, or fragment.")
    host = parsed.hostname or ""
    if not host:
        raise ValueError(f"Origin '{origin}' is missing a hostname.")
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme.lower()}://{host.lower()}{port}"


def _parse_allowed_origins(raw: str | None) -> tuple[str, ...]:
    origins: list[str] = []
    seen: set[str] = set()
    for item in _as_list(raw):
        normalized = _normalize_origin(item)
        if normalized in seen:
            continue
        seen.add(normalized)
        origins.append(normalized)
    return tuple(origins)


def _validate_origin_regex(value: str | None) -> str | None:
    if not value:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    try:
        re.compile(normalized)
    except re.error as exc:
        raise ValueError(f"ALLOWED_ORIGIN_REGEX is invalid: {exc}") from exc
    return normalized


def _as_int(value: str | None, default: int) -> int:
    if value is None:
        return default
    try:
        return int(value.strip())
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class Settings:
    environment: str
    app_log_level: str
    allowed_origins: tuple[str, ...]
    allowed_origin_regex: str | None
    cors_allow_credentials: bool
    jwt_algorithm: str
    jwt_active_secret: str
    jwt_previous_secrets: tuple[str, ...]
    jwt_active_kid: str | None
    app_log_file: str | None
    skip_schema_verify: bool
    auto_run_migrations: bool
    admin_auth_max_failed_attempts: int
    admin_auth_lockout_minutes: int
    admin_suspicious_failed_threshold: int
    admin_sensitive_confirmation_required: bool
    payment_provider: str
    stripe_secret_key: str | None
    stripe_publishable_key: str | None
    stripe_webhook_secret: str | None
    stripe_checkout_success_url: str | None
    stripe_checkout_cancel_url: str | None
    stripe_portal_return_url: str | None
    stripe_price_premium_monthly: str | None
    stripe_price_family_plus_monthly: str | None
    payment_reconciliation_enabled: bool
    payment_reconciliation_schedule: str | None
    ai_provider_mode: str
    ai_provider_api_key: str | None

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @classmethod
    def from_env(cls) -> "Settings":
        environment = os.getenv("ENVIRONMENT", "development").strip().lower()
        app_log_level = (os.getenv("APP_LOG_LEVEL") or "INFO").strip().upper()
        allowed_origins = _parse_allowed_origins(os.getenv("ALLOWED_ORIGINS"))
        allowed_origin_regex = _validate_origin_regex(os.getenv("ALLOWED_ORIGIN_REGEX"))
        cors_allow_credentials = _as_bool(
            os.getenv("CORS_ALLOW_CREDENTIALS"),
            default=True,
        )
        jwt_algorithm = os.getenv("JWT_ALGORITHM", "HS256").strip() or "HS256"
        jwt_active_secret = (
            os.getenv("KINDER_JWT_SECRET")
            or os.getenv("JWT_SECRET_KEY")
            or os.getenv("SECRET_KEY")
            or ""
        ).strip()
        previous = tuple(
            secret
            for secret in _as_list(os.getenv("JWT_PREVIOUS_SECRETS"))
            if secret and secret != jwt_active_secret
        )
        jwt_active_kid = (os.getenv("JWT_ACTIVE_KID") or "").strip() or None
        app_log_file = (os.getenv("APP_LOG_FILE") or "").strip() or None
        skip_schema_verify = _as_bool(os.getenv("SKIP_SCHEMA_VERIFY"), default=False)
        auto_run_migrations = _as_bool(os.getenv("AUTO_RUN_MIGRATIONS"), default=False)
        admin_auth_max_failed_attempts = max(
            _as_int(os.getenv("ADMIN_AUTH_MAX_FAILED_ATTEMPTS"), 5),
            1,
        )
        admin_auth_lockout_minutes = max(
            _as_int(os.getenv("ADMIN_AUTH_LOCKOUT_MINUTES"), 15),
            1,
        )
        admin_suspicious_failed_threshold = max(
            _as_int(os.getenv("ADMIN_SUSPICIOUS_FAILED_THRESHOLD"), 3),
            1,
        )
        admin_sensitive_confirmation_required = _as_bool(
            os.getenv("ADMIN_SENSITIVE_CONFIRMATION_REQUIRED"),
            default=False,
        )
        payment_provider = (os.getenv("PAYMENT_PROVIDER") or "internal").strip().lower()
        stripe_secret_key = (os.getenv("STRIPE_SECRET_KEY") or "").strip() or None
        stripe_publishable_key = (os.getenv("STRIPE_PUBLISHABLE_KEY") or "").strip() or None
        stripe_webhook_secret = (os.getenv("STRIPE_WEBHOOK_SECRET") or "").strip() or None
        stripe_checkout_success_url = (
            (os.getenv("STRIPE_CHECKOUT_SUCCESS_URL") or "").strip() or None
        )
        stripe_checkout_cancel_url = (
            (os.getenv("STRIPE_CHECKOUT_CANCEL_URL") or "").strip() or None
        )
        stripe_portal_return_url = (
            (os.getenv("STRIPE_PORTAL_RETURN_URL") or "").strip() or None
        )
        stripe_price_premium_monthly = (
            (os.getenv("STRIPE_PRICE_PREMIUM_MONTHLY") or "").strip() or None
        )
        stripe_price_family_plus_monthly = (
            (os.getenv("STRIPE_PRICE_FAMILY_PLUS_MONTHLY") or "").strip() or None
        )
        payment_reconciliation_enabled = _as_bool(
            os.getenv("PAYMENT_RECONCILIATION_ENABLED"),
            default=False,
        )
        payment_reconciliation_schedule = (
            (os.getenv("PAYMENT_RECONCILIATION_SCHEDULE") or "").strip() or None
        )
        ai_provider_mode = (os.getenv("AI_PROVIDER_MODE") or "fallback").strip().lower()
        ai_provider_api_key = (os.getenv("AI_PROVIDER_API_KEY") or "").strip() or None

        if not jwt_active_secret:
            raise ValueError(
                "JWT secret not configured. Set KINDER_JWT_SECRET "
                "(preferred) or JWT_SECRET_KEY/SECRET_KEY for compatibility."
            )
        if environment == "production" and jwt_active_secret in {
            "CHANGE_ME",
            "DEV_ONLY_SECRET",
            "TEST_ONLY_SECRET",
        }:
            raise ValueError("Production JWT secret is insecure. Use a strong random value.")
        if payment_provider not in {"internal", "stripe"}:
            raise ValueError("PAYMENT_PROVIDER must be either 'internal' or 'stripe'")
        if environment == "production" and payment_provider != "stripe":
            raise ValueError("PAYMENT_PROVIDER must be 'stripe' in production.")
        if payment_provider == "stripe":
            missing = [
                name
                for name, value in {
                    "STRIPE_SECRET_KEY": stripe_secret_key,
                    "STRIPE_WEBHOOK_SECRET": stripe_webhook_secret,
                    "STRIPE_CHECKOUT_SUCCESS_URL": stripe_checkout_success_url,
                    "STRIPE_CHECKOUT_CANCEL_URL": stripe_checkout_cancel_url,
                    "STRIPE_PORTAL_RETURN_URL": stripe_portal_return_url,
                    "STRIPE_PRICE_PREMIUM_MONTHLY": stripe_price_premium_monthly,
                    "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": stripe_price_family_plus_monthly,
                }.items()
                if not value
            ]
            if missing:
                raise ValueError(
                    "Stripe payment provider is enabled but required settings are missing: "
                    + ", ".join(missing)
                )
            if stripe_secret_key and not stripe_secret_key.startswith("sk_"):
                raise ValueError("STRIPE_SECRET_KEY is invalid (expected 'sk_...').")
            if stripe_publishable_key and not stripe_publishable_key.startswith("pk_"):
                raise ValueError("STRIPE_PUBLISHABLE_KEY is invalid (expected 'pk_...').")
            if stripe_webhook_secret and not stripe_webhook_secret.startswith("whsec_"):
                raise ValueError("STRIPE_WEBHOOK_SECRET is invalid (expected 'whsec_...').")
            for name, value in {
                "STRIPE_CHECKOUT_SUCCESS_URL": stripe_checkout_success_url,
                "STRIPE_CHECKOUT_CANCEL_URL": stripe_checkout_cancel_url,
                "STRIPE_PORTAL_RETURN_URL": stripe_portal_return_url,
            }.items():
                if value:
                    parsed = urlparse(value)
                    if not parsed.scheme or not parsed.netloc:
                        raise ValueError(f"{name} must be a valid absolute URL.")
                    if environment == "production" and parsed.scheme != "https":
                        raise ValueError(f"{name} must use https in production.")
            for name, value in {
                "STRIPE_PRICE_PREMIUM_MONTHLY": stripe_price_premium_monthly,
                "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": stripe_price_family_plus_monthly,
            }.items():
                if value and not value.startswith("price_"):
                    raise ValueError(f"{name} is invalid (expected 'price_...').")

        if environment == "production" and not allowed_origins and not allowed_origin_regex:
            raise ValueError(
                "CORS is not configured for production. Set ALLOWED_ORIGINS or ALLOWED_ORIGIN_REGEX."
            )
        if "*" in allowed_origins:
            if cors_allow_credentials:
                raise ValueError("CORS wildcard origins cannot be used with credentials.")
            if environment == "production":
                raise ValueError("CORS wildcard origins are not allowed in production.")
        if environment == "production" and allowed_origin_regex in {"*", ".*", "^.*$", "^.*"}:
            raise ValueError(
                "ALLOWED_ORIGIN_REGEX is too permissive for production."
            )

        if payment_reconciliation_enabled and not payment_reconciliation_schedule:
            raise ValueError(
                "PAYMENT_RECONCILIATION_ENABLED is true but PAYMENT_RECONCILIATION_SCHEDULE is missing."
            )

        if ai_provider_mode not in {"fallback", "external", "openai"}:
            raise ValueError(
                "AI_PROVIDER_MODE must be one of: fallback, external, openai."
            )
        if ai_provider_mode != "fallback" and not ai_provider_api_key:
            raise ValueError(
                "AI_PROVIDER_API_KEY is required when AI_PROVIDER_MODE is not 'fallback'."
            )

        return cls(
            environment=environment,
            app_log_level=app_log_level,
            allowed_origins=allowed_origins,
            allowed_origin_regex=allowed_origin_regex,
            cors_allow_credentials=cors_allow_credentials,
            jwt_algorithm=jwt_algorithm,
            jwt_active_secret=jwt_active_secret,
            jwt_previous_secrets=previous,
            jwt_active_kid=jwt_active_kid,
            app_log_file=app_log_file,
            skip_schema_verify=skip_schema_verify,
            auto_run_migrations=auto_run_migrations,
            admin_auth_max_failed_attempts=admin_auth_max_failed_attempts,
            admin_auth_lockout_minutes=admin_auth_lockout_minutes,
            admin_suspicious_failed_threshold=admin_suspicious_failed_threshold,
            admin_sensitive_confirmation_required=admin_sensitive_confirmation_required,
            payment_provider=payment_provider,
            stripe_secret_key=stripe_secret_key,
            stripe_publishable_key=stripe_publishable_key,
            stripe_webhook_secret=stripe_webhook_secret,
            stripe_checkout_success_url=stripe_checkout_success_url,
            stripe_checkout_cancel_url=stripe_checkout_cancel_url,
            stripe_portal_return_url=stripe_portal_return_url,
            stripe_price_premium_monthly=stripe_price_premium_monthly,
            stripe_price_family_plus_monthly=stripe_price_family_plus_monthly,
            payment_reconciliation_enabled=payment_reconciliation_enabled,
            payment_reconciliation_schedule=payment_reconciliation_schedule,
            ai_provider_mode=ai_provider_mode,
            ai_provider_api_key=ai_provider_api_key,
        )


settings = Settings.from_env()
