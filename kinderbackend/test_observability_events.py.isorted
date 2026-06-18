from __future__ import annotations

from core.observability import (
    clear_events,
    clear_metrics,
    emit_event,
    get_metrics,
    observe_duration,
)
from core.request_context import reset_request_id, set_request_id


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


def test_emit_event_includes_request_id_from_context() -> None:
    clear_events()
    token = set_request_id("req-test-123")
    try:
        emit_event(
            "ai.session.started",
            category="ai",
            session_id=77,
        )
    finally:
        reset_request_id(token)

    from core.observability import get_recent_events

    events = get_recent_events(limit=5, category="ai")
    assert events[-1]["fields"]["request_id"] == "req-test-123"


def test_observe_duration_records_operation_metrics() -> None:
    clear_metrics()

    with observe_duration("payment.webhook.handle", category="payment", provider="stripe"):
        pass

    metrics = get_metrics(category="payment", name_prefix="payment.webhook.handle")
    names = {item["name"] for item in metrics}
    assert "payment.webhook.handle.count" in names
    assert "payment.webhook.handle.duration_ms" in names


def test_admin_diagnostics_metrics_endpoint_exposes_request_metrics(
    client,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
):
    clear_metrics()
    seed_builtin_rbac()
    admin = create_admin(email="metrics.admin@example.com", role_names=["super_admin"])

    health = client.get("/health")
    assert health.status_code == 200
    assert "X-Process-Time-Ms" in health.headers

    unauthorized = client.get("/admin/diagnostics/metrics")
    assert unauthorized.status_code == 401

    response = client.get(
        "/admin/diagnostics/metrics",
        headers=admin_headers(admin),
        params={"category": "http", "name_prefix": "http."},
    )
    assert response.status_code == 200
    payload = response.json()
    names = {item["name"] for item in payload["items"]}
    assert "http.requests.total" in names
    assert "http.request.duration_ms" in names
    assert "http.errors.total" in names
