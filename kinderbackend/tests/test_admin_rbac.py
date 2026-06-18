"""
Tests for admin RBAC permission enforcement.
"""
from __future__ import annotations
import pytest

CONTENT_LIST_URL = "/api/v1/admin/contents"
USERS_LIST_URL = "/api/v1/admin/users"
ANALYTICS_URL = "/api/v1/admin/analytics/overview"


def test_admin_without_permission_cannot_view_contents(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="norole@example.invalid")
    resp = client.get(CONTENT_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 403


def test_admin_without_permission_cannot_view_users(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="norole2@example.invalid")
    resp = client.get(USERS_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 403


def test_admin_without_permission_cannot_view_analytics(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="norole3@example.invalid")
    resp = client.get(ANALYTICS_URL, headers=admin_headers(admin))
    assert resp.status_code == 403


def test_content_admin_can_view_contents(
    client, db, seed_builtin_rbac, create_admin, admin_headers, api
):
    seed_builtin_rbac()
    admin = create_admin(email="content.admin@example.invalid", role_names=["content_admin"])
    resp = client.get(CONTENT_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 200
    body = api.parse(resp)
    assert "items" in body


def test_analytics_admin_can_view_analytics(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="analytics.admin@example.invalid", role_names=["analytics_admin"])
    resp = client.get(ANALYTICS_URL, headers=admin_headers(admin))
    assert resp.status_code == 200


def test_support_admin_cannot_view_contents(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="support.admin@example.invalid", role_names=["support_admin"])
    resp = client.get(CONTENT_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 403


def test_content_admin_cannot_view_analytics(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="content.admin2@example.invalid", role_names=["content_admin"])
    resp = client.get(ANALYTICS_URL, headers=admin_headers(admin))
    assert resp.status_code == 403


def test_super_admin_can_view_contents(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="super.admin1@example.invalid", role_names=["super_admin"])
    resp = client.get(CONTENT_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 200


def test_super_admin_can_view_users(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="super.admin2@example.invalid", role_names=["super_admin"])
    resp = client.get(USERS_LIST_URL, headers=admin_headers(admin))
    assert resp.status_code == 200


def test_super_admin_can_view_analytics(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="super.admin3@example.invalid", role_names=["super_admin"])
    resp = client.get(ANALYTICS_URL, headers=admin_headers(admin))
    assert resp.status_code == 200


def test_unauthenticated_request_is_rejected(client, db, seed_builtin_rbac):
    seed_builtin_rbac()
    resp = client.get(CONTENT_LIST_URL)
    assert resp.status_code in {401, 403}
