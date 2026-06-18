"""add_data_lifecycle_and_daily_summary

Revision ID: b2d4f6a8c0e1
Revises: a8b7c6d5e4f3
Create Date: 2026-03-15 17:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b2d4f6a8c0e1"
down_revision: Union[str, Sequence[str], None] = "a8b7c6d5e4f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("deleted_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_child_profiles_deleted_at"), ["deleted_at"], unique=False)

    with op.batch_alter_table("payment_methods", schema=None) as batch_op:
        batch_op.add_column(sa.Column("deleted_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_payment_methods_deleted_at"), ["deleted_at"], unique=False)

    with op.batch_alter_table("child_session_logs", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_child_session_logs_retention_expires_at"), ["retention_expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_session_logs_archived_at"), ["archived_at"], unique=False)

    with op.batch_alter_table("child_activity_events", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_child_activity_events_retention_expires_at"), ["retention_expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_activity_events_archived_at"), ["archived_at"], unique=False)

    with op.batch_alter_table("activity_sessions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_activity_sessions_retention_expires_at"), ["retention_expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_archived_at"), ["archived_at"], unique=False)

    with op.batch_alter_table("screen_time_logs", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_screen_time_logs_retention_expires_at"), ["retention_expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_archived_at"), ["archived_at"], unique=False)

    with op.batch_alter_table("ai_interactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("retention_expires_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("archived_at", sa.DateTime(), nullable=True))
        batch_op.create_index(batch_op.f("ix_ai_interactions_retention_expires_at"), ["retention_expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_archived_at"), ["archived_at"], unique=False)

    op.create_table(
        "child_daily_activity_summaries",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("summary_date", sa.Date(), nullable=False),
        sa.Column("screen_time_minutes", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("activities_completed", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("lessons_completed", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("mood_entries", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("achievements_unlocked", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("ai_interactions_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("data_source", sa.String(), server_default=sa.text("'realtime'"), nullable=False),
        sa.Column("last_event_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("archived_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("child_id", "summary_date", name="uq_child_daily_activity_summary"),
    )
    with op.batch_alter_table("child_daily_activity_summaries", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_daily_activity_summaries_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_daily_activity_summaries_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_daily_activity_summaries_summary_date"), ["summary_date"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_daily_activity_summaries_last_event_at"), ["last_event_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_daily_activity_summaries_archived_at"), ["archived_at"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("child_daily_activity_summaries", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_daily_activity_summaries_archived_at"))
        batch_op.drop_index(batch_op.f("ix_child_daily_activity_summaries_last_event_at"))
        batch_op.drop_index(batch_op.f("ix_child_daily_activity_summaries_summary_date"))
        batch_op.drop_index(batch_op.f("ix_child_daily_activity_summaries_child_id"))
        batch_op.drop_index(batch_op.f("ix_child_daily_activity_summaries_id"))
    op.drop_table("child_daily_activity_summaries")

    with op.batch_alter_table("ai_interactions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_ai_interactions_archived_at"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("screen_time_logs", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_archived_at"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("activity_sessions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_activity_sessions_archived_at"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("child_activity_events", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_activity_events_archived_at"))
        batch_op.drop_index(batch_op.f("ix_child_activity_events_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("child_session_logs", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_session_logs_archived_at"))
        batch_op.drop_index(batch_op.f("ix_child_session_logs_retention_expires_at"))
        batch_op.drop_column("archived_at")
        batch_op.drop_column("retention_expires_at")

    with op.batch_alter_table("payment_methods", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_payment_methods_deleted_at"))
        batch_op.drop_column("deleted_at")

    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_profiles_deleted_at"))
        batch_op.drop_column("deleted_at")

