"""add_content_slug_for_public_content

Revision ID: 1d9c4b7a2f31
Revises: f4c2d8a1b9e3
Create Date: 2026-03-17 10:20:00.000000

"""

from __future__ import annotations

import re
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "1d9c4b7a2f31"
down_revision: Union[str, Sequence[str], None] = "f4c2d8a1b9e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (value or "").strip().lower())
    return slug.strip("-") or "content"


def upgrade() -> None:
    with op.batch_alter_table("contents", schema=None) as batch_op:
        batch_op.add_column(sa.Column("slug", sa.String(), nullable=True))

    bind = op.get_bind()
    contents = sa.table(
        "contents",
        sa.column("id", sa.Integer()),
        sa.column("title_en", sa.String()),
        sa.column("slug", sa.String()),
    )
    rows = list(bind.execute(sa.select(contents.c.id, contents.c.title_en)).fetchall())
    seen: set[str] = set()
    for row in rows:
        base_slug = _slugify(row.title_en or f"content-{row.id}")
        slug = base_slug
        suffix = 2
        while slug in seen:
            slug = f"{base_slug}-{suffix}"
            suffix += 1
        seen.add(slug)
        bind.execute(
            contents.update().where(contents.c.id == row.id).values(slug=slug),
        )

    with op.batch_alter_table("contents", schema=None) as batch_op:
        batch_op.alter_column("slug", existing_type=sa.String(), nullable=False)
        batch_op.create_index(batch_op.f("ix_contents_slug"), ["slug"], unique=True)


def downgrade() -> None:
    with op.batch_alter_table("contents", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_contents_slug"))
        batch_op.drop_column("slug")
