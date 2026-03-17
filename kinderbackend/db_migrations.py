from __future__ import annotations

import logging
from pathlib import Path

from sqlalchemy import inspect
from sqlalchemy.engine import Engine

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from database import BASE_DIR, DATABASE_URL, Base


def _alembic_ini_path() -> Path:
    return BASE_DIR / "alembic.ini"


def _build_alembic_config() -> Config:
    config = Config(str(_alembic_ini_path()))
    config.set_main_option("sqlalchemy.url", DATABASE_URL)
    return config


def _script_heads(config: Config) -> tuple[str, ...]:
    script = ScriptDirectory.from_config(config)
    return tuple(sorted(script.get_heads()))


def _db_heads(engine: Engine) -> tuple[str, ...]:
    with engine.connect() as connection:
        context = MigrationContext.configure(connection)
        return tuple(sorted(head for head in context.get_current_heads() if head))


def _is_legacy_schema_without_alembic_version(engine: Engine) -> bool:
    inspector = inspect(engine)
    table_names = set(inspector.get_table_names())
    if "alembic_version" in table_names:
        return False

    expected_tables = set(Base.metadata.tables.keys())
    # If a meaningful subset of ORM tables exists but alembic_version does not,
    # treat this as a legacy/stamped-missing database.
    return len(expected_tables.intersection(table_names)) > 0


def verify_database_schema(
    engine: Engine, logger: logging.Logger, *, auto_upgrade: bool = False
) -> None:
    config = _build_alembic_config()
    expected_heads = _script_heads(config)
    current_heads = _db_heads(engine)

    if not current_heads and _is_legacy_schema_without_alembic_version(engine):
        logger.warning(
            "Legacy database detected without alembic version tracking. "
            "After backing up the database, run 'python -m alembic stamp head' once "
            "to align Alembic with the current schema."
        )
        return

    if auto_upgrade and set(current_heads) != set(expected_heads):
        logger.warning("Database schema not at head; applying migrations automatically.")
        command.upgrade(config, "head")
        current_heads = _db_heads(engine)

    if set(current_heads) != set(expected_heads):
        current = ", ".join(current_heads) if current_heads else "(none)"
        target = ", ".join(expected_heads) if expected_heads else "(none)"
        raise RuntimeError(
            "Database schema revision mismatch. "
            f"Current DB revision(s): {current}. Expected head revision(s): {target}. "
            "Run 'python -m alembic upgrade head' before starting the app."
        )
