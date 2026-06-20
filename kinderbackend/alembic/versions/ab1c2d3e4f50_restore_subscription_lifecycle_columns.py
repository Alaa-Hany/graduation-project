"""restore subscription_profiles lifecycle columns dropped by a diverged branch

Revision ID: ab1c2d3e4f50
Revises: aa_add_pw_reset_token_20260619
Create Date: 2026-06-19 12:00:00.000000

The migration graph contains two independent branches rooted at the initial
schema:

  * 72445407446a -> a1b2c3d4e5f6 drops expires_at/cancel_at/will_renew from
    subscription_profiles, assuming the table already existed pre-initial-schema.
  * 72445407446a -> ... -> e1a5c7b9d3f2 creates subscription_profiles from
    scratch *with* those same three columns, on a sibling branch that never
    depends on a1b2c3d4e5f6.

Both branches are joined by zz_merge_all_heads_20260618, but a merge revision
does not replay column-level intent - whichever branch Alembic's topological
sort happens to apply last wins. Verified empirically: running
`alembic upgrade head` against a fresh database applies the create-table
branch first and the drop-column branch last, leaving subscription_profiles
without expires_at/cancel_at/will_renew even though models.py
(SubscriptionProfile) declares them as live columns and
services/subscription_service_parts/lifecycle.py and
services/payment_reconciliation_service.py read/write them unconditionally.
That mismatch raises OperationalError: no such column on first use.

This migration is intentionally idempotent (checks existing columns/indexes
before adding) so it is safe to apply regardless of which branch ordering a
given database happened to run.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "ab1c2d3e4f50"
down_revision: Union[str, Sequence[str], None] = "aa_add_pw_reset_token_20260619"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TABLE = "subscription_profiles"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_columns = {col["name"] for col in inspector.get_columns(_TABLE)}
    existing_indexes = {idx["name"] for idx in inspector.get_indexes(_TABLE)}

    with op.batch_alter_table(_TABLE, schema=None) as batch_op:
        if "expires_at" not in existing_columns:
            batch_op.add_column(sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True))
        if "cancel_at" not in existing_columns:
            batch_op.add_column(sa.Column("cancel_at", sa.DateTime(timezone=True), nullable=True))
        if "will_renew" not in existing_columns:
            batch_op.add_column(
                sa.Column(
                    "will_renew",
                    sa.Boolean(),
                    nullable=False,
                    server_default=sa.false(),
                )
            )

    # Re-inspect after the batch so newly added columns/indexes are visible
    # before deciding which indexes still need to be created.
    inspector = sa.inspect(bind)
    existing_indexes = {idx["name"] for idx in inspector.get_indexes(_TABLE)}

    with op.batch_alter_table(_TABLE, schema=None) as batch_op:
        if "ix_subscription_profiles_expires_at" not in existing_indexes:
            batch_op.create_index(
                "ix_subscription_profiles_expires_at", ["expires_at"], unique=False
            )
        if "ix_subscription_profiles_cancel_at" not in existing_indexes:
            batch_op.create_index(
                "ix_subscription_profiles_cancel_at", ["cancel_at"], unique=False
            )


def downgrade() -> None:
    # No-op: the columns are required by the current ORM model and active
    # service code, so there is no safe state to downgrade to.
    pass
