from __future__ import annotations


def test_change_password_rate_limit_is_user_scoped(
    client,
    db,
    create_parent,
    auth_headers,
):
    primary_user = create_parent(email="rate.limit.primary@example.com")
    secondary_user = create_parent(email="rate.limit.secondary@example.com")

    current_password = "Password123!"
    next_passwords = [
        "NewPassword123!",
        "Password123!",
        "AnotherPass123!",
        "Password123!",
        "FinalPass123!",
    ]

    for next_password in next_passwords:
        response = client.post(
            "/auth/change-password",
            json={
                "currentPassword": current_password,
                "newPassword": next_password,
                "confirmPassword": next_password,
            },
            headers=auth_headers(primary_user),
        )
        assert response.status_code == 200
        db.refresh(primary_user)
        current_password = next_password

    blocked = client.post(
        "/auth/change-password",
        json={
            "currentPassword": current_password,
            "newPassword": "BlockedPass123!",
            "confirmPassword": "BlockedPass123!",
        },
        headers=auth_headers(primary_user),
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.json()["detail"]["scope"] == "password_change"
    assert blocked.headers["Retry-After"] == "300"

    other_user = client.post(
        "/auth/change-password",
        json={
            "currentPassword": "Password123!",
            "newPassword": "SecondUserPass123!",
            "confirmPassword": "SecondUserPass123!",
        },
        headers=auth_headers(secondary_user),
    )
    assert other_user.status_code == 200


def test_parent_pin_reset_request_rate_limit_blocks_after_threshold(
    client,
    create_parent,
    auth_headers,
):
    user = create_parent(email="pin.reset.limit@example.com")
    headers = auth_headers(user)

    for attempt in range(5):
        response = client.post(
            "/auth/parent-pin/reset-request",
            json={"note": f"Need help resetting PIN #{attempt}"},
            headers=headers,
        )
        assert response.status_code == 200
        assert response.json()["success"] is True

    blocked = client.post(
        "/auth/parent-pin/reset-request",
        json={"note": "Need one more reset request"},
        headers=headers,
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.json()["detail"]["scope"] == "parent_pin"
    assert blocked.headers["Retry-After"] == "300"


def test_support_contact_rate_limit_blocks_after_threshold(
    client,
    create_parent,
    auth_headers,
):
    user = create_parent(email="support.limit@example.com")
    headers = auth_headers(user)

    for attempt in range(5):
        response = client.post(
            "/support/contact",
            json={
                "subject": f"Billing question {attempt}",
                "message": "I need help understanding my subscription billing details.",
                "category": "billing_issue",
            },
            headers=headers,
        )
        assert response.status_code == 200
        assert response.json()["success"] is True

    blocked = client.post(
        "/support/contact",
        json={
            "subject": "Billing question blocked",
            "message": "I still need help understanding my subscription billing details.",
            "category": "billing_issue",
        },
        headers=headers,
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.json()["detail"]["scope"] == "support_write"
    assert blocked.headers["Retry-After"] == "300"


def test_child_change_password_rate_limit_blocks_repeated_attempts(client, db, create_parent):
    from models import ChildProfile

    parent = create_parent(email="child.password.limit@example.com")
    child = ChildProfile(
        parent_id=parent.id,
        name="Limiter Kid",
        picture_password=["cat", "dog", "apple"],
        age=7,
    )
    db.add(child)
    db.commit()
    db.refresh(child)

    for _ in range(5):
        response = client.post(
            "/auth/child/change-password",
            json={
                "child_id": child.id,
                "name": child.name,
                "current_picture_password": ["wrong", "wrong", "wrong"],
                "new_picture_password": ["tree", "book", "fish"],
            },
        )
        assert response.status_code == 401

    blocked = client.post(
        "/auth/child/change-password",
        json={
            "child_id": child.id,
            "name": child.name,
            "current_picture_password": ["wrong", "wrong", "wrong"],
            "new_picture_password": ["tree", "book", "fish"],
        },
    )
    assert blocked.status_code == 429
    assert blocked.json()["detail"]["code"] == "RATE_LIMIT_EXCEEDED"
    assert blocked.json()["detail"]["scope"] == "authentication"
    assert blocked.headers["Retry-After"] == "300"
