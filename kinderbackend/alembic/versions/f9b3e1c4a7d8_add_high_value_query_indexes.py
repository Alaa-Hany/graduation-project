"""add high value query indexes

Revision ID: f9b3e1c4a7d8
Revises: e5a1b7c9d2f4
Create Date: 2026-03-23 18:10:00.000000
"""

from alembic import op


# revision identifiers, used by Alembic.
revision = "f9b3e1c4a7d8"
down_revision = "e5a1b7c9d2f4"
branch_labels = None
# This migration adds indexes on subscription/billing tables created on a sibling
# Alembic branch, so it must wait for that branch to be applied first.
depends_on = "e1a5c7b9d3f2"


def upgrade() -> None:
    op.create_index(
        "ix_subscription_events_profile_occurred_at",
        "subscription_events",
        ["subscription_profile_id", "occurred_at"],
        unique=False,
    )
    op.create_index(
        "ix_billing_transactions_profile_effective_at",
        "billing_transactions",
        ["subscription_profile_id", "effective_at"],
        unique=False,
    )
    op.create_index(
        "ix_payment_attempts_profile_requested_at",
        "payment_attempts",
        ["subscription_profile_id", "requested_at"],
        unique=False,
    )
    op.create_index(
        "ix_child_profiles_parent_deleted_created_at",
        "child_profiles",
        ["parent_id", "deleted_at", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_child_session_logs_child_archived_started_at",
        "child_session_logs",
        ["child_id", "archived_at", "started_at"],
        unique=False,
    )
    op.create_index(
        "ix_child_activity_events_child_archived_occurred_at",
        "child_activity_events",
        ["child_id", "archived_at", "occurred_at"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_user_created_at",
        "notifications",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_notifications_user_is_read_created_at",
        "notifications",
        ["user_id", "is_read", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_audit_logs_entity_type_entity_id_created_at",
        "audit_logs",
        ["entity_type", "entity_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_audit_logs_entity_type_entity_id_created_at", table_name="audit_logs")
    op.drop_index("ix_notifications_user_is_read_created_at", table_name="notifications")
    op.drop_index("ix_notifications_user_created_at", table_name="notifications")
    op.drop_index(
        "ix_child_activity_events_child_archived_occurred_at",
        table_name="child_activity_events",
    )
    op.drop_index(
        "ix_child_session_logs_child_archived_started_at",
        table_name="child_session_logs",
    )
    op.drop_index(
        "ix_child_profiles_parent_deleted_created_at",
        table_name="child_profiles",
    )
    op.drop_index(
        "ix_payment_attempts_profile_requested_at",
        table_name="payment_attempts",
    )
    op.drop_index(
        "ix_billing_transactions_profile_effective_at",
        table_name="billing_transactions",
    )
    op.drop_index(
        "ix_subscription_events_profile_occurred_at",
        table_name="subscription_events",
    )
