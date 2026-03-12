"""add_support_ticket_category

Revision ID: c12e6f8a9b41
Revises: b3f7c1d9a2e4
Create Date: 2026-03-11 16:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c12e6f8a9b41"
down_revision: Union[str, Sequence[str], None] = "b3f7c1d9a2e4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("support_tickets", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "category",
                sa.String(),
                nullable=False,
                server_default=sa.text("'general_inquiry'"),
            )
        )
        batch_op.create_index(
            batch_op.f("ix_support_tickets_category"),
            ["category"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("support_tickets", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_support_tickets_category"))
        batch_op.drop_column("category")
