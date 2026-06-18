"""convert_datetimes_to_timezone_aware

Revision ID: c4f2e7a1b8d9
Revises: f4c2d8a1b9e3
Create Date: 2026-03-15 21:20:00.000000

"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from typing import Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c4f2e7a1b8d9"
down_revision: Union[str, Sequence[str], None] = ("b2d4f6a8c0e1", "c12e6f8a9b41")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


TIMESTAMP_COLUMNS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "admin_users",
        ("last_login_at", "last_failed_login_at", "locked_until", "created_at", "updated_at"),
    ),
    ("roles", ("created_at",)),
    ("permissions", ("created_at",)),
    ("audit_logs", ("created_at",)),
    ("users", ("parent_pin_locked_until", "parent_pin_updated_at", "created_at", "updated_at")),
    ("child_profiles", ("created_at", "updated_at", "deleted_at")),
    (
        "child_session_logs",
        ("started_at", "ended_at", "retention_expires_at", "archived_at", "created_at"),
    ),
    ("child_activity_events", ("occurred_at", "retention_expires_at", "archived_at", "created_at")),
    (
        "activity_sessions",
        (
            "started_at",
            "ended_at",
            "retention_expires_at",
            "archived_at",
            "created_at",
            "updated_at",
        ),
    ),
    (
        "lesson_progress",
        ("started_at", "last_activity_at", "completed_at", "created_at", "updated_at"),
    ),
    ("child_mood_entries", ("recorded_at", "created_at")),
    (
        "reward_redemptions",
        ("requested_at", "redeemed_at", "fulfilled_at", "created_at", "updated_at"),
    ),
    ("screen_time_logs", ("logged_at", "retention_expires_at", "archived_at", "created_at")),
    ("ai_interactions", ("occurred_at", "retention_expires_at", "archived_at", "created_at")),
    (
        "child_daily_activity_summaries",
        ("last_event_at", "created_at", "updated_at", "archived_at"),
    ),
    ("notifications", ("created_at",)),
    ("support_tickets", ("closed_at", "created_at", "updated_at")),
    ("support_ticket_messages", ("created_at",)),
    ("categories", ("created_at", "updated_at", "deleted_at")),
    ("contents", ("published_at", "created_at", "updated_at", "deleted_at")),
    ("quizzes", ("published_at", "created_at", "updated_at", "deleted_at")),
    ("system_settings", ("updated_at",)),
    ("parental_controls", ("created_at", "updated_at")),
    ("child_parental_control_settings", ("last_synced_at", "created_at", "updated_at")),
    ("child_schedule_rules", ("created_at",)),
    ("child_blocked_apps", ("created_at",)),
    ("child_blocked_sites", ("created_at",)),
    ("payment_methods", ("deleted_at", "created_at")),
)


def _iter_columns() -> Iterable[tuple[str, str]]:
    for table_name, columns in TIMESTAMP_COLUMNS:
        for column_name in columns:
            yield table_name, column_name


def _normalize_sqlite_values() -> None:
    connection = op.get_bind()
    for table_name, column_name in _iter_columns():
        connection.execute(
            sa.text(
                f"""
                UPDATE "{table_name}"
                SET "{column_name}" = CASE
                    WHEN "{column_name}" IS NULL THEN NULL
                    WHEN substr("{column_name}", -1) = 'Z' THEN "{column_name}"
                    WHEN substr("{column_name}", -6, 1) IN ('+', '-') THEN "{column_name}"
                    ELSE "{column_name}" || '+00:00'
                END
                WHERE "{column_name}" IS NOT NULL
                """
            )
        )


def _denormalize_sqlite_values() -> None:
    connection = op.get_bind()
    for table_name, column_name in _iter_columns():
        connection.execute(
            sa.text(
                f"""
                UPDATE "{table_name}"
                SET "{column_name}" = CASE
                    WHEN "{column_name}" IS NULL THEN NULL
                    WHEN substr("{column_name}", -1) = 'Z' THEN substr("{column_name}", 1, length("{column_name}") - 1)
                    WHEN substr("{column_name}", -6, 1) IN ('+', '-') THEN substr("{column_name}", 1, length("{column_name}") - 6)
                    ELSE "{column_name}"
                END
                WHERE "{column_name}" IS NOT NULL
                """
            )
        )


def _upgrade_postgres() -> None:
    for table_name, column_name in _iter_columns():
        op.alter_column(
            table_name,
            column_name,
            existing_type=sa.DateTime(),
            type_=sa.DateTime(timezone=True),
            postgresql_using=f"\"{column_name}\" AT TIME ZONE 'UTC'",
        )


def _downgrade_postgres() -> None:
    for table_name, column_name in _iter_columns():
        op.alter_column(
            table_name,
            column_name,
            existing_type=sa.DateTime(timezone=True),
            type_=sa.DateTime(),
            postgresql_using=f"\"{column_name}\" AT TIME ZONE 'UTC'",
        )


def _upgrade_sqlite() -> None:
    _normalize_sqlite_values()
    for table_name, columns in TIMESTAMP_COLUMNS:
        with op.batch_alter_table(table_name, schema=None) as batch_op:
            for column_name in columns:
                batch_op.alter_column(
                    column_name,
                    existing_type=sa.DateTime(),
                    type_=sa.DateTime(timezone=True),
                )


def _downgrade_sqlite() -> None:
    _denormalize_sqlite_values()
    for table_name, columns in TIMESTAMP_COLUMNS:
        with op.batch_alter_table(table_name, schema=None) as batch_op:
            for column_name in columns:
                batch_op.alter_column(
                    column_name,
                    existing_type=sa.DateTime(timezone=True),
                    type_=sa.DateTime(),
                )


def upgrade() -> None:
    dialect_name = op.get_bind().dialect.name
    if dialect_name == "postgresql":
        _upgrade_postgres()
        return
    if dialect_name == "sqlite":
        _upgrade_sqlite()
        return
    raise RuntimeError(f"Unsupported dialect for timezone migration: {dialect_name}")


def downgrade() -> None:
    dialect_name = op.get_bind().dialect.name
    if dialect_name == "postgresql":
        _downgrade_postgres()
        return
    if dialect_name == "sqlite":
        _downgrade_sqlite()
        return
    raise RuntimeError(f"Unsupported dialect for timezone migration: {dialect_name}")
