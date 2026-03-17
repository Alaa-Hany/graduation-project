"""add_ai_buddy_sessions_and_messages

Revision ID: f1b2c3d4e5f6
Revises: e1a5c7b9d3f2
Create Date: 2026-03-17 18:05:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "f1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "e1a5c7b9d3f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ai_buddy_sessions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("parent_user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default=sa.text("'active'")),
        sa.Column("title", sa.String(), nullable=True),
        sa.Column(
            "provider_mode",
            sa.String(),
            nullable=False,
            server_default=sa.text("'internal_fallback'"),
        ),
        sa.Column(
            "provider_status",
            sa.String(),
            nullable=False,
            server_default=sa.text("'fallback'"),
        ),
        sa.Column("unavailable_reason", sa.String(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("retention_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["parent_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("ai_buddy_sessions", schema=None) as batch_op:
        for name in (
            "id",
            "child_id",
            "parent_user_id",
            "status",
            "provider_mode",
            "provider_status",
            "started_at",
            "last_message_at",
            "ended_at",
            "retention_expires_at",
            "archived_at",
        ):
            batch_op.create_index(batch_op.f(f"ix_ai_buddy_sessions_{name}"), [name], unique=False)

    op.create_table(
        "ai_buddy_messages",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(), nullable=False),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("intent", sa.String(), nullable=True),
        sa.Column(
            "response_source",
            sa.String(),
            nullable=False,
            server_default=sa.text("'internal_fallback'"),
        ),
        sa.Column("status", sa.String(), nullable=False, server_default=sa.text("'completed'")),
        sa.Column("client_message_id", sa.String(), nullable=True),
        sa.Column("safety_status", sa.String(), nullable=False, server_default=sa.text("'allowed'")),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["ai_buddy_sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("ai_buddy_messages", schema=None) as batch_op:
        for name in (
            "id",
            "session_id",
            "child_id",
            "role",
            "intent",
            "response_source",
            "status",
            "client_message_id",
            "safety_status",
            "created_at",
        ):
            batch_op.create_index(batch_op.f(f"ix_ai_buddy_messages_{name}"), [name], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("ai_buddy_messages", schema=None) as batch_op:
        for name in (
            "created_at",
            "safety_status",
            "client_message_id",
            "status",
            "response_source",
            "intent",
            "role",
            "child_id",
            "session_id",
            "id",
        ):
            batch_op.drop_index(batch_op.f(f"ix_ai_buddy_messages_{name}"))
    op.drop_table("ai_buddy_messages")

    with op.batch_alter_table("ai_buddy_sessions", schema=None) as batch_op:
        for name in (
            "archived_at",
            "retention_expires_at",
            "ended_at",
            "last_message_at",
            "started_at",
            "provider_status",
            "provider_mode",
            "status",
            "parent_user_id",
            "child_id",
            "id",
        ):
            batch_op.drop_index(batch_op.f(f"ix_ai_buddy_sessions_{name}"))
    op.drop_table("ai_buddy_sessions")
