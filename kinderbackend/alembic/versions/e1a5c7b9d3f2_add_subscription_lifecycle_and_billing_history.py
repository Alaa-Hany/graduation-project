"""add_subscription_lifecycle_and_billing_history

Revision ID: e1a5c7b9d3f2
Revises: c4f2e7a1b8d9, 1d9c4b7a2f31
Create Date: 2026-03-17 13:10:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "e1a5c7b9d3f2"
down_revision: Union[str, Sequence[str], None] = ("c4f2e7a1b8d9", "1d9c4b7a2f31")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "subscription_profiles",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("current_plan_id", sa.String(), nullable=False, server_default=sa.text("'FREE'")),
        sa.Column("selected_plan_id", sa.String(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("will_renew", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("status", sa.String(), nullable=False, server_default=sa.text("'free'")),
        sa.Column(
            "last_payment_status",
            sa.String(),
            nullable=False,
            server_default=sa.text("'not_applicable'"),
        ),
        sa.Column(
            "provider",
            sa.String(),
            nullable=False,
            server_default=sa.text("'internal'"),
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    with op.batch_alter_table("subscription_profiles", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_subscription_profiles_id"), ["id"], unique=False)
        batch_op.create_index(batch_op.f("ix_subscription_profiles_user_id"), ["user_id"], unique=False)
        batch_op.create_index(
            batch_op.f("ix_subscription_profiles_current_plan_id"), ["current_plan_id"], unique=False
        )
        batch_op.create_index(
            batch_op.f("ix_subscription_profiles_selected_plan_id"), ["selected_plan_id"], unique=False
        )
        batch_op.create_index(batch_op.f("ix_subscription_profiles_started_at"), ["started_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_subscription_profiles_expires_at"), ["expires_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_subscription_profiles_cancel_at"), ["cancel_at"], unique=False)
        batch_op.create_index(batch_op.f("ix_subscription_profiles_status"), ["status"], unique=False)
        batch_op.create_index(
            batch_op.f("ix_subscription_profiles_last_payment_status"),
            ["last_payment_status"],
            unique=False,
        )

    op.create_table(
        "subscription_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("subscription_profile_id", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("previous_plan_id", sa.String(), nullable=True),
        sa.Column("plan_id", sa.String(), nullable=False),
        sa.Column("previous_status", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("payment_status", sa.String(), nullable=True),
        sa.Column("source", sa.String(), nullable=False, server_default=sa.text("'internal'")),
        sa.Column("details_json", sa.JSON(), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["subscription_profile_id"], ["subscription_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("subscription_events", schema=None) as batch_op:
        for name in (
            "id",
            "user_id",
            "subscription_profile_id",
            "event_type",
            "previous_plan_id",
            "plan_id",
            "previous_status",
            "status",
            "payment_status",
            "source",
            "occurred_at",
        ):
            batch_op.create_index(batch_op.f(f"ix_subscription_events_{name}"), [name], unique=False)

    op.create_table(
        "billing_transactions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("subscription_profile_id", sa.Integer(), nullable=False),
        sa.Column("plan_id", sa.String(), nullable=False),
        sa.Column("transaction_type", sa.String(), nullable=False),
        sa.Column("amount_cents", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("currency", sa.String(), nullable=False, server_default=sa.text("'USD'")),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["subscription_profile_id"], ["subscription_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("billing_transactions", schema=None) as batch_op:
        for name in (
            "id",
            "user_id",
            "subscription_profile_id",
            "plan_id",
            "transaction_type",
            "status",
            "effective_at",
        ):
            batch_op.create_index(batch_op.f(f"ix_billing_transactions_{name}"), [name], unique=False)

    op.create_table(
        "payment_attempts",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("subscription_profile_id", sa.Integer(), nullable=False),
        sa.Column("plan_id", sa.String(), nullable=False),
        sa.Column("attempt_type", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("amount_cents", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("currency", sa.String(), nullable=False, server_default=sa.text("'USD'")),
        sa.Column("provider_reference", sa.String(), nullable=True),
        sa.Column("failure_code", sa.String(), nullable=True),
        sa.Column("failure_message", sa.String(), nullable=True),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["subscription_profile_id"], ["subscription_profiles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("payment_attempts", schema=None) as batch_op:
        for name in (
            "id",
            "user_id",
            "subscription_profile_id",
            "plan_id",
            "attempt_type",
            "status",
            "provider_reference",
            "failure_code",
            "requested_at",
            "completed_at",
        ):
            batch_op.create_index(batch_op.f(f"ix_payment_attempts_{name}"), [name], unique=False)

    conn = op.get_bind()
    conn.execute(
        sa.text(
            """
            INSERT INTO subscription_profiles (
                user_id,
                current_plan_id,
                selected_plan_id,
                started_at,
                expires_at,
                cancel_at,
                will_renew,
                status,
                last_payment_status,
                provider
            )
            SELECT
                users.id,
                COALESCE(users.plan, 'FREE'),
                NULL,
                CASE WHEN UPPER(COALESCE(users.plan, 'FREE')) != 'FREE' THEN users.updated_at ELSE NULL END,
                NULL,
                NULL,
                CASE WHEN UPPER(COALESCE(users.plan, 'FREE')) != 'FREE' THEN 1 ELSE 0 END,
                CASE
                    WHEN UPPER(COALESCE(users.plan, 'FREE')) = 'FREE' THEN 'free'
                    WHEN users.is_active = 1 THEN 'active'
                    ELSE 'canceled'
                END,
                CASE
                    WHEN UPPER(COALESCE(users.plan, 'FREE')) = 'FREE' THEN 'not_applicable'
                    ELSE 'succeeded'
                END,
                'internal'
            FROM users
            """
        )
    )


def downgrade() -> None:
    with op.batch_alter_table("payment_attempts", schema=None) as batch_op:
        for name in (
            "requested_at",
            "failure_code",
            "provider_reference",
            "status",
            "attempt_type",
            "plan_id",
            "subscription_profile_id",
            "user_id",
            "id",
            "completed_at",
        ):
            batch_op.drop_index(batch_op.f(f"ix_payment_attempts_{name}"))
    op.drop_table("payment_attempts")

    with op.batch_alter_table("billing_transactions", schema=None) as batch_op:
        for name in (
            "effective_at",
            "status",
            "transaction_type",
            "plan_id",
            "subscription_profile_id",
            "user_id",
            "id",
        ):
            batch_op.drop_index(batch_op.f(f"ix_billing_transactions_{name}"))
    op.drop_table("billing_transactions")

    with op.batch_alter_table("subscription_events", schema=None) as batch_op:
        for name in (
            "occurred_at",
            "source",
            "payment_status",
            "status",
            "previous_status",
            "plan_id",
            "previous_plan_id",
            "event_type",
            "subscription_profile_id",
            "user_id",
            "id",
        ):
            batch_op.drop_index(batch_op.f(f"ix_subscription_events_{name}"))
    op.drop_table("subscription_events")

    with op.batch_alter_table("subscription_profiles", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_last_payment_status"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_status"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_cancel_at"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_expires_at"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_started_at"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_selected_plan_id"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_current_plan_id"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_user_id"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_id"))
    op.drop_table("subscription_profiles")
