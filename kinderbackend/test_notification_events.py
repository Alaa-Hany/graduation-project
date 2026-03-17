from __future__ import annotations

import admin_models  # noqa: F401
from models import Notification, SupportTicket


def test_support_ticket_admin_updates_create_parent_notifications(
    client, db, seed_builtin_rbac, create_parent, create_admin, admin_headers
):
    seed_builtin_rbac()
    parent = create_parent(email="notify.parent@gmail.com", name="Parent", plan="FREE")
    admin = create_admin(email="notify.admin@gmail.com", role_names=["super_admin"])
    ticket = SupportTicket(
        user_id=parent.id,
        subject="Need support",
        message="Please help with an account problem.",
        category="login_issue",
        email=parent.email,
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    reply = client.post(
        f"/admin/support/tickets/{ticket.id}/reply",
        json={"message": "We are looking into it."},
        headers=admin_headers(admin),
    )
    assert reply.status_code == 200

    resolve = client.post(
        f"/admin/support/tickets/{ticket.id}/resolve",
        headers=admin_headers(admin),
    )
    assert resolve.status_code == 200

    notifications = (
        db.query(Notification)
        .filter(Notification.user_id == parent.id)
        .order_by(Notification.created_at.asc())
        .all()
    )
    assert len(notifications) == 2
    assert notifications[0].type == "SUPPORT_TICKET_UPDATE"
    assert "Need support" in notifications[0].body
    assert notifications[1].title == "Support ticket resolved"


def test_subscription_changes_create_notifications_and_are_listed(
    client, db, seed_builtin_rbac, create_parent, create_admin, admin_headers, auth_headers
):
    seed_builtin_rbac()
    parent = create_parent(email="subscription.notify@gmail.com", name="Parent", plan="FREE")
    admin = create_admin(email="subscription.admin@gmail.com", role_names=["super_admin"])
    headers = auth_headers(parent)

    select = client.post(
        "/subscription/select",
        json={"plan_type": "premium"},
        headers=headers,
    )
    assert select.status_code == 200

    cancel = client.post("/subscription/cancel", headers=headers)
    assert cancel.status_code == 200

    override = client.post(
        f"/admin/subscriptions/{parent.id}/override-plan",
        json={"plan": "family_plus"},
        headers=admin_headers(admin),
    )
    assert override.status_code == 200

    listed = client.get("/notifications", headers=headers)
    assert listed.status_code == 200
    payload = listed.json()
    assert payload["summary"]["unread_count"] == 3
    assert payload["notifications"][0]["type"] == "SUBSCRIPTION_UPDATED"
    assert payload["notifications"][0]["child_id"] is None
