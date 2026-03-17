from __future__ import annotations

import admin_models  # noqa: F401
from models import SupportTicket, SupportTicketMessage


def test_parent_support_ticket_creation_history_detail_and_reply(
    client, db, create_parent, auth_headers
):
    parent = create_parent(email="parent.support@gmail.com")
    headers = auth_headers(parent)

    create = client.post(
        "/support/contact",
        json={
            "subject": "Billing question",
            "message": "I need help understanding my current plan billing.",
            "category": "billing_issue",
        },
        headers=headers,
    )
    assert create.status_code == 200
    created_ticket = create.json()["item"]
    assert created_ticket["category"] == "billing_issue"
    assert created_ticket["status"] == "open"
    assert len(created_ticket["thread"]) == 1

    history = client.get("/support/tickets", headers=headers)
    assert history.status_code == 200
    assert history.json()["summary"]["total"] == 1
    assert history.json()["items"][0]["category"] == "billing_issue"

    detail = client.get(f"/support/tickets/{created_ticket['id']}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["item"]["thread"][0]["author_type"] == "user"

    reply = client.post(
        f"/support/tickets/{created_ticket['id']}/reply",
        json={"message": "I still need an invoice copy."},
        headers=headers,
    )
    assert reply.status_code == 200
    assert reply.json()["item"]["reply_count"] == 1
    assert reply.json()["item"]["thread"][-1]["author_type"] == "user"

    stored = (
        db.query(SupportTicketMessage)
        .filter(SupportTicketMessage.ticket_id == created_ticket["id"])
        .one()
    )
    assert stored.user_id == parent.id


def test_parent_support_validation_and_cross_user_access(client, db, create_parent, auth_headers):
    owner = create_parent(email="owner@gmail.com")
    other = create_parent(email="other@gmail.com")

    invalid_category = client.post(
        "/support/contact",
        json={
            "subject": "Need help",
            "message": "This is a valid support message body.",
            "category": "unknown_issue",
        },
        headers=auth_headers(owner),
    )
    assert invalid_category.status_code == 422
    assert invalid_category.json()["detail"]["code"] == "INVALID_SUPPORT_CATEGORY"

    short_message = client.post(
        "/support/contact",
        json={
            "subject": "Hi",
            "message": "short",
            "category": "technical_issue",
        },
        headers=auth_headers(owner),
    )
    assert short_message.status_code == 422
    assert short_message.json()["detail"]["code"] == "SUBJECT_TOO_SHORT"

    ticket = SupportTicket(
        user_id=owner.id,
        subject="Login problem",
        message="I cannot access my account after password reset.",
        category="login_issue",
        email=owner.email,
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    forbidden_detail = client.get(f"/support/tickets/{ticket.id}", headers=auth_headers(other))
    assert forbidden_detail.status_code == 404

    closed_ticket = SupportTicket(
        user_id=owner.id,
        subject="Already closed",
        message="This ticket is already closed by the team.",
        category="general_inquiry",
        email=owner.email,
        status="closed",
    )
    db.add(closed_ticket)
    db.commit()
    db.refresh(closed_ticket)

    reply_closed = client.post(
        f"/support/tickets/{closed_ticket.id}/reply",
        json={"message": "Please reopen this ticket."},
        headers=auth_headers(owner),
    )
    assert reply_closed.status_code == 400
    assert reply_closed.json()["detail"]["code"] == "TICKET_CLOSED"


def test_admin_support_filters_resolve_and_closed_reply_guard(
    client, db, seed_builtin_rbac, create_admin, create_parent, admin_headers, auth_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="support.admin@gmail.com", role_names=["super_admin"])
    parent = create_parent(email="ticket.parent@gmail.com")

    billing_ticket = SupportTicket(
        user_id=parent.id,
        subject="Billing issue",
        message="I was charged twice for the same subscription.",
        category="billing_issue",
        email=parent.email,
        status="open",
    )
    technical_ticket = SupportTicket(
        user_id=parent.id,
        subject="Technical issue",
        message="The app freezes every time I open the reports screen.",
        category="technical_issue",
        email=parent.email,
        status="in_progress",
    )
    db.add(billing_ticket)
    db.add(technical_ticket)
    db.commit()
    db.refresh(billing_ticket)
    db.refresh(technical_ticket)

    filtered = client.get(
        "/admin/support/tickets",
        params={"status": "open", "category": "billing_issue"},
        headers=admin_headers(admin),
    )
    assert filtered.status_code == 200
    assert len(filtered.json()["items"]) == 1
    assert filtered.json()["items"][0]["category"] == "billing_issue"

    resolve = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/resolve",
        headers=admin_headers(admin),
    )
    assert resolve.status_code == 200
    assert resolve.json()["item"]["status"] == "resolved"

    parent_reply = client.post(
        f"/support/tickets/{technical_ticket.id}/reply",
        json={"message": "The reports issue still happens on my phone."},
        headers=auth_headers(parent),
    )
    assert parent_reply.status_code == 200
    assert parent_reply.json()["item"]["status"] == "open"

    close = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/close",
        headers=admin_headers(admin),
    )
    assert close.status_code == 200
    assert close.json()["item"]["status"] == "closed"

    reply_closed = client.post(
        f"/admin/support/tickets/{technical_ticket.id}/reply",
        json={"message": "This should not be sent"},
        headers=admin_headers(admin),
    )
    assert reply_closed.status_code == 400
    assert reply_closed.json()["detail"] == "Closed tickets cannot receive replies"

    invalid_filter = client.get(
        "/admin/support/tickets",
        params={"category": "bad_filter"},
        headers=admin_headers(admin),
    )
    assert invalid_filter.status_code == 422
