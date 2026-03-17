from datetime import datetime

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
    assert select_payload["current_plan_id"] == PLAN_PREMIUM
    assert select_payload["status"] == "active"
    assert select_payload["will_renew"] is True
    assert select_payload["last_payment_status"] == "succeeded"
    assert select_payload["session_id"].startswith("mock_session_")
    assert datetime.fromisoformat(select_payload["started_at"]) < datetime.fromisoformat(
        select_payload["expires_at"]
    )

    me_after_select = client.get("/subscription/me", headers=headers)
    assert me_after_select.status_code == 200
    me_payload = me_after_select.json()
    assert me_payload["plan"] == PLAN_PREMIUM
    assert me_payload["current_plan_id"] == PLAN_PREMIUM
    assert me_payload["lifecycle"]["status"] == "active"
    assert me_payload["lifecycle"]["last_payment_status"] == "succeeded"
    assert me_payload["history_summary"]["event_count"] >= 2
    assert me_payload["history_summary"]["billing_transaction_count"] >= 1
    assert me_payload["history_summary"]["payment_attempt_count"] >= 1

    history = client.get("/subscription/history", headers=headers)
    assert history.status_code == 200
    history_payload = history.json()
    event_types = [item["event_type"] for item in history_payload["events"]]
    assert "select" in event_types
    assert "activate" in event_types
    assert history_payload["billing_transactions"][0]["transaction_type"] == "activation"
    assert history_payload["payment_attempts"][0]["attempt_type"] == "checkout"

    before_renew = client.get("/subscription", headers=headers).json()
    renew = client.post(
        "/subscription/activate",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert renew.status_code == 200
    renew_payload = renew.json()
    assert renew_payload["current_plan_id"] == PLAN_PREMIUM
    assert renew_payload["status"] == "active"
    assert datetime.fromisoformat(renew_payload["expires_at"]) > datetime.fromisoformat(
        before_renew["expires_at"]
    )

    history_after_renew = client.get("/subscription/history", headers=headers)
    assert history_after_renew.status_code == 200
    renew_event_types = [item["event_type"] for item in history_after_renew.json()["events"]]
    assert "renew" in renew_event_types
    assert any(
        item["transaction_type"] == "renewal"
        for item in history_after_renew.json()["billing_transactions"]
    )
    assert any(
        item["attempt_type"] == "renewal"
        for item in history_after_renew.json()["payment_attempts"]
    )

    cancel = client.post("/subscription/cancel", headers=headers)
    assert cancel.status_code == 200
    cancel_payload = cancel.json()
    assert cancel_payload["plan"] == PLAN_FREE
    assert cancel_payload["lifecycle"]["status"] == "canceled"
    assert cancel_payload["lifecycle"]["cancel_at"] is not None
    assert cancel_payload["lifecycle"]["will_renew"] is False
    assert cancel_payload["lifecycle"]["last_payment_status"] == "canceled"

    manage = client.post("/subscription/manage", headers=headers)
    assert manage.status_code == 501

    history_after_manage = client.get("/subscription/history", headers=headers)
    assert history_after_manage.status_code == 200
    final_event_types = [item["event_type"] for item in history_after_manage.json()["events"]]
    assert "cancel" in final_event_types
    assert "manage_request" in final_event_types
    assert "failure" in final_event_types


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
    assert item["plan"] == PLAN_FAMILY_PLUS
    assert item["lifecycle"]["status"] == "active"
    assert item["history_summary"]["event_count"] >= 2
    assert len(item["recent_events"]) >= 2
    assert len(item["billing_history"]) >= 1
    assert len(item["payment_attempts"]) >= 1
