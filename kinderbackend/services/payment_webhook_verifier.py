from __future__ import annotations

import hashlib
import hmac
import json
import time
from typing import Any

from core.settings import settings


class WebhookVerificationError(Exception):
    pass


class StripeWebhookVerifier:
    provider_key = "stripe"
    default_tolerance_seconds = 300

    def verify(self, *, payload: bytes, signature: str | None) -> dict[str, Any]:
        if not signature:
            raise WebhookVerificationError("Missing Stripe-Signature header")
        if not settings.stripe_webhook_secret:
            raise WebhookVerificationError("Stripe webhook secret is not configured")

        timestamp, signatures = self._parse_signature_header(signature)
        if timestamp is None or not signatures:
            raise WebhookVerificationError("Invalid Stripe-Signature header")

        if abs(int(time.time()) - timestamp) > self.default_tolerance_seconds:
            raise WebhookVerificationError("Stripe webhook signature timestamp is outside tolerance")

        signed_payload = f"{timestamp}.{payload.decode('utf-8')}".encode("utf-8")
        expected = hmac.new(
            settings.stripe_webhook_secret.encode("utf-8"),
            signed_payload,
            hashlib.sha256,
        ).hexdigest()
        if not any(hmac.compare_digest(expected, item) for item in signatures):
            raise WebhookVerificationError("Invalid Stripe webhook signature")

        try:
            event = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise WebhookVerificationError("Invalid Stripe webhook payload") from exc
        if not isinstance(event, dict):
            raise WebhookVerificationError("Stripe webhook event could not be parsed")
        return event

    @staticmethod
    def _parse_signature_header(signature: str) -> tuple[int | None, list[str]]:
        timestamp = None
        signatures: list[str] = []
        for part in signature.split(","):
            key, _, value = part.strip().partition("=")
            if key == "t":
                try:
                    timestamp = int(value)
                except (TypeError, ValueError):
                    timestamp = None
            elif key == "v1" and value:
                signatures.append(value)
        return timestamp, signatures


stripe_webhook_verifier = StripeWebhookVerifier()
