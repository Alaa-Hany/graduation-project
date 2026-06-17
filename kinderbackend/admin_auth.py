"""
Admin-specific JWT helpers.

Admin tokens are isolated using:
- role = "admin"
- type = "access" | "refresh"

This prevents misuse across different auth flows.
"""

from datetime import timedelta
from jose import jwt, JWTError

from auth import ALGORITHM, SECRET_KEY
from core.time_utils import utc_now

# ================================
# Constants
# ================================

ADMIN_ROLE = "admin"
ADMIN_TOKEN_TYPE = ADMIN_ROLE

ACCESS_TOKEN_TYPE = "access"
REFRESH_TOKEN_TYPE = "refresh"

_ACCESS_MINUTES = 60
_REFRESH_DAYS = 7


# ================================
# Token Creation
# ================================

def create_admin_access_token(admin_id: int, token_version: int = 0) -> str:
    expire = utc_now() + timedelta(minutes=_ACCESS_MINUTES)

    payload = {
        "sub": str(admin_id),
        "exp": expire,
        "iat": utc_now(),
        "role": ADMIN_ROLE,
        "token_type": ADMIN_TOKEN_TYPE,
        "type": ACCESS_TOKEN_TYPE,
        "token_version": token_version,
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_admin_refresh_token(admin_id: int, token_version: int = 0) -> str:
    expire = utc_now() + timedelta(days=_REFRESH_DAYS)

    payload = {
        "sub": str(admin_id),
        "exp": expire,
        "iat": utc_now(),
        "role": ADMIN_ROLE,
        "token_type": ADMIN_TOKEN_TYPE,
        "type": REFRESH_TOKEN_TYPE,
        "token_version": token_version,
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


# ================================
# Token Decoding
# ================================

def decode_admin_token(token: str) -> dict:
    """
    Decode and validate an admin JWT.
    Raises Exception if invalid.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise Exception("Invalid or expired admin token")


# ================================
# Validators
# ================================

def verify_admin_access_token(token: str) -> dict:
    payload = decode_admin_token(token)

    if payload.get("role") != ADMIN_ROLE:
        raise Exception("Not an admin token")

    if payload.get("type") != ACCESS_TOKEN_TYPE:
        raise Exception("Invalid token type (expected access)")

    return payload


def verify_admin_refresh_token(token: str) -> dict:
    payload = decode_admin_token(token)

    if payload.get("role") != ADMIN_ROLE:
        raise Exception("Not an admin token")

    if payload.get("type") != REFRESH_TOKEN_TYPE:
        raise Exception("Invalid token type (expected refresh)")

    return payload
