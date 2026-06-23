"""
Functional (business-logic) tests for every admin endpoint.

Where the RBAC suites prove *who* may call an endpoint, these tests prove the
endpoint actually does its job: the database changes the way it should, the
response shape is correct, and edge cases (404, filters, defaults) are handled.

All tests run as a freshly-created ``super_admin`` (full access, no permission
noise) and each test arranges its own data so it is independent of the others.
DB state is asserted directly after every call, not just the HTTP response.
"""

from __future__ import annotations

import pytest

import admin_models  # noqa: F401
from admin_models import AuditLog
from models import (
    ChildProfile,
    ContentCategory,
    ContentItem,
    Quiz,
    SupportTicket,
    SupportTicketMessage,
    SystemSetting,
    User,
)

MISSING_ID = 99999
VALID_AXIS = "behavioral"


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


@pytest.fixture
def super_admin_headers(seed_builtin_rbac, create_admin, admin_headers):
    """Seed built-in RBAC and return headers for a fresh super_admin."""
    seed_builtin_rbac()
    admin = create_admin(email="functional.super@kinderworld.app", role_names=["super_admin"])
    return admin_headers(admin)


def _create_category(client, headers, *, slug: str, title: str = "Cat") -> int:
    resp = client.post(
        "/admin/categories",
        json={
            "axis_key": VALID_AXIS,
            "slug": slug,
            "title_en": f"{title} EN",
            "title_ar": f"{title} AR",
        },
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["item"]["id"]


def _create_content(
    client, headers, *, slug: str, status: str = "draft", with_body: bool = True
) -> int:
    payload = {
        "slug": slug,
        "content_type": "lesson",
        "status": status,
        "title_en": "Content EN",
        "title_ar": "Content AR",
    }
    if with_body:
        payload["body_en"] = "Body EN"
        payload["body_ar"] = "Body AR"
    resp = client.post("/admin/contents", json=payload, headers=headers)
    assert resp.status_code == 200, resp.text
    return resp.json()["item"]["id"]


def _create_ticket(db, *, user_id: int, subject: str = "Need help") -> SupportTicket:
    ticket = SupportTicket(
        user_id=user_id,
        subject=subject,
        message="Original message",
        status="open",
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return ticket


# ===========================================================================
# CMS — categories
# ===========================================================================


def test_category_create_persists_row(client, db, super_admin_headers):
    resp = client.post(
        "/admin/categories",
        json={
            "axis_key": VALID_AXIS,
            "slug": "math-basics",
            "title_en": "Math Basics",
            "title_ar": "أساسيات الرياضيات",
        },
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    item = resp.json()["item"]
    assert item["slug"] == "math-basics"

    row = db.query(ContentCategory).filter(ContentCategory.id == item["id"]).one()
    assert row.title_en == "Math Basics"
    assert row.axis_key == VALID_AXIS
    assert row.slug == "math-basics"
    assert row.deleted_at is None


def test_category_list_and_axis_filter(client, db, super_admin_headers):
    _create_category(client, super_admin_headers, slug="cat-a", title="A")
    resp = client.get("/admin/categories", headers=super_admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert any(c["slug"] == "cat-a" for c in body["items"])
    assert len(body["axes"]) == 4  # behavioral/educational/skillful/entertaining

    # filtering by a different axis returns nothing for our behavioral category
    other = client.get(
        "/admin/categories", params={"axis_key": "educational"}, headers=super_admin_headers
    )
    assert other.status_code == 200
    assert all(c["slug"] != "cat-a" for c in other.json()["items"])


def test_category_update_persists(client, db, super_admin_headers):
    category_id = _create_category(client, super_admin_headers, slug="cat-upd")
    resp = client.patch(
        f"/admin/categories/{category_id}",
        json={"title_en": "Renamed EN"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ContentCategory).filter(ContentCategory.id == category_id).one()
    assert row.title_en == "Renamed EN"


def test_category_delete_soft_deletes(client, db, super_admin_headers):
    category_id = _create_category(client, super_admin_headers, slug="cat-del")
    resp = client.delete(f"/admin/categories/{category_id}", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ContentCategory).filter(ContentCategory.id == category_id).one()
    assert row.deleted_at is not None


# ===========================================================================
# CMS — contents
# ===========================================================================


def test_content_create_defaults_to_draft(client, db, super_admin_headers):
    content_id = _create_content(client, super_admin_headers, slug="lesson-one")
    row = db.query(ContentItem).filter(ContentItem.id == content_id).one()
    assert row.status == "draft"
    assert row.slug == "lesson-one"
    assert row.published_at is None


def test_content_list_with_status_and_search_filters(client, db, super_admin_headers):
    _create_content(client, super_admin_headers, slug="draft-lesson", status="draft")
    _create_content(client, super_admin_headers, slug="ready-lesson", status="ready")

    only_draft = client.get(
        "/admin/contents", params={"status": "draft"}, headers=super_admin_headers
    )
    assert only_draft.status_code == 200
    slugs = {i["slug"] for i in only_draft.json()["items"]}
    assert "draft-lesson" in slugs and "ready-lesson" not in slugs
    assert only_draft.json()["pagination"]["total"] == 1

    search = client.get(
        "/admin/contents", params={"search": "ready-lesson"}, headers=super_admin_headers
    )
    assert {i["slug"] for i in search.json()["items"]} == {"ready-lesson"}


def test_content_get_single_and_404(client, db, super_admin_headers):
    content_id = _create_content(client, super_admin_headers, slug="single-lesson")
    ok = client.get(f"/admin/contents/{content_id}", headers=super_admin_headers)
    assert ok.status_code == 200
    assert ok.json()["item"]["slug"] == "single-lesson"

    missing = client.get(f"/admin/contents/{MISSING_ID}", headers=super_admin_headers)
    assert missing.status_code == 404


def test_content_update_persists(client, db, super_admin_headers):
    content_id = _create_content(client, super_admin_headers, slug="edit-lesson")
    resp = client.patch(
        f"/admin/contents/{content_id}",
        json={"title_en": "Edited Title"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ContentItem).filter(ContentItem.id == content_id).one()
    assert row.title_en == "Edited Title"


def test_content_publish_then_unpublish(client, db, super_admin_headers):
    content_id = _create_content(client, super_admin_headers, slug="pub-lesson")

    pub = client.post(f"/admin/contents/{content_id}/publish", headers=super_admin_headers)
    assert pub.status_code == 200
    db.expire_all()
    row = db.query(ContentItem).filter(ContentItem.id == content_id).one()
    assert row.status == "published"
    assert row.published_at is not None

    unpub = client.post(f"/admin/contents/{content_id}/unpublish", headers=super_admin_headers)
    assert unpub.status_code == 200
    db.expire_all()
    row = db.query(ContentItem).filter(ContentItem.id == content_id).one()
    assert row.status != "published"
    assert row.status == "ready"
    assert row.published_at is None


def test_content_delete_soft_deletes(client, db, super_admin_headers):
    content_id = _create_content(client, super_admin_headers, slug="del-lesson")
    resp = client.delete(f"/admin/contents/{content_id}", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ContentItem).filter(ContentItem.id == content_id).one()
    assert row.deleted_at is not None


def test_media_upload_returns_meaningful_error_without_service(client, db, super_admin_headers):
    # No real media backend configured in tests -> should fail gracefully (not 500).
    resp = client.post(
        "/admin/media/videos/upload",
        files={"file": ("clip.mp4", b"fake-bytes", "video/mp4")},
        headers=super_admin_headers,
    )
    assert resp.status_code != 500
    assert resp.status_code in {400, 415, 502, 503}


def test_youtube_import_rejects_empty_selection(client, db, super_admin_headers):
    resp = client.post(
        "/admin/content/youtube/import",
        json={"items": []},
        headers=super_admin_headers,
    )
    # Business rule: at least one video must be selected -> 400, never 500.
    assert resp.status_code == 400


# ===========================================================================
# CMS — quizzes
# ===========================================================================


def test_quiz_create_persists_row(client, db, super_admin_headers):
    resp = client.post(
        "/admin/quizzes",
        json={"title_en": "Quiz EN", "title_ar": "Quiz AR", "status": "draft"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    quiz_id = resp.json()["item"]["id"]
    row = db.query(Quiz).filter(Quiz.id == quiz_id).one()
    assert row.title_en == "Quiz EN"
    assert row.status == "draft"


def test_quiz_list_returns_created_quiz(client, db, super_admin_headers):
    resp = client.post(
        "/admin/quizzes",
        json={"title_en": "Listed Quiz", "title_ar": "Listed AR"},
        headers=super_admin_headers,
    )
    quiz_id = resp.json()["item"]["id"]
    listing = client.get("/admin/quizzes", headers=super_admin_headers)
    assert listing.status_code == 200
    assert any(q["id"] == quiz_id for q in listing.json()["items"])


def test_quiz_update_persists(client, db, super_admin_headers):
    resp = client.post(
        "/admin/quizzes",
        json={"title_en": "Old Quiz", "title_ar": "Old AR"},
        headers=super_admin_headers,
    )
    quiz_id = resp.json()["item"]["id"]
    upd = client.patch(
        f"/admin/quizzes/{quiz_id}",
        json={"title_en": "New Quiz Title"},
        headers=super_admin_headers,
    )
    assert upd.status_code == 200
    db.expire_all()
    row = db.query(Quiz).filter(Quiz.id == quiz_id).one()
    assert row.title_en == "New Quiz Title"


def test_quiz_delete_soft_deletes(client, db, super_admin_headers):
    resp = client.post(
        "/admin/quizzes",
        json={"title_en": "Doomed Quiz", "title_ar": "Doomed AR"},
        headers=super_admin_headers,
    )
    quiz_id = resp.json()["item"]["id"]
    delete = client.delete(f"/admin/quizzes/{quiz_id}", headers=super_admin_headers)
    assert delete.status_code == 200
    db.expire_all()
    row = db.query(Quiz).filter(Quiz.id == quiz_id).one()
    assert row.deleted_at is not None


# ===========================================================================
# Analytics
# ===========================================================================


def test_analytics_overview_shape(client, db, super_admin_headers):
    resp = client.get("/admin/analytics/overview", headers=super_admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    for key in ("kpis", "subscriptions_summary", "usage_summary"):
        assert key in body
    assert "total_users" in body["kpis"]


def test_analytics_usage_returns_points(client, db, super_admin_headers):
    resp = client.get(
        "/admin/analytics/usage", params={"range": "week"}, headers=super_admin_headers
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["range"] == "week"
    assert isinstance(body["points"], list)


def test_analytics_axes_list(client, db, super_admin_headers):
    resp = client.get("/admin/analytics/axes", headers=super_admin_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json()["axes"], list)
    assert len(resp.json()["axes"]) == 4


def test_analytics_axis_valid_and_invalid_key(client, db, super_admin_headers):
    ok = client.get(f"/admin/analytics/axes/{VALID_AXIS}", headers=super_admin_headers)
    assert ok.status_code == 200
    assert "axis" in ok.json() and "stats" in ok.json()

    bad = client.get("/admin/analytics/axes/not-a-real-axis", headers=super_admin_headers)
    assert bad.status_code == 404


def test_analytics_axis_usage(client, db, super_admin_headers):
    resp = client.get(
        f"/admin/analytics/axes/{VALID_AXIS}/usage",
        params={"range": "week"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200


# ===========================================================================
# Diagnostics
# ===========================================================================


def test_diagnostics_health(client, db, super_admin_headers):
    resp = client.get("/admin/diagnostics/health", headers=super_admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert "environment" in body
    assert "counters" in body
    assert "payment" in body


def test_diagnostics_events_returns_list(client, db, super_admin_headers):
    resp = client.get("/admin/diagnostics/events", headers=super_admin_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json()["items"], list)


def test_diagnostics_metrics_returns_dict(client, db, super_admin_headers):
    resp = client.get("/admin/diagnostics/metrics", headers=super_admin_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert "items" in body and "summary" in body


# ===========================================================================
# Subscriptions
# ===========================================================================


def test_subscriptions_list_paginated(client, db, super_admin_headers, create_parent):
    create_parent(email="sub.list@example.com")
    resp = client.get("/admin/subscriptions", headers=super_admin_headers)
    assert resp.status_code == 200
    assert "pagination" in resp.json()
    assert any(i["user"]["email"] == "sub.list@example.com" for i in resp.json()["items"])


def test_subscription_detail_and_404(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="sub.detail@example.com")
    ok = client.get(f"/admin/subscriptions/{parent.id}", headers=super_admin_headers)
    assert ok.status_code == 200
    assert ok.json()["item"]["user"]["email"] == "sub.detail@example.com"

    missing = client.get(f"/admin/subscriptions/{MISSING_ID}", headers=super_admin_headers)
    assert missing.status_code == 404


def test_subscription_diagnostics_shape(client, db, super_admin_headers):
    resp = client.get("/admin/subscriptions/diagnostics", headers=super_admin_headers)
    assert resp.status_code == 200
    assert "summary" in resp.json()


def test_subscription_override_plan_changes_db(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="sub.override@example.com")
    resp = client.post(
        f"/admin/subscriptions/{parent.id}/override-plan",
        json={"plan": "PREMIUM"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(User).filter(User.id == parent.id).one()
    assert row.plan.upper() == "PREMIUM"


def test_subscription_cancel_reverts_to_free(client, db, super_admin_headers, create_parent):
    from plan_service import PLAN_PREMIUM

    parent = create_parent(email="sub.cancel@example.com", plan=PLAN_PREMIUM)
    resp = client.post(
        f"/admin/subscriptions/{parent.id}/cancel",
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(User).filter(User.id == parent.id).one()
    assert row.plan.upper() == "FREE"


@pytest.mark.skip(reason="Requires payment provider mocks for refund flow")
def test_subscription_refund(client, db, super_admin_headers): ...


@pytest.mark.skip(reason="Requires payment provider mocks for reconciliation")
def test_subscription_reconcile(client, db, super_admin_headers): ...


# ===========================================================================
# Support
# ===========================================================================


def test_support_list_and_status_filter(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="support.list@example.com")
    open_ticket = _create_ticket(db, user_id=parent.id, subject="Open one")
    closed = _create_ticket(db, user_id=parent.id, subject="Closed one")
    closed.status = "closed"
    db.commit()

    resp = client.get("/admin/support/tickets", headers=super_admin_headers)
    assert resp.status_code == 200
    ids = {t["id"] for t in resp.json()["items"]}
    assert {open_ticket.id, closed.id} <= ids

    filtered = client.get(
        "/admin/support/tickets", params={"status": "open"}, headers=super_admin_headers
    )
    assert filtered.status_code == 200
    statuses = {t["status"] for t in filtered.json()["items"]}
    assert statuses == {"open"}


def test_support_get_and_404(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="support.get@example.com")
    ticket = _create_ticket(db, user_id=parent.id)
    ok = client.get(f"/admin/support/tickets/{ticket.id}", headers=super_admin_headers)
    assert ok.status_code == 200

    missing = client.get(f"/admin/support/tickets/{MISSING_ID}", headers=super_admin_headers)
    assert missing.status_code == 404


def test_support_reply_saves_message_and_updates_status(
    client, db, super_admin_headers, create_parent
):
    parent = create_parent(email="support.reply@example.com")
    ticket = _create_ticket(db, user_id=parent.id)
    resp = client.post(
        f"/admin/support/tickets/{ticket.id}/reply",
        json={"message": "We are on it"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(SupportTicket).filter(SupportTicket.id == ticket.id).one()
    assert row.status == "in_progress"
    messages = (
        db.query(SupportTicketMessage).filter(SupportTicketMessage.ticket_id == ticket.id).all()
    )
    assert any(m.message == "We are on it" for m in messages)


def test_support_resolve_sets_status(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="support.resolve@example.com")
    ticket = _create_ticket(db, user_id=parent.id)
    resp = client.post(f"/admin/support/tickets/{ticket.id}/resolve", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(SupportTicket).filter(SupportTicket.id == ticket.id).one()
    assert row.status == "resolved"


def test_support_close_sets_status_and_closed_at(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="support.close@example.com")
    ticket = _create_ticket(db, user_id=parent.id)
    resp = client.post(f"/admin/support/tickets/{ticket.id}/close", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(SupportTicket).filter(SupportTicket.id == ticket.id).one()
    assert row.status == "closed"
    assert row.closed_at is not None


def test_support_assign_sets_assigned_admin(
    client, db, super_admin_headers, create_parent, create_admin
):
    parent = create_parent(email="support.assign@example.com")
    ticket = _create_ticket(db, user_id=parent.id)
    assignee = create_admin(email="support.assignee@kinderworld.app", role_names=["support_admin"])

    resp = client.post(
        f"/admin/support/tickets/{ticket.id}/assign",
        json={"admin_user_id": assignee.id},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(SupportTicket).filter(SupportTicket.id == ticket.id).one()
    assert row.assigned_admin_id == assignee.id


# ===========================================================================
# Users
# ===========================================================================


def test_user_create_persists_parent(client, db, super_admin_headers):
    resp = client.post(
        "/admin/users",
        json={
            "name": "Created Parent",
            "email": "created.parent@example.com",
            "password": "CreatedPass123!",
        },
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    row = db.query(User).filter(User.email == "created.parent@example.com").one()
    assert row.role == "parent"
    assert row.is_active is True


def test_user_list_paginated_and_search(client, db, super_admin_headers, create_parent):
    create_parent(email="findme.user@example.com", name="Findme")
    create_parent(email="other.user@example.com", name="Other")

    listing = client.get("/admin/users", headers=super_admin_headers)
    assert listing.status_code == 200
    assert "pagination" in listing.json()

    search = client.get("/admin/users", params={"search": "findme"}, headers=super_admin_headers)
    emails = {u["email"] for u in search.json()["items"]}
    assert emails == {"findme.user@example.com"}


def test_user_get_and_404(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.get@example.com")
    ok = client.get(f"/admin/users/{parent.id}", headers=super_admin_headers)
    assert ok.status_code == 200
    assert ok.json()["item"]["email"] == "user.get@example.com"

    missing = client.get(f"/admin/users/{MISSING_ID}", headers=super_admin_headers)
    assert missing.status_code == 404


def test_user_update_persists(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.update@example.com", name="Before")
    resp = client.patch(
        f"/admin/users/{parent.id}",
        json={"name": "After Name"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(User).filter(User.id == parent.id).one()
    assert row.name == "After Name"


def test_user_disable_then_enable(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.toggle@example.com")

    disable = client.post(f"/admin/users/{parent.id}/disable", headers=super_admin_headers)
    assert disable.status_code == 200
    db.expire_all()
    assert db.query(User).filter(User.id == parent.id).one().is_active is False

    enable = client.post(f"/admin/users/{parent.id}/enable", headers=super_admin_headers)
    assert enable.status_code == 200
    db.expire_all()
    assert db.query(User).filter(User.id == parent.id).one().is_active is True


def test_user_reset_password_changes_hash(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.reset@example.com")
    original_hash = db.query(User).filter(User.id == parent.id).one().password_hash

    resp = client.post(
        f"/admin/users/{parent.id}/reset-password",
        json={"new_password": "FreshPass123!"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(User).filter(User.id == parent.id).one()
    assert row.password_hash != original_hash


def test_user_delete_removes_row(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.delete@example.com")
    resp = client.delete(f"/admin/users/{parent.id}", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    assert db.query(User).filter(User.id == parent.id).first() is None


def test_user_activity_returns_data(client, db, super_admin_headers, create_parent):
    parent = create_parent(email="user.activity@example.com")
    resp = client.get(f"/admin/users/{parent.id}/activity", headers=super_admin_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json(), dict)


# ===========================================================================
# Children
# ===========================================================================


def test_children_list(client, db, super_admin_headers, create_parent, create_child):
    parent = create_parent(email="child.list@example.com")
    child = create_child(parent_id=parent.id, name="Lister")
    resp = client.get("/admin/children", headers=super_admin_headers)
    assert resp.status_code == 200
    assert any(c["id"] == child.id for c in resp.json()["items"])


def test_child_get_and_404(client, db, super_admin_headers, create_parent, create_child):
    parent = create_parent(email="child.get@example.com")
    child = create_child(parent_id=parent.id, name="Getter")
    ok = client.get(f"/admin/children/{child.id}", headers=super_admin_headers)
    assert ok.status_code == 200
    assert ok.json()["item"]["name"] == "Getter"

    missing = client.get(f"/admin/children/{MISSING_ID}", headers=super_admin_headers)
    assert missing.status_code == 404


def test_child_update_persists(client, db, super_admin_headers, create_parent, create_child):
    parent = create_parent(email="child.update@example.com")
    child = create_child(parent_id=parent.id, name="Before")
    resp = client.patch(
        f"/admin/children/{child.id}",
        json={"name": "After Child"},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ChildProfile).filter(ChildProfile.id == child.id).one()
    assert row.name == "After Child"


def test_child_deactivate_sets_inactive(
    client, db, super_admin_headers, create_parent, create_child
):
    parent = create_parent(email="child.deactivate@example.com")
    child = create_child(parent_id=parent.id)
    resp = client.post(f"/admin/children/{child.id}/deactivate", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    row = db.query(ChildProfile).filter(ChildProfile.id == child.id).one()
    assert row.is_active is False


def test_child_delete_removes_row(client, db, super_admin_headers, create_parent, create_child):
    parent = create_parent(email="child.delete@example.com")
    child = create_child(parent_id=parent.id)
    resp = client.delete(f"/admin/children/{child.id}", headers=super_admin_headers)
    assert resp.status_code == 200
    db.expire_all()
    assert db.query(ChildProfile).filter(ChildProfile.id == child.id).first() is None


def test_child_progress_returns_data(client, db, super_admin_headers, create_parent, create_child):
    parent = create_parent(email="child.progress@example.com")
    child = create_child(parent_id=parent.id)
    resp = client.get(f"/admin/children/{child.id}/progress", headers=super_admin_headers)
    assert resp.status_code == 200
    assert "child" in resp.json()


def test_child_activity_log_returns_list(
    client, db, super_admin_headers, create_parent, create_child
):
    parent = create_parent(email="child.activity@example.com")
    child = create_child(parent_id=parent.id)
    resp = client.get(f"/admin/children/{child.id}/activity-log", headers=super_admin_headers)
    assert resp.status_code == 200
    assert isinstance(resp.json()["items"], list)


def test_child_ai_buddy_summary_returns_dict(
    client, db, super_admin_headers, create_parent, create_child
):
    parent = create_parent(email="child.aibuddy@example.com")
    child = create_child(parent_id=parent.id)
    resp = client.get(f"/admin/children/{child.id}/ai-buddy-summary", headers=super_admin_headers)
    assert resp.status_code == 200
    assert "item" in resp.json()


# ===========================================================================
# Settings
# ===========================================================================


def test_settings_get_returns_effective(client, db, super_admin_headers):
    resp = client.get("/admin/settings", headers=super_admin_headers)
    assert resp.status_code == 200
    assert "effective" in resp.json()
    assert "maintenance_mode" in resp.json()["effective"]


def test_settings_update_persists(client, db, super_admin_headers):
    resp = client.patch(
        "/admin/settings",
        json={"maintenance_mode": True},
        headers=super_admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["effective"]["maintenance_mode"] is True

    db.expire_all()
    row = db.query(SystemSetting).filter(SystemSetting.key == "maintenance_mode").one()
    assert row.value_json is True


# ===========================================================================
# Audit (mounted at /admin/audit-logs)
# ===========================================================================


def test_audit_log_lists_and_records_new_mutation(client, db, super_admin_headers):
    before = client.get("/admin/audit-logs", headers=super_admin_headers)
    assert before.status_code == 200

    _create_category(client, super_admin_headers, slug="audited-cat")

    after = client.get(
        "/admin/audit-logs", params={"action": "category.create"}, headers=super_admin_headers
    )
    assert after.status_code == 200
    actions = [item["action"] for item in after.json()["items"]]
    assert "category.create" in actions
    # cross-check the row exists directly in the DB
    assert db.query(AuditLog).filter(AuditLog.action == "category.create").count() >= 1
