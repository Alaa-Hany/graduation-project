"""Phase 2 (audit finding #2): account deletion, child purge, analytics opt-out."""

from __future__ import annotations

from datetime import timedelta

import pytest

from core.time_utils import db_utc_now
from core.two_factor import generate_totp_code, generate_totp_secret
from models import (
    BillingTransaction,
    ChildActivityEvent,
    ChildDailyActivitySummary,
    ChildProfile,
    ChildSessionLog,
    Notification,
    PaymentWebhookEvent,
    PrivacySetting,
    SubscriptionProfile,
    SupportTicket,
    User,
)
from services.account_deletion_service import account_deletion_service, data_purge_enabled

PASSWORD = "Password123!"


def _event(client, headers, child_id, points=10, event_type="activity_completed"):
    return client.post(
        "/api/v1/analytics/events",
        json={
            "child_id": child_id,
            "event_type": event_type,
            "activity_name": "Counting Stars",
            "points": points,
        },
        headers=headers,
    )


def _seed_family(db, create_parent, create_child, email):
    parent = create_parent(email=email)
    active = create_child(parent_id=parent.id, name="Active Kid")
    gone = create_child(parent_id=parent.id, name="Gone Kid")
    gone.deleted_at = db_utc_now()
    db.add(gone)
    db.add(Notification(user_id=parent.id, child_id=active.id, title="hi", body="there"))
    db.add(PrivacySetting(user_id=parent.id))
    db.add(SupportTicket(user_id=parent.id, subject="Help", message="My kid Active Kid ..."))
    db.commit()
    return parent, active, gone


# ── DELETE /auth/account ───────────────────────────────────────────────────


def test_delete_account_requires_auth(client):
    response = client.request("DELETE", "/api/v1/auth/account", json={"password": PASSWORD})
    assert response.status_code == 401


def test_delete_account_wrong_password_deletes_nothing(
    client, db, create_parent, create_child, auth_headers
):
    parent, active, _ = _seed_family(db, create_parent, create_child, "del.wrong@example.com")
    response = client.request(
        "DELETE",
        "/api/v1/auth/account",
        json={"password": "not-my-password"},
        headers=auth_headers(parent),
    )
    assert response.status_code == 401
    assert db.query(User).filter(User.id == parent.id).count() == 1
    assert db.query(ChildProfile).filter(ChildProfile.id == active.id).count() == 1


def test_delete_account_removes_parent_children_and_their_data(
    client, db, create_parent, create_child, auth_headers
):
    parent, active, gone = _seed_family(db, create_parent, create_child, "del.ok@example.com")
    other = create_parent(email="del.other@example.com")
    other_child = create_child(parent_id=other.id, name="Neighbour Kid")
    headers = auth_headers(parent)
    assert _event(client, headers, active.id).status_code == 200
    assert _event(client, auth_headers(other), other_child.id).status_code == 200

    # Billing history that must survive, anonymised.
    profile = SubscriptionProfile(
        user_id=parent.id,
        current_plan_id="FREE",
        status="free",
        last_payment_status="not_applicable",
        provider="internal",
    )
    db.add(profile)
    db.flush()
    db.add(
        BillingTransaction(
            user_id=parent.id,
            subscription_profile_id=profile.id,
            plan_id="PREMIUM",
            transaction_type="purchase",
            amount_cents=300,
            currency="usd",
            status="succeeded",
            effective_at=db_utc_now(),
        )
    )
    db.add(
        PaymentWebhookEvent(
            provider="stripe",
            event_id="evt_del_1",
            event_type="invoice.paid",
            status="processed",
            subscription_profile_id=profile.id,
            payload_json={"customer_email": "del.ok@example.com"},
        )
    )
    db.commit()
    parent_id, active_id, gone_id = parent.id, active.id, gone.id

    response = client.request(
        "DELETE", "/api/v1/auth/account", json={"password": PASSWORD}, headers=headers
    )
    assert response.status_code == 200, response.text
    assert response.json()["children_deleted"] == 2

    db.expire_all()
    assert db.query(User).filter(User.id == parent_id).count() == 0
    assert db.query(ChildProfile).filter(ChildProfile.id.in_([active_id, gone_id])).count() == 0
    assert (
        db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == active_id).count() == 0
    )
    assert db.query(Notification).filter(Notification.user_id == parent_id).count() == 0
    assert db.query(PrivacySetting).filter(PrivacySetting.user_id == parent_id).count() == 0
    assert db.query(SupportTicket).filter(SupportTicket.user_id == parent_id).count() == 0
    assert (
        db.query(SubscriptionProfile).filter(SubscriptionProfile.user_id == parent_id).count() == 0
    )

    kept = db.query(BillingTransaction).filter(BillingTransaction.amount_cents == 300).one()
    assert kept.user_id is None and kept.subscription_profile_id is None
    webhook = (
        db.query(PaymentWebhookEvent).filter(PaymentWebhookEvent.event_id == "evt_del_1").one()
    )
    assert webhook.payload_json is None

    # The old token no longer works and the account can't log in.
    assert client.get("/api/v1/auth/me", headers=headers).status_code in (401, 404)
    login = client.post(
        "/api/v1/auth/login", json={"email": "del.ok@example.com", "password": PASSWORD}
    )
    assert login.status_code == 401

    # Another family is untouched.
    assert db.query(ChildProfile).filter(ChildProfile.id == other_child.id).count() == 1
    assert (
        db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == other_child.id).count()
        == 1
    )


def test_delete_account_requires_2fa_code_when_enabled(client, db, create_parent, auth_headers):
    parent = create_parent(email="del.2fa@example.com")
    secret = generate_totp_secret()
    parent.two_factor_enabled = True
    parent.two_factor_method = "totp"
    parent.two_factor_secret = secret
    db.add(parent)
    db.commit()
    headers = auth_headers(parent)

    missing = client.request(
        "DELETE", "/api/v1/auth/account", json={"password": PASSWORD}, headers=headers
    )
    assert missing.status_code == 401
    assert db.query(User).filter(User.id == parent.id).count() == 1

    ok = client.request(
        "DELETE",
        "/api/v1/auth/account",
        json={"password": PASSWORD, "two_factor_code": generate_totp_code(secret)},
        headers=headers,
    )
    assert ok.status_code == 200


class _FakeStripe:
    provider_key = "stripe"

    def __init__(self, fail=False):
        self.fail = fail
        self.deleted: list[str] = []

    def delete_customer(self, *, customer_id):
        if self.fail:
            raise RuntimeError("stripe down")
        self.deleted.append(customer_id)
        return {"id": customer_id, "deleted": True}


def _stripe_parent(db, create_parent, email):
    parent = create_parent(email=email, plan="PREMIUM")
    db.add(
        SubscriptionProfile(
            user_id=parent.id,
            current_plan_id="PREMIUM",
            status="active",
            last_payment_status="succeeded",
            provider="stripe",
            provider_customer_id="cus_del_123",
            provider_subscription_id="sub_del_123",
        )
    )
    db.commit()
    return parent


def test_delete_account_deletes_stripe_customer(db, create_parent):
    parent = _stripe_parent(db, create_parent, "del.stripe@example.com")
    fake = _FakeStripe()
    result = account_deletion_service.delete_parent_account(
        db=db,
        user=parent,
        password=PASSWORD,
        two_factor_code=None,
        payment_provider_factory=lambda: fake,
    )
    assert result["success"] is True
    assert fake.deleted == ["cus_del_123"]


def test_delete_account_continues_when_stripe_customer_already_gone(db, create_parent):
    class _Missing(Exception):
        code = "resource_missing"

    class _GoneStripe(_FakeStripe):
        def delete_customer(self, *, customer_id):
            raise _Missing("No such customer")

    parent = _stripe_parent(db, create_parent, "del.stripegone@example.com")
    result = account_deletion_service.delete_parent_account(
        db=db,
        user=parent,
        password=PASSWORD,
        two_factor_code=None,
        payment_provider_factory=lambda: _GoneStripe(),
    )
    assert result["success"] is True


def test_delete_account_aborts_when_stripe_fails(db, create_parent):
    from fastapi import HTTPException

    parent = _stripe_parent(db, create_parent, "del.stripefail@example.com")
    parent_id = parent.id
    with pytest.raises(HTTPException) as exc:
        account_deletion_service.delete_parent_account(
            db=db,
            user=parent,
            password=PASSWORD,
            two_factor_code=None,
            payment_provider_factory=lambda: _FakeStripe(fail=True),
        )
    assert exc.value.status_code == 502
    db.rollback()
    # Nothing deleted, so the parent can retry and isn't left billed without an account.
    assert db.query(User).filter(User.id == parent_id).count() == 1


# ── purge of soft-deleted children ─────────────────────────────────────────


def test_purge_removes_children_past_grace_period_only(
    client, db, create_parent, create_child, auth_headers
):
    parent = create_parent(email="purge.parent@example.com")
    old = create_child(parent_id=parent.id, name="Old Kid")
    recent = create_child(parent_id=parent.id, name="Recent Kid")
    active = create_child(parent_id=parent.id, name="Active Kid")
    headers = auth_headers(parent)
    for child in (old, recent, active):
        assert _event(client, headers, child.id).status_code == 200

    now = db_utc_now()
    old.deleted_at = now - timedelta(days=31)
    recent.deleted_at = now - timedelta(days=5)
    db.add_all([old, recent])
    db.commit()
    ids = (old.id, recent.id, active.id)

    assert account_deletion_service.purge_soft_deleted_children(db, now=now) == 1

    db.expire_all()
    assert db.query(ChildProfile).filter(ChildProfile.id == ids[0]).count() == 0
    assert db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == ids[0]).count() == 0
    # Inside the grace period, and active children, are kept with their data.
    for cid in ids[1:]:
        assert db.query(ChildProfile).filter(ChildProfile.id == cid).count() == 1
        assert db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == cid).count() == 1


def test_background_purge_is_off_outside_production(monkeypatch):
    monkeypatch.delenv("DATA_PURGE_ENABLED", raising=False)
    assert data_purge_enabled() is False
    monkeypatch.setenv("DATA_PURGE_ENABLED", "true")
    assert data_purge_enabled() is True


# ── analytics opt-out ──────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "privacy",
    [
        {"analytics_enabled": False, "data_collection_opt_out": False},
        {"analytics_enabled": True, "data_collection_opt_out": True},
    ],
)
def test_opted_out_events_keep_only_daily_totals(
    client, db, create_parent, create_child, auth_headers, privacy
):
    parent = create_parent(
        email=f"optout.{len(str(privacy))}.{privacy['analytics_enabled']}@ex.com"
    )
    child = create_child(parent_id=parent.id, name="Private Kid")
    headers = auth_headers(parent)
    update = client.put(
        "/api/v1/privacy/settings",
        json={**privacy, "personalized_recommendations": True},
        headers=headers,
    )
    assert update.status_code == 200

    assert _event(client, headers, child.id, points=25).status_code == 200
    session = client.post(
        "/api/v1/analytics/sessions",
        json={
            "child_id": child.id,
            "session_id": "s-1",
            "started_at": "2026-11-16T10:00:00Z",
            "ended_at": "2026-11-16T10:10:00Z",
        },
        headers=headers,
    )
    assert session.status_code == 200

    assert db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == child.id).count() == 0
    assert db.query(ChildSessionLog).filter(ChildSessionLog.child_id == child.id).count() == 0
    summaries = (
        db.query(ChildDailyActivitySummary)
        .filter(ChildDailyActivitySummary.child_id == child.id)
        .all()
    )
    assert sum(s.unlogged_points for s in summaries) == 25
    assert sum(s.unlogged_activities for s in summaries) == 1
    assert sum(s.unlogged_screen_seconds for s in summaries) == 600

    # The parent dashboard still shows the totals.
    children = client.get("/api/v1/children", headers=headers).json()
    listed = next(c for c in children["children"] if c["id"] == child.id)
    assert listed["xp"] == 25
    assert listed["activities_completed"] == 1
    assert listed["total_time_spent"] == 10


def test_events_are_stored_normally_when_analytics_on(
    client, db, create_parent, create_child, auth_headers
):
    parent = create_parent(email="optin.parent@example.com")
    child = create_child(parent_id=parent.id, name="Tracked Kid")
    headers = auth_headers(parent)
    assert _event(client, headers, child.id, points=7).status_code == 200
    assert db.query(ChildActivityEvent).filter(ChildActivityEvent.child_id == child.id).count() == 1
    children = client.get("/api/v1/children", headers=headers).json()
    listed = next(c for c in children["children"] if c["id"] == child.id)
    assert listed["xp"] == 7
