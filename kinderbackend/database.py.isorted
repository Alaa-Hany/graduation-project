import os
from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "kinder.db"
DEFAULT_DATABASE_URL = f"sqlite:///{DB_PATH.as_posix()}"


def _normalize_database_url(database_url: str) -> str:
    normalized = (database_url or "").strip()
    if not normalized:
        return DEFAULT_DATABASE_URL
    if normalized.startswith("postgres://"):
        # Heroku/Render-style URLs still appear in some environments.
        return "postgresql+psycopg://" + normalized[len("postgres://") :]
    if normalized.startswith("postgresql://"):
        return "postgresql+psycopg://" + normalized[len("postgresql://") :]
    return normalized


DATABASE_URL = _normalize_database_url(os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL))
IS_SQLITE = DATABASE_URL.startswith("sqlite")
IS_POSTGRES = DATABASE_URL.startswith("postgresql")


def _build_connect_args(database_url: str) -> dict[str, object]:
    if database_url.startswith("sqlite"):
        return {
            "check_same_thread": False,
            # Wait before throwing "database is locked" for transient write contention.
            "timeout": 30,
        }
    return {}


def _build_engine_kwargs(database_url: str) -> dict[str, object]:
    kwargs: dict[str, object] = {
        "connect_args": _build_connect_args(database_url),
        "pool_pre_ping": True,
    }
    if database_url.startswith("postgresql"):
        kwargs.update(
            {
                "pool_size": int(os.getenv("DB_POOL_SIZE", "5")),
                "max_overflow": int(os.getenv("DB_MAX_OVERFLOW", "10")),
                "pool_recycle": int(os.getenv("DB_POOL_RECYCLE_SECONDS", "1800")),
            }
        )
    return kwargs


engine = create_engine(
    DATABASE_URL,
    **_build_engine_kwargs(DATABASE_URL),
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


@event.listens_for(engine, "connect")
def _set_sqlite_pragmas(dbapi_connection, _connection_record):
    if not IS_SQLITE:
        return
    cursor = dbapi_connection.cursor()
    # Better concurrent read/write behavior for SQLite.
    cursor.execute("PRAGMA journal_mode=WAL;")
    cursor.execute("PRAGMA busy_timeout=30000;")
    cursor.execute("PRAGMA foreign_keys=ON;")
    cursor.close()
