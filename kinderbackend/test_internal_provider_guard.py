from __future__ import annotations

from dataclasses import replace

import pytest

from core.settings import settings as current_settings
from services.payment_provider import PaymentProviderUnavailableError
from services.payment_providers import internal_provider


def test_internal_provider_fails_fast_in_production(monkeypatch: pytest.MonkeyPatch) -> None:
    production_settings = replace(current_settings, environment="production")
    monkeypatch.setattr(internal_provider, "settings", production_settings)

    with pytest.raises(PaymentProviderUnavailableError):
        internal_provider.internal_payment_provider.create_checkout_session(
            plan_id="PREMIUM",
            user_email="parent@example.com",
            user_name="Parent",
            customer_id=None,
            metadata={"user_id": "1"},
        )
