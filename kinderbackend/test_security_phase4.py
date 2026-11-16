"""Phase 4 security tests: #11 analytics limits, #25 video upload, #16 readiness
details, #17 uniform register / forgot-password, #18 no emails in logs,
#19 escaped names in emails."""

from __future__ import annotations

import io
import logging
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from core.settings import settings
from services.auth_service import auth_service
from services.media_service import MediaService, UploadedVideoAsset

EVENTS_URL = "/api/v1/analytics/events"
SESSIONS_URL = "/api/v1/analytics/sessions"
GAMIFICATION_URL = "/api/v1/analytics/gamification"
UPLOAD_URL = "/api/v1/admin/media/videos/upload"
PASSWORD = "Password123!"


@pytest.fixture
def family(create_parent, create_child, auth_headers):
    parent = create_parent(email="p4.family@example.com")
    child = create_child(parent_id=parent.id, name="P4Kid")
    return parent, child, auth_headers(parent)


# ── #11: analytics payload limits and rate limit ───────────────────────────


def test_analytics_rejects_inflated_points_and_huge_metadata(client, family):
    _, child, headers = family
    base = {"child_id": child.id, "event_type": "activity_completed"}

    too_many_points = client.post(EVENTS_URL, json={**base, "points": 50_000}, headers=headers)
    assert too_many_points.status_code == 422
    negative_points = client.post(EVENTS_URL, json={**base, "points": -10}, headers=headers)
    assert negative_points.status_code == 422
    huge_metadata = client.post(
        EVENTS_URL, json={**base, "metadata_json": {"blob": "x" * 20_000}}, headers=headers
    )
    assert huge_metadata.status_code == 422


def test_analytics_normal_event_still_accepted(client, family):
    _, child, headers = family
    ok = client.post(
        EVENTS_URL,
        json={
            "child_id": child.id,
            "event_type": "activity_completed",
            "activity_name": "Memory Match",
            "points": 82,
            "duration_seconds": 240,
            "metadata_json": {"content_type": "game", "stars": 3},
        },
        headers=headers,
    )
    assert ok.status_code == 200


def test_session_longer_than_a_day_is_rejected_but_normal_one_is_kept(client, family):
    _, child, headers = family
    start = datetime(2026, 11, 1, 10, tzinfo=timezone.utc)
    too_long = client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "started_at": start.isoformat(),
            "ended_at": (start + timedelta(days=3)).isoformat(),
        },
        headers=headers,
    )
    assert too_long.status_code == 422
    normal = client.post(
        SESSIONS_URL,
        json={
            "child_id": child.id,
            "started_at": start.isoformat(),
            "ended_at": (start + timedelta(minutes=25)).isoformat(),
        },
        headers=headers,
    )
    assert normal.status_code == 200


def test_gamification_snapshot_size_is_capped(client, family):
    _, child, headers = family
    oversized = client.put(
        GAMIFICATION_URL,
        json={
            "child_id": child.id,
            "updated_at": 1,
            "data": {f"k{i}": "v" * 200 for i in range(600)},
        },
        headers=headers,
    )
    assert oversized.status_code == 422
    normal = client.put(
        GAMIFICATION_URL,
        json={"child_id": child.id, "updated_at": 2, "data": {"gam_coins_1": 120}},
        headers=headers,
    )
    assert normal.status_code == 200


def test_analytics_rate_limit_is_per_child_and_shared_across_endpoints():
    from rate_limit import analytics_principal_rate_limit

    check = analytics_principal_rate_limit(max_requests=3, scope="p4_analytics_test")
    kid = SimpleNamespace(child=SimpleNamespace(id=9101), parent=SimpleNamespace(id=1))
    sibling = SimpleNamespace(child=SimpleNamespace(id=9102), parent=SimpleNamespace(id=1))

    for _ in range(3):
        check(principal=kid)
    with pytest.raises(HTTPException) as exc:
        check(principal=kid)
    assert exc.value.status_code == 429
    # Another child of the same parent has its own budget.
    check(principal=sibling)


# ── #25: video upload streams, rejects oversize early ──────────────────────


@pytest.fixture
def media_admin(seed_builtin_rbac, create_admin, admin_headers):
    seed_builtin_rbac()
    admin = create_admin(email="p4.media@example.com", role_names=["super_admin"])
    return admin_headers(admin)


def _fake_asset():
    return UploadedVideoAsset(
        video_url="https://cdn.example.com/v.mp4",
        thumbnail_url=None,
        provider="cloudinary",
        public_id="kinderworld/v-1",
        duration_seconds=3,
        bytes_size=16,
        format="mp4",
        resource_type="video",
        folder="kinderworld",
    )


def test_oversized_upload_rejected_before_reaching_the_handler(client, media_admin, monkeypatch):
    object.__setattr__(settings, "media_max_upload_size_mb", 1)
    calls = []
    monkeypatch.setattr(
        "routers.admin_cms.media_service.upload_video", lambda **kw: calls.append(kw)
    )
    try:
        response = client.post(
            UPLOAD_URL,
            headers=media_admin,
            files={"file": ("big.mp4", b"0" * (3 * 1024 * 1024), "video/mp4")},
        )
    finally:
        object.__setattr__(settings, "media_max_upload_size_mb", 200)
    assert response.status_code == 413
    assert calls == []


def test_upload_over_limit_but_under_overhead_is_rejected_by_handler(
    client, media_admin, monkeypatch
):
    # 1.5 MB fits the middleware's 1 MB multipart allowance, so the chunked
    # check in the handler is what refuses it.
    object.__setattr__(settings, "media_max_upload_size_mb", 1)
    calls = []
    monkeypatch.setattr(
        "routers.admin_cms.media_service.upload_video", lambda **kw: calls.append(kw)
    )
    try:
        response = client.post(
            UPLOAD_URL,
            headers=media_admin,
            files={"file": ("mid.mp4", b"0" * (1536 * 1024), "video/mp4")},
        )
    finally:
        object.__setattr__(settings, "media_max_upload_size_mb", 200)
    assert response.status_code == 413
    assert calls == []


def test_normal_upload_streams_a_file_object(client, media_admin, monkeypatch):
    received = {}

    def _fake_upload(**kwargs):
        received.update(kwargs)
        received["content"] = kwargs["file_obj"].read()
        return _fake_asset()

    monkeypatch.setattr("routers.admin_cms.media_service.upload_video", _fake_upload)
    response = client.post(
        UPLOAD_URL,
        headers=media_admin,
        files={"file": ("ok.mp4", b"fake-video-bytes", "video/mp4")},
    )
    assert response.status_code == 200
    assert "file_bytes" not in received
    assert received["content"] == b"fake-video-bytes"


def test_media_service_accepts_file_object(monkeypatch):
    object.__setattr__(settings, "cloudinary_cloud_name", "demo")
    object.__setattr__(settings, "cloudinary_api_key", "key")
    object.__setattr__(settings, "cloudinary_api_secret", "secret")
    sent = {}

    class _Resp:
        status_code = 200

        @staticmethod
        def json():
            return {"secure_url": "https://x/v.mp4", "public_id": "kw/v"}

    def _post(url, data, files, timeout):
        sent["file"] = files["file"][1]
        return _Resp()

    monkeypatch.setattr("services.media_service.httpx.post", _post)
    try:
        stream = io.BytesIO(b"abc")
        asset = MediaService().upload_video(file_obj=stream, filename="a.mp4")
        assert asset.public_id == "kw/v"
        assert sent["file"] is stream
        with pytest.raises(Exception):
            MediaService().upload_video(file_obj=io.BytesIO(b""), filename="e.mp4")
    finally:
        for name in ("cloudinary_cloud_name", "cloudinary_api_key", "cloudinary_api_secret"):
            object.__setattr__(settings, name, None)


# ── #16: readiness details are not public in production ────────────────────


@pytest.fixture
def production(monkeypatch):
    monkeypatch.setattr(type(settings), "is_production", property(lambda self: True))


def test_readiness_hides_details_in_production(client, production, monkeypatch):
    monkeypatch.delenv("HEALTH_DETAILS_TOKEN", raising=False)
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

    monkeypatch.setenv("HEALTH_DETAILS_TOKEN", "health-secret-123")
    wrong = client.get("/health/ready", headers={"X-Health-Token": "nope"})
    assert wrong.json() == {"status": "ok"}


def test_readiness_details_with_token_or_outside_production(client, production, monkeypatch):
    monkeypatch.setenv("HEALTH_DETAILS_TOKEN", "health-secret-123")
    detailed = client.get("/health/ready", headers={"X-Health-Token": "health-secret-123"})
    assert detailed.status_code == 200
    assert {"db", "payment", "ai", "background_jobs"} <= set(detailed.json())


def test_readiness_details_still_shown_in_development(client):
    body = client.get("/health/ready").json()
    assert body["status"] == "ok"
    assert "payment" in body


# ── #17: register / forgot-password answer the same for every email ────────


def _register(client, email, name="New Parent"):
    return client.post(
        "/api/v1/auth/register",
        json={
            "name": name,
            "email": email,
            "password": PASSWORD,
            "confirm_password": PASSWORD,
        },
    )


def test_register_existing_email_looks_identical_to_new_one(client, create_parent):
    create_parent(email="p4.taken@example.com")
    taken = _register(client, "p4.taken@example.com")
    fresh = _register(client, "p4.fresh@example.com")
    assert taken.status_code == fresh.status_code == 200
    assert set(taken.json()) == set(fresh.json())
    assert taken.json()["message"] == fresh.json()["message"]
    assert taken.json()["verification_required"] is True


def test_register_existing_email_emails_the_owner_not_an_otp(client, create_parent, monkeypatch):
    create_parent(email="p4.owner@example.com")
    sent = []
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    _register(client, "p4.owner@example.com")
    assert len(sent) == 1
    assert "already have an account" in sent[0]["body"]


def test_new_signup_still_gets_an_otp_and_can_verify(client, db, monkeypatch):
    sent = []
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    assert _register(client, "p4.newbie@example.com").status_code == 200
    code = next(word for word in sent[0]["body"].split() if word.isdigit() and len(word) == 6)
    verified = client.post(
        "/api/v1/auth/verify-email-otp", json={"email": "p4.newbie@example.com", "otp": code}
    )
    assert verified.status_code == 200
    assert verified.json()["access_token"]


def test_verify_and_resend_do_not_reveal_accounts(client, create_parent):
    create_parent(email="p4.known@example.com")
    for email in ("p4.known@example.com", "p4.nobody@example.com"):
        verify = client.post(
            "/api/v1/auth/verify-email-otp", json={"email": email, "otp": "123456"}
        )
        assert verify.status_code == 400
        resend = client.post("/api/v1/auth/resend-email-otp", json={"email": email})
        assert resend.status_code == 200


def test_forgot_password_same_answer_even_when_email_fails(client, create_parent, monkeypatch):
    create_parent(email="p4.reset@example.com")

    def _boom(**_kwargs):
        raise RuntimeError("smtp down")

    monkeypatch.setattr("services.email_delivery_service.email_delivery_service.send_email", _boom)
    known = client.post("/api/v1/auth/forgot-password", json={"email": "p4.reset@example.com"})
    unknown = client.post("/api/v1/auth/forgot-password", json={"email": "p4.ghost@example.com"})
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()


def test_forgot_password_still_sends_the_link(client, create_parent, monkeypatch):
    create_parent(email="p4.link@example.com")
    sent = []
    monkeypatch.setattr(
        "services.email_delivery_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    response = client.post("/api/v1/auth/forgot-password", json={"email": "p4.link@example.com"})
    assert response.status_code == 200
    assert len(sent) == 1
    assert "reset-password?token=" in sent[0]["body"]


# ── #18: logs carry ids, not emails ────────────────────────────────────────


def test_password_reset_and_admin_login_logs_have_no_email(
    client, create_parent, seed_builtin_rbac, create_admin, caplog
):
    create_parent(email="p4.logged@example.com")
    seed_builtin_rbac()
    create_admin(email="p4.admin.logged@example.com", role_names=["super_admin"])
    with caplog.at_level(logging.INFO):
        client.post("/api/v1/auth/forgot-password", json={"email": "p4.logged@example.com"})
        client.post("/api/v1/auth/forgot-password", json={"email": "p4.unknown@example.com"})
        client.post(
            "/api/v1/admin/auth/login",
            json={"email": "p4.admin.logged@example.com", "password": "wrong-pass"},
        )
    text = caplog.text
    assert "@example.com" not in text
    assert "user_id=" in text


def test_email_fingerprint_is_stable_and_not_reversible_text():
    from core.log_privacy import email_fingerprint

    first = email_fingerprint("Someone@Example.com ")
    assert first == email_fingerprint("someone@example.com")
    assert "example" not in first
    assert first != email_fingerprint("other@example.com")


# ── #19: user-typed names are escaped in HTML emails ───────────────────────


_EVIL_NAME = '<a href="https://evil.example">Click</a>'


def _capture_emails(monkeypatch):
    sent = []
    monkeypatch.setattr(
        "services.auth_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    monkeypatch.setattr(
        "services.child_service.email_delivery_service.send_email",
        lambda **kwargs: sent.append(kwargs),
    )
    return sent


def test_names_are_escaped_in_every_html_email(monkeypatch):
    from services.child_service import child_service

    sent = _capture_emails(monkeypatch)
    auth_service._send_email_otp(email="a@example.com", name=_EVIL_NAME, otp_code="123456")
    auth_service._send_password_reset_email(
        email="a@example.com", name=_EVIL_NAME, token="1:abc", app_base_url="https://app"
    )
    child_service._send_picture_password_reset_email(
        email="a@example.com",
        parent_name=_EVIL_NAME,
        child_name=_EVIL_NAME,
        token="1:abc",
        app_base_url="https://app",
    )
    assert len(sent) == 3
    for message in sent:
        assert _EVIL_NAME not in message["html_body"]
        assert "&lt;a href=&quot;https://evil.example&quot;&gt;" in message["html_body"]


def test_normal_names_and_links_still_render(monkeypatch):
    sent = _capture_emails(monkeypatch)
    auth_service._send_password_reset_email(
        email="a@example.com", name="Mona Ali", token="7:tok", app_base_url="https://app"
    )
    html_body = sent[0]["html_body"]
    assert "Hello <strong>Mona Ali</strong>" in html_body
    assert 'href="https://app/#/parent/reset-password?token=7:tok"' in html_body
    assert "Mona Ali" in sent[0]["body"]
