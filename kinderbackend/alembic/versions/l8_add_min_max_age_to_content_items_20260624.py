"""add min_age and max_age to content_items

Revision ID: l8_add_min_max_age_to_content_items_20260624
Revises: k7_add_pm_updated_at_20260624
Create Date: 2026-06-24 09:00:00.000000

The child content listing (GET /content/child/items) used to load every
published row and range-check the free-text `age_group` string in Python. This
adds structured `min_age`/`max_age` integer columns to `contents` so the age
filter (and pagination) can run as a SQL WHERE clause instead. NULL on either
bound means "unbounded" on that side (treated as all ages), so legacy rows that
only ever had `age_group` populated still behave the same. Idempotent (guarded
by an inspector check), matching the surrounding migrations.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "l8_add_min_max_age_to_content_items_20260624"
down_revision: Union[str, Sequence[str], None] = "k7_add_pm_updated_at_20260624"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(col["name"] == column for col in inspector.get_columns(table))


def _backfill_age_bounds() -> None:
    """Populate min_age/max_age from the legacy free-text age_group values.

    Recognized formats (already enforced by the admin validator): ``"5-7"`` and
    ``"8+"``. A ``"N+"`` group leaves max_age unbounded (NULL). Anything that
    doesn't parse is left as NULL/NULL ("all ages"), so the SQL filter behaves
    exactly like the old Python parser did for these rows.
    """
    bind = op.get_bind()
    contents = sa.table(
        "contents",
        sa.column("id", sa.Integer),
        sa.column("age_group", sa.String),
        sa.column("min_age", sa.Integer),
        sa.column("max_age", sa.Integer),
    )
    rows = bind.execute(
        sa.select(contents.c.id, contents.c.age_group).where(
            contents.c.age_group.is_not(None)
        )
    ).fetchall()
    for row_id, age_group in rows:
        group = (age_group or "").replace(" ", "")
        min_age: int | None = None
        max_age: int | None = None
        if group.endswith("+") and group[:-1].isdigit():
            min_age = int(group[:-1])
        elif "-" in group:
            start_raw, _, end_raw = group.partition("-")
            if start_raw.isdigit() and end_raw.isdigit():
                min_age, max_age = int(start_raw), int(end_raw)
        if min_age is None and max_age is None:
            continue
        bind.execute(
            contents.update()
            .where(contents.c.id == row_id)
            .values(min_age=min_age, max_age=max_age)
        )


def upgrade() -> None:
    if not _has_column("contents", "min_age"):
        op.add_column("contents", sa.Column("min_age", sa.Integer(), nullable=True))
    if not _has_column("contents", "max_age"):
        op.add_column("contents", sa.Column("max_age", sa.Integer(), nullable=True))
    _backfill_age_bounds()


def downgrade() -> None:
    if _has_column("contents", "max_age"):
        op.drop_column("contents", "max_age")
    if _has_column("contents", "min_age"):
        op.drop_column("contents", "min_age")
