"""add (status, published_at) indexes to contents and quizzes

Revision ID: m9_published_at_idx_20260624
Revises: l8_min_max_age_20260624
Create Date: 2026-06-24 09:30:00.000000

Published-content listings filter by `status == 'published'` and order by
`published_at DESC`. Without an index covering both columns those queries fall
back to a full scan + filesort once the catalog grows. This adds composite
`(status, published_at)` indexes to `contents` and `quizzes`. Idempotent
(guarded by an inspector check), matching the surrounding migrations.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "m9_published_at_idx_20260624"
down_revision: Union[str, Sequence[str], None] = "l8_min_max_age_20260624"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_INDEXES = (
    ("ix_content_items_status_published_at", "contents", ["status", "published_at"]),
    ("ix_quizzes_status_published_at", "quizzes", ["status", "published_at"]),
)


def _has_index(table: str, index_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(idx["name"] == index_name for idx in inspector.get_indexes(table))


def upgrade() -> None:
    for index_name, table, columns in _INDEXES:
        if not _has_index(table, index_name):
            op.create_index(index_name, table, columns)


def downgrade() -> None:
    for index_name, table, _columns in _INDEXES:
        if _has_index(table, index_name):
            op.drop_index(index_name, table_name=table)
