"""hash_child_picture_passwords

One-time data migration: re-hashes legacy picture passwords stored as plain
JSON arrays (e.g. ["apple","cat","dog"]) into the bcrypt_json_v1 envelope
{"scheme": "bcrypt_json_v1", "hash": "<bcrypt>", "length": N}.

Rows already in the hashed-dict format are skipped.

Revision ID: c8d9e0f1a2b3
Revises: b8c9d0e1f2a3
Create Date: 2026-03-23 11:15:00.000000

"""

from __future__ import annotations

import json
from typing import Sequence, Union

import bcrypt
import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c8d9e0f1a2b3"
down_revision: Union[str, Sequence[str], None] = "b8c9d0e1f2a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_SCHEME = "bcrypt_json_v1"


# ---------------------------------------------------------------------------
# Self-contained helpers — do NOT import from application code so that this
# migration remains replayable independently of future refactors.
# ---------------------------------------------------------------------------

def _bcrypt_hash(value: str) -> str:
    return bcrypt.hashpw(value.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _hash_picture_password(items: list[str]) -> dict[str, str | int]:
    canonical = json.dumps(items, separators=(",", ":"), ensure_ascii=True)
    return {
        "scheme": _SCHEME,
        "hash": _bcrypt_hash(canonical),
        "length": len(items),
    }


def _parse_stored(raw: object) -> object:
    """Normalise the value coming back from the DB to a Python object.

    Raw ``sa.text()`` queries bypass SQLAlchemy's type coercion layer, so the
    JSON column arrives as:
      - a Python list/dict on PostgreSQL (psycopg2 deserialises automatically)
      - a plain str on SQLite (JSON is stored as TEXT)

    Return the decoded Python object, or None if the value cannot be parsed.
    """
    if isinstance(raw, (list, dict)):
        return raw
    if isinstance(raw, str):
        try:
            return json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            return None
    return None


# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

def upgrade() -> None:
    connection = op.get_bind()

    # Materialise with .all() before iterating so that the UPDATE statements
    # we issue below don't inadvertently close the read cursor on backends that
    # share a single implicit transaction cursor (e.g. SQLite in autocommit=off).
    rows = connection.execute(
        sa.text(
            "SELECT id, picture_password FROM child_profiles"
            " WHERE picture_password IS NOT NULL"
        )
    ).mappings().all()

    migrated = 0
    skipped = 0

    for row in rows:
        stored = _parse_stored(row["picture_password"])

        if not isinstance(stored, list):
            # Already a hashed dict (or unrecognised format) — leave untouched.
            skipped += 1
            continue

        new_value = json.dumps(_hash_picture_password(stored))
        connection.execute(
            sa.text(
                "UPDATE child_profiles"
                " SET picture_password = :picture_password"
                " WHERE id = :id"
            ),
            {"id": row["id"], "picture_password": new_value},
        )
        migrated += 1

    # Alembic's op.get_bind() logger isn't always visible; use print so the
    # counts appear in alembic upgrade output regardless of log configuration.
    print(f"[c8d9e0f1a2b3] picture_password migration: {migrated} hashed, {skipped} skipped")


def downgrade() -> None:
    # Bcrypt hashes cannot be reversed to recover the original picture sequence.
    # A downgrade would require the application to re-accept legacy list passwords
    # which is a security regression; leave this as a no-op and document that
    # this migration is intentionally irreversible.
    pass
