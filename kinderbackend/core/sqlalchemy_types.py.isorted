from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime
from sqlalchemy.types import TypeDecorator

from core.time_utils import ensure_utc


class UTCDateTime(TypeDecorator[datetime]):
    """Persist datetimes as UTC-aware values and normalize legacy naive rows."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def load_dialect_impl(self, dialect):
        return dialect.type_descriptor(DateTime(timezone=True))

    def process_bind_param(self, value: datetime | None, dialect) -> datetime | None:
        if value is None:
            return None
        return ensure_utc(value)

    def process_result_value(self, value: datetime | str | None, dialect) -> datetime | None:
        if value is None:
            return None
        if isinstance(value, str):
            normalized = value.strip()
            if normalized.endswith("Z"):
                normalized = normalized[:-1] + "+00:00"
            value = datetime.fromisoformat(normalized)
        return ensure_utc(value)
