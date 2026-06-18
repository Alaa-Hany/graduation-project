"""add_child_analytics_tables

Revision ID: d9a4f2c0b7e1
Revises: c12e6f8a9b41
Create Date: 2026-03-15 06:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d9a4f2c0b7e1"
down_revision: Union[str, Sequence[str], None] = "c12e6f8a9b41"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "child_session_logs",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.String(), nullable=True),
        sa.Column("source", sa.String(), server_default=sa.text("'app'"), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_session_logs", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_session_logs_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_session_logs_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_session_logs_session_id"), ["session_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_session_logs_started_at"), ["started_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_session_logs_ended_at"), ["ended_at"], unique=False)

    op.create_table(
        "child_activity_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(), nullable=False),
        sa.Column("source", sa.String(), server_default=sa.text("'app'"), nullable=False),
        sa.Column("activity_name", sa.String(), nullable=True),
        sa.Column("lesson_id", sa.String(), nullable=True),
        sa.Column("mood_value", sa.Integer(), nullable=True),
        sa.Column("achievement_key", sa.String(), nullable=True),
        sa.Column("points", sa.Integer(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_activity_events", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_activity_events_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_activity_events_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_activity_events_event_type"), ["event_type"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_activity_events_occurred_at"), ["occurred_at"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("child_activity_events", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_activity_events_occurred_at"))
        batch_op.drop_index(batch_op.f("ix_child_activity_events_event_type"))
        batch_op.drop_index(batch_op.f("ix_child_activity_events_child_id"))
        batch_op.drop_index(batch_op.f("ix_child_activity_events_id"))
    op.drop_table("child_activity_events")

    with op.batch_alter_table("child_session_logs", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_session_logs_ended_at"))
        batch_op.drop_index(batch_op.f("ix_child_session_logs_started_at"))
        batch_op.drop_index(batch_op.f("ix_child_session_logs_session_id"))
        batch_op.drop_index(batch_op.f("ix_child_session_logs_child_id"))
        batch_op.drop_index(batch_op.f("ix_child_session_logs_id"))
    op.drop_table("child_session_logs")
