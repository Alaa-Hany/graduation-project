import logging
import os
from datetime import datetime, timedelta
from typing import Optional, Dict
from jose import jwt
import bcrypt
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

ALGORITHM = "HS256"

SECRET_KEY = (
    os.getenv("KINDER_JWT_SECRET")
    or os.getenv("JWT_SECRET_KEY")
    or os.getenv("SECRET_KEY")  # legacy fallback for existing deployments
)
if not SECRET_KEY:
    raise ValueError(
        "JWT secret not configured. Set KINDER_JWT_SECRET, JWT_SECRET_KEY, or SECRET_KEY environment variable."
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
