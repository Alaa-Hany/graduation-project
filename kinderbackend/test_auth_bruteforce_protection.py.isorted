from __future__ import annotations


def test_parent_login_locks_after_repeated_failed_attempts(client, create_parent, monkeypatch):
    parent = create_parent(email="parent.lockout@example.com", password="Password123!")

    monkeypatch.setenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "3")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_BASE_SECONDS", "120")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_MAX_SECONDS", "120")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_WINDOW_SECONDS", "600")

    payload = {
        "email": parent.email,
        "password": "WrongPassword123!",
    }

    first = client.post("/auth/login", json=payload)
    assert first.status_code == 401

    second = client.post("/auth/login", json=payload)
    assert second.status_code == 401

    third = client.post("/auth/login", json=payload)
    assert third.status_code == 401

    locked = client.post("/auth/login", json=payload)
    assert locked.status_code == 423
    detail = locked.json()["detail"]
    assert detail["code"] == "PARENT_AUTH_TEMP_LOCKED"
    assert detail["locked_until"] is not None


def test_parent_login_recovers_after_lockout_window(client, create_parent, monkeypatch):
    import services.auth_service as auth_service_module
    from rate_limit import rate_limiter

    parent = create_parent(email="parent.recovery@example.com", password="Password123!")

    base_time = 1_700_000_000.0
    monkeypatch.setenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "3")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_BASE_SECONDS", "60")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_MAX_SECONDS", "60")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_WINDOW_SECONDS", "600")

    monkeypatch.setattr(auth_service_module.time, "time", lambda: base_time)

    bad_payload = {
        "email": parent.email,
        "password": "WrongPassword123!",
    }

    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 423

    still_locked = client.post(
        "/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert still_locked.status_code == 423

    monkeypatch.setattr(auth_service_module.time, "time", lambda: base_time + 61)
    rate_limiter.requests.clear()

    recovered = client.post(
        "/auth/login",
        json={"email": parent.email, "password": "Password123!"},
    )
    assert recovered.status_code == 200
    assert recovered.json()["user"]["email"] == parent.email


def test_failed_parent_login_does_not_lock_different_account(
    client,
    create_parent,
    monkeypatch,
):
    first_parent = create_parent(email="first.parent@example.com", password="Password123!")
    second_parent = create_parent(email="second.parent@example.com", password="Password123!")

    monkeypatch.setenv("PARENT_AUTH_MAX_FAILED_ATTEMPTS", "3")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_BASE_SECONDS", "120")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_MAX_SECONDS", "120")
    monkeypatch.setenv("PARENT_AUTH_LOCKOUT_WINDOW_SECONDS", "600")

    bad_payload = {
        "email": first_parent.email,
        "password": "WrongPassword123!",
    }

    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 401
    assert client.post("/auth/login", json=bad_payload).status_code == 423

    other_account = client.post(
        "/auth/login",
        json={"email": second_parent.email, "password": "Password123!"},
    )
    assert other_account.status_code == 200
    assert other_account.json()["user"]["email"] == second_parent.email
