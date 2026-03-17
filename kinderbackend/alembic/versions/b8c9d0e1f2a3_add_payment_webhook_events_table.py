"""add_payment_webhook_events_table

Revision ID: b8c9d0e1f2a3
Revises: d4e8f1a2b3c4
Create Date: 2026-03-18 00:30:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "b8c9d0e1f2a3"
down_revision: Union[str, Sequence[str], None] = "d4e8f1a2b3c4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "payment_webhook_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("event_id", sa.String(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column(
            "status",
            sa.String(),
            nullable=False,
            server_default=sa.text("'received'"),
        ),
        sa.Column(
            "signature_valid",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column("duplicate_of_event_id", sa.String(), nullable=True),
        sa.Column("error_message", sa.String(), nullable=True),
        sa.Column("provider_customer_id", sa.String(), nullable=True),
        sa.Column("provider_subscription_id", sa.String(), nullable=True),
        sa.Column("provider_invoice_id", sa.String(), nullable=True),
        sa.Column("provider_session_id", sa.String(), nullable=True),
        sa.Column("subscription_profile_id", sa.Integer(), nullable=True),
        sa.Column("payload_json", sa.JSON(), nullable=True),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["subscription_profile_id"],
            ["subscription_profiles.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "event_id", name="uq_payment_webhook_events_provider_event"),
    )
    for name in (
        "provider",
        "event_id",
        "event_type",
        "status",
        "duplicate_of_event_id",
        "provider_customer_id",
        "provider_subscription_id",
        "provider_invoice_id",
        "provider_session_id",
        "subscription_profile_id",
        "received_at",
        "processed_at",
    ):
        op.create_index(op.f(f"ix_payment_webhook_events_{name}"), "payment_webhook_events", [name], unique=False)


def downgrade() -> None:
    for name in (
        "processed_at",
        "received_at",
        "subscription_profile_id",
        "provider_session_id",
        "provider_invoice_id",
        "provider_subscription_id",
        "provider_customer_id",
        "duplicate_of_event_id",
        "status",
        "event_type",
        "event_id",
        "provider",
    ):
        op.drop_index(op.f(f"ix_payment_webhook_events_{name}"), table_name="payment_webhook_events")
    op.drop_table("payment_webhook_events")
