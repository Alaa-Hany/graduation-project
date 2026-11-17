"""add unlogged_* totals to child_daily_activity_summaries

Revision ID: q13_summary_unlogged_20261116
Revises: p12_child_gam_state_20260625
Create Date: 2026-11-16 00:00:00.000000

When a parent turns off analytics (analytics_enabled=false or
data_collection_opt_out=true), individual activity events and session logs are
no longer stored. Only these per-day totals are kept, so the parent dashboard
can still show XP, activity count and time spent without event-level detail.

Note: the revision id is kept under 32 characters because Alembic's default
`alembic_version.version_num` column is VARCHAR(32).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "q13_summary_unlogged_20261116"
down_revision: Union[str, Sequence[str], None] = "p12_child_gam_state_20260625"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "child_daily_activity_summaries"
_COLUMNS = ("unlogged_points", "unlogged_activities", "unlogged_screen_seconds")


def _existing_columns() -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(_TABLE)}


def upgrade() -> None:
    existing = _existing_columns()
    for name in _COLUMNS:
        if name not in existing:
            op.add_column(
                _TABLE,
                sa.Column(name, sa.Integer(), nullable=False, server_default=sa.text("0")),
            )


def downgrade() -> None:
    existing = _existing_columns()
    for name in reversed(_COLUMNS):
        if name in existing:
            op.drop_column(_TABLE, name)
