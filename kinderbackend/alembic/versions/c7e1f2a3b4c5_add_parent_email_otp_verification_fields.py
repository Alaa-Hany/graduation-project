"""add parent email otp verification fields

Revision ID: c7e1f2a3b4c5
Revises: b6e4a2d1c9f8
Create Date: 2026-04-27 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "c7e1f2a3b4c5"
down_revision: Union[str, Sequence[str], None] = "b6e4a2d1c9f8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "email_verified",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )
        batch_op.add_column(sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("email_otp_hash", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("email_otp_expires_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("email_otp_last_sent_at", sa.DateTime(timezone=True), nullable=True))

    op.execute("UPDATE users SET email_verified = CASE WHEN is_active THEN TRUE ELSE FALSE END")

    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.alter_column("email_verified", server_default=None)


def downgrade() -> None:
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_column("email_otp_last_sent_at")
        batch_op.drop_column("email_otp_expires_at")
        batch_op.drop_column("email_otp_hash")
        batch_op.drop_column("email_verified_at")
        batch_op.drop_column("email_verified")
