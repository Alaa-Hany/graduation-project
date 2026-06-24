"""add billing_interval column to subscription_profiles for monthly/yearly recurring plans

Revision ID: bc2d3e4f5061
Revises: ab1c2d3e4f50
Create Date: 2026-06-20 09:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "bc2d3e4f5061"
down_revision: Union[str, Sequence[str], None] = "ab1c2d3e4f50"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "subscription_profiles"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {col["name"] for col in inspector.get_columns(_TABLE)}

    if "billing_interval" not in existing_columns:
        with op.batch_alter_table(_TABLE, schema=None) as batch_op:
            batch_op.add_column(
                sa.Column(
                    "billing_interval",
                    sa.String(),
                    nullable=False,
                    server_default=sa.text("'monthly'"),
                )
            )


def downgrade() -> None:
    with op.batch_alter_table(_TABLE, schema=None) as batch_op:
        batch_op.drop_column("billing_interval")
