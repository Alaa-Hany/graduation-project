"""preserve history on parent deletion

Revision ID: fa2d9e4c1b7a
Revises: f9b3e1c4a7d8
Create Date: 2026-03-23 23:55:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "fa2d9e4c1b7a"
down_revision: Union[str, Sequence[str], None] = "f9b3e1c4a7d8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

NAMING_CONVENTION = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
}

FALLBACK_FK_NAMES = {
    ("support_tickets", ("user_id",), "users"): "fk_support_tickets_user_id_users",
    ("subscription_events", ("user_id",), "users"): "fk_subscription_events_user_id_users",
    (
        "subscription_events",
        ("subscription_profile_id",),
        "subscription_profiles",
    ): "fk_subscription_events_subscription_profile_id_subscription_profiles",
    ("billing_transactions", ("user_id",), "users"): "fk_billing_transactions_user_id_users",
    (
        "billing_transactions",
        ("subscription_profile_id",),
        "subscription_profiles",
    ): "fk_billing_transactions_subscription_profile_id_subscription_profiles",
    ("payment_attempts", ("user_id",), "users"): "fk_payment_attempts_user_id_users",
    (
        "payment_attempts",
        ("subscription_profile_id",),
        "subscription_profiles",
    ): "fk_payment_attempts_subscription_profile_id_subscription_profiles",
}


def _fk_name(bind, table_name: str, columns: tuple[str, ...], referred_table: str) -> str:
    inspector = sa.inspect(bind)
    for fk in inspector.get_foreign_keys(table_name):
        if fk.get("referred_table") != referred_table:
            continue
        if tuple(fk.get("constrained_columns") or ()) != columns:
            continue
        if fk.get("name"):
            return str(fk["name"])
        break
    return FALLBACK_FK_NAMES[(table_name, columns, referred_table)]


def upgrade() -> None:
    bind = op.get_bind()

    with op.batch_alter_table(
        "support_tickets",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint(
            _fk_name(bind, "support_tickets", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_support_tickets_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )

    with op.batch_alter_table(
        "subscription_events",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=True)
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=True)
        batch_op.drop_constraint(
            _fk_name(bind, "subscription_events", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "subscription_events",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_subscription_events_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_foreign_key(
            "fk_subscription_events_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="SET NULL",
        )

    with op.batch_alter_table(
        "billing_transactions",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=True)
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=True)
        batch_op.drop_constraint(
            _fk_name(bind, "billing_transactions", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "billing_transactions",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_billing_transactions_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_foreign_key(
            "fk_billing_transactions_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="SET NULL",
        )

    with op.batch_alter_table(
        "payment_attempts",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=True)
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=True)
        batch_op.drop_constraint(
            _fk_name(bind, "payment_attempts", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "payment_attempts",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_payment_attempts_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_foreign_key(
            "fk_payment_attempts_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    bind = op.get_bind()

    op.execute(sa.text("DELETE FROM payment_attempts WHERE user_id IS NULL OR subscription_profile_id IS NULL"))
    op.execute(
        sa.text(
            "DELETE FROM billing_transactions WHERE user_id IS NULL OR subscription_profile_id IS NULL"
        )
    )
    op.execute(
        sa.text(
            "DELETE FROM subscription_events WHERE user_id IS NULL OR subscription_profile_id IS NULL"
        )
    )

    with op.batch_alter_table(
        "payment_attempts",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint(
            _fk_name(bind, "payment_attempts", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "payment_attempts",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_payment_attempts_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_foreign_key(
            "fk_payment_attempts_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=False)
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=False)

    with op.batch_alter_table(
        "billing_transactions",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint(
            _fk_name(bind, "billing_transactions", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "billing_transactions",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_billing_transactions_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_foreign_key(
            "fk_billing_transactions_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=False)
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=False)

    with op.batch_alter_table(
        "subscription_events",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint(
            _fk_name(bind, "subscription_events", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.drop_constraint(
            _fk_name(
                bind,
                "subscription_events",
                ("subscription_profile_id",),
                "subscription_profiles",
            ),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_subscription_events_user_id_users",
            "users",
            ["user_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_foreign_key(
            "fk_subscription_events_subscription_profile_id",
            "subscription_profiles",
            ["subscription_profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.alter_column("subscription_profile_id", existing_type=sa.Integer(), nullable=False)
        batch_op.alter_column("user_id", existing_type=sa.Integer(), nullable=False)

    with op.batch_alter_table(
        "support_tickets",
        schema=None,
        naming_convention=NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint(
            _fk_name(bind, "support_tickets", ("user_id",), "users"),
            type_="foreignkey",
        )
        batch_op.create_foreign_key(
            "fk_support_tickets_user_id_users",
            "users",
            ["user_id"],
            ["id"],
        )
