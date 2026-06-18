"""rename_picture_password_to_picture_password_hash

Renames the JSON picture_password column to picture_password_hash and converts
it to a String (VARCHAR) type to store the bcrypt_json_v1 envelope as a string.

This follows the successful completion of migration c8d9e0f1a2b3, which converted
all picture passwords to the bcrypt_json_v1 format with structure:
  {"scheme": "bcrypt_json_v1", "hash": "<bcrypt>", "length": N}

Revision ID: h3f6d2a7b1e8c
Revises: g2e5d3c4a1b6f
Create Date: 2026-06-17 15:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "h3f6d2a7b1e8c"
down_revision: Union[str, Sequence[str], None] = "g2e5d3c4a1b6f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Rename picture_password to picture_password_hash and convert to String type."""
    # SQLite doesn't support direct column type changes or renames in batch mode,
    # so we must recreate the column with the new name and type.
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        # Add the new column with the correct type and NOT NULL constraint
        batch_op.add_column(
            sa.Column("picture_password_hash", sa.String(), nullable=False, server_default="")
        )

    # Migrate data from picture_password (JSON) to picture_password_hash (String)
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE child_profiles
            SET picture_password_hash = picture_password
            WHERE picture_password IS NOT NULL
            """
        )
    )

    # Remove the server default after data migration
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.alter_column(
            "picture_password_hash",
            existing_type=sa.String(),
            existing_nullable=False,
            server_default=None,
        )

    # Drop the old column
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.drop_column("picture_password")


def downgrade() -> None:
    """Revert: rename picture_password_hash back to picture_password and restore JSON type."""
    # Recreate the JSON column
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("picture_password", sa.JSON(), nullable=False, server_default={})
        )

    # Migrate data back
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE child_profiles
            SET picture_password = picture_password_hash
            WHERE picture_password_hash IS NOT NULL
            """
        )
    )

    # Remove the server default
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.alter_column(
            "picture_password",
            existing_type=sa.JSON(),
            existing_nullable=False,
            server_default=None,
        )

    # Drop the new column
    with op.batch_alter_table("child_profiles", schema=None) as batch_op:
        batch_op.drop_column("picture_password_hash")
