"""add_ai_buddy_safety_and_visibility_fields

Revision ID: a7d3c9e4f2b1
Revises: f1b2c3d4e5f6
Create Date: 2026-03-17 22:10:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "a7d3c9e4f2b1"
down_revision: Union[str, Sequence[str], None] = "f1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("ai_buddy_sessions", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "visibility_mode",
                sa.String(),
                nullable=False,
                server_default=sa.text("'summary_and_metrics'"),
            )
        )
        batch_op.add_column(sa.Column("parent_summary", sa.String(), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_ai_buddy_sessions_visibility_mode"),
            ["visibility_mode"],
            unique=False,
        )

    with op.batch_alter_table("ai_buddy_messages", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_ai_buddy_messages_retention_expires_at"),
            ["retention_expires_at"],
            unique=False,
        )
        batch_op.create_index(
            batch_op.f("ix_ai_buddy_messages_archived_at"),
            ["archived_at"],
            unique=False,
        )

    op.execute(
        sa.text(
            """
            UPDATE ai_buddy_sessions
            SET visibility_mode = 'summary_and_metrics',
                parent_summary = COALESCE(
                    parent_summary,
                    'Parents can review AI Buddy summaries and safety metrics. Full transcripts stay hidden by default.'
                )
            """
        )
    )


def downgrade() -> None:
    with op.batch_alter_table("ai_buddy_messages", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_ai_buddy_messages_archived_at"))
        batch_op.drop_index(batch_op.f("ix_ai_buddy_messages_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("ai_buddy_sessions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_ai_buddy_sessions_visibility_mode"))
        batch_op.drop_column("parent_summary")
        batch_op.drop_column("visibility_mode")
