import os

import pytest

from core.settings import Settings


def _with_env(overrides: dict[str, str | None]):
    original = {}
    for key, value in overrides.items():
        original[key] = os.getenv(key)
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value
    return original


def _restore_env(original: dict[str, str | None]):
    for key, value in original.items():
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value


def test_production_requires_cors():
    original = _with_env(
        {
            "ENVIRONMENT": "production",
            "PAYMENT_PROVIDER": "stripe",
            "ALLOWED_ORIGINS": "",
            "ALLOWED_ORIGIN_REGEX": "",
            "STRIPE_SECRET_KEY": "sk_test_placeholder",
            "STRIPE_WEBHOOK_SECRET": "whsec_placeholder",
            "STRIPE_CHECKOUT_SUCCESS_URL": "https://app.example.invalid/success",
            "STRIPE_CHECKOUT_CANCEL_URL": "https://app.example.invalid/cancel",
            "STRIPE_PORTAL_RETURN_URL": "https://app.example.invalid/portal",
            "STRIPE_PRICE_PREMIUM_MONTHLY": "price_placeholder_premium",
            "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": "price_placeholder_family",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        with pytest.raises(ValueError, match="CORS is not configured for production"):
            Settings.from_env()
    finally:
        _restore_env(original)


def test_reconciliation_requires_schedule():
    original = _with_env(
        {
            "ENVIRONMENT": "development",
            "PAYMENT_RECONCILIATION_ENABLED": "true",
            "PAYMENT_RECONCILIATION_SCHEDULE": "",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        with pytest.raises(ValueError, match="PAYMENT_RECONCILIATION_SCHEDULE is missing"):
            Settings.from_env()
    finally:
        _restore_env(original)


def test_stripe_https_required_in_production():
    original = _with_env(
        {
            "ENVIRONMENT": "production",
            "PAYMENT_PROVIDER": "stripe",
            "STRIPE_SECRET_KEY": "sk_test_placeholder",
            "STRIPE_WEBHOOK_SECRET": "whsec_placeholder",
            "STRIPE_CHECKOUT_SUCCESS_URL": "http://app.example.invalid/success",
            "STRIPE_CHECKOUT_CANCEL_URL": "http://app.example.invalid/cancel",
            "STRIPE_PORTAL_RETURN_URL": "http://app.example.invalid/portal",
            "STRIPE_PRICE_PREMIUM_MONTHLY": "price_placeholder_premium",
            "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": "price_placeholder_family",
            "ALLOWED_ORIGINS": "https://app.example.invalid",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        with pytest.raises(ValueError, match="must use https"):
            Settings.from_env()
    finally:
        _restore_env(original)


def test_ai_provider_requires_key():
    original = _with_env(
        {
            "ENVIRONMENT": "development",
            "AI_PROVIDER_MODE": "external",
            "AI_PROVIDER_API_KEY": "",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        with pytest.raises(ValueError, match="AI_PROVIDER_API_KEY is required"):
            Settings.from_env()
    finally:
        _restore_env(original)


def test_internal_provider_blocked_in_production():
    original = _with_env(
        {
            "ENVIRONMENT": "production",
            "PAYMENT_PROVIDER": "internal",
            "ALLOWED_ORIGINS": "https://app.example.invalid",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        with pytest.raises(ValueError, match="PAYMENT_PROVIDER must be 'stripe' in production"):
            Settings.from_env()
    finally:
        _restore_env(original)


def test_internal_provider_allowed_in_development():
    original = _with_env(
        {
            "ENVIRONMENT": "development",
            "PAYMENT_PROVIDER": "internal",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
        }
    )
    try:
        settings = Settings.from_env()
        assert settings.payment_provider == "internal"
    finally:
        _restore_env(original)


def test_data_encryption_settings_are_loaded():
    original = _with_env(
        {
            "ENVIRONMENT": "development",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
            "DATA_ENCRYPTION_KEY": "field-secret-v2",
            "DATA_ENCRYPTION_PREVIOUS_KEYS": "field-secret-v1,field-secret-v0",
        }
    )
    try:
        settings = Settings.from_env()
        assert settings.data_encryption_key == "field-secret-v2"
        assert settings.data_encryption_previous_keys == (
            "field-secret-v1",
            "field-secret-v0",
        )
    finally:
        _restore_env(original)


def test_ai_provider_generation_settings_are_loaded() -> None:
    original = _with_env(
        {
            "ENVIRONMENT": "development",
            "KINDER_JWT_SECRET": "TEST_ONLY_PLACEHOLDER_SECRET",
            "AI_MODEL": "gpt-4o-mini",
            "AI_MAX_TOKENS": "700",
            "AI_TEMPERATURE": "0.4",
        }
    )
    try:
        settings = Settings.from_env()
        assert settings.ai_model == "gpt-4o-mini"
        assert settings.ai_max_tokens == 700
        assert settings.ai_temperature == 0.4
    finally:
        _restore_env(original)
