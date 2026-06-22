"""Unit tests for services.payment_webhook_service.PaymentWebhookService.

Complements test_payment_webhook_integration.py (which drives the happy paths
over HTTP) by targeting the static parsing helpers, the ``subscription.updated``
handler, and the ignored / duplicate / dispatch-failure / profile-resolution
branches. Event verification is replaced with a fake verifier that returns a
pre-built event dict, and the real subscription_service runs against the
in-memory DB.
"""

from __future__ import annotations

from datetime import datetime, timezone

import pytest
from fastapi import HTTPException

from models import PaymentWebhookEvent, SubscriptionProfile
from plan_service import PLAN_FREE, PLAN_PREMIUM
from services.payment_webhook_service import PaymentWebhookService
from services.payment_webhook_verifier import WebhookVerificationError
from services.subscription_service import subscription_service


class _FakeVerifier:
    def __init__(self, event=None, error=None):
        self._event = event
        self._error = error

    def verify(self, *, payload, signature):
        if self._error is not None:
            raise self._error
        return self._event


def _service(event=None, error=None):
    return PaymentWebhookService(
        stripe_verifier=_FakeVerifier(event=event, error=error),
        subscription_service_instance=subscription_service,
    )


@pytest.fixture
def svc():
    return PaymentWebhookService()


# ---------------------------------------------------------------------------
# Static / pure helpers
# ---------------------------------------------------------------------------


def test_normalize_plan(svc):
    assert svc._normalize_plan("premium-monthly") == "PREMIUM_MONTHLY"
    assert svc._normalize_plan("  family_plus ") == "FAMILY_PLUS"
    assert svc._normalize_plan(None) is None
    assert svc._normalize_plan("") is None


def test_metadata_from_object(svc):
    assert svc._metadata_from_object({"metadata": {"a": 1}}) == {"a": 1}
    assert svc._metadata_from_object({"metadata": "nope"}) == {}
    assert svc._metadata_from_object({}) == {}


def test_event_object(svc):
    assert svc._event_object({"data": {"object": {"id": "x"}}}) == {"id": "x"}
    assert svc._event_object({"data": "bad"}) == {}
    assert svc._event_object({"data": {"object": "bad"}}) == {}


def test_as_str(svc):
    assert svc._as_str(None) is None
    assert svc._as_str("  ") is None
    assert svc._as_str("  hi ") == "hi"
    assert svc._as_str(123) == "123"


def test_as_int(svc):
    assert svc._as_int("42") == 42
    assert svc._as_int(7) == 7
    assert svc._as_int("nope") is None
    assert svc._as_int(None) is None


def test_timestamp_to_utc(svc):
    ts = 1_700_000_000
    result = svc._timestamp_to_utc(ts)
    assert result == datetime.fromtimestamp(ts, tz=timezone.utc)
    assert svc._timestamp_to_utc(None) is None
    assert svc._timestamp_to_utc("") is None
    assert svc._timestamp_to_utc("bad") is None


def test_subscription_id_from_object(svc):
    assert svc._subscription_id_from_object({"object": "subscription", "id": "sub_1"}) == "sub_1"
    assert svc._subscription_id_from_object({"object": "invoice", "subscription": "sub_2"}) == "sub_2"
    assert svc._subscription_id_from_object({"object": "invoice"}) is None


def test_invoice_id_from_object(svc):
    assert svc._invoice_id_from_object({"id": "in_1"}, event_type="invoice.paid") == "in_1"
    assert (
        svc._invoice_id_from_object({"invoice": "in_2"}, event_type="checkout.session.completed")
        == "in_2"
    )
    assert svc._invoice_id_from_object({}, event_type="invoice.paid") is None


def test_session_id_from_object(svc):
    assert (
        svc._session_id_from_object({"id": "cs_1"}, event_type="checkout.session.completed")
        == "cs_1"
    )
    assert svc._session_id_from_object({"id": "cs_1"}, event_type="invoice.paid") is None


def test_invoice_period_end_from_lines(svc):
    obj = {
        "lines": {
            "data": [
                {"period": {"end": 1000}},
                {"period": {"end": 2000}},
                "not-a-dict",
            ]
        }
    }
    assert svc._invoice_period_end(obj) == datetime.fromtimestamp(2000, tz=timezone.utc)


def test_invoice_period_end_fallback_to_current_period_end(svc):
    obj = {"current_period_end": 5000}
    assert svc._invoice_period_end(obj) == datetime.fromtimestamp(5000, tz=timezone.utc)


def test_price_id_from_object_lines_and_items(svc):
    assert svc._price_id_from_object({"lines": {"data": [{"price": {"id": "price_a"}}]}}) == "price_a"
    assert svc._price_id_from_object({"items": {"data": [{"price": {"id": "price_b"}}]}}) == "price_b"
    assert svc._price_id_from_object({"lines": {"data": [{"no_price": True}]}}) is None
    assert svc._price_id_from_object({}) is None


def test_plan_from_price_id(svc):
    # settings is a frozen dataclass, so patch fields via object.__setattr__.
    from core.settings import settings

    fields = {
        "stripe_price_premium_monthly": "price_prem_m",
        "stripe_price_premium_yearly": "price_prem_y",
        "stripe_price_family_plus_monthly": "price_fam_m",
        "stripe_price_family_plus_yearly": "price_fam_y",
    }
    originals = {name: getattr(settings, name) for name in fields}
    for name, value in fields.items():
        object.__setattr__(settings, name, value)
    try:
        assert svc._plan_from_price_id("price_prem_m") == "PREMIUM"
        assert svc._plan_from_price_id("price_fam_y") == "FAMILY_PLUS"
        assert svc._plan_from_price_id("price_unknown") is None
        assert svc._plan_from_price_id(None) is None
    finally:
        for name, value in originals.items():
            object.__setattr__(settings, name, value)


def test_failure_message_from_invoice(svc):
    assert (
        svc._failure_message_from_invoice({"last_finalization_error": {"message": "Declined"}})
        == "Declined"
    )
    assert "failed invoice" in svc._failure_message_from_invoice({})


def test_amount_cents_from_object(svc):
    assert svc._amount_cents_from_object(obj={"amount_total": 1500}, fallback_plan=None) == 1500
    assert svc._amount_cents_from_object(obj={"amount_paid": 999}, fallback_plan=None) == 999
    assert svc._amount_cents_from_object(obj={"amount_total": "bad"}, fallback_plan=None) == 0
    # fallback to plan price when no amount present
    fallback = svc._amount_cents_from_object(obj={}, fallback_plan=PLAN_PREMIUM)
    assert isinstance(fallback, int)


def test_checkout_result_and_attempt_metadata(svc):
    obj = {
        "id": "cs_1",
        "url": "https://x",
        "status": "complete",
        "payment_status": "paid",
        "customer": "cus_1",
        "subscription": "sub_1",
        "payment_intent": "pi_1",
        "payment_method": "pm_1",
    }
    checkout = svc._checkout_result_from_object(obj)
    assert checkout.session_id == "cs_1"
    metadata = svc._checkout_attempt_metadata(checkout)
    assert metadata["session_id"] == "cs_1"
    assert metadata["customer_id"] == "cus_1"
    assert metadata["payment_intent_id"] == "pi_1"


def test_ignored_result_shape(svc):
    obj = {"customer": "cus_1", "object": "invoice", "id": "in_1", "subscription": "sub_1"}
    result = svc._ignored_result(obj=obj, event_type="invoice.created")
    assert result["status"] == "ignored"
    assert result["provider_customer_id"] == "cus_1"
    assert result["provider_invoice_id"] == "in_1"
    assert result["provider_subscription_id"] == "sub_1"


# ---------------------------------------------------------------------------
# handle_stripe_webhook — control-flow branches
# ---------------------------------------------------------------------------


def test_signature_invalid_records_failed_event(db):
    service = _service(error=WebhookVerificationError("bad sig"))
    with pytest.raises(HTTPException) as exc:
        service.handle_stripe_webhook(db=db, payload=b"{}", signature="bad")
    assert exc.value.status_code == 400
    record = db.query(PaymentWebhookEvent).order_by(PaymentWebhookEvent.id.desc()).first()
    assert record.event_type == "signature_invalid"
    assert record.signature_valid is False


def test_missing_id_or_type_raises_400(db):
    service = _service(event={"id": "", "type": ""})
    with pytest.raises(HTTPException) as exc:
        service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")
    assert exc.value.status_code == 400


def test_unhandled_event_type_is_ignored(db):
    event = {
        "id": "evt_ignored_1",
        "type": "customer.created",
        "data": {"object": {"id": "cus_x", "object": "customer", "customer": "cus_x"}},
    }
    service = _service(event=event)
    result = service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")
    assert result["status"] == "ignored"
    record = db.query(PaymentWebhookEvent).filter_by(event_id="evt_ignored_1").first()
    assert record.status == "ignored"


def test_duplicate_event_short_circuits(db):
    existing = PaymentWebhookEvent(
        provider="stripe",
        event_id="evt_dup_1",
        event_type="checkout.session.completed",
        status="processed",
        signature_valid=True,
    )
    db.add(existing)
    db.commit()

    event = {
        "id": "evt_dup_1",
        "type": "checkout.session.completed",
        "data": {"object": {"id": "cs_dup"}},
    }
    service = _service(event=event)
    result = service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")
    assert result["status"] == "duplicate"


def test_dispatch_failure_marks_record_failed(db, create_parent, monkeypatch):
    parent = create_parent(email="wh-fail@example.com", plan=PLAN_FREE)
    # The failure handler re-marks an *already-committed* record; the freshly
    # flushed one is rolled back. Pre-commit a record whose status is outside the
    # dedupe set so it is reprocessed (and then marked failed) rather than skipped.
    db.add(
        PaymentWebhookEvent(
            provider="stripe",
            event_id="evt_fail_1",
            event_type="checkout.session.completed",
            status="pending",
            signature_valid=True,
        )
    )
    db.commit()
    event = {
        "id": "evt_fail_1",
        "type": "checkout.session.completed",
        "data": {"object": {"id": "cs_fail", "metadata": {"user_id": str(parent.id)}}},
    }
    service = _service(event=event)
    monkeypatch.setattr(
        service,
        "_handle_checkout_session_completed",
        lambda **kwargs: (_ for _ in ()).throw(RuntimeError("kaboom")),
    )
    with pytest.raises(RuntimeError, match="kaboom"):
        service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")

    record = db.query(PaymentWebhookEvent).filter_by(event_id="evt_fail_1").first()
    assert record.status == "failed"
    assert "kaboom" in (record.error_message or "")


def test_subscription_updated_handler(db, create_parent):
    parent = create_parent(email="wh-subupd@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider_customer_id = "cus_subupd"
    profile.provider_subscription_id = "sub_subupd"
    profile.current_plan_id = PLAN_PREMIUM
    db.add(profile)
    db.commit()

    event = {
        "id": "evt_subupd_1",
        "type": "customer.subscription.updated",
        "data": {
            "object": {
                "id": "sub_subupd",
                "object": "subscription",
                "customer": "cus_subupd",
                "status": "active",
                "cancel_at_period_end": True,
                "current_period_end": 1_900_000_000,
                "cancel_at": 1_900_000_000,
                "metadata": {"user_id": str(parent.id)},
            }
        },
    }
    service = _service(event=event)
    result = service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")
    assert result["status"] == "processed"

    db.refresh(profile)
    assert profile.cancel_at is not None  # cancel_at_period_end → cancel scheduled
    assert profile.will_renew is False


def test_subscription_updated_past_due_status(db, create_parent):
    parent = create_parent(email="wh-pastdue@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider_subscription_id = "sub_pastdue"
    db.add(profile)
    db.commit()

    event = {
        "id": "evt_pastdue_1",
        "type": "customer.subscription.updated",
        "data": {
            "object": {
                "id": "sub_pastdue",
                "object": "subscription",
                "status": "past_due",
                "cancel_at_period_end": False,
            }
        },
    }
    service = _service(event=event)
    result = service.handle_stripe_webhook(db=db, payload=b"{}", signature="ok")
    assert result["status"] == "processed"
    db.refresh(profile)
    assert profile.status == "past_due"


# ---------------------------------------------------------------------------
# _resolve_profile_context resolution strategies
# ---------------------------------------------------------------------------


def test_resolve_by_profile_id_metadata(db, create_parent):
    parent = create_parent(email="wh-byprofile@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    db.add(profile)
    db.commit()

    svc = PaymentWebhookService()
    obj = {"metadata": {"profile_id": str(profile.id)}}
    user, resolved = svc._resolve_profile_context(db=db, obj=obj)
    assert resolved is not None
    assert resolved.id == profile.id
    assert user is not None


def test_resolve_by_customer_id(db, create_parent):
    parent = create_parent(email="wh-bycustomer@example.com", plan=PLAN_PREMIUM)
    profile = subscription_service._ensure_subscription_profile(db=db, user=parent)
    profile.provider_customer_id = "cus_resolve"
    db.add(profile)
    db.commit()

    svc = PaymentWebhookService()
    user, resolved = svc._resolve_profile_context(db=db, obj={"customer": "cus_resolve"})
    assert resolved is not None
    assert resolved.provider_customer_id == "cus_resolve"


def test_resolve_returns_none_when_unmatched(db):
    svc = PaymentWebhookService()
    user, resolved = svc._resolve_profile_context(db=db, obj={"customer": "cus_missing"})
    assert user is None
    assert resolved is None


def test_get_webhook_record_found_and_missing(db):
    svc = PaymentWebhookService()
    assert svc._get_webhook_record(db=db, provider="stripe", event_id="nope") is None
    record = PaymentWebhookEvent(
        provider="stripe", event_id="evt_lookup", event_type="x", status="processed"
    )
    db.add(record)
    db.commit()
    found = svc._get_webhook_record(db=db, provider="stripe", event_id="evt_lookup")
    assert found is not None
