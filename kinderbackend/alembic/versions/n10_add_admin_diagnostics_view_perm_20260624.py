"""seed admin.diagnostics.view permission and grant it to super_admin

Revision ID: n10_diag_view_perm_20260624
Revises: m9_published_at_idx_20260624
Create Date: 2026-06-24 10:00:00.000000

The /admin/diagnostics health/events/metrics GET endpoints used to require the
write permission admin.settings.edit. They now require a dedicated read
permission, admin.diagnostics.view. ensure_builtin_admin_rbac() only runs on
admin bootstrap / the seed endpoint, so existing deployments would not pick up
the new permission row (or its super_admin grant) until re-seeded. This migration
inserts both so diagnostics access is preserved without a manual re-seed.

admin.settings.edit is held only by super_admin, so super_admin is the single
role that receives admin.diagnostics.view here — preserving the previous access
boundary exactly. Idempotent.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "n10_diag_view_perm_20260624"
down_revision: Union[str, Sequence[str], None] = "m9_published_at_idx_20260624"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

PERMISSION_NAME = "admin.diagnostics.view"
PERMISSION_DESCRIPTION = "View operational diagnostics (health, events, metrics)"
ROLE_NAME = "super_admin"


def upgrade() -> None:
    bind = op.get_bind()

    permission_id = bind.execute(
        sa.text("SELECT id FROM permissions WHERE name = :name"),
        {"name": PERMISSION_NAME},
    ).scalar()
    if permission_id is None:
        bind.execute(
            sa.text(
                "INSERT INTO permissions (name, description) VALUES (:name, :description)"
            ),
            {"name": PERMISSION_NAME, "description": PERMISSION_DESCRIPTION},
        )
        permission_id = bind.execute(
            sa.text("SELECT id FROM permissions WHERE name = :name"),
            {"name": PERMISSION_NAME},
        ).scalar()

    role_id = bind.execute(
        sa.text("SELECT id FROM roles WHERE name = :name"),
        {"name": ROLE_NAME},
    ).scalar()
    if role_id is None:
        return  # super_admin not seeded yet; ensure_builtin_admin_rbac will grant it later

    already_mapped = bind.execute(
        sa.text(
            "SELECT 1 FROM role_permissions "
            "WHERE role_id = :role_id AND permission_id = :permission_id"
        ),
        {"role_id": role_id, "permission_id": permission_id},
    ).scalar()
    if already_mapped is None:
        bind.execute(
            sa.text(
                "INSERT INTO role_permissions (role_id, permission_id) "
                "VALUES (:role_id, :permission_id)"
            ),
            {"role_id": role_id, "permission_id": permission_id},
        )


def downgrade() -> None:
    bind = op.get_bind()
    permission_id = bind.execute(
        sa.text("SELECT id FROM permissions WHERE name = :name"),
        {"name": PERMISSION_NAME},
    ).scalar()
    if permission_id is None:
        return
    bind.execute(
        sa.text("DELETE FROM role_permissions WHERE permission_id = :permission_id"),
        {"permission_id": permission_id},
    )
    bind.execute(
        sa.text("DELETE FROM permissions WHERE id = :permission_id"),
        {"permission_id": permission_id},
    )
