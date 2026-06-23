"""add refresh token rotation fields to users

Revision ID: i5b8f3a2d9c1
Revises: f7a8b9c0d1e2
Create Date: 2026-06-24 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "i5b8f3a2d9c1"
down_revision: Union[str, Sequence[str], None] = "f7a8b9c0d1e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("refresh_token_hash", sa.String(), nullable=True))
    op.add_column(
        "users",
        sa.Column(
            "refresh_token_expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "refresh_token_expires_at")
    op.drop_column("users", "refresh_token_hash")
