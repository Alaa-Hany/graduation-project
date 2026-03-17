"""
Admin-specific JWT helpers.

Admin tokens carry an extra claim  token_type = "admin"  so they can NEVER
be accepted by the parent/child auth dependency (get_current_user) and vice-versa.
"""

from datetime import timedelta

from jose import jwt

# Re-use the same secret/algorithm as the rest of the app — isolation is
# enforced by the token_type claim, not by a different secret.
from auth import ALGORITHM, SECRET_KEY
from core.time_utils import utc_now

# Sentinel value embedded in every admin JWT
ADMIN_TOKEN_TYPE = "admin"

# Token lifetimes
_ACCESS_MINUTES = 60  # 1 hour
_REFRESH_DAYS = 7  # 7 days


def create_admin_access_token(admin_id: int, token_version: int = 0) -> str:
    """
    Create a short-lived access token for an admin user.
    The token_type='admin' claim prevents it from being used on parent/child endpoints.
    """
    expire = utc_now() + timedelta(minutes=_ACCESS_MINUTES)
    payload = {
        "sub": str(admin_id),
        "exp": expire,
        "token_type": ADMIN_TOKEN_TYPE,
        "token_version": token_version,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_admin_refresh_token(admin_id: int, token_version: int = 0) -> str:
    """
    Create a long-lived refresh token for an admin user.
    token_version is stored on the AdminUser row; bumping it invalidates all
    existing refresh tokens (used on logout).
    """
    expire = utc_now() + timedelta(days=_REFRESH_DAYS)
    payload = {
        "sub": str(admin_id),
        "exp": expire,
        "token_type": ADMIN_TOKEN_TYPE,
        "token_version": token_version,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
