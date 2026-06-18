"""add_admin_security_tracking_fields

Revision ID: f4c2d8a1b9e3
Revises: e7f3c1a9d2b4
Create Date: 2026-03-15 13:10:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4c2d8a1b9e3"
down_revision: Union[str, Sequence[str], None] = "e7f3c1a9d2b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("last_login_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("last_login_ip", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("last_login_user_agent", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("last_failed_login_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("last_failed_login_ip", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("last_failed_login_user_agent", sa.String(), nullable=True))
        batch_op.add_column(
            sa.Column(
                "failed_login_attempts",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("0"),
            )
        )
        batch_op.add_column(
            sa.Column(
                "suspicious_access_count",
                sa.Integer(),
                nullable=False,
                server_default=sa.text("0"),
            )
        )
        batch_op.add_column(
            sa.Column(
                "is_flagged_suspicious",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )
        batch_op.add_column(sa.Column("locked_until", sa.DateTime(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("admin_users", schema=None) as batch_op:
        batch_op.drop_column("locked_until")
        batch_op.drop_column("is_flagged_suspicious")
        batch_op.drop_column("suspicious_access_count")
        batch_op.drop_column("failed_login_attempts")
        batch_op.drop_column("last_failed_login_user_agent")
        batch_op.drop_column("last_failed_login_ip")
        batch_op.drop_column("last_failed_login_at")
        batch_op.drop_column("last_login_user_agent")
        batch_op.drop_column("last_login_ip")
        batch_op.drop_column("last_login_at")

