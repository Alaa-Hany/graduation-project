from __future__ import annotations

import base64
import hashlib
import logging
from functools import lru_cache

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import Text
from sqlalchemy.types import TypeDecorator

from core.observability import emit_event
from core.settings import settings

logger = logging.getLogger(__name__)

ENCRYPTED_VALUE_PREFIX = "enc::v1::"
DECRYPT_FAILURE_SENTINEL = "[ENCRYPTED_FIELD_UNREADABLE]"


def _derive_fernet_key(secret_material: str) -> bytes:
    digest = hashlib.sha256(secret_material.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest)


def _active_secret_material() -> str:
    key = settings.data_encryption_key
    if not key:
        raise RuntimeError(
            "DATA_ENCRYPTION_KEY environment variable is not set. "
            "This is required for field-level encryption and must be separate "
            "from the JWT secret. Set it before starting the application."
        )
    return key


def _previous_secret_materials() -> tuple[str, ...]:
    if settings.data_encryption_previous_keys:
        return settings.data_encryption_previous_keys
    return ()


@lru_cache(maxsize=1)
def _fernet_chain() -> tuple[Fernet, tuple[Fernet, ...]]:
    active = Fernet(_derive_fernet_key(_active_secret_material()))
    previous = tuple(Fernet(_derive_fernet_key(item)) for item in _previous_secret_materials())
    return active, previous


def encrypt_text(value: str) -> str:
    if not value or value.startswith(ENCRYPTED_VALUE_PREFIX):
        return value
    active, _ = _fernet_chain()
    token = active.encrypt(value.encode("utf-8")).decode("utf-8")
    return f"{ENCRYPTED_VALUE_PREFIX}{token}"


def decrypt_text(value: str) -> str:
    if not value or not value.startswith(ENCRYPTED_VALUE_PREFIX):
        return value

    token = value[len(ENCRYPTED_VALUE_PREFIX) :].encode("utf-8")
    active, previous = _fernet_chain()
    for candidate in (active, *previous):
        try:
            return candidate.decrypt(token).decode("utf-8")
        except InvalidToken:
            continue

    # Every active/previous key failed to decrypt this value, meaning the
    # ciphertext is corrupted or was encrypted under a key that has since
    # been retired without being kept in DATA_ENCRYPTION_PREVIOUS_KEYS.
    # Returning the raw ciphertext here would let an opaque Fernet token
    # silently flow into API responses/UI as if it were valid plaintext, and
    # a plain log.error is easy to miss. Emit a tracked observability event
    # (visible via /admin/diagnostics) and return a clearly-marked sentinel.
    emit_event(
        "encrypted_field.decrypt_failed",
        category="security",
        severity="critical",
    )
    return DECRYPT_FAILURE_SENTINEL


class EncryptedString(TypeDecorator[str]):
    impl = Text
    cache_ok = True

    def process_bind_param(self, value: str | None, dialect) -> str | None:
        if value is None:
            return None
        return encrypt_text(value)

    def process_result_value(self, value: str | None, dialect) -> str | None:
        if value is None:
            return None
        return decrypt_text(value)
