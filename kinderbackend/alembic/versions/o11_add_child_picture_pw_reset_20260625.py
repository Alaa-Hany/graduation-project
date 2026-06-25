"""add picture-password reset token fields to child_profiles

Revision ID: o11_child_pw_reset_20260625
Revises: n10_diag_view_perm_20260624
Create Date: 2026-06-25 00:00:00.000000

Note: the revision id is kept under 32 characters because Alembic's default
`alembic_version.version_num` column is VARCHAR(32).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "o11_child_pw_reset_20260625"
down_revision: Union[str, Sequence[str], None] = "n10_diag_view_perm_20260624"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "child_profiles",
        sa.Column("picture_password_reset_token_hash", sa.String(), nullable=True),
    )
    op.add_column(
        "child_profiles",
        sa.Column(
            "picture_password_reset_token_expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("child_profiles", "picture_password_reset_token_expires_at")
    op.drop_column("child_profiles", "picture_password_reset_token_hash")
