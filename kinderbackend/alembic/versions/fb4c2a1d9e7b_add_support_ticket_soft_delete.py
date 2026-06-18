"""add support ticket soft delete

Revision ID: fb4c2a1d9e7b
Revises: fa2d9e4c1b7a
Create Date: 2026-03-24 00:20:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "fb4c2a1d9e7b"
down_revision: Union[str, Sequence[str], None] = "fa2d9e4c1b7a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("support_tickets", schema=None) as batch_op:
        batch_op.add_column(sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.create_index(batch_op.f("ix_support_tickets_deleted_at"), ["deleted_at"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("support_tickets", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_support_tickets_deleted_at"))
        batch_op.drop_column("deleted_at")
