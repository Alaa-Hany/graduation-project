from datetime import timedelta
from typing import Dict, Optional

import bcrypt
from jose import JWTError, jwt

from core.settings import settings
from core.time_utils import utc_now

ALGORITHM = settings.jwt_algorithm
SECRET_KEY = settings.jwt_active_secret


def get_jwt_decode_secrets() -> list[str]:
    # Active key first; previous keys allow staged secret rotation for token verification.
    return [settings.jwt_active_secret, *settings.jwt_previous_secrets]


def hash_password(password: str) -> str:
    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except Exception:
        return False


def create_token(subject: str, minutes: int, extra_claims: Optional[Dict] = None) -> str:
    expire = utc_now() + timedelta(minutes=minutes)
    payload = {"sub": subject, "exp": expire}
    if extra_claims:
        payload.update(extra_claims)
    headers = {"kid": settings.jwt_active_kid} if settings.jwt_active_kid else None
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM, headers=headers)


def decode_token(token: str) -> dict:
    last_error: JWTError | None = None
    for secret in get_jwt_decode_secrets():
        try:
            return jwt.decode(token, secret, algorithms=[ALGORITHM])
        except JWTError as exc:
            last_error = exc
            continue
    if last_error is None:
        raise JWTError("No decode secrets configured")
    raise last_error


def create_access_token(user_id: str, token_version: Optional[int] = 0) -> str:
    resolved_token_version = 0 if token_version is None else int(token_version)
    return create_token(
        user_id,
        minutes=60,
        extra_claims={"token_version": resolved_token_version},
    )


def create_refresh_token(user_id: str, token_version: int = 0) -> str:
    return create_token(
        user_id, minutes=60 * 24 * 7, extra_claims={"token_version": token_version}
    )  # 7 days
