"""add_child_tracking_core_tables

Revision ID: a8b7c6d5e4f3
Revises: f4c2d8a1b9e3
Create Date: 2026-03-15 15:40:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a8b7c6d5e4f3"
down_revision: Union[str, Sequence[str], None] = "f4c2d8a1b9e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "activity_sessions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("activity_type", sa.String(), nullable=False),
        sa.Column("source", sa.String(), server_default=sa.text("'app'"), nullable=False),
        sa.Column("context", sa.String(), nullable=True),
        sa.Column("session_key", sa.String(), nullable=True),
        sa.Column("status", sa.String(), server_default=sa.text("'active'"), nullable=False),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("activity_sessions", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_activity_sessions_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_activity_type"), ["activity_type"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_source"), ["source"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_status"), ["status"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_session_key"), ["session_key"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_started_at"), ["started_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_activity_sessions_ended_at"), ["ended_at"], unique=False)

    op.create_table(
        "lesson_progress",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("lesson_id", sa.String(), nullable=False),
        sa.Column("status", sa.String(), server_default=sa.text("'not_started'"), nullable=False),
        sa.Column("progress_percent", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("attempt_count", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("score", sa.Integer(), nullable=True),
        sa.Column("started_at", sa.DateTime(), nullable=True),
        sa.Column("last_activity_at", sa.DateTime(), nullable=True),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("child_id", "lesson_id", name="uq_lesson_progress_child_lesson"),
    )
    with op.batch_alter_table("lesson_progress", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_lesson_progress_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_lesson_progress_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_lesson_progress_lesson_id"), ["lesson_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_lesson_progress_status"), ["status"], unique=False)
        batch_op.create_index(batch_op.f("ix_lesson_progress_last_activity_at"), ["last_activity_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_lesson_progress_completed_at"), ["completed_at"], unique=False)

    op.create_table(
        "child_mood_entries",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("mood_category", sa.String(), nullable=False),
        sa.Column("mood_value", sa.Integer(), nullable=True),
        sa.Column("note", sa.String(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_mood_entries", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_mood_entries_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_mood_entries_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_mood_entries_mood_category"), ["mood_category"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_mood_entries_recorded_at"), ["recorded_at"], unique=False)

    op.create_table(
        "reward_redemptions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("reward_id", sa.String(), nullable=True),
        sa.Column("reward_name", sa.String(), nullable=False),
        sa.Column("points_spent", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("status", sa.String(), server_default=sa.text("'pending'"), nullable=False),
        sa.Column("requested_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("redeemed_at", sa.DateTime(), nullable=True),
        sa.Column("fulfilled_at", sa.DateTime(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("reward_redemptions", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_reward_redemptions_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_reward_id"), ["reward_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_status"), ["status"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_requested_at"), ["requested_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_redeemed_at"), ["redeemed_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_reward_redemptions_fulfilled_at"), ["fulfilled_at"], unique=False)

    op.create_table(
        "screen_time_logs",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("minutes_used", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("source", sa.String(), server_default=sa.text("'app'"), nullable=False),
        sa.Column("device_id", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=True),
        sa.Column("session_key", sa.String(), nullable=True),
        sa.Column("logged_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("screen_time_logs", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_screen_time_logs_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_usage_date"), ["usage_date"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_source"), ["source"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_device_id"), ["device_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_category"), ["category"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_session_key"), ["session_key"], unique=False)
        batch_op.create_index(batch_op.f("ix_screen_time_logs_logged_at"), ["logged_at"], unique=False)

    op.create_table(
        "ai_interactions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("interaction_type", sa.String(), nullable=False),
        sa.Column("intent", sa.String(), nullable=True),
        sa.Column("input_preview", sa.String(), nullable=True),
        sa.Column("response_category", sa.String(), nullable=True),
        sa.Column("safety_status", sa.String(), server_default=sa.text("'unknown'"), nullable=False),
        sa.Column("source", sa.String(), server_default=sa.text("'ai_buddy'"), nullable=False),
        sa.Column("safety_flags_json", sa.JSON(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("occurred_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("ai_interactions", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_ai_interactions_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_child_id"), ["child_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_interaction_type"), ["interaction_type"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_intent"), ["intent"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_safety_status"), ["safety_status"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_source"), ["source"], unique=False)
        batch_op.create_index(batch_op.f("ix_ai_interactions_occurred_at"), ["occurred_at"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("ai_interactions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_ai_interactions_occurred_at"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_source"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_safety_status"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_intent"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_interaction_type"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_child_id"))
        batch_op.drop_index(batch_op.f("ix_ai_interactions_id"))
    op.drop_table("ai_interactions")

    with op.batch_alter_table("screen_time_logs", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_logged_at"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_session_key"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_category"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_device_id"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_source"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_usage_date"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_child_id"))
        batch_op.drop_index(batch_op.f("ix_screen_time_logs_id"))
    op.drop_table("screen_time_logs")

    with op.batch_alter_table("reward_redemptions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_fulfilled_at"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_redeemed_at"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_requested_at"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_status"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_reward_id"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_child_id"))
        batch_op.drop_index(batch_op.f("ix_reward_redemptions_id"))
    op.drop_table("reward_redemptions")

    with op.batch_alter_table("child_mood_entries", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_mood_entries_recorded_at"))
        batch_op.drop_index(batch_op.f("ix_child_mood_entries_mood_category"))
        batch_op.drop_index(batch_op.f("ix_child_mood_entries_child_id"))
        batch_op.drop_index(batch_op.f("ix_child_mood_entries_id"))
    op.drop_table("child_mood_entries")

    with op.batch_alter_table("lesson_progress", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_lesson_progress_completed_at"))
        batch_op.drop_index(batch_op.f("ix_lesson_progress_last_activity_at"))
        batch_op.drop_index(batch_op.f("ix_lesson_progress_status"))
        batch_op.drop_index(batch_op.f("ix_lesson_progress_lesson_id"))
        batch_op.drop_index(batch_op.f("ix_lesson_progress_child_id"))
        batch_op.drop_index(batch_op.f("ix_lesson_progress_id"))
    op.drop_table("lesson_progress")

    with op.batch_alter_table("activity_sessions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_activity_sessions_ended_at"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_started_at"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_session_key"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_status"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_source"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_activity_type"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_child_id"))
        batch_op.drop_index(batch_op.f("ix_activity_sessions_id"))
    op.drop_table("activity_sessions")

