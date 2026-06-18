"""merge all schema heads

Revision ID: zz_merge_all_heads_20260618
Revises: a1b2c3d4e5f6, c7e1f2a3b4c5, e8f0a3b5c2d1, h3f6d2a7b1e8c
Create Date: 2026-06-18 00:00:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = "zz_merge_all_heads_20260618"
down_revision: Union[str, Sequence[str], None] = (
    "a1b2c3d4e5f6",
    "c7e1f2a3b4c5",
    "e8f0a3b5c2d1",
    "h3f6d2a7b1e8c",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # No-op merge revision to unify multiple heads for repository consistency.
    pass


def downgrade() -> None:
    # Downgrade is a no-op for merge-only migration in tests.
    pass
