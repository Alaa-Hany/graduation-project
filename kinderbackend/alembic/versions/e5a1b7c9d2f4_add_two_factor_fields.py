"""add_two_factor_fields

Revision ID: e5a1b7c9d2f4
Revises: f4c2d8a1b9e3
Create Date: 2026-03-23 22:40:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e5a1b7c9d2f4"
down_revision: Union[str, Sequence[str], None] = "f4c2d8a1b9e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "two_factor_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            )
        )
        batch_op.add_column(sa.Column("two_factor_method", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("two_factor_secret", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("two_factor_confirmed_at", sa.DateTime(), nullable=True))

    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "two_factor_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            )
        )
        batch_op.add_column(sa.Column("two_factor_method", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("two_factor_secret", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("two_factor_confirmed_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.drop_column("two_factor_confirmed_at")
        batch_op.drop_column("two_factor_secret")
        batch_op.drop_column("two_factor_method")
        batch_op.drop_column("two_factor_enabled")

    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("two_factor_confirmed_at")
        batch_op.drop_column("two_factor_secret")
        batch_op.drop_column("two_factor_method")
        batch_op.drop_column("two_factor_enabled")
