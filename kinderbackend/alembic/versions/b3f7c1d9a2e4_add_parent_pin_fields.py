"""add_parent_pin_fields

Revision ID: b3f7c1d9a2e4
Revises: 72445407446a
Create Date: 2026-03-11 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b3f7c1d9a2e4"
down_revision: Union[str, Sequence[str], None] = "72445407446a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("parent_pin_hash", sa.String(), nullable=True))
        batch_op.add_column(
            sa.Column(
                "parent_pin_failed_attempts",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("0"),
            )
        )
        batch_op.add_column(sa.Column("parent_pin_locked_until", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("parent_pin_updated_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("parent_pin_updated_at")
        batch_op.drop_column("parent_pin_locked_until")
        batch_op.drop_column("parent_pin_failed_attempts")
        batch_op.drop_column("parent_pin_hash")
