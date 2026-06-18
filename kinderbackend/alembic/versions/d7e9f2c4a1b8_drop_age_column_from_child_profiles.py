"""drop age column from child_profiles

Age is now computed from date_of_birth via a Python property.

Revision ID: d7e9f2c4a1b8
Revises: c8d9e0f1a2b3
Create Date: 2026-06-17 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "d7e9f2c4a1b8"
down_revision: Union[str, Sequence[str], None] = "c8d9e0f1a2b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.drop_column("age")


def downgrade() -> None:
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("age", sa.Integer(), nullable=True))
