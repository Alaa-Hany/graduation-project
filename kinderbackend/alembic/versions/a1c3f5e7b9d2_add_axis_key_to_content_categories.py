"""add axis key to content categories

Revision ID: a1c3f5e7b9d2
Revises: fc1a2b3d4e5f
Create Date: 2026-04-24 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a1c3f5e7b9d2"
down_revision = "fc1a2b3d4e5f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "categories",
        sa.Column(
            "axis_key",
            sa.String(),
            nullable=False,
            server_default="educational",
        ),
    )
    op.create_index(op.f("ix_categories_axis_key"), "categories", ["axis_key"], unique=False)

    op.execute(
        """
        UPDATE categories
        SET axis_key = CASE
            WHEN lower(slug) = 'behavioral' THEN 'behavioral'
            WHEN lower(slug) = 'educational' THEN 'educational'
            WHEN lower(slug) = 'skillful' THEN 'skillful'
            WHEN lower(slug) = 'entertaining' THEN 'entertaining'
            WHEN lower(slug) LIKE 'skill%%' THEN 'skillful'
            WHEN lower(slug) LIKE 'entertain%%' THEN 'entertaining'
            WHEN lower(slug) LIKE 'behavior%%' THEN 'behavioral'
            ELSE 'educational'
        END
        """
    )

    op.alter_column("categories", "axis_key", server_default=None)


def downgrade() -> None:
    op.drop_index(op.f("ix_categories_axis_key"), table_name="categories")
    op.drop_column("categories", "axis_key")
