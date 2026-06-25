from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")


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


def _as_float(value: str | None, default: float) -> float:
    if value is None:
        return default
    try:
        return float(value.strip())
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
    data_encryption_key: str | None
    data_encryption_previous_keys: tuple[str, ...]
    app_log_file: str | None
    skip_schema_verify: bool
    auto_run_migrations: bool
    cache_enabled: bool
    redis_url: str | None
    admin_analytics_cache_ttl_seconds: int
    admin_auth_max_failed_attempts: int
    admin_auth_lockout_minutes: int
    admin_suspicious_failed_threshold: int
    admin_sensitive_confirmation_required: bool
    enforce_admin_2fa: bool
    cloudinary_cloud_name: str | None
    cloudinary_api_key: str | None
    cloudinary_api_secret: str | None
    cloudinary_media_root_folder: str
    media_max_upload_size_mb: int
    payment_provider: str
    stripe_secret_key: str | None
    stripe_publishable_key: str | None
    stripe_webhook_secret: str | None
    stripe_checkout_success_url: str | None
    stripe_checkout_cancel_url: str | None
    stripe_portal_return_url: str | None
    stripe_price_premium_monthly: str | None
    stripe_price_family_plus_monthly: str | None
    stripe_price_premium_yearly: str | None
    stripe_price_family_plus_yearly: str | None
    payment_reconciliation_enabled: bool
    payment_reconciliation_schedule: str | None
    ai_provider_mode: str
    ai_provider_api_key: str | None
    ai_model: str
    ai_max_tokens: int
    ai_temperature: float
    ai_frequency_penalty: float
    ai_presence_penalty: float
    tts_model: str
    tts_voice_ar: str
    tts_voice_en: str
    sentry_dsn: str | None
    youtube_api_key: str | None

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
        data_encryption_key = (os.getenv("DATA_ENCRYPTION_KEY") or "").strip() or None
        data_encryption_previous_keys = tuple(
            secret
            for secret in _as_list(os.getenv("DATA_ENCRYPTION_PREVIOUS_KEYS"))
            if secret and secret != data_encryption_key
        )
        app_log_file = (os.getenv("APP_LOG_FILE") or "").strip() or None
        skip_schema_verify = _as_bool(os.getenv("SKIP_SCHEMA_VERIFY"), default=False)
        auto_run_migrations = _as_bool(os.getenv("AUTO_RUN_MIGRATIONS"), default=False)
        cache_enabled = _as_bool(os.getenv("CACHE_ENABLED"), default=False)
        redis_url = (os.getenv("REDIS_URL") or "").strip() or None
        admin_analytics_cache_ttl_seconds = max(
            _as_int(os.getenv("ADMIN_ANALYTICS_CACHE_TTL_SECONDS"), 30),
            1,
        )
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
        enforce_admin_2fa = _as_bool(
            os.getenv("ENFORCE_ADMIN_2FA"),
            default=False,
        )
        cloudinary_cloud_name = (os.getenv("CLOUDINARY_CLOUD_NAME") or "").strip() or None
        cloudinary_api_key = (os.getenv("CLOUDINARY_API_KEY") or "").strip() or None
        cloudinary_api_secret = (os.getenv("CLOUDINARY_API_SECRET") or "").strip() or None
        cloudinary_media_root_folder = (
            os.getenv("CLOUDINARY_MEDIA_ROOT_FOLDER") or "kinderworld"
        ).strip() or "kinderworld"
        media_max_upload_size_mb = max(
            _as_int(os.getenv("MEDIA_MAX_UPLOAD_SIZE_MB"), 200),
            1,
        )
        payment_provider = (os.getenv("PAYMENT_PROVIDER") or "internal").strip().lower()
        stripe_secret_key = (os.getenv("STRIPE_SECRET_KEY") or "").strip() or None
        stripe_publishable_key = (os.getenv("STRIPE_PUBLISHABLE_KEY") or "").strip() or None
        stripe_webhook_secret = (os.getenv("STRIPE_WEBHOOK_SECRET") or "").strip() or None
        stripe_checkout_success_url = (
            os.getenv("STRIPE_CHECKOUT_SUCCESS_URL") or ""
        ).strip() or None
        stripe_checkout_cancel_url = (os.getenv("STRIPE_CHECKOUT_CANCEL_URL") or "").strip() or None
        stripe_portal_return_url = (os.getenv("STRIPE_PORTAL_RETURN_URL") or "").strip() or None
        stripe_price_premium_monthly = (
            os.getenv("STRIPE_PRICE_PREMIUM_MONTHLY") or ""
        ).strip() or None
        stripe_price_family_plus_monthly = (
            os.getenv("STRIPE_PRICE_FAMILY_PLUS_MONTHLY") or ""
        ).strip() or None
        stripe_price_premium_yearly = (
            os.getenv("STRIPE_PRICE_PREMIUM_YEARLY") or ""
        ).strip() or None
        stripe_price_family_plus_yearly = (
            os.getenv("STRIPE_PRICE_FAMILY_PLUS_YEARLY") or ""
        ).strip() or None
        payment_reconciliation_enabled = _as_bool(
            os.getenv("PAYMENT_RECONCILIATION_ENABLED"),
            default=False,
        )
        payment_reconciliation_schedule = (
            os.getenv("PAYMENT_RECONCILIATION_SCHEDULE") or ""
        ).strip() or None
        ai_provider_mode = (os.getenv("AI_PROVIDER_MODE") or "fallback").strip().lower()
        ai_provider_api_key = (os.getenv("AI_PROVIDER_API_KEY") or "").strip() or None
        ai_model = (os.getenv("AI_MODEL") or "gpt-4o-mini").strip() or "gpt-4o-mini"
        ai_max_tokens = max(_as_int(os.getenv("AI_MAX_TOKENS"), 500), 64)
        ai_temperature = min(max(_as_float(os.getenv("AI_TEMPERATURE"), 0.7), 0.0), 2.0)
        # Penalties nudge the model away from repeating words/topics it already
        # used, which keeps stories/facts/games fresh across a conversation.
        ai_frequency_penalty = min(
            max(_as_float(os.getenv("AI_FREQUENCY_PENALTY"), 0.4), -2.0), 2.0
        )
        ai_presence_penalty = min(max(_as_float(os.getenv("AI_PRESENCE_PENALTY"), 0.6), -2.0), 2.0)
        # Text-to-speech: model plus a child-friendly voice per language.
        tts_model = (os.getenv("TTS_MODEL") or "gpt-4o-mini-tts").strip() or "gpt-4o-mini-tts"
        tts_voice_ar = (os.getenv("TTS_VOICE_AR") or "shimmer").strip() or "shimmer"
        tts_voice_en = (os.getenv("TTS_VOICE_EN") or "nova").strip() or "nova"
        sentry_dsn = (os.getenv("SENTRY_DSN") or "").strip() or None
        youtube_api_key = (os.getenv("YOUTUBE_API_KEY") or "").strip() or None

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
                    "STRIPE_PRICE_PREMIUM_YEARLY": stripe_price_premium_yearly,
                    "STRIPE_PRICE_FAMILY_PLUS_YEARLY": stripe_price_family_plus_yearly,
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
                "STRIPE_PRICE_PREMIUM_YEARLY": stripe_price_premium_yearly,
                "STRIPE_PRICE_FAMILY_PLUS_YEARLY": stripe_price_family_plus_yearly,
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
            raise ValueError("ALLOWED_ORIGIN_REGEX is too permissive for production.")

        if environment == "production" and not redis_url:
            raise ValueError(
                "REDIS_URL is required in production. "
                "Rate limiting uses Redis-backed counters that are not safe to run "
                "in-process across multiple workers."
            )

        # Matches the exact truthy set routers/admin_seed.py checks, so this
        # guard fires precisely when that endpoint would actually be enabled.
        admin_seed_endpoint_enabled = os.getenv(
            "ENABLE_ADMIN_SEED_ENDPOINT", ""
        ).strip().lower() in {"1", "true", "yes"}
        if environment == "production" and admin_seed_endpoint_enabled:
            raise ValueError(
                "ENABLE_ADMIN_SEED_ENDPOINT must be false in production. This endpoint "
                "creates an admin account from environment-configured credentials and "
                "must never be reachable outside local/dev environments."
            )

        if payment_reconciliation_enabled and not payment_reconciliation_schedule:
            raise ValueError(
                "PAYMENT_RECONCILIATION_ENABLED is true but PAYMENT_RECONCILIATION_SCHEDULE is missing."
            )

        if ai_provider_mode not in {"fallback", "external", "openai"}:
            raise ValueError("AI_PROVIDER_MODE must be one of: fallback, external, openai.")
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
            data_encryption_key=data_encryption_key,
            data_encryption_previous_keys=data_encryption_previous_keys,
            app_log_file=app_log_file,
            skip_schema_verify=skip_schema_verify,
            auto_run_migrations=auto_run_migrations,
            cache_enabled=cache_enabled,
            redis_url=redis_url,
            admin_analytics_cache_ttl_seconds=admin_analytics_cache_ttl_seconds,
            admin_auth_max_failed_attempts=admin_auth_max_failed_attempts,
            admin_auth_lockout_minutes=admin_auth_lockout_minutes,
            admin_suspicious_failed_threshold=admin_suspicious_failed_threshold,
            admin_sensitive_confirmation_required=admin_sensitive_confirmation_required,
            enforce_admin_2fa=enforce_admin_2fa,
            cloudinary_cloud_name=cloudinary_cloud_name,
            cloudinary_api_key=cloudinary_api_key,
            cloudinary_api_secret=cloudinary_api_secret,
            cloudinary_media_root_folder=cloudinary_media_root_folder,
            media_max_upload_size_mb=media_max_upload_size_mb,
            payment_provider=payment_provider,
            stripe_secret_key=stripe_secret_key,
            stripe_publishable_key=stripe_publishable_key,
            stripe_webhook_secret=stripe_webhook_secret,
            stripe_checkout_success_url=stripe_checkout_success_url,
            stripe_checkout_cancel_url=stripe_checkout_cancel_url,
            stripe_portal_return_url=stripe_portal_return_url,
            stripe_price_premium_monthly=stripe_price_premium_monthly,
            stripe_price_family_plus_monthly=stripe_price_family_plus_monthly,
            stripe_price_premium_yearly=stripe_price_premium_yearly,
            stripe_price_family_plus_yearly=stripe_price_family_plus_yearly,
            payment_reconciliation_enabled=payment_reconciliation_enabled,
            payment_reconciliation_schedule=payment_reconciliation_schedule,
            ai_provider_mode=ai_provider_mode,
            ai_provider_api_key=ai_provider_api_key,
            ai_model=ai_model,
            ai_max_tokens=ai_max_tokens,
            ai_temperature=ai_temperature,
            ai_frequency_penalty=ai_frequency_penalty,
            ai_presence_penalty=ai_presence_penalty,
            tts_model=tts_model,
            tts_voice_ar=tts_voice_ar,
            tts_voice_en=tts_voice_en,
            sentry_dsn=sentry_dsn,
            youtube_api_key=youtube_api_key,
        )


settings = Settings.from_env()
