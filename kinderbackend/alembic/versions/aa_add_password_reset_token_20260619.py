"""add password reset token fields to users

Revision ID: aa_add_pw_reset_token_20260619
Revises: zz_merge_all_heads_20260618
Create Date: 2026-06-19 00:00:00.000000

Note: the revision id is intentionally kept to 30 characters. Alembic's
default `alembic_version.version_num` column is VARCHAR(32); the original
id used here ("aa_add_password_reset_token_20260619", 36 chars) overflowed
that column and made every upgrade fail with StringDataRightTruncation.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "aa_add_pw_reset_token_20260619"
down_revision: Union[str, Sequence[str], None] = "zz_merge_all_heads_20260618"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("password_reset_token_hash", sa.String(), nullable=True))
    op.add_column(
        "users",
        sa.Column(
            "password_reset_token_expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "password_reset_token_expires_at")
    op.drop_column("users", "password_reset_token_hash")
