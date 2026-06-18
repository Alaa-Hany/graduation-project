"""
Tests for CMS content management via the admin API.

Covers:
- Create, read, update, delete content items
- Content publishing workflow (publish -> unpublish)
"""

from __future__ import annotations

import pytest

CONTENTS_URL = "/api/v1/admin/contents"
CATEGORIES_URL = "/api/v1/admin/categories"


def _content_url(content_id: int) -> str:
    return f"{CONTENTS_URL}/{content_id}"


def _publish_url(content_id: int) -> str:
    return f"{CONTENTS_URL}/{content_id}/publish"


def _unpublish_url(content_id: int) -> str:
    return f"{CONTENTS_URL}/{content_id}/unpublish"


def _base_content_payload(**overrides) -> dict:
    payload = {
        "title_en": "Test Lesson",
        "title_ar": "درس تجريبي",
        "content_type": "lesson",
        "status": "draft",
        "body_en": "English body text.",
        "body_ar": "نص عربي.",
    }
    payload.update(overrides)
    return payload


@pytest.fixture
def cms_admin(db, seed_builtin_rbac, create_admin):
    seed_builtin_rbac()
    return create_admin(
        email="cms.test.admin@example.invalid",
        role_names=["super_admin"],
    )


@pytest.fixture
def cms_headers(cms_admin, admin_headers):
    return admin_headers(cms_admin)


# --- CREATE ---


def test_create_content_item_returns_201_body(client, cms_headers, api):
    resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="create-test-lesson"),
        headers=cms_headers,
    )
    assert resp.status_code == 200
    body = api.parse(resp)
    assert body["success"] is True
    item = body["item"]
    assert item["slug"] == "create-test-lesson"
    assert item["status"] == "draft"
    assert item["title_en"] == "Test Lesson"


def test_create_content_requires_english_title(client, cms_headers):
    payload = _base_content_payload()
    del payload["title_en"]
    resp = client.post(CONTENTS_URL, json=payload, headers=cms_headers)
    assert resp.status_code == 422


def test_create_content_duplicate_slug_rejected(client, cms_headers):
    client.post(CONTENTS_URL, json=_base_content_payload(slug="dup-slug"), headers=cms_headers)
    resp = client.post(
        CONTENTS_URL, json=_base_content_payload(slug="dup-slug"), headers=cms_headers
    )
    assert resp.status_code == 400


# --- READ ---


def test_read_content_item_by_id(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="read-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    resp = client.get(_content_url(content_id), headers=cms_headers)
    assert resp.status_code == 200
    assert api.parse(resp)["item"]["id"] == content_id


def test_read_nonexistent_content_returns_404(client, cms_headers):
    resp = client.get(_content_url(999999), headers=cms_headers)
    assert resp.status_code == 404


def test_list_contents_returns_items_list(client, cms_headers, api):
    client.post(
        CONTENTS_URL, json=_base_content_payload(slug="list-test-lesson"), headers=cms_headers
    )
    resp = client.get(CONTENTS_URL, headers=cms_headers)
    assert resp.status_code == 200
    body = api.parse(resp)
    assert "items" in body
    assert "pagination" in body
    slugs = [item["slug"] for item in body["items"]]
    assert "list-test-lesson" in slugs


# --- UPDATE ---


def test_update_content_title(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="update-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    resp = client.patch(
        _content_url(content_id), json={"title_en": "Updated Title"}, headers=cms_headers
    )
    assert resp.status_code == 200
    assert api.parse(resp)["item"]["title_en"] == "Updated Title"


def test_update_content_status_to_review(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="review-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    resp = client.patch(_content_url(content_id), json={"status": "review"}, headers=cms_headers)
    assert resp.status_code == 200
    assert api.parse(resp)["item"]["status"] == "review"


# --- PUBLISH WORKFLOW ---


def test_publish_draft_content(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="publish-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    resp = client.post(_publish_url(content_id), headers=cms_headers)
    assert resp.status_code == 200
    item = api.parse(resp)["item"]
    assert item["status"] == "published"
    assert item["published_at"] is not None


def test_cannot_publish_content_missing_body(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json={
            "title_en": "No Body",
            "title_ar": "لا نص",
            "slug": "no-body-lesson",
            "content_type": "lesson",
            "status": "draft",
        },
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    resp = client.post(_publish_url(content_id), headers=cms_headers)
    assert resp.status_code == 400


def test_unpublish_published_content(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="unpublish-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    client.post(_publish_url(content_id), headers=cms_headers)
    resp = client.post(_unpublish_url(content_id), headers=cms_headers)
    assert resp.status_code == 200
    item = api.parse(resp)["item"]
    assert item["status"] == "ready"
    assert item["published_at"] is None


def test_create_content_as_published_directly(client, cms_headers, api):
    resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="direct-publish-lesson", status="published"),
        headers=cms_headers,
    )
    assert resp.status_code == 200
    item = api.parse(resp)["item"]
    assert item["status"] == "published"
    assert item["published_at"] is not None


# --- DELETE ---


def test_delete_content_item(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="delete-test-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    delete_resp = client.delete(_content_url(content_id), headers=cms_headers)
    assert delete_resp.status_code == 200
    assert api.parse(delete_resp)["success"] is True
    get_resp = client.get(_content_url(content_id), headers=cms_headers)
    assert get_resp.status_code == 404


def test_deleted_content_excluded_from_list(client, cms_headers, api):
    create_resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="excluded-lesson"),
        headers=cms_headers,
    )
    content_id = api.parse(create_resp)["item"]["id"]
    client.delete(_content_url(content_id), headers=cms_headers)
    resp = client.get(CONTENTS_URL, headers=cms_headers)
    slugs = [item["slug"] for item in api.parse(resp)["items"]]
    assert "excluded-lesson" not in slugs


# --- Permission enforcement ---


def test_support_admin_cannot_create_content(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="support.cms@example.invalid", role_names=["support_admin"])
    resp = client.post(
        CONTENTS_URL,
        json=_base_content_payload(slug="forbidden-lesson"),
        headers=admin_headers(admin),
    )
    assert resp.status_code == 403
