"""merge schema heads

Revision ID: fc1a2b3d4e5f
Revises: c8d9e0f1a2b3, fb4c2a1d9e7b
Create Date: 2026-03-24 00:45:00.000000
"""

from __future__ import annotations

from typing import Sequence, Union

# revision identifiers, used by Alembic.
revision: str = "fc1a2b3d4e5f"
down_revision: Union[str, Sequence[str], None] = ("c8d9e0f1a2b3", "fb4c2a1d9e7b")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
