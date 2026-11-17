"""add idempotency_key to child activity events and session logs

Revision ID: t16_analytics_idem_20261116
Revises: s15_pending_signup_20261116
Create Date: 2026-11-16 00:00:00.000000

The child app sends an Idempotency-Key with every analytics upload and may
resend the same record after a network failure. The unique (child_id,
idempotency_key) constraint makes the database itself refuse the duplicate,
so a retry can never count an activity twice. NULL keys (older clients) are
not constrained: both SQLite and PostgreSQL treat NULLs as distinct.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "t16_analytics_idem_20261116"
down_revision: Union[str, Sequence[str], None] = "s15_pending_signup_20261116"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLES = {
    "child_activity_events": "uq_child_activity_events_child_idempotency",
    "child_session_logs": "uq_child_session_logs_child_idempotency",
}


def _columns(table: str) -> set[str]:
    return {col["name"] for col in sa.inspect(op.get_bind()).get_columns(table)}


def _unique_names(table: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    names = {uc["name"] for uc in inspector.get_unique_constraints(table)}
    names |= {ix["name"] for ix in inspector.get_indexes(table) if ix.get("unique")}
    return names


def upgrade() -> None:
    for table, constraint in _TABLES.items():
        with op.batch_alter_table(table) as batch:
            if "idempotency_key" not in _columns(table):
                batch.add_column(sa.Column("idempotency_key", sa.String(length=128), nullable=True))
            if constraint not in _unique_names(table):
                batch.create_unique_constraint(constraint, ["child_id", "idempotency_key"])


def downgrade() -> None:
    for table, constraint in _TABLES.items():
        with op.batch_alter_table(table) as batch:
            if constraint in _unique_names(table):
                batch.drop_constraint(constraint, type_="unique")
            if "idempotency_key" in _columns(table):
                batch.drop_column("idempotency_key")
