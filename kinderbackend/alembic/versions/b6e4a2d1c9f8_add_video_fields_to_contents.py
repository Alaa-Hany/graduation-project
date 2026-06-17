"""add video fields to contents

Revision ID: b6e4a2d1c9f8
Revises: a1c3f5e7b9d2
Create Date: 2026-04-25 21:15:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "b6e4a2d1c9f8"
down_revision: Union[str, Sequence[str], None] = "a1c3f5e7b9d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("contents", schema=None) as batch_op:
        batch_op.add_column(sa.Column("video_url", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("video_provider", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("video_public_id", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("video_duration_seconds", sa.Integer(), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_contents_video_public_id"),
            ["video_public_id"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("contents", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_contents_video_public_id"))
        batch_op.drop_column("video_duration_seconds")
        batch_op.drop_column("video_public_id")
        batch_op.drop_column("video_provider")
        batch_op.drop_column("video_url")
