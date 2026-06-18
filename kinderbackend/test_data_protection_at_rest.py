from __future__ import annotations

from sqlalchemy import text


def test_support_ticket_sensitive_fields_are_encrypted_at_rest(
    client,
    db,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="support.encryption@example.com")
    headers = auth_headers(parent)
    subject = "Billing statement request"
    message = "Please send me a detailed invoice for my last subscription payment."
    email = "billing.contact@example.com"

    create = client.post(
        "/support/contact",
        json={
            "subject": subject,
            "message": message,
            "category": "billing_issue",
            "email": email,
        },
        headers=headers,
    )
    assert create.status_code == 200
    ticket_id = create.json()["item"]["id"]

    row = db.execute(
        text("SELECT subject, message, email FROM support_tickets WHERE id = :ticket_id"),
        {"ticket_id": ticket_id},
    ).one()
    assert row.subject != subject
    assert row.message != message
    assert row.email != email
    assert row.subject.startswith("enc::v1::")
    assert row.message.startswith("enc::v1::")
    assert row.email.startswith("enc::v1::")

    reply = client.post(
        f"/support/tickets/{ticket_id}/reply",
        json={"message": "I also need the invoice emailed to accounting."},
        headers=headers,
    )
    assert reply.status_code == 200

    reply_message = db.execute(
        text(
            "SELECT message FROM support_ticket_messages WHERE ticket_id = :ticket_id ORDER BY id DESC"
        ),
        {"ticket_id": ticket_id},
    ).scalar_one()
    assert reply_message.startswith("enc::v1::")
    assert "accounting" not in reply_message


def test_support_ticket_plaintext_legacy_rows_still_read_back(
    client,
    db,
    create_parent,
    auth_headers,
):
    parent = create_parent(email="support.legacy@example.com")
    db.execute(
        text(
            """
            INSERT INTO support_tickets (user_id, subject, message, email, category, status)
            VALUES (:user_id, :subject, :message, :email, 'general_inquiry', 'open')
            """
        ),
        {
            "user_id": parent.id,
            "subject": "Legacy subject",
            "message": "Legacy plaintext support body.",
            "email": "legacy.ticket@example.com",
        },
    )
    db.commit()
    ticket_id = db.execute(text("SELECT max(id) FROM support_tickets")).scalar_one()

    detail = client.get(f"/support/tickets/{ticket_id}", headers=auth_headers(parent))
    assert detail.status_code == 200
    item = detail.json()["item"]
    assert item["subject"] == "Legacy subject"
    assert item["message"] == "Legacy plaintext support body."
    assert item["email"] == "legacy.ticket@example.com"


def test_ai_buddy_message_content_is_encrypted_at_rest(
    client,
    db,
    create_parent,
    create_child,
    auth_headers,
):
    parent = create_parent(email="ai.encryption@example.com")
    child = create_child(parent_id=parent.id, name="Nora", age=8)
    headers = auth_headers(parent)
    prompt = "Can you teach me a fun fact about space?"

    start = client.post("/ai-buddy/sessions", json={"child_id": child.id}, headers=headers)
    assert start.status_code == 200
    session_id = start.json()["session"]["id"]

    send = client.post(
        f"/ai-buddy/sessions/{session_id}/messages",
        json={"child_id": child.id, "content": prompt},
        headers=headers,
    )
    assert send.status_code == 200
    assert send.json()["user_message"]["content"] == prompt

    rows = db.execute(
        text(
            "SELECT role, content FROM ai_buddy_messages WHERE session_id = :session_id ORDER BY id ASC"
        ),
        {"session_id": session_id},
    ).all()
    assert rows
    assert all(row.content.startswith("enc::v1::") for row in rows)
    child_row = next(row for row in rows if row.role == "child")
    assert child_row.content != prompt


def test_admin_login_metadata_is_encrypted_at_rest(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
):
    seed_builtin_rbac()
    admin = create_admin(email="secure.admin@example.com", role_names=["super_admin"])
    user_agent = "UnitTestAgent/1.0"

    login = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
        headers={"User-Agent": user_agent},
    )
    assert login.status_code == 200
    payload = login.json()["admin"]
    assert payload["last_login_ip"] == "testclient"
    assert payload["last_login_user_agent"] == user_agent

    row = db.execute(
        text(
            """
            SELECT last_login_ip, last_login_user_agent
            FROM admin_users
            WHERE id = :admin_id
            """
        ),
        {"admin_id": admin.id},
    ).one()
    assert row.last_login_ip.startswith("enc::v1::")
    assert row.last_login_user_agent.startswith("enc::v1::")
    assert row.last_login_ip != "testclient"
    assert row.last_login_user_agent != user_agent
