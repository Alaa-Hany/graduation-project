"""
Integration test: complete parent-registration -> OTP verification
-> child creation -> child login flow.
"""

import pytest

from services.auth_service import auth_service

PARENT_EMAIL = "integtest.parent@example.com"
PARENT_PASSWORD = "Password123!"
PARENT_NAME = "Integration Parent"
FIXED_OTP = "987654"
CHILD_NAME = "Alice"
CHILD_PICTURE_PASSWORD = ["sun", "moon", "star"]
CHILD_AGE = 8


@pytest.fixture()
def patched_otp(monkeypatch):
    monkeypatch.setattr(auth_service, "_generate_email_otp", lambda: FIXED_OTP)


def test_parent_register_verify_otp_create_child_child_login(client, patched_otp, api):
    # Step 1: parent registers
    register_resp = client.post(
        "/api/v1/auth/register",
        json={
            "name": PARENT_NAME,
            "email": PARENT_EMAIL,
            "password": PARENT_PASSWORD,
            "confirm_password": PARENT_PASSWORD,
        },
    )
    assert register_resp.status_code == 200, register_resp.text
    reg_body = api.parse(register_resp)
    assert reg_body["verification_required"] is True
    assert reg_body["email"] == PARENT_EMAIL

    # Step 2: parent verifies OTP
    verify_resp = client.post(
        "/api/v1/auth/verify-email-otp",
        json={"email": PARENT_EMAIL, "otp": FIXED_OTP},
    )
    assert verify_resp.status_code == 200, verify_resp.text
    verify_body = api.parse(verify_resp)
    assert verify_body["user"]["email_verified"] is True
    assert verify_body["user"]["is_active"] is True

    access_token = verify_body["access_token"]
    auth_headers = {"Authorization": f"Bearer {access_token}"}

    # Step 3: parent creates a child profile
    create_child_resp = client.post(
        "/api/v1/children",
        json={
            "name": CHILD_NAME,
            "picture_password": CHILD_PICTURE_PASSWORD,
            "age": CHILD_AGE,
            "parent_email": PARENT_EMAIL,
        },
        headers=auth_headers,
    )
    assert create_child_resp.status_code == 200, create_child_resp.text
    child_body = api.parse(create_child_resp)
    child_id = child_body["child"]["id"]
    assert child_body["child"]["name"] == CHILD_NAME

    # Step 4: child logs in
    login_resp = client.post(
        "/api/v1/auth/child/login",
        json={
            "child_id": child_id,
            "name": CHILD_NAME,
            "picture_password": CHILD_PICTURE_PASSWORD,
        },
    )
    assert login_resp.status_code == 200, login_resp.text
    login_body = api.parse(login_resp)
    assert login_body["success"] is True
    assert login_body["child_id"] == child_id
    assert login_body.get(
        "session_token"
    ), "expected a non-empty session_token in child login response"

    # Child login returns the all-time progress aggregate so child mode can
    # backfill its local-first profile on a fresh device / after a logout cycle.
    progress = login_body.get("progress")
    assert isinstance(progress, dict), "expected a progress object in child login response"
    for key in (
        "xp",
        "level",
        "streak",
        "total_time_spent",
        "activities_completed",
    ):
        assert key in progress, f"expected '{key}' in child login progress"
    # A brand-new child has no analytics yet, so progress starts at the baseline.
    assert progress["xp"] == 0
    assert progress["level"] == 1
    assert progress["activities_completed"] == 0
