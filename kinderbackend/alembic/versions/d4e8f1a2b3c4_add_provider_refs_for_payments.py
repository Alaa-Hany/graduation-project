"""add_provider_refs_for_payments

Revision ID: d4e8f1a2b3c4
Revises: a7d3c9e4f2b1
Create Date: 2026-03-17 23:40:00.000000

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "d4e8f1a2b3c4"
down_revision: Union[str, Sequence[str], None] = "a7d3c9e4f2b1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("subscription_profiles", schema=None) as batch_op:
        batch_op.add_column(sa.Column("provider_customer_id", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("provider_subscription_id", sa.String(), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_subscription_profiles_provider_customer_id"),
            ["provider_customer_id"],
            unique=False,
        )
        batch_op.create_index(
            batch_op.f("ix_subscription_profiles_provider_subscription_id"),
            ["provider_subscription_id"],
            unique=False,
        )

    with op.batch_alter_table("subscription_events", schema=None) as batch_op:
        batch_op.add_column(sa.Column("provider_reference", sa.String(), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_subscription_events_provider_reference"),
            ["provider_reference"],
            unique=False,
        )

    with op.batch_alter_table("billing_transactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("provider_reference", sa.String(), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_billing_transactions_provider_reference"),
            ["provider_reference"],
            unique=False,
        )

    with op.batch_alter_table("payment_methods", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "provider",
                sa.String(),
                nullable=False,
                server_default=sa.text("'internal'"),
            )
        )
        batch_op.add_column(sa.Column("provider_customer_id", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("provider_method_id", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("method_type", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("brand", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("last4", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("exp_month", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("exp_year", sa.Integer(), nullable=True))
        batch_op.add_column(
            sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch_op.add_column(sa.Column("fingerprint", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("metadata_json", sa.JSON(), nullable=True))
        for name in (
            "provider",
            "provider_customer_id",
            "provider_method_id",
            "method_type",
            "fingerprint",
        ):
            batch_op.create_index(batch_op.f(f"ix_payment_methods_{name}"), [name], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("payment_methods", schema=None) as batch_op:
        for name in (
            "fingerprint",
            "method_type",
            "provider_method_id",
            "provider_customer_id",
            "provider",
        ):
            batch_op.drop_index(batch_op.f(f"ix_payment_methods_{name}"))
        batch_op.drop_column("metadata_json")
        batch_op.drop_column("fingerprint")
        batch_op.drop_column("is_default")
        batch_op.drop_column("exp_year")
        batch_op.drop_column("exp_month")
        batch_op.drop_column("last4")
        batch_op.drop_column("brand")
        batch_op.drop_column("method_type")
        batch_op.drop_column("provider_method_id")
        batch_op.drop_column("provider_customer_id")
        batch_op.drop_column("provider")

    with op.batch_alter_table("billing_transactions", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_billing_transactions_provider_reference"))
        batch_op.drop_column("provider_reference")

    with op.batch_alter_table("subscription_events", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_subscription_events_provider_reference"))
        batch_op.drop_column("provider_reference")

    with op.batch_alter_table("subscription_profiles", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_provider_subscription_id"))
        batch_op.drop_index(batch_op.f("ix_subscription_profiles_provider_customer_id"))
        batch_op.drop_column("provider_subscription_id")
        batch_op.drop_column("provider_customer_id")
