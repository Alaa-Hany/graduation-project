"""add parent_refresh_sessions (one refresh session per device)

Revision ID: r14_refresh_sessions_20261116
Revises: q13_summary_unlogged_20261116
Create Date: 2026-11-16 00:00:00.000000

Until now each parent had a single refresh-token slot on the users row, so
signing in on a second device silently logged the first one out, and one
reused token revoked every device. Sessions now live in their own table.

The old users.refresh_token_* columns are left in place: tokens issued before
this release are still accepted once and moved into a session row. They can be
dropped in a later migration.

Note: the revision id is kept under 32 characters because Alembic's default
`alembic_version.version_num` column is VARCHAR(32).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "r14_refresh_sessions_20261116"
down_revision: Union[str, Sequence[str], None] = "q13_summary_unlogged_20261116"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "parent_refresh_sessions"


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if _TABLE in inspector.get_table_names():
        return
    op.create_table(
        _TABLE,
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_parent_refresh_sessions_id", _TABLE, ["id"])
    op.create_index("ix_parent_refresh_sessions_user_id", _TABLE, ["user_id"])
    op.create_index("ix_parent_refresh_sessions_expires_at", _TABLE, ["expires_at"])
    op.create_index("ix_parent_refresh_sessions_revoked_at", _TABLE, ["revoked_at"])


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if _TABLE not in inspector.get_table_names():
        return
    op.drop_table(_TABLE)
