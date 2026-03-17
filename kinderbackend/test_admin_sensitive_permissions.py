from __future__ import annotations

from dataclasses import replace

import admin_models  # noqa: F401
import core.admin_security as admin_security
from admin_models import Permission, Role, RolePermission


def _enable_sensitive_confirmations(monkeypatch):
    new_settings = replace(
        admin_security.settings,
        admin_sensitive_confirmation_required=True,
    )
    monkeypatch.setattr(admin_security, "settings", new_settings)


def _create_role_with_permissions(db, *, name: str, permissions: list[str]) -> Role:
    role = Role(name=name, description=f"Custom role: {name}")
    db.add(role)
    db.flush()
    for permission_name in permissions:
        permission = db.query(Permission).filter(Permission.name == permission_name).one()
        db.add(RolePermission(role_id=role.id, permission_id=permission.id))
    db.commit()
    db.refresh(role)
    return role


def test_admin_user_plan_override_requires_permission_and_confirmation(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    admin_headers,
    create_parent,
    monkeypatch,
):
    seed_builtin_rbac()
    _enable_sensitive_confirmations(monkeypatch)

    editor_role = _create_role_with_permissions(
        db,
        name="user_editor_only",
        permissions=["admin.users.edit"],
    )
    limited_admin = create_admin(
        email="limited.editor@example.com",
        role_ids=[editor_role.id],
    )
    parent = create_parent(email="plan.override.target@example.com")

    resp = client.patch(
        f"/admin/users/{parent.id}",
        json={"plan": "PREMIUM"},
        headers={
            **admin_headers(limited_admin),
            "X-Admin-Confirm": "CONFIRM",
            "X-Admin-Confirm-Action": "user.override_plan",
        },
    )
    assert resp.status_code == 403
    assert resp.json()["detail"]["code"] == "PERMISSION_DENIED"

    super_admin = create_admin(
        email="super.admin.permissions@example.com",
        role_names=["super_admin"],
    )
    resp = client.patch(
        f"/admin/users/{parent.id}",
        json={"plan": "PREMIUM"},
        headers=admin_headers(super_admin),
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "ADMIN_CONFIRMATION_REQUIRED"

    resp = client.patch(
        f"/admin/users/{parent.id}",
        json={"plan": "PREMIUM"},
        headers={
            **admin_headers(super_admin),
            "X-Admin-Confirm": "CONFIRM",
            "X-Admin-Confirm-Action": "user.override_plan",
        },
    )
    assert resp.status_code == 200
    assert resp.json()["item"]["plan"] == "PREMIUM"
