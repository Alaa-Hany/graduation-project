from __future__ import annotations

import admin_models  # noqa: F401
from auth import hash_password
from models import SupportTicket


def test_parent_pin_status_set_verify_change_and_reset_request(
    client, db, create_parent, auth_headers
):
    user = create_parent(email="pin.parent@gmail.com", name="Pin Parent", plan="FREE")
    headers = auth_headers(user)

    status_before = client.get("/auth/parent-pin/status", headers=headers)
    assert status_before.status_code == 200
    assert status_before.json()["has_pin"] is False

    set_pin = client.post(
        "/auth/parent-pin/set",
        json={"pin": "1234", "confirm_pin": "1234"},
        headers=headers,
    )
    assert set_pin.status_code == 200
    assert set_pin.json()["success"] is True

    db.refresh(user)
    assert user.parent_pin_hash is not None
    assert user.parent_pin_hash != "1234"

    status_after = client.get("/auth/parent-pin/status", headers=headers)
    assert status_after.status_code == 200
    assert status_after.json()["has_pin"] is True
    assert status_after.json()["is_locked"] is False

    verify_pin = client.post(
        "/auth/parent-pin/verify",
        json={"pin": "1234"},
        headers=headers,
    )
    assert verify_pin.status_code == 200
    assert verify_pin.json()["success"] is True

    change_pin = client.post(
        "/auth/parent-pin/change",
        json={
            "current_pin": "1234",
            "new_pin": "5678",
            "confirm_pin": "5678",
        },
        headers=headers,
    )
    assert change_pin.status_code == 200
    assert change_pin.json()["success"] is True

    verify_old = client.post(
        "/auth/parent-pin/verify",
        json={"pin": "1234"},
        headers=headers,
    )
    assert verify_old.status_code == 401

    verify_new = client.post(
        "/auth/parent-pin/verify",
        json={"pin": "5678"},
        headers=headers,
    )
    assert verify_new.status_code == 200

    reset_request = client.post(
        "/auth/parent-pin/reset-request",
        json={"note": "Need help resetting the parent PIN"},
        headers=headers,
    )
    assert reset_request.status_code == 200
    assert reset_request.json()["success"] is True

    ticket = (
        db.query(SupportTicket)
        .filter(SupportTicket.user_id == user.id)
        .order_by(SupportTicket.id.desc())
        .first()
    )
    assert ticket is not None
    assert ticket.subject == "Parent PIN reset request"


def test_parent_pin_lockout_after_repeated_failures(client, db, create_parent, auth_headers):
    user = create_parent(email="lock.parent@gmail.com", name="Pin Parent", plan="FREE")
    user.parent_pin_hash = hash_password("2468")
    db.add(user)
    db.commit()
    db.refresh(user)
    headers = auth_headers(user)

    for _ in range(4):
        response = client.post(
            "/auth/parent-pin/verify",
            json={"pin": "1111"},
            headers=headers,
        )
        assert response.status_code == 401

    locked = client.post(
        "/auth/parent-pin/verify",
        json={"pin": "1111"},
        headers=headers,
    )
    assert locked.status_code == 423
    assert locked.json()["detail"]["locked_until"] is not None

    status = client.get("/auth/parent-pin/status", headers=headers)
    assert status.status_code == 200
    assert status.json()["is_locked"] is True
    assert status.json()["failed_attempts"] == 5

    even_correct_while_locked = client.post(
        "/auth/parent-pin/verify",
        json={"pin": "2468"},
        headers=headers,
    )
    assert even_correct_while_locked.status_code == 423
