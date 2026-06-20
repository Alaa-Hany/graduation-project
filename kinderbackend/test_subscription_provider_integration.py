from __future__ import annotations

from dataclasses import dataclass

from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_provider import (
    CheckoutSessionResult,
    PaymentMethodReference,
    PortalSessionResult,
    RefundResult,
)
from services.subscription_service import subscription_service


@dataclass
class _FakeProviderState:
    customer_id: str = "cus_test_123"
    subscription_id: str = "sub_test_123"
    session_id: str = "cs_test_123"
    payment_intent_id: str = "pi_test_123"
    checkout_status: str = "complete"
    checkout_payment_status: str = "paid"
    refunded: bool = False
    detached_method_ids: list[str] | None = None
    attached_method_ids: list[str] | None = None


class FakeStripeProvider:
    provider_key = "stripe"
    is_external = True

    def __init__(self) -> None:
        self.state = _FakeProviderState(detached_method_ids=[], attached_method_ids=[])

    def create_checkout_session(
        self,
        *,
        plan_id: str,
        user_email: str,
        user_name: str | None,
        customer_id: str | None,
        metadata: dict[str, str],
        billing_interval: str = "monthly",
    ) -> CheckoutSessionResult:
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=self.state.session_id,
            checkout_url=f"https://checkout.stripe.test/{self.state.session_id}",
            status="open",
            payment_status="unpaid",
            customer_id=customer_id or self.state.customer_id,
            subscription_id=self.state.subscription_id,
            payment_intent_id=self.state.payment_intent_id,
            raw={"metadata": metadata, "plan_id": plan_id, "email": user_email, "name": user_name},
        )

    def retrieve_checkout_session(self, *, session_id: str) -> CheckoutSessionResult:
        assert session_id == self.state.session_id
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=session_id,
            checkout_url=f"https://checkout.stripe.test/{session_id}",
            status=self.state.checkout_status,
            payment_status=self.state.checkout_payment_status,
            customer_id=self.state.customer_id,
            subscription_id=self.state.subscription_id,
            payment_intent_id=self.state.payment_intent_id,
            payment_method_id="pm_card_visa",
            raw={"mode": "external_test"},
        )

    def create_billing_portal_session(
        self,
        *,
        customer_id: str,
        metadata: dict[str, str],
    ) -> PortalSessionResult:
        assert customer_id == self.state.customer_id
        return PortalSessionResult(
            provider=self.provider_key,
            session_id="bps_test_123",
            url="https://billing.stripe.test/portal",
            customer_id=customer_id,
            raw={"metadata": metadata},
        )

    def cancel_subscription(self, *, subscription_id: str) -> dict[str, str]:
        assert subscription_id == self.state.subscription_id
        return {"id": subscription_id, "status": "canceled"}

    def refund_payment(
        self,
        *,
        payment_intent_id: str | None,
        charge_id: str | None,
        amount_cents: int | None,
        reason: str | None,
        metadata: dict[str, str],
    ) -> RefundResult:
        assert payment_intent_id == self.state.payment_intent_id
        self.state.refunded = True
        return RefundResult(
            provider=self.provider_key,
            refund_id="re_test_123",
            status="succeeded",
            amount_cents=amount_cents or 1000,
            currency="usd",
            payment_intent_id=payment_intent_id,
            charge_id=charge_id,
            raw={"reason": reason, "metadata": metadata},
        )

    def list_payment_methods(self, *, customer_id: str) -> list[PaymentMethodReference]:
        assert customer_id == self.state.customer_id
        methods = [
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
                fingerprint="fp_visa",
            )
        ]
        if "pm_card_mastercard" not in (self.state.detached_method_ids or []):
            methods.append(
                PaymentMethodReference(
                    provider=self.provider_key,
                    customer_id=customer_id,
                    method_id="pm_card_mastercard",
                    method_type="card",
                    brand="mastercard",
                    last4="4444",
                    exp_month=11,
                    exp_year=2031,
                    is_default=False,
                    fingerprint="fp_mc",
                )
            )
        if "pm_card_amex" in (self.state.attached_method_ids or []):
            methods.append(
                PaymentMethodReference(
                    provider=self.provider_key,
                    customer_id=customer_id,
                    method_id="pm_card_amex",
                    method_type="card",
                    brand="amex",
                    last4="0005",
                    exp_month=10,
                    exp_year=2032,
                    is_default=True,
                    fingerprint="fp_amex",
                )
            )
        return methods

    def attach_payment_method(
        self,
        *,
        customer_id: str,
        payment_method_id: str,
        set_default: bool,
    ) -> PaymentMethodReference:
        assert customer_id == self.state.customer_id
        self.state.attached_method_ids.append(payment_method_id)
        return PaymentMethodReference(
            provider=self.provider_key,
            customer_id=customer_id,
            method_id=payment_method_id,
            method_type="card",
            brand="amex",
            last4="0005",
            exp_month=10,
            exp_year=2032,
            is_default=set_default,
            fingerprint="fp_amex",
        )

    def detach_payment_method(self, *, payment_method_id: str) -> dict[str, object]:
        self.state.detached_method_ids.append(payment_method_id)
        return {"id": payment_method_id, "detached": True}


def test_external_provider_recurring_purchase_unlocks_access_and_supports_refund(
    client,
    create_parent,
    auth_headers,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    fake_provider = FakeStripeProvider()
    original_factory = subscription_service._payment_provider_factory
    subscription_service._payment_provider_factory = lambda: fake_provider
    try:
        parent = create_parent(email="provider.parent@example.com", plan=PLAN_FREE)
        headers = auth_headers(parent)

        gated_before_purchase = client.get("/downloads/offline", headers=headers)
        assert gated_before_purchase.status_code == 403

        select = client.post(
            "/subscription/checkout",
            json={"plan_type": "premium"},
            headers=headers,
        )
        assert select.status_code == 200
        select_payload = select.json()
        assert select_payload["current_plan_id"] == PLAN_FREE
        assert select_payload["status"] == "pending_activation"
        assert select_payload["session_id"] == fake_provider.state.session_id
        assert select_payload["provider"] == "stripe"

        activate = client.post(
            "/subscription/activate",
            json={"plan_type": "premium", "session_id": fake_provider.state.session_id},
            headers=headers,
        )
        assert activate.status_code == 200
        activate_payload = activate.json()
        assert activate_payload["current_plan_id"] == PLAN_PREMIUM
        assert activate_payload["status"] == "active"

        snapshot = client.get("/subscription/me", headers=headers)
        assert snapshot.status_code == 200
        snapshot_payload = snapshot.json()
        assert snapshot_payload["plan"] == PLAN_PREMIUM
        assert snapshot_payload["lifecycle"]["provider"] == "stripe"
        assert (
            snapshot_payload["lifecycle"]["provider_customer_id"] == fake_provider.state.customer_id
        )
        assert snapshot_payload["lifecycle"]["has_paid_access"] is True
        assert snapshot_payload["lifecycle"]["provider_subscription_id"] == fake_provider.state.subscription_id
        assert snapshot_payload["lifecycle"]["will_renew"] is True
        assert any(
            item["provider_reference"] == fake_provider.state.session_id
            for item in snapshot_payload["payment_attempts"]
        )
        assert any(
            item["provider_reference"] == fake_provider.state.session_id
            for item in snapshot_payload["billing_history"]
        )
        gated_after_purchase = client.get("/downloads/offline", headers=headers)
        assert gated_after_purchase.status_code == 200

        methods = client.get("/billing/methods", headers=headers)
        assert methods.status_code == 200
        methods_payload = methods.json()["methods"]
        assert any(item["provider_method_id"] == "pm_card_visa" for item in methods_payload)
        assert any(item["brand"] == "visa" for item in methods_payload)

        attach_method = client.post(
            "/billing/methods",
            json={"provider_method_id": "pm_card_amex", "set_default": True},
            headers=headers,
        )
        assert attach_method.status_code == 200
        assert attach_method.json()["method"]["provider_method_id"] == "pm_card_amex"

        manage = client.post("/subscription/manage", headers=headers)
        assert manage.status_code == 200
        assert manage.json()["url"] == "https://billing.stripe.test/portal"

        portal = client.post("/billing/portal", headers=headers)
        assert portal.status_code == 200
        assert portal.json()["url"] == "https://billing.stripe.test/portal"

        cancel = client.post("/subscription/cancel", headers=headers)
        assert cancel.status_code == 200
        assert cancel.json()["lifecycle"]["will_renew"] is False

        history_after_purchase = client.get("/subscription/history", headers=headers)
        assert history_after_purchase.status_code == 200
        purchase_history = history_after_purchase.json()
        event_types = [item["event_type"] for item in purchase_history["events"]]
        assert "purchase" in event_types
        assert "renew" not in event_types
        assert "cancel" not in event_types
        assert {item["attempt_type"] for item in purchase_history["payment_attempts"]} <= {
            "checkout",
            "activation",
        }

        seed_builtin_rbac()
        admin = create_admin(email="refund.admin@example.com", role_names=["super_admin"])
        refund = client.post(
            f"/admin/subscriptions/{parent.id}/refund",
            json={"amount_cents": 500, "reason": "requested_by_customer"},
            headers=admin_headers(admin),
        )
        assert refund.status_code == 200
        refund_payload = refund.json()
        assert refund_payload["success"] is True
        assert refund_payload["refund_id"] == "re_test_123"

        history_after_refund = client.get("/subscription/history", headers=headers)
        assert history_after_refund.status_code == 200
        history_payload = history_after_refund.json()
        assert any(item["event_type"] == "refund" for item in history_payload["events"])
        assert any(
            item["transaction_type"] == "refund" for item in history_payload["billing_transactions"]
        )
        assert any(
            item["amount_cents"] < 0 and item["transaction_type"] == "refund"
            for item in history_payload["billing_transactions"]
        )

        snapshot_after_refund = client.get("/subscription/me", headers=headers)
        assert snapshot_after_refund.status_code == 200
        assert snapshot_after_refund.json()["plan"] == PLAN_PREMIUM
        assert snapshot_after_refund.json()["lifecycle"]["has_paid_access"] is True

        synced_methods = client.get("/billing/methods", headers=headers)
        visa_method = next(
            item
            for item in synced_methods.json()["methods"]
            if item["provider_method_id"] == "pm_card_visa"
        )
        delete_method = client.delete(f"/billing/methods/{visa_method['id']}", headers=headers)
        assert delete_method.status_code == 200
    finally:
        subscription_service._payment_provider_factory = original_factory


def test_external_provider_incomplete_checkout_keeps_access_gated(
    client,
    create_parent,
    auth_headers,
):
    fake_provider = FakeStripeProvider()
    fake_provider.state.checkout_status = "open"
    fake_provider.state.checkout_payment_status = "unpaid"
    original_factory = subscription_service._payment_provider_factory
    subscription_service._payment_provider_factory = lambda: fake_provider
    try:
        parent = create_parent(email="provider.pending@example.com", plan=PLAN_FREE)
        headers = auth_headers(parent)

        before_purchase = client.get("/downloads/offline", headers=headers)
        assert before_purchase.status_code == 403

        checkout = client.post(
            "/subscription/checkout",
            json={"plan_type": "premium"},
            headers=headers,
        )
        assert checkout.status_code == 200

        activate = client.post(
            "/subscription/activate",
            json={"plan_type": "premium", "session_id": fake_provider.state.session_id},
            headers=headers,
        )
        assert activate.status_code == 409
        assert activate.json()["detail"] == "Payment is not completed yet"

        after_attempt = client.get("/subscription/me", headers=headers)
        assert after_attempt.status_code == 200
        payload = after_attempt.json()
        assert payload["plan"] == PLAN_FREE
        assert payload["current_plan_id"] == PLAN_FREE
        assert payload["lifecycle"]["selected_plan_id"] == PLAN_PREMIUM
        assert payload["lifecycle"]["status"] == "pending_activation"
        assert payload["lifecycle"]["has_paid_access"] is False

        gated_after_attempt = client.get("/downloads/offline", headers=headers)
        assert gated_after_attempt.status_code == 403

        history = client.get("/subscription/history", headers=headers)
        assert history.status_code == 200
        history_payload = history.json()
        assert any(item["event_type"] == "failure" for item in history_payload["events"])
        assert not any(item["event_type"] == "renew" for item in history_payload["events"])
        assert not any(
            item["attempt_type"] == "renewal" for item in history_payload["payment_attempts"]
        )
    finally:
        subscription_service._payment_provider_factory = original_factory
