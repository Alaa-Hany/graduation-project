"""convert_schedule_times_to_time_type

Revision ID: g2e5d3c4a1b6f
Revises: fc1a2b3d4e5f
Create Date: 2026-06-17 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "g2e5d3c4a1b6f"
down_revision: Union[str, Sequence[str], None] = "fc1a2b3d4e5f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Convert start_time and end_time from VARCHAR to TIME type with data migration."""
    # SQLite doesn't support direct column type changes, so we use batch_alter_table
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        # Rename old columns
        batch_op.alter_column(
            "start_time",
            new_column_name="start_time_old",
            existing_type=sa.String(),
            existing_nullable=False,
        )
        batch_op.alter_column(
            "end_time",
            new_column_name="end_time_old",
            existing_type=sa.String(),
            existing_nullable=False,
        )

    # Create new TIME columns
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.add_column(sa.Column("start_time", sa.Time(), nullable=True))
        batch_op.add_column(sa.Column("end_time", sa.Time(), nullable=True))

    # Migrate data from old columns to new columns
    # Parse HH:MM format strings to time objects
    connection = op.get_bind()

    # For each row, convert the old string format to time
    # In SQLite, we need to use strftime or custom SQL
    if connection.dialect.name == "sqlite":
        # SQLite: convert string to time using time() function
        connection.execute(
            sa.text("""
                UPDATE child_schedule_rules
                SET start_time = time(start_time_old),
                    end_time = time(end_time_old)
                WHERE start_time_old IS NOT NULL
                  AND end_time_old IS NOT NULL
            """)
        )
    else:
        # PostgreSQL and MySQL variants
        connection.execute(
            sa.text("""
                UPDATE child_schedule_rules
                SET start_time = CAST(start_time_old AS TIME),
                    end_time = CAST(end_time_old AS TIME)
                WHERE start_time_old IS NOT NULL
                  AND end_time_old IS NOT NULL
            """)
        )

    # Drop old columns and set NOT NULL constraints
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.drop_column("start_time_old")
        batch_op.drop_column("end_time_old")
        batch_op.alter_column(
            "start_time",
            existing_type=sa.Time(),
            existing_nullable=True,
            nullable=False,
        )
        batch_op.alter_column(
            "end_time",
            existing_type=sa.Time(),
            existing_nullable=True,
            nullable=False,
        )
        # Add index for common queries
        batch_op.create_index(
            "ix_child_schedule_rules_setting_day",
            ["setting_id", "day_of_week"],
            unique=False,
        )


def downgrade() -> None:
    """Revert TIME columns back to VARCHAR."""
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        # Drop the new index
        batch_op.drop_index("ix_child_schedule_rules_setting_day")

        # Rename new columns
        batch_op.alter_column(
            "start_time",
            new_column_name="start_time_new",
            existing_type=sa.Time(),
            existing_nullable=False,
        )
        batch_op.alter_column(
            "end_time",
            new_column_name="end_time_new",
            existing_type=sa.Time(),
            existing_nullable=False,
        )

    # Create old VARCHAR columns
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.add_column(sa.Column("start_time", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("end_time", sa.String(), nullable=True))

    # Migrate data back from new columns to old columns
    connection = op.get_bind()
    connection.execute(
        sa.text("""
            UPDATE child_schedule_rules
            SET start_time = strftime('%H:%M', start_time_new),
                end_time = strftime('%H:%M', end_time_new)
            WHERE start_time_new IS NOT NULL
              AND end_time_new IS NOT NULL
        """)
    )

    # Drop new columns and set NOT NULL constraints
    with op.batch_alter_table("child_schedule_rules", schema=None) as batch_op:
        batch_op.drop_column("start_time_new")
        batch_op.drop_column("end_time_new")
        batch_op.alter_column(
            "start_time",
            existing_type=sa.String(),
            existing_nullable=True,
            nullable=False,
        )
        batch_op.alter_column(
            "end_time",
            existing_type=sa.String(),
            existing_nullable=True,
            nullable=False,
        )
