import logging
from collections.abc import Callable, Generator
from typing import Optional

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from admin_auth import ADMIN_TOKEN_TYPE
from auth import decode_token
from core.errors import http_error, not_found, unauthorized
from database import SessionLocal
from models import User

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False, bearerFormat="JWT")


def _coerce_token_version(raw_token_version: object) -> int | None:
    if isinstance(raw_token_version, bool):
        return int(raw_token_version)
    if isinstance(raw_token_version, int):
        return raw_token_version
    if isinstance(raw_token_version, (str, bytes, bytearray)):
        try:
            return int(raw_token_version)
        except ValueError:
            return None
    return None


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def decode_bearer(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise unauthorized("Authentication required")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
        if token_type == ADMIN_TOKEN_TYPE:
            raise unauthorized("Invalid token type")
        if token_type == "child_session":
            raise unauthorized("Invalid token type")
        subject = payload.get("sub")
        if not isinstance(subject, str) or not subject:
            raise unauthorized("Invalid token payload")
        return subject
    except JWTError:
        raise unauthorized("Invalid token")


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if creds is None or not creds.credentials:
        raise unauthorized("Authentication required")

    token = creds.credentials
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
        if token_type == ADMIN_TOKEN_TYPE:
            raise unauthorized("Invalid token type")
        if token_type == "child_session":
            raise unauthorized("Invalid token type")
        user_id = payload.get("sub")
        token_version = _coerce_token_version(payload.get("token_version"))
    except JWTError:
        raise unauthorized("Invalid token")

    if not user_id:
        raise unauthorized("Invalid token payload")
    if token_version is None:
        raise unauthorized("Token has been revoked")

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise not_found("User not found")
    if token_version != int(user.token_version or 0):
        raise unauthorized("Token has been revoked")
    return user


def require_feature(feature_name: str) -> Callable[[User], User]:
    """
    Dependency factory for feature-gated endpoints.

    Usage:
        @router.get("/reports/basic")
        def get_basic_reports(user: User = Depends(require_feature("basic_reports"))):
            return {"reports": []}

    Args:
        feature_name: The feature to require (e.g., "advanced_reports")

    Raises:
        HTTPException(403): If feature not available in user's plan

    Returns:
        User object if feature is available
    """
    from plan_service import feature_enabled, get_user_plan

    def check_feature(user: User = Depends(get_current_user)) -> User:
        plan = get_user_plan(user)
        if not feature_enabled(plan, feature_name):
            logger.warning(
                f"Access denied to feature '{feature_name}' for user {user.id} on plan {plan}"
            )
            raise http_error(
                status_code=403,
                message=f"Feature '{feature_name}' not available in {plan} plan",
                code="FEATURE_NOT_AVAILABLE",
                extra={
                    "feature": feature_name,
                    "current_plan": plan,
                    "hint": f"Upgrade to access {feature_name}",
                },
            )
        return user

    return check_feature
