from plan_service import PLAN_FAMILY_PLUS, PLAN_FREE, PLAN_PREMIUM


def test_subscription_lifecycle_and_history_flow(client, db, create_parent, auth_headers):
    parent = create_parent(email="lifecycle.parent@example.com", plan=PLAN_FREE)
    headers = auth_headers(parent)

    initial = client.get("/subscription/me", headers=headers)
    assert initial.status_code == 200
    initial_payload = initial.json()
    assert initial_payload["plan"] == PLAN_FREE
    assert initial_payload["lifecycle"]["status"] == "free"
    assert initial_payload["history_summary"]["event_count"] == 0

    select = client.post(
        "/subscription/select",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert select.status_code == 200
    select_payload = select.json()
    assert select_payload["current_plan_id"] == PLAN_FREE
    assert select_payload["status"] == "pending_activation"
    assert select_payload["last_payment_status"] == "pending"
    assert select_payload["has_paid_access"] is False
    assert select_payload["session_id"].startswith("mock_session_")
    assert select_payload["started_at"] is None

    me_after_select = client.get("/subscription/me", headers=headers)
    assert me_after_select.status_code == 200
    me_payload = me_after_select.json()
    assert me_payload["plan"] == PLAN_FREE
    assert me_payload["current_plan_id"] == PLAN_FREE
    assert me_payload["lifecycle"]["selected_plan_id"] == PLAN_PREMIUM
    assert me_payload["lifecycle"]["status"] == "pending_activation"
    assert me_payload["lifecycle"]["last_payment_status"] == "pending"
    assert me_payload["history_summary"]["event_count"] >= 1
    assert me_payload["history_summary"]["billing_transaction_count"] == 0
    assert me_payload["history_summary"]["payment_attempt_count"] >= 1

    history = client.get("/subscription/history", headers=headers)
    assert history.status_code == 200
    history_payload = history.json()
    event_types = [item["event_type"] for item in history_payload["events"]]
    assert "select" in event_types
    assert history_payload["payment_attempts"][0]["attempt_type"] == "checkout"

    before_renew = client.get("/subscription", headers=headers).json()
    renew = client.post(
        "/subscription/activate",
        json={"plan_type": "premium", "session_id": select_payload["session_id"]},
        headers=headers,
    )
    assert renew.status_code == 409
    assert renew.json()["detail"] == "Payment is not completed yet"

    after_activate_attempt = client.get("/subscription", headers=headers).json()
    assert after_activate_attempt["current_plan_id"] == before_renew["current_plan_id"]
    assert after_activate_attempt["status"] == "pending_activation"

    history_after_renew = client.get("/subscription/history", headers=headers)
    assert history_after_renew.status_code == 200
    renew_event_types = [item["event_type"] for item in history_after_renew.json()["events"]]
    assert any(
        item["attempt_type"] in {"checkout", "activation"}
        for item in history_after_renew.json()["payment_attempts"]
    )
    assert "failure" in renew_event_types

    cancel = client.post("/subscription/cancel", headers=headers)
    assert cancel.status_code == 410
    assert cancel.json()["detail"] == "Cancel is disabled for one-time purchases"

    manage = client.post("/subscription/manage", headers=headers)
    assert manage.status_code == 410
    assert manage.json()["detail"] == "Billing portal is disabled for one-time purchases"


def test_activate_rejects_mismatched_pending_plan(client, create_parent, auth_headers):
    parent = create_parent(email="mismatch.parent@example.com", plan=PLAN_FREE)
    headers = auth_headers(parent)

    select = client.post(
        "/subscription/select",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert select.status_code == 200
    select_payload = select.json()

    activate = client.post(
        "/subscription/activate",
        json={"plan_type": "family_plus", "session_id": select_payload["session_id"]},
        headers=headers,
    )
    assert activate.status_code == 409
    assert (
        activate.json()["detail"] == "Requested plan does not match the pending checkout selection"
    )


def test_manage_subscription_rejects_accounts_without_billing_customer(
    client,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="manage.empty@example.com", plan=PLAN_FREE)
    headers = auth_headers(parent)

    manage = client.post("/subscription/manage", headers=headers)
    assert manage.status_code == 410
    assert manage.json()["detail"] == "Billing portal is disabled for one-time purchases"


def test_manage_subscription_requires_authentication(client):
    manage = client.post("/subscription/manage")
    assert manage.status_code == 401


def test_billing_portal_rejects_accounts_without_billing_customer(
    client,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="portal.empty@example.com", plan=PLAN_FREE)
    headers = auth_headers(parent)

    portal = client.post("/billing/portal", headers=headers)
    assert portal.status_code == 410
    assert portal.json()["detail"] == "Billing portal is disabled for one-time purchases"


def test_billing_portal_requires_authentication(client):
    portal = client.post("/billing/portal")
    assert portal.status_code == 401


def test_admin_subscription_detail_exposes_lifecycle_and_history(
    client,
    db,
    seed_builtin_rbac,
    create_parent,
    create_admin,
    admin_headers,
    auth_headers,
):
    seed_builtin_rbac()
    parent = create_parent(email="admin.lifecycle@example.com", plan=PLAN_FREE)
    admin = create_admin(email="subscriptions.admin@example.com", role_names=["super_admin"])

    client.post(
        "/subscription/select",
        json={"plan_type": "family_plus"},
        headers=auth_headers(parent),
    )

    detail = client.get(
        f"/admin/subscriptions/{parent.id}",
        headers=admin_headers(admin),
    )
    assert detail.status_code == 200
    item = detail.json()["item"]
    assert item["plan"] == PLAN_FREE
    assert item["lifecycle"]["selected_plan_id"] == PLAN_FAMILY_PLUS
    assert item["lifecycle"]["status"] == "pending_activation"
    assert item["history_summary"]["event_count"] >= 1
    assert len(item["recent_events"]) >= 1
    assert len(item["billing_history"]) == 0
    assert len(item["payment_attempts"]) >= 1
