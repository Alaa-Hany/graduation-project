from __future__ import annotations

from core.observability import clear_events, emit_event


def test_admin_diagnostics_events_endpoint(
    client,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    clear_events()
    seed_builtin_rbac()
    admin = create_admin(email="obs.admin@example.com", role_names=["super_admin"])

    emit_event(
        "payment.checkout.created",
        category="payment",
        user_id=123,
        plan_id="PREMIUM",
        provider="internal",
    )

    response = client.get(
        "/admin/diagnostics/events",
        headers=admin_headers(admin),
        params={"limit": 10, "category": "payment"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["summary"]["total"] >= 1
    assert any(item["name"] == "payment.checkout.created" for item in payload["items"])
