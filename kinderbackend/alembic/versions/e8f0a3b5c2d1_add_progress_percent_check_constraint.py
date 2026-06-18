"""Add CHECK constraint for progress_percent in lesson_progress table

Ensures that progress_percent is always between 0 and 100.

Revision ID: e8f0a3b5c2d1
Revises: d7e9f2c4a1b8
Create Date: 2026-06-17 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "e8f0a3b5c2d1"
down_revision: Union[str, Sequence[str], None] = "d7e9f2c4a1b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("lesson_progress", schema=None) as batch_op:
        batch_op.create_check_constraint(
            "ck_lesson_progress_percent_range",
            "progress_percent BETWEEN 0 AND 100",
        )


def downgrade() -> None:
    with op.batch_alter_table("lesson_progress", schema=None) as batch_op:
        batch_op.drop_constraint(
            "ck_lesson_progress_percent_range", type_="check"
        )
