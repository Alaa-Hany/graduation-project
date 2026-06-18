"""drop_unused_subscription_columns

Revision ID: a1b2c3d4e5f6
Revises: 72445407446a
Create Date: 2026-06-17 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '72445407446a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Drop unused subscription profile columns."""
    with op.batch_alter_table('subscription_profiles', schema=None) as batch_op:
        batch_op.drop_index('ix_subscription_profiles_expires_at')
        batch_op.drop_index('ix_subscription_profiles_cancel_at')
        batch_op.drop_column('expires_at')
        batch_op.drop_column('cancel_at')
        batch_op.drop_column('will_renew')


def downgrade() -> None:
    """Restore unused subscription profile columns."""
    with op.batch_alter_table('subscription_profiles', schema=None) as batch_op:
        batch_op.add_column(sa.Column('will_renew', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('cancel_at', sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column('expires_at', sa.DateTime(), nullable=True))
        batch_op.create_index('ix_subscription_profiles_cancel_at', ['cancel_at'])
        batch_op.create_index('ix_subscription_profiles_expires_at', ['expires_at'])
