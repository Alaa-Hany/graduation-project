"""add updated_at to payment_methods

Revision ID: k7_add_pm_updated_at_20260624
Revises: j6_add_pm_expires_at_20260624
Create Date: 2026-06-24 08:00:00.000000

The PaymentMethod model defines `updated_at` (server_default=func.now(),
onupdate=func.now()), but no migration ever created it — the initial schema
only created `created_at`, and later migrations added `deleted_at`/`expires_at`
without ever touching `updated_at`. Production Postgres therefore lacks
`payment_methods.updated_at`, so every SELECT against the table raised
`UndefinedColumn` (500s on GET /api/v1/reports/basic, and a swallowed sync
warning on POST /api/v1/subscription/checkout).

This adds the missing column, backfilling existing rows from `created_at` so
the NOT NULL + onupdate semantics hold going forward. Idempotent (guarded by
an inspector check), matching j6_add_pm_expires_at_20260624.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "k7_add_pm_updated_at_20260624"
down_revision: Union[str, Sequence[str], None] = "j6_add_pm_expires_at_20260624"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(col["name"] == column for col in inspector.get_columns(table))


def upgrade() -> None:
    if not _has_column("payment_methods", "updated_at"):
        op.add_column(
            "payment_methods",
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.execute(
            "UPDATE payment_methods SET updated_at = created_at WHERE updated_at IS NULL"
        )
        with op.batch_alter_table("payment_methods", schema=None) as batch_op:
            batch_op.alter_column(
                "updated_at",
                existing_type=sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            )


def downgrade() -> None:
    if _has_column("payment_methods", "updated_at"):
        op.drop_column("payment_methods", "updated_at")
