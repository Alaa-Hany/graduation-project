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
            "ALLOWED_ORIGINS": "",
            "ALLOWED_ORIGIN_REGEX": "",
            "KINDER_JWT_SECRET": "SUPER_SECRET_FOR_TEST_123",
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
            "KINDER_JWT_SECRET": "TEST_ONLY_SECRET",
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
            "STRIPE_SECRET_KEY": "sk_test_123",
            "STRIPE_WEBHOOK_SECRET": "whsec_123",
            "STRIPE_CHECKOUT_SUCCESS_URL": "http://example.com/success",
            "STRIPE_CHECKOUT_CANCEL_URL": "http://example.com/cancel",
            "STRIPE_PORTAL_RETURN_URL": "http://example.com/portal",
            "STRIPE_PRICE_PREMIUM_MONTHLY": "price_123",
            "STRIPE_PRICE_FAMILY_PLUS_MONTHLY": "price_456",
            "ALLOWED_ORIGINS": "https://example.com",
            "KINDER_JWT_SECRET": "SUPER_SECRET_FOR_TEST_123",
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
            "KINDER_JWT_SECRET": "TEST_ONLY_SECRET",
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
            "ALLOWED_ORIGINS": "https://example.com",
            "KINDER_JWT_SECRET": "SUPER_SECRET_FOR_TEST_123",
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
            "KINDER_JWT_SECRET": "TEST_ONLY_SECRET",
        }
    )
    try:
        settings = Settings.from_env()
        assert settings.payment_provider == "internal"
    finally:
        _restore_env(original)
