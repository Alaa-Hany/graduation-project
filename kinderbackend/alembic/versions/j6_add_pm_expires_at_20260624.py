"""add expires_at to payment_methods

Revision ID: j6_add_pm_expires_at_20260624
Revises: i5b8f3a2d9c1
Create Date: 2026-06-24 02:00:00.000000

The PaymentMethod model was refactored from (exp_month, exp_year) to a single
`expires_at` column, but no migration was created for it. Production Postgres
therefore still lacks `payment_methods.expires_at`, so every SELECT against the
table raised `UndefinedColumn` and turned GET /api/v1/subscription/me into a
500 (the access-plans page showed a generic error instead of the plans).

This adds the missing column. It is intentionally idempotent (guarded by an
inspector check) so it is safe to run against databases that already have the
column — e.g. fresh schemas built from the ORM via create_all.

Note: the revision id is kept under 32 chars to fit alembic's default
`alembic_version.version_num` VARCHAR(32) column.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "j6_add_pm_expires_at_20260624"
down_revision: Union[str, Sequence[str], None] = "i5b8f3a2d9c1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(col["name"] == column for col in inspector.get_columns(table))


def upgrade() -> None:
    if not _has_column("payment_methods", "expires_at"):
        op.add_column(
            "payment_methods",
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        )


def downgrade() -> None:
    if _has_column("payment_methods", "expires_at"):
        op.drop_column("payment_methods", "expires_at")
