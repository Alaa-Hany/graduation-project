from __future__ import annotations

import hashlib
import hmac
import json
import time
from dataclasses import dataclass

from core.time_utils import db_utc_now
from models import ContentCategory, ContentItem
from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_provider import CheckoutSessionResult
from services.subscription_service import subscription_service


def _seed_presentation_content(db) -> None:
    category = ContentCategory(
        slug="presentation-learning",
        title_en="Presentation Learning",
        title_ar="Presentation Learning",
    )
    db.add(category)
    db.flush()

    lesson = ContentItem(
        category_id=category.id,
        slug="presentation-lesson",
        content_type="lesson",
        status="published",
        title_en="Presentation Lesson",
        title_ar="Presentation Lesson",
        description_en="Presentation flow lesson",
        description_ar="Presentation flow lesson",
        body_en="Presentation lesson body",
        body_ar="Presentation lesson body",
        age_group="5-7",
        published_at=db_utc_now(),
    )
    db.add(lesson)
    db.commit()


@dataclass
class _FakeCheckoutState:
    customer_id: str = "cus_presentation_123"
    session_id: str = "cs_presentation_123"
    payment_intent_id: str = "pi_presentation_123"


class _FakeStripeProvider:
    provider_key = "stripe"
    is_external = True

    def __init__(self) -> None:
        self.state = _FakeCheckoutState()

    def create_checkout_session(
        self,
        *,
        plan_id,
        user_email,
        user_name,
        customer_id,
        metadata,
    ):
        return CheckoutSessionResult(
            provider=self.provider_key,
            session_id=self.state.session_id,
            checkout_url=f"https://checkout.test/{self.state.session_id}",
            status="open",
            payment_status="unpaid",
            customer_id=customer_id or self.state.customer_id,
            subscription_id=None,
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
            subscription_id=None,
            payment_intent_id=self.state.payment_intent_id,
            payment_method_id="pm_card_visa",
            raw={},
        )

    def list_payment_methods(self, *, customer_id):
        return []


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


def test_presentation_parent_child_activity_and_reports_flow(
    client,
    db,
    create_parent,
    create_child,
):
    _seed_presentation_content(db)
    parent = create_parent(
        email="presentation.parent@example.com",
        password="Password123!",
        plan=PLAN_FREE,
    )
    child = create_child(
        parent_id=parent.id,
        name="Presentation Kid",
        picture_password=["cat", "dog", "apple"],
    )

    parent_login = client.post(
        "/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert parent_login.status_code == 200
    parent_payload = parent_login.json()
    assert parent_payload["user"]["email"] == parent.email
    headers = {"Authorization": f"Bearer {parent_payload['access_token']}"}

    child_login = client.post(
        "/auth/child/login",
        json={
            "child_id": child.id,
            "name": "Presentation Kid",
            "picture_password": ["cat", "dog", "apple"],
            "device_id": "presentation-device-1",
        },
    )
    assert child_login.status_code == 200
    assert child_login.json()["session_token"]

    child_items = client.get("/content/child/items")
    assert child_items.status_code == 200
    assert any(item["slug"] == "presentation-lesson" for item in child_items.json()["items"])

    event_payload = {
        "child_id": child.id,
        "event_type": "lesson_completed",
        "lesson_id": "presentation-lesson",
        "activity_name": "Presentation Lesson",
        "duration_seconds": 420,
    }
    event_resp = client.post("/analytics/events", json=event_payload, headers=headers)
    assert event_resp.status_code == 200

    session_payload = {
        "child_id": child.id,
        "session_id": "presentation-session-1",
        "started_at": db_utc_now().isoformat(),
        "ended_at": (db_utc_now()).isoformat(),
        "source": "child_mode",
    }
    session_resp = client.post("/analytics/sessions", json=session_payload, headers=headers)
    assert session_resp.status_code == 200

    reports = client.get("/reports/basic", headers=headers)
    assert reports.status_code == 200
    report_payload = reports.json()
    assert report_payload.get("child_summary") is not None
    assert isinstance(report_payload["child_summary"], dict)


def test_presentation_admin_login_smoke(
    client,
    seed_builtin_rbac,
    create_admin,
):
    seed_builtin_rbac()
    admin = create_admin(
        email="presentation.admin@example.com",
        password="AdminPass123!",
        role_names=["super_admin"],
    )

    response = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["admin"]["email"] == admin.email


def test_presentation_one_time_purchase_unlocks_premium_access(
    client,
    create_parent,
    auth_headers,
):
    secret = "whsec_presentation_checkout"
    original_secret = _with_webhook_secret(secret)
    fake_provider = _FakeStripeProvider()
    original_factory = subscription_service._payment_provider_factory
    subscription_service._payment_provider_factory = lambda: fake_provider
    try:
        parent = create_parent(email="presentation.checkout@example.com", plan=PLAN_FREE)
        headers = auth_headers(parent)

        checkout = client.post(
            "/subscription/checkout",
            json={"plan_type": "premium"},
            headers=headers,
        )
        assert checkout.status_code == 200
        checkout_payload = checkout.json()
        assert checkout_payload["session_id"] == fake_provider.state.session_id
        assert checkout_payload["checkout_url"]

        event_payload = {
            "id": "evt_presentation_checkout_completed",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": fake_provider.state.session_id,
                    "object": "checkout.session",
                    "status": "complete",
                    "payment_status": "paid",
                    "customer": fake_provider.state.customer_id,
                    "payment_intent": fake_provider.state.payment_intent_id,
                    "metadata": {
                        "user_id": str(parent.id),
                        "plan_id": PLAN_PREMIUM,
                    },
                    "amount_total": 3900,
                }
            },
        }

        webhook = _post_stripe_event(client, event_payload, secret=secret)
        assert webhook.status_code == 200
        assert webhook.json()["status"] == "processed"

        snapshot = client.get("/subscription/me", headers=headers)
        assert snapshot.status_code == 200
        payload = snapshot.json()
        assert payload["current_plan_id"] == PLAN_PREMIUM
        assert payload["plan"] == PLAN_PREMIUM
        assert payload["lifecycle"]["status"] == "active"
        assert payload["lifecycle"]["has_paid_access"] is True
        assert payload["lifecycle"]["last_payment_status"] == "succeeded"
        assert any(item["event_type"] == "checkout_completed" for item in payload["recent_events"])

        history = client.get("/subscription/history", headers=headers)
        assert history.status_code == 200
        history_payload = history.json()
        assert any(item["status"] == "succeeded" for item in history_payload["payment_attempts"])
        assert any(
            item["transaction_type"] in {"activation", "purchase", "upgrade"}
            for item in history_payload["billing_transactions"]
        )
    finally:
        subscription_service._payment_provider_factory = original_factory
        _restore_webhook_secret(original_secret)
