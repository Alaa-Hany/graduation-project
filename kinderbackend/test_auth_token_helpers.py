"""Unit tests for low-level auth/admin token helpers.

These exercise pure JWT/password helper functions (no DB, no HTTP) so the
critical ``auth_flows`` modules keep their branches covered.
"""

from datetime import timedelta

import pytest
from jose import jwt

import admin_auth
import auth
from admin_auth import (
    ACCESS_TOKEN_TYPE,
    ADMIN_ROLE,
    REFRESH_TOKEN_TYPE,
    create_admin_access_token,
    create_admin_refresh_token,
    decode_admin_token,
    verify_admin_access_token,
    verify_admin_refresh_token,
)
from auth import ALGORITHM, SECRET_KEY
from core.time_utils import utc_now


def _encode(payload: dict) -> str:
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


# ---------------------------------------------------------------------------
# admin_auth.py
# ---------------------------------------------------------------------------


def test_admin_access_token_roundtrip():
    token = create_admin_access_token(admin_id=42, token_version=3)
    payload = verify_admin_access_token(token)
    assert payload["sub"] == "42"
    assert payload["role"] == ADMIN_ROLE
    assert payload["type"] == ACCESS_TOKEN_TYPE
    assert payload["token_version"] == 3


def test_admin_refresh_token_roundtrip():
    token = create_admin_refresh_token(admin_id=7)
    payload = verify_admin_refresh_token(token)
    assert payload["sub"] == "7"
    assert payload["role"] == ADMIN_ROLE
    assert payload["type"] == REFRESH_TOKEN_TYPE


def test_decode_admin_token_rejects_garbage():
    with pytest.raises(Exception, match="Invalid or expired admin token"):
        decode_admin_token("not-a-real-token")


def test_decode_admin_token_rejects_expired():
    expired = _encode(
        {
            "sub": "1",
            "exp": utc_now() - timedelta(minutes=5),
            "role": ADMIN_ROLE,
            "type": ACCESS_TOKEN_TYPE,
        }
    )
    with pytest.raises(Exception, match="Invalid or expired admin token"):
        decode_admin_token(expired)


def test_verify_admin_access_token_rejects_non_admin_role():
    token = _encode({"sub": "1", "exp": utc_now() + timedelta(minutes=5),
                     "role": "user", "type": ACCESS_TOKEN_TYPE})
    with pytest.raises(Exception, match="Not an admin token"):
        verify_admin_access_token(token)


def test_verify_admin_access_token_rejects_wrong_type():
    # A valid admin refresh token must not pass the access-token check.
    refresh = create_admin_refresh_token(admin_id=1)
    with pytest.raises(Exception, match="expected access"):
        verify_admin_access_token(refresh)


def test_verify_admin_refresh_token_rejects_non_admin_role():
    token = _encode({"sub": "1", "exp": utc_now() + timedelta(minutes=5),
                     "role": "user", "type": REFRESH_TOKEN_TYPE})
    with pytest.raises(Exception, match="Not an admin token"):
        verify_admin_refresh_token(token)


def test_verify_admin_refresh_token_rejects_wrong_type():
    access = create_admin_access_token(admin_id=1)
    with pytest.raises(Exception, match="expected refresh"):
        verify_admin_refresh_token(access)


# ---------------------------------------------------------------------------
# auth.py helpers
# ---------------------------------------------------------------------------


def test_hash_and_verify_password_roundtrip():
    hashed = auth.hash_password("s3cret-pass")
    assert hashed != "s3cret-pass"
    assert auth.verify_password("s3cret-pass", hashed) is True
    assert auth.verify_password("wrong", hashed) is False


def test_verify_password_returns_false_on_malformed_hash():
    # A non-bcrypt hash makes bcrypt.checkpw raise -> helper must swallow it.
    assert auth.verify_password("anything", "not-a-bcrypt-hash") is False


def test_create_token_without_extra_claims():
    token = auth.create_token("subject-1", minutes=5)
    decoded = auth.decode_token(token)
    assert decoded["sub"] == "subject-1"
    assert "exp" in decoded


def test_create_token_with_extra_claims():
    token = auth.create_token("subject-2", minutes=5, extra_claims={"role": "parent"})
    decoded = auth.decode_token(token)
    assert decoded["role"] == "parent"


def test_decode_token_raises_on_invalid_token():
    from jose import JWTError

    with pytest.raises(JWTError):
        auth.decode_token("clearly.invalid.token")


def test_get_jwt_decode_secrets_includes_active_secret():
    secrets = auth.get_jwt_decode_secrets()
    assert secrets
    assert secrets[0] == SECRET_KEY
