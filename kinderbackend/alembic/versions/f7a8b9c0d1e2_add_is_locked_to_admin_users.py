"""add is_locked column to admin_users

Revision ID: f7a8b9c0d1e2
Revises: d1e2f3a4b5c6
Create Date: 2026-06-22 00:05:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f7a8b9c0d1e2"
down_revision: Union[str, Sequence[str], None] = "d1e2f3a4b5c6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "is_locked",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.drop_column("is_locked")
