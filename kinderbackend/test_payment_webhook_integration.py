from __future__ import annotations

import hashlib
import hmac
import json
import time
from dataclasses import dataclass

from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_provider import CheckoutSessionResult, PaymentMethodReference, PortalSessionResult, RefundResult
from services.subscription_service import subscription_service


@dataclass
class _FakeProviderState:
    customer_id: str = "cus_webhook_123"
    subscription_id: str = "sub_webhook_123"
    session_id: str = "cs_webhook_123"
    payment_intent_id: str = "pi_webhook_123"


class FakeStripeProvider:
    provider_key = "stripe"
    is_external = True

    def __init__(self) -> None:
        self.state = _FakeProviderState()

    def create_checkout_session(self, *, plan_id, user_email, user_name, customer_id, metadata):
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=self.state.session_id,
            checkout_url=f"https://checkout.test/{self.state.session_id}",
            status="open",
            payment_status="unpaid",
            customer_id=customer_id or self.state.customer_id,
            subscription_id=self.state.subscription_id,
            payment_intent_id=self.state.payment_intent_id,
            raw={"metadata": metadata, "plan_id": plan_id, "email": user_email, "name": user_name},
        )

    def retrieve_checkout_session(self, *, session_id):
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=session_id,
            checkout_url=f"https://checkout.test/{session_id}",
            status="complete",
            payment_status="paid",
            customer_id=self.state.customer_id,
            subscription_id=self.state.subscription_id,
            payment_intent_id=self.state.payment_intent_id,
            payment_method_id="pm_card_visa",
            raw={},
        )

    def create_billing_portal_session(self, *, customer_id, metadata):
        return PortalSessionResult(
            provider=self.provider_key,
            session_id="bps_webhook",
            url="https://billing.test/portal",
            customer_id=customer_id,
            raw={"metadata": metadata},
        )

    def cancel_subscription(self, *, subscription_id):
        return {"id": subscription_id, "status": "canceled"}

    def refund_payment(self, *, payment_intent_id, charge_id, amount_cents, reason, metadata):
        return RefundResult(
            provider=self.provider_key,
            refund_id="re_webhook_123",
            status="succeeded",
            amount_cents=amount_cents or 1000,
            currency="usd",
            payment_intent_id=payment_intent_id,
            charge_id=charge_id,
            raw={"reason": reason, "metadata": metadata},
        )

    def list_payment_methods(self, *, customer_id):
        return [
            PaymentMethodReference(
                provider=self.provider_key,
                customer_id=customer_id,
                method_id="pm_card_visa",
                method_type="card",
                brand="visa",
                last4="4242",
                exp_month=12,
                exp_year=2030,
                is_default=True,
                fingerprint="fp_webhook",
            )
        ]

    def attach_payment_method(self, *, customer_id, payment_method_id, set_default):
        return PaymentMethodReference(
            provider=self.provider_key,
            customer_id=customer_id,
            method_id=payment_method_id,
            method_type="card",
            brand="visa",
            last4="4242",
            exp_month=12,
            exp_year=2030,
            is_default=set_default,
            fingerprint="fp_webhook_attach",
        )

    def detach_payment_method(self, *, payment_method_id):
        return {"id": payment_method_id, "detached": True}


def _with_webhook_secret(secret: str):
    from core.settings import settings

    original = settings.stripe_webhook_secret
    object.__setattr__(settings, "stripe_webhook_secret", secret)
    return original


def _restore_webhook_secret(original: str | None):
    from core.settings import settings

    object.__setattr__(settings, "stripe_webhook_secret", original)


def _stripe_signature(payload: bytes, secret: str, timestamp: int | None = None) -> str:
    ts = timestamp or int(time.time())
    signed_payload = f"{ts}.{payload.decode('utf-8')}".encode("utf-8")
    digest = hmac.new(secret.encode("utf-8"), signed_payload, hashlib.sha256).hexdigest()
    return f"t={ts},v1={digest}"


def _post_stripe_event(client, event_payload: dict, *, secret: str):
    payload_bytes = json.dumps(event_payload, separators=(",", ":")).encode("utf-8")
    signature = _stripe_signature(payload_bytes, secret)
    return client.post(
        "/webhooks/stripe",
        content=payload_bytes,
        headers={"Stripe-Signature": signature, "Content-Type": "application/json"},
    )


def test_stripe_webhook_rejects_invalid_signature(client):
    secret = "whsec_test_invalid"
    original = _with_webhook_secret(secret)
    try:
        bad_signature = f"t={int(time.time())},v1=bad"
        response = client.post(
            "/webhooks/stripe",
            content=b'{"id":"evt_invalid","type":"checkout.session.completed","data":{"object":{}}}',
            headers={"Stripe-Signature": bad_signature, "Content-Type": "application/json"},
        )
        assert response.status_code == 400
        assert "Invalid Stripe webhook signature" in response.json()["detail"]
    finally:
        _restore_webhook_secret(original)


def test_checkout_completed_webhook_updates_lifecycle_and_deduplicates(
    client,
    create_parent,
    auth_headers,
    db,
):
    secret = "whsec_checkout"
    original_secret = _with_webhook_secret(secret)
    fake_provider = FakeStripeProvider()
    original_factory = subscription_service._payment_provider_factory
    subscription_service._payment_provider_factory = lambda: fake_provider
    try:
        parent = create_parent(email="checkout.webhook@example.com", plan=PLAN_FREE)
        headers = auth_headers(parent)

        checkout = client.post("/subscription/checkout", json={"plan_type": "premium"}, headers=headers)
        assert checkout.status_code == 200

        event_payload = {
            "id": "evt_checkout_completed",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": fake_provider.state.session_id,
                    "object": "checkout.session",
                    "status": "complete",
                    "payment_status": "paid",
                    "customer": fake_provider.state.customer_id,
                    "subscription": fake_provider.state.subscription_id,
                    "payment_intent": fake_provider.state.payment_intent_id,
                    "metadata": {
                        "user_id": str(parent.id),
                        "plan_id": PLAN_PREMIUM,
                    },
                    "amount_total": 1000,
                }
            },
        }

        response = _post_stripe_event(client, event_payload, secret=secret)
        assert response.status_code == 200
        assert response.json()["status"] == "processed"

        snapshot = client.get("/subscription/me", headers=headers)
        assert snapshot.status_code == 200
        payload = snapshot.json()
        assert payload["plan"] == PLAN_PREMIUM
        assert payload["lifecycle"]["status"] == "active"
        assert payload["lifecycle"]["provider_customer_id"] == fake_provider.state.customer_id
        assert any(item["event_type"] == "checkout_completed" for item in payload["recent_events"])

        duplicate = _post_stripe_event(client, event_payload, secret=secret)
        assert duplicate.status_code == 200
        assert duplicate.json()["status"] == "duplicate"
    finally:
        subscription_service._payment_provider_factory = original_factory
        _restore_webhook_secret(original_secret)


def test_invoice_paid_and_failed_and_subscription_deleted_webhooks_update_history(
    client,
    create_parent,
    auth_headers,
):
    secret = "whsec_invoice"
    original_secret = _with_webhook_secret(secret)
    fake_provider = FakeStripeProvider()
    original_factory = subscription_service._payment_provider_factory
    subscription_service._payment_provider_factory = lambda: fake_provider
    try:
        parent = create_parent(email="invoice.webhook@example.com", plan=PLAN_FREE)
        headers = auth_headers(parent)

        checkout = client.post("/subscription/checkout", json={"plan_type": "premium"}, headers=headers)
        assert checkout.status_code == 200

        checkout_event = {
            "id": "evt_checkout_for_invoice",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": fake_provider.state.session_id,
                    "object": "checkout.session",
                    "status": "complete",
                    "payment_status": "paid",
                    "customer": fake_provider.state.customer_id,
                    "subscription": fake_provider.state.subscription_id,
                    "payment_intent": fake_provider.state.payment_intent_id,
                    "metadata": {"user_id": str(parent.id), "plan_id": PLAN_PREMIUM},
                    "amount_total": 1000,
                }
            },
        }
        assert _post_stripe_event(client, checkout_event, secret=secret).status_code == 200

        paid_event = {
            "id": "evt_invoice_paid",
            "type": "invoice.paid",
            "data": {
                "object": {
                    "id": "in_paid_123",
                    "object": "invoice",
                    "customer": fake_provider.state.customer_id,
                    "subscription": fake_provider.state.subscription_id,
                    "payment_intent": fake_provider.state.payment_intent_id,
                    "amount_paid": 1000,
                    "billing_reason": "subscription_cycle",
                    "lines": {
                        "data": [
                            {
                                "price": {"id": "price_premium_test"},
                                "period": {"end": int(time.time()) + 30 * 24 * 3600},
                            }
                        ]
                    },
                    "metadata": {"user_id": str(parent.id), "plan_id": PLAN_PREMIUM},
                }
            },
        }

        from core.settings import settings

        original_premium_price = settings.stripe_price_premium_monthly
        object.__setattr__(settings, "stripe_price_premium_monthly", "price_premium_test")
        try:
            paid_response = _post_stripe_event(client, paid_event, secret=secret)
            assert paid_response.status_code == 200
            assert paid_response.json()["status"] == "processed"
        finally:
            object.__setattr__(settings, "stripe_price_premium_monthly", original_premium_price)

        failed_event = {
            "id": "evt_invoice_failed",
            "type": "invoice.payment_failed",
            "data": {
                "object": {
                    "id": "in_failed_123",
                    "object": "invoice",
                    "customer": fake_provider.state.customer_id,
                    "subscription": fake_provider.state.subscription_id,
                    "amount_due": 1000,
                    "billing_reason": "subscription_cycle",
                    "metadata": {"user_id": str(parent.id), "plan_id": PLAN_PREMIUM},
                    "last_finalization_error": {"message": "Card was declined"},
                }
            },
        }
        failed_response = _post_stripe_event(client, failed_event, secret=secret)
        assert failed_response.status_code == 200

        snapshot_after_failed = client.get("/subscription/me", headers=headers)
        assert snapshot_after_failed.status_code == 200
        snapshot_payload = snapshot_after_failed.json()
        assert snapshot_payload["lifecycle"]["last_payment_status"] == "failed"
        assert snapshot_payload["lifecycle"]["status"] == "past_due"

        deleted_event = {
            "id": "evt_subscription_deleted",
            "type": "customer.subscription.deleted",
            "data": {
                "object": {
                    "id": fake_provider.state.subscription_id,
                    "object": "subscription",
                    "customer": fake_provider.state.customer_id,
                    "status": "canceled",
                    "canceled_at": int(time.time()),
                    "current_period_end": int(time.time()) + 60,
                    "metadata": {"user_id": str(parent.id), "plan_id": PLAN_PREMIUM},
                }
            },
        }
        deleted_response = _post_stripe_event(client, deleted_event, secret=secret)
        assert deleted_response.status_code == 200

        history = client.get("/subscription/history", headers=headers)
        assert history.status_code == 200
        history_payload = history.json()
        assert any(item["event_type"] == "invoice_paid" for item in history_payload["events"])
        assert any(item["event_type"] == "invoice_payment_failed" for item in history_payload["events"])
        assert any(item["event_type"] == "cancel" for item in history_payload["events"])
        assert any(item["transaction_type"] in {"renewal", "invoice_paid"} for item in history_payload["billing_transactions"])
        assert any(item["transaction_type"] == "invoice_failed" for item in history_payload["billing_transactions"])
        assert any(item["provider_reference"] == "in_paid_123" for item in history_payload["payment_attempts"])
        assert any(item["provider_reference"] == "in_failed_123" for item in history_payload["payment_attempts"])

        final_snapshot = client.get("/subscription/me", headers=headers)
        assert final_snapshot.status_code == 200
        final_payload = final_snapshot.json()
        assert final_payload["plan"] == PLAN_FREE
        assert final_payload["lifecycle"]["status"] == "canceled"
    finally:
        subscription_service._payment_provider_factory = original_factory
        _restore_webhook_secret(original_secret)
