from __future__ import annotations

import logging
from pathlib import Path

import pytest

import db_migrations
from database import engine


def test_load_expected_heads_rejects_multiple_heads(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(db_migrations, "_script_heads", lambda _config: ("head_a", "head_b"))

    with pytest.raises(RuntimeError, match="Multiple Alembic heads detected"):
        db_migrations._load_expected_heads(db_migrations._build_alembic_config())


def test_load_expected_heads_wraps_script_loading_errors(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def _raise(_config):
        raise ModuleNotFoundError("auth")

    monkeypatch.setattr(db_migrations, "_script_heads", _raise)

    with pytest.raises(RuntimeError, match="Unable to load Alembic migration scripts"):
        db_migrations._load_expected_heads(db_migrations._build_alembic_config())


def test_build_alembic_config_uses_backend_paths() -> None:
    config = db_migrations._build_alembic_config()
    script_location = Path(config.get_main_option("script_location"))
    prepend_sys_path = Path(config.get_main_option("prepend_sys_path"))

    assert script_location.name == "alembic"
    assert script_location.parent.name == "kinderbackend"
    assert prepend_sys_path.name == "kinderbackend"


def test_real_script_heads_load_from_repo_config() -> None:
    heads = db_migrations._load_expected_heads(db_migrations._build_alembic_config())

    assert len(heads) == 1


def test_verify_database_schema_uses_single_expected_head(monkeypatch: pytest.MonkeyPatch) -> None:
    logger = logging.getLogger("migration-test")
    monkeypatch.setattr(db_migrations, "_load_expected_heads", lambda _config: ("head_1",))
    monkeypatch.setattr(db_migrations, "_db_heads", lambda _engine: ("head_1",))

    db_migrations.verify_database_schema(engine, logger)
