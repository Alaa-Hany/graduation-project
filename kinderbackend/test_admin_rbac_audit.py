"""
Exhaustive audit of the Admin RBAC system.

Complements the existing admin test suites by verifying, end to end:

* Each built-in role resolves to exactly the permission set declared in ROLE_DEFS.
* A read-side allow/deny matrix across every built-in role and every
  "view/manage" GET endpoint (Step 2: can access what they're allowed, blocked
  from what they're not).
* Sensitive-action confirmation gates disable / remove-role / update-permissions.
* Last-super-admin, self-disable and self-role-removal protections.
* token_version is bumped on password change and on disable.
* Audit-log rows are written for every mutating RBAC action.
* /admin/roles-matrix flags built-in roles whose DB permissions drift from ROLE_DEFS.
* Bootstrap creates the first super_admin only when no admins exist.
* The 2FA setup -> enable -> disable lifecycle.
* Guard test for orphaned permissions (defined but never enforced).
"""

from __future__ import annotations

import re
from dataclasses import replace
from pathlib import Path

import pytest

import admin_models  # noqa: F401
import core.admin_security as admin_security
from admin_models import AuditLog, Permission, Role, RolePermission
from core.admin_rbac import PERMISSION_DEFS, ROLE_DEFS
from core.two_factor import generate_totp_code

CONFIRM_HEADERS = {
    "X-Admin-Confirm": "CONFIRM",
}


def _enable_sensitive_confirmations(monkeypatch):
    new_settings = replace(
        admin_security.settings,
        admin_sensitive_confirmation_required=True,
    )
    monkeypatch.setattr(admin_security, "settings", new_settings)


# A representative GET endpoint for every "view/manage" permission.  These are
# side-effect free, so they can be hammered across all roles deterministically.
GET_ENDPOINT_BY_PERMISSION: dict[str, str] = {
    "admin.admins.manage": "/admin/admin-users",
    "admin.users.view": "/admin/users",
    "admin.children.view": "/admin/children",
    "admin.content.view": "/admin/categories",
    "admin.analytics.view": "/admin/analytics/overview",
    "admin.audit.view": "/admin/audit-logs",
    "admin.support.view": "/admin/support/tickets",
    "admin.subscription.view": "/admin/subscriptions",
    "admin.settings.edit": "/admin/settings",
}


# ---------------------------------------------------------------------------
# Step 2.1 — each role resolves to exactly its ROLE_DEFS permission set
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("role_name", sorted(ROLE_DEFS.keys()))
def test_builtin_role_has_exactly_declared_permissions(
    role_name, client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email=f"{role_name}@kinderworld.app", role_names=[role_name])

    me = client.get("/admin/auth/me", headers=admin_headers(admin))
    assert me.status_code == 200

    payload = me.json()["admin"]
    assert payload["roles"] == [role_name]
    assert sorted(payload["permissions"]) == sorted(ROLE_DEFS[role_name])


# ---------------------------------------------------------------------------
# Step 2.2 / 2.3 — allow/deny matrix over read-side endpoints, all roles
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("role_name", sorted(ROLE_DEFS.keys()))
def test_read_endpoint_matrix_allows_and_denies_per_role(
    role_name, client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email=f"matrix.{role_name}@kinderworld.app", role_names=[role_name])
    headers = admin_headers(admin)
    granted = set(ROLE_DEFS[role_name])

    for permission, path in GET_ENDPOINT_BY_PERMISSION.items():
        resp = client.get(path, headers=headers)
        if permission in granted:
            assert (
                resp.status_code != 403
            ), f"{role_name} should reach {path} (has {permission}); got 403"
        else:
            assert resp.status_code == 403, (
                f"{role_name} must be blocked from {path} (missing {permission}); "
                f"got {resp.status_code}"
            )
            assert resp.json()["detail"]["code"] == "PERMISSION_DENIED"


def test_no_role_admin_is_denied_all_rbac_management_endpoints(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    admin = create_admin(email="noroles@kinderworld.app")  # no roles at all
    headers = admin_headers(admin)

    for path in (
        "/admin/admin-users",
        "/admin/roles",
        "/admin/roles-matrix",
        "/admin/permissions",
    ):
        resp = client.get(path, headers=headers)
        assert resp.status_code == 403
        assert resp.json()["detail"]["code"] == "PERMISSION_DENIED"


# ---------------------------------------------------------------------------
# Step 3.2 — sensitive-action confirmation on RBAC mutations
# ---------------------------------------------------------------------------


def test_sensitive_confirmation_required_for_disable_remove_role_and_permissions(
    client, db, seed_builtin_rbac, create_admin, admin_headers, monkeypatch
):
    seed_builtin_rbac()
    _enable_sensitive_confirmations(monkeypatch)

    super_admin = create_admin(email="confirm.super@kinderworld.app", role_names=["super_admin"])
    # second super admin so last-super-admin guard never interferes
    create_admin(email="confirm.super2@kinderworld.app", role_names=["super_admin"])
    target = create_admin(email="confirm.target@kinderworld.app", role_names=["support_admin"])
    support_role = db.query(Role).filter(Role.name == "support_admin").one()
    headers = admin_headers(super_admin)

    # disable without confirmation -> 400
    resp = client.post(f"/admin/admin-users/{target.id}/disable", headers=headers)
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "ADMIN_CONFIRMATION_REQUIRED"

    # remove-role without confirmation -> 400
    resp = client.post(
        f"/admin/admin-users/{target.id}/remove-role",
        json={"role_id": support_role.id},
        headers=headers,
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "ADMIN_CONFIRMATION_REQUIRED"

    # update role permissions without confirmation -> 400
    resp = client.patch(
        f"/admin/roles/{support_role.id}/permissions",
        json={"permission_ids": []},
        headers=headers,
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "ADMIN_CONFIRMATION_REQUIRED"

    # with the right confirmation headers the actions go through
    resp = client.post(
        f"/admin/admin-users/{target.id}/remove-role",
        json={"role_id": support_role.id},
        headers={
            **headers,
            **CONFIRM_HEADERS,
            "X-Admin-Confirm-Action": "admin_user.remove_role",
        },
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Step 3.3 / 3.5 — last-super-admin and self-role-removal protections
# ---------------------------------------------------------------------------


def test_remove_role_protects_last_super_admin(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    sole_super = create_admin(email="sole.super.rr@kinderworld.app", role_names=["super_admin"])
    manager_role = Role(name="rbac_manager", description="manage only")
    db.add(manager_role)
    db.flush()
    manage_perm = db.query(Permission).filter(Permission.name == "admin.admins.manage").one()
    db.add(RolePermission(role_id=manager_role.id, permission_id=manage_perm.id))
    db.commit()
    manager = create_admin(email="rr.manager@kinderworld.app", role_ids=[manager_role.id])
    super_role = db.query(Role).filter(Role.name == "super_admin").one()

    resp = client.post(
        f"/admin/admin-users/{sole_super.id}/remove-role",
        json={"role_id": super_role.id},
        headers=admin_headers(manager),
    )
    assert resp.status_code == 400
    assert "last active super admin" in resp.json()["detail"]


def test_admin_cannot_remove_their_own_role(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    # two super admins so the last-super-admin guard is not the thing that fires
    actor = create_admin(email="selfrr.a@kinderworld.app", role_names=["super_admin"])
    create_admin(email="selfrr.b@kinderworld.app", role_names=["super_admin"])
    super_role = db.query(Role).filter(Role.name == "super_admin").one()

    resp = client.post(
        f"/admin/admin-users/{actor.id}/remove-role",
        json={"role_id": super_role.id},
        headers=admin_headers(actor),
    )
    assert resp.status_code == 400
    assert resp.json()["detail"] == "You cannot remove your own roles"


# ---------------------------------------------------------------------------
# Step 3.6 — token_version bumped on password change and on disable
# ---------------------------------------------------------------------------


def test_token_version_increments_on_password_change_and_disable(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    super_admin = create_admin(email="tv.super@kinderworld.app", role_names=["super_admin"])
    target = create_admin(email="tv.target@kinderworld.app", role_names=["support_admin"])
    headers = admin_headers(super_admin)

    assert target.token_version == 0

    resp = client.patch(
        f"/admin/admin-users/{target.id}",
        json={"password": "BrandNewPass123!"},
        headers=headers,
    )
    assert resp.status_code == 200
    db.refresh(target)
    assert target.token_version == 1

    resp = client.post(f"/admin/admin-users/{target.id}/disable", headers=headers)
    assert resp.status_code == 200
    db.refresh(target)
    assert target.token_version == 2
    assert target.is_active is False


def test_password_change_revokes_existing_admin_tokens(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    super_admin = create_admin(email="rev.super@kinderworld.app", role_names=["super_admin"])
    target = create_admin(email="rev.target@kinderworld.app", role_names=["support_admin"])
    target_headers = admin_headers(target)

    # token valid before the password change
    assert client.get("/admin/auth/me", headers=target_headers).status_code == 200

    resp = client.patch(
        f"/admin/admin-users/{target.id}",
        json={"password": "RotatedPass123!"},
        headers=admin_headers(super_admin),
    )
    assert resp.status_code == 200

    # old token now carries a stale token_version -> revoked
    revoked = client.get("/admin/auth/me", headers=target_headers)
    assert revoked.status_code == 401


# ---------------------------------------------------------------------------
# Step 3.7 — audit log written for every mutating RBAC action
# ---------------------------------------------------------------------------


def _audit_actions(db) -> set[str]:
    return {row.action for row in db.query(AuditLog).all()}


def test_audit_log_records_all_rbac_mutations(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    super_admin = create_admin(email="audit.super@kinderworld.app", role_names=["super_admin"])
    headers = admin_headers(super_admin)
    content_role = db.query(Role).filter(Role.name == "content_admin").one()

    # create admin user
    created = client.post(
        "/admin/admin-users",
        json={"email": "audit.new@kinderworld.app", "password": "NewAdminPass123!"},
        headers=headers,
    )
    assert created.status_code == 200
    new_id = created.json()["item"]["id"]

    # update admin user
    assert (
        client.patch(
            f"/admin/admin-users/{new_id}", json={"name": "Renamed"}, headers=headers
        ).status_code
        == 200
    )

    # assign + remove role
    assert (
        client.post(
            f"/admin/admin-users/{new_id}/assign-role",
            json={"role_id": content_role.id},
            headers=headers,
        ).status_code
        == 200
    )
    assert (
        client.post(
            f"/admin/admin-users/{new_id}/remove-role",
            json={"role_id": content_role.id},
            headers=headers,
        ).status_code
        == 200
    )

    # disable + enable
    assert client.post(f"/admin/admin-users/{new_id}/disable", headers=headers).status_code == 200
    assert client.post(f"/admin/admin-users/{new_id}/enable", headers=headers).status_code == 200

    # role create / update / update-permissions
    role_resp = client.post(
        "/admin/roles", json={"name": "auditor_role", "description": "x"}, headers=headers
    )
    assert role_resp.status_code == 200
    role_id = role_resp.json()["item"]["id"]
    assert (
        client.patch(
            f"/admin/roles/{role_id}", json={"description": "updated"}, headers=headers
        ).status_code
        == 200
    )
    view_perm = db.query(Permission).filter(Permission.name == "admin.content.view").one()
    assert (
        client.patch(
            f"/admin/roles/{role_id}/permissions",
            json={"permission_ids": [view_perm.id]},
            headers=headers,
        ).status_code
        == 200
    )

    actions = _audit_actions(db)
    for expected in {
        "admin_user.create",
        "admin_user.update",
        "admin_user.assign_role",
        "admin_user.remove_role",
        "admin_user.disable",
        "admin_user.enable",
        "role.create",
        "role.update",
        "role.update_permissions",
    }:
        assert expected in actions, f"missing audit action {expected}"


# ---------------------------------------------------------------------------
# Step 3.8 — roles-matrix flags drift from ROLE_DEFS
# ---------------------------------------------------------------------------


def test_roles_matrix_flags_builtin_drift(
    client, db, seed_builtin_rbac, create_admin, admin_headers
):
    seed_builtin_rbac()
    super_admin = create_admin(email="matrix.super@kinderworld.app", role_names=["super_admin"])
    # custom role so the "is_built_in == False / matches == None" branch is exercised
    custom = Role(name="custom_matrix_role", description="custom")
    db.add(custom)
    db.commit()
    headers = admin_headers(super_admin)

    resp = client.get("/admin/roles-matrix", headers=headers)
    assert resp.status_code == 200
    roles = {r["name"]: r for r in resp.json()["roles"]}

    # every built-in role matches its declared matrix initially
    for name in ROLE_DEFS:
        assert roles[name]["is_built_in"] is True
        assert roles[name]["matches_built_in_matrix"] is True
        assert sorted(roles[name]["expected_built_in_permissions"]) == sorted(ROLE_DEFS[name])

    # custom role is not evaluated against the matrix
    assert roles["custom_matrix_role"]["is_built_in"] is False
    assert roles["custom_matrix_role"]["matches_built_in_matrix"] is None

    # Drift the content_admin role by stripping a permission directly in the DB.
    content_role = db.query(Role).filter(Role.name == "content_admin").one()
    mapping = db.query(RolePermission).filter(RolePermission.role_id == content_role.id).first()
    db.delete(mapping)
    db.commit()

    resp = client.get("/admin/roles-matrix", headers=headers)
    assert resp.status_code == 200
    drifted = {r["name"]: r for r in resp.json()["roles"]}["content_admin"]
    assert drifted["matches_built_in_matrix"] is False
    assert drifted["permission_count"] == len(ROLE_DEFS["content_admin"]) - 1


# ---------------------------------------------------------------------------
# Step 3.9 — bootstrap creates the first super_admin only when none exist
# ---------------------------------------------------------------------------


def test_bootstrap_creates_first_super_admin_then_is_locked(client, db):
    status_before = client.get("/admin/auth/bootstrap/status")
    assert status_before.status_code == 200
    assert status_before.json()["can_bootstrap"] is True

    resp = client.post(
        "/admin/auth/bootstrap",
        json={
            "email": "founder@kinderworld.app",
            "password": "FounderPass123!",
            "name": "Founder",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body and "refresh_token" in body
    assert "super_admin" in body["admin"]["roles"]
    assert "admin.admins.manage" in body["admin"]["permissions"]

    # the bootstrapped admin can immediately use a privileged endpoint
    me_headers = {"Authorization": f"Bearer {body['access_token']}"}
    assert client.get("/admin/admin-users", headers=me_headers).status_code == 200

    # bootstrap is now closed
    status_after = client.get("/admin/auth/bootstrap/status")
    assert status_after.json()["can_bootstrap"] is False

    second = client.post(
        "/admin/auth/bootstrap",
        json={"email": "second@kinderworld.app", "password": "SecondPass123!"},
    )
    assert second.status_code == 409


# ---------------------------------------------------------------------------
# Step 3.10 — 2FA setup -> enable -> disable lifecycle
# ---------------------------------------------------------------------------


def test_two_factor_full_lifecycle(client, db, seed_builtin_rbac, create_admin, admin_headers):
    seed_builtin_rbac()
    admin = create_admin(email="twofa@kinderworld.app", role_names=["super_admin"])
    headers = admin_headers(admin)

    status0 = client.get("/admin/auth/2fa/status", headers=headers)
    assert status0.status_code == 200
    assert status0.json()["enabled"] is False

    setup = client.post("/admin/auth/2fa/setup", headers=headers)
    assert setup.status_code == 200
    secret = setup.json()["secret"]
    assert secret
    assert setup.json()["enabled"] is False  # not enabled until confirmed

    # wrong code is rejected
    bad = client.post("/admin/auth/2fa/enable", json={"code": "000000"}, headers=headers)
    assert bad.status_code == 422

    # correct TOTP code enables 2FA
    good = client.post(
        "/admin/auth/2fa/enable",
        json={"code": generate_totp_code(secret)},
        headers=headers,
    )
    assert good.status_code == 200
    assert good.json()["enabled"] is True
    assert good.json()["success"] is True

    enabled_status = client.get("/admin/auth/2fa/status", headers=headers)
    assert enabled_status.json()["enabled"] is True
    assert enabled_status.json()["confirmed_at"] is not None

    # login now requires a valid 2FA code
    db.refresh(admin)
    no_code = client.post(
        "/admin/auth/login",
        json={"email": admin.email, "password": "AdminPass123!"},
    )
    assert no_code.status_code == 401

    with_code = client.post(
        "/admin/auth/login",
        json={
            "email": admin.email,
            "password": "AdminPass123!",
            "two_factor_code": generate_totp_code(secret),
        },
    )
    assert with_code.status_code == 200

    # disable 2FA
    disabled = client.post("/admin/auth/2fa/disable", headers=headers)
    assert disabled.status_code == 200
    assert disabled.json()["enabled"] is False

    final_status = client.get("/admin/auth/2fa/status", headers=headers)
    assert final_status.json()["enabled"] is False


# ---------------------------------------------------------------------------
# Step 4 — orphaned permission guard (defined but never enforced)
# ---------------------------------------------------------------------------


def test_orphaned_permissions_are_exactly_the_known_set():
    """
    Every permission in PERMISSION_DEFS should be enforced by at least one
    require_permission()/ensure_permission() call, except for a documented
    allowlist.  This test fails loudly if a new orphan appears OR if a known
    orphan finally gets wired up (so the allowlist can be trimmed).
    """
    known_orphans = {"admin.reports.view"}

    routers_dir = Path(__file__).parent / "routers"
    enforced: set[str] = set()
    pattern = re.compile(r"(?:require_permission|permission_name=)\s*[(=]?\s*[\"']([^\"']+)[\"']")
    for source in routers_dir.glob("*.py"):
        for match in pattern.findall(source.read_text(encoding="utf-8")):
            enforced.add(match)

    defined = {name for name, _ in PERMISSION_DEFS}
    orphans = defined - enforced

    assert orphans == known_orphans, (
        f"Orphaned permission set changed. Now orphaned: {sorted(orphans)}. "
        f"Expected: {sorted(known_orphans)}."
    )
