"""add_child_parental_controls_tables

Revision ID: e7f3c1a9d2b4
Revises: d9a4f2c0b7e1
Create Date: 2026-03-15 07:05:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e7f3c1a9d2b4"
down_revision: Union[str, Sequence[str], None] = "d9a4f2c0b7e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "child_parental_control_settings",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("parent_id", sa.Integer(), nullable=False),
        sa.Column("child_id", sa.Integer(), nullable=False),
        sa.Column("daily_limit_enabled", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("daily_limit_minutes", sa.Integer(), server_default=sa.text("120"), nullable=False),
        sa.Column("break_reminders_enabled", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("age_appropriate_only", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("require_approval", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("sleep_mode", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("bedtime_start", sa.String(), nullable=True),
        sa.Column("bedtime_end", sa.String(), nullable=True),
        sa.Column("emergency_lock", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("enforcement_mode", sa.String(), server_default=sa.text("'monitor'"), nullable=False),
        sa.Column("device_status", sa.String(), server_default=sa.text("'unknown'"), nullable=False),
        sa.Column("pending_changes", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("last_synced_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["child_id"], ["child_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["parent_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("child_id"),
    )
    with op.batch_alter_table("child_parental_control_settings", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_parental_control_settings_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_parental_control_settings_parent_id"), ["parent_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_parental_control_settings_child_id"), ["child_id"], unique=False)

    op.create_table(
        "child_schedule_rules",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("setting_id", sa.Integer(), nullable=False),
        sa.Column("day_of_week", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.String(), nullable=False),
        sa.Column("end_time", sa.String(), nullable=False),
        sa.Column("is_allowed", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["setting_id"], ["child_parental_control_settings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_schedule_rules_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_schedule_rules_setting_id"), ["setting_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_schedule_rules_day_of_week"), ["day_of_week"], unique=False)

    op.create_table(
        "child_blocked_apps",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("setting_id", sa.Integer(), nullable=False),
        sa.Column("app_identifier", sa.String(), nullable=False),
        sa.Column("app_name", sa.String(), nullable=True),
        sa.Column("reason", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["setting_id"], ["child_parental_control_settings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_blocked_apps", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_blocked_apps_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_blocked_apps_setting_id"), ["setting_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_blocked_apps_app_identifier"), ["app_identifier"], unique=False)

    op.create_table(
        "child_blocked_sites",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("setting_id", sa.Integer(), nullable=False),
        sa.Column("domain", sa.String(), nullable=False),
        sa.Column("label", sa.String(), nullable=True),
        sa.Column("reason", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["setting_id"], ["child_parental_control_settings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("child_blocked_sites", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_child_blocked_sites_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_blocked_sites_setting_id"), ["setting_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_child_blocked_sites_domain"), ["domain"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("child_blocked_sites", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_blocked_sites_domain"))
        batch_op.drop_index(batch_op.f("ix_child_blocked_sites_setting_id"))
        batch_op.drop_index(batch_op.f("ix_child_blocked_sites_id"))
    op.drop_table("child_blocked_sites")

    with op.batch_alter_table("child_blocked_apps", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_blocked_apps_app_identifier"))
        batch_op.drop_index(batch_op.f("ix_child_blocked_apps_setting_id"))
        batch_op.drop_index(batch_op.f("ix_child_blocked_apps_id"))
    op.drop_table("child_blocked_apps")

    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_schedule_rules_day_of_week"))
        batch_op.drop_index(batch_op.f("ix_child_schedule_rules_setting_id"))
        batch_op.drop_index(batch_op.f("ix_child_schedule_rules_id"))
    op.drop_table("child_schedule_rules")

    with op.batch_alter_table("child_parental_control_settings", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_child_parental_control_settings_child_id"))
        batch_op.drop_index(batch_op.f("ix_child_parental_control_settings_parent_id"))
        batch_op.drop_index(batch_op.f("ix_child_parental_control_settings_id"))
    op.drop_table("child_parental_control_settings")
