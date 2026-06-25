"""add gamification_state snapshot column to child_profiles

Revision ID: p12_child_gam_state_20260625
Revises: o11_child_pw_reset_20260625
Create Date: 2026-06-25 00:00:00.000000

Note: the revision id is kept under 32 characters because Alembic's default
`alembic_version.version_num` column is VARCHAR(32).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "p12_child_gam_state_20260625"
down_revision: Union[str, Sequence[str], None] = "o11_child_pw_reset_20260625"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "child_profiles",
        sa.Column("gamification_state", sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("child_profiles", "gamification_state")
