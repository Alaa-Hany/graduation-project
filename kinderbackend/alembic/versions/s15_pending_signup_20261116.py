"""add pending signup columns to users

Revision ID: s15_pending_signup_20261116
Revises: r14_refresh_sessions_20261116
Create Date: 2026-11-16 00:00:00.000000

Registering again on an email that is not verified yet used to overwrite the
account's name and password immediately, so anyone could set the password of a
pending account that isn't theirs. The new name/password now wait in these
columns and are applied only when the OTP is confirmed by the same app session
that registered (matched through registration_token_hash).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "s15_pending_signup_20261116"
down_revision: Union[str, Sequence[str], None] = "r14_refresh_sessions_20261116"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "users"
_COLUMNS = (
    ("pending_name", sa.String()),
    ("pending_password_hash", sa.String()),
    ("registration_token_hash", sa.String(length=64)),
)


def _existing_columns() -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {col["name"] for col in inspector.get_columns(_TABLE)}


def upgrade() -> None:
    existing = _existing_columns()
    for name, type_ in _COLUMNS:
        if name not in existing:
            op.add_column(_TABLE, sa.Column(name, type_, nullable=True))


def downgrade() -> None:
    existing = _existing_columns()
    for name, _type in reversed(_COLUMNS):
        if name in existing:
            op.drop_column(_TABLE, name)
