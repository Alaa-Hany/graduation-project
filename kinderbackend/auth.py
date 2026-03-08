import logging
import os
from datetime import datetime, timedelta
from typing import Optional, Dict
from jose import jwt
import bcrypt

logger = logging.getLogger(__name__)

SECRET_KEY = (
    os.getenv("KINDER_JWT_SECRET")
    or os.getenv("JWT_SECRET_KEY")
    or os.getenv("SECRET_KEY")
    or "CHANGE_ME_TO_A_LONG_RANDOM_SECRET"
)
ALGORITHM = "HS256"

if SECRET_KEY == "CHANGE_ME_TO_A_LONG_RANDOM_SECRET":
    logger.warning(
        "Using fallback JWT secret. Set KINDER_JWT_SECRET (or JWT_SECRET_KEY) in production."
    )

def hash_password(password: str) -> str:
    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    return hashed.decode('utf-8')

def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
    except Exception:
        return False

def create_token(subject: str, minutes: int, extra_claims: Optional[Dict] = None) -> str:
    expire = datetime.utcnow() + timedelta(minutes=minutes)
    payload = {"sub": subject, "exp": expire}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def create_access_token(user_id: str, token_version: Optional[int] = None) -> str:
    extra_claims = {"token_version": token_version} if token_version is not None else None
    return create_token(user_id, minutes=60, extra_claims=extra_claims)

def create_refresh_token(user_id: str, token_version: int = 0) -> str:
    return create_token(user_id, minutes=60 * 24 * 7, extra_claims={"token_version": token_version})  # 7 days
