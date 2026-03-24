from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote, urlencode

TWO_FACTOR_TOTP_METHOD = "totp"
TWO_FACTOR_TOTP_DIGITS = 6
TWO_FACTOR_TOTP_PERIOD_SECONDS = 30
DEFAULT_TWO_FACTOR_ISSUER = "KinderWorld"


def generate_totp_secret(*, num_bytes: int = 20) -> str:
    return base64.b32encode(secrets.token_bytes(num_bytes)).decode("ascii").rstrip("=")


def _normalized_secret(secret: str) -> str:
    normalized = secret.strip().replace(" ", "").upper()
    padding = "=" * ((8 - len(normalized) % 8) % 8)
    return normalized + padding


def normalize_totp_code(value: str | None) -> str | None:
    if value is None:
        return None
    digits = "".join(char for char in value.strip() if char.isdigit())
    return digits or None


def generate_totp_code(
    secret: str,
    *,
    for_time: int | float | None = None,
    digits: int = TWO_FACTOR_TOTP_DIGITS,
    period_seconds: int = TWO_FACTOR_TOTP_PERIOD_SECONDS,
) -> str:
    counter = int((for_time if for_time is not None else time.time()) // period_seconds)
    key = base64.b32decode(_normalized_secret(secret), casefold=True)
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code_int = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(code_int % (10**digits)).zfill(digits)


def verify_totp_code(
    secret: str,
    code: str | None,
    *,
    for_time: int | float | None = None,
    window: int = 1,
    digits: int = TWO_FACTOR_TOTP_DIGITS,
    period_seconds: int = TWO_FACTOR_TOTP_PERIOD_SECONDS,
) -> bool:
    normalized_code = normalize_totp_code(code)
    if normalized_code is None or len(normalized_code) != digits:
        return False

    current_time = for_time if for_time is not None else time.time()
    for offset in range(-window, window + 1):
        candidate_time = current_time + (offset * period_seconds)
        if (
            generate_totp_code(
                secret,
                for_time=candidate_time,
                digits=digits,
                period_seconds=period_seconds,
            )
            == normalized_code
        ):
            return True
    return False


def provisioning_uri(
    *,
    secret: str,
    account_name: str,
    issuer: str = DEFAULT_TWO_FACTOR_ISSUER,
) -> str:
    label = quote(f"{issuer}:{account_name}")
    query = urlencode(
        {
            "secret": secret,
            "issuer": issuer,
            "algorithm": "SHA1",
            "digits": str(TWO_FACTOR_TOTP_DIGITS),
            "period": str(TWO_FACTOR_TOTP_PERIOD_SECONDS),
        }
    )
    return f"otpauth://totp/{label}?{query}"
