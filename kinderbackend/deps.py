import logging
from collections.abc import Callable, Generator
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWTError as JWTError
from sqlalchemy.orm import Session

from admin_auth import ADMIN_TOKEN_TYPE
from auth import decode_token
from core.errors import http_error, not_found, unauthorized
from core.message_catalog import AuthMessages, FeatureMessages
from database import SessionLocal
from models import ChildProfile, User

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False, bearerFormat="JWT")


def _is_parent_user_verified(user: User) -> bool:
    # email_verified is the sole source of truth. The old fallback
    # (is_active=True AND email_otp_hash=None) allowed accounts with
    # email_verified=False to pass — removed.
    return bool(getattr(user, "email_verified", False))


@dataclass(frozen=True)
class AiBuddyPrincipal:
    parent: User
    child: ChildProfile | None
    token_type: str


@dataclass(frozen=True)
class AnalyticsPrincipal:
    """Resolved caller for analytics-ingest endpoints.

    ``child`` is set only when the request was authenticated with a
    ``child_session`` token; for parent access tokens it is ``None``.
    """

    parent: User
    child: ChildProfile | None
    token_type: str


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
        raise unauthorized(AuthMessages.AUTHENTICATION_REQUIRED)
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
        if token_type == ADMIN_TOKEN_TYPE:
            raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)
        if token_type == "child_session":
            raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)
        subject = payload.get("sub")
        if not isinstance(subject, str) or not subject:
            raise unauthorized(AuthMessages.INVALID_TOKEN_PAYLOAD)
        return subject
    except JWTError:
        raise unauthorized(AuthMessages.INVALID_TOKEN)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if creds is None or not creds.credentials:
        raise unauthorized(AuthMessages.AUTHENTICATION_REQUIRED)

    token = creds.credentials
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
        if token_type == ADMIN_TOKEN_TYPE:
            raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)
        if token_type == "child_session":
            raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)
        user_id = payload.get("sub")
        token_version = _coerce_token_version(payload.get("token_version"))
    except JWTError:
        raise unauthorized(AuthMessages.INVALID_TOKEN)

    if not user_id:
        raise unauthorized(AuthMessages.INVALID_TOKEN_PAYLOAD)
    if token_version is None:
        raise unauthorized(AuthMessages.TOKEN_REVOKED)

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise not_found(AuthMessages.USER_NOT_FOUND)
    if token_version != int(user.token_version or 0):
        raise unauthorized(AuthMessages.TOKEN_REVOKED)
    if not bool(getattr(user, "is_active", False)) or not _is_parent_user_verified(user):
        raise unauthorized(AuthMessages.EMAIL_VERIFICATION_REQUIRED)
    return user


def get_ai_buddy_principal(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> AiBuddyPrincipal:
    if creds is None or not creds.credentials:
        raise unauthorized(AuthMessages.AUTHENTICATION_REQUIRED)

    token = creds.credentials
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
    except JWTError:
        raise unauthorized(AuthMessages.INVALID_TOKEN)

    if token_type == ADMIN_TOKEN_TYPE:
        raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)

    if token_type == "child_session":
        child_id = payload.get("child_id") or payload.get("sub")
        if child_id is None:
            raise unauthorized(AuthMessages.INVALID_TOKEN_PAYLOAD)

        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == int(child_id),
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if child is None:
            raise not_found("Child not found")

        parent = db.query(User).filter(User.id == int(child.parent_id)).first()
        if parent is None:
            raise not_found(AuthMessages.USER_NOT_FOUND)

        return AiBuddyPrincipal(
            parent=parent,
            child=child,
            token_type="child_session",
        )

    parent = get_current_user(creds=creds, db=db)
    return AiBuddyPrincipal(parent=parent, child=None, token_type="access")


def get_analytics_principal(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> AnalyticsPrincipal:
    """Authorize an analytics-ingest request from a parent OR a child.

    Child mode authenticates with a ``child_session`` token and never holds a
    parent access token, so without this the child's own activity could never
    reach the backend — only a parent replaying the same device could push it.
    Accepting the child token here lets the child's progress sync in real time
    and show up for the parent on any device.

    The owning parent is resolved from the child record, so analytics stay
    attributed to the right account. Endpoints must still verify that a child
    only pushes data for itself (``payload.child_id == principal.child.id``).
    """
    if creds is None or not creds.credentials:
        raise unauthorized(AuthMessages.AUTHENTICATION_REQUIRED)

    token = creds.credentials
    try:
        payload = decode_token(token)
        token_type = payload.get("token_type")
    except JWTError:
        raise unauthorized(AuthMessages.INVALID_TOKEN)

    if token_type == ADMIN_TOKEN_TYPE:
        raise unauthorized(AuthMessages.INVALID_TOKEN_TYPE)

    if token_type == "child_session":
        child_id = payload.get("child_id") or payload.get("sub")
        if child_id is None:
            raise unauthorized(AuthMessages.INVALID_TOKEN_PAYLOAD)

        child = (
            db.query(ChildProfile)
            .filter(
                ChildProfile.id == int(child_id),
                ChildProfile.deleted_at.is_(None),
            )
            .first()
        )
        if child is None:
            raise not_found("Child not found")

        parent = db.query(User).filter(User.id == int(child.parent_id)).first()
        if parent is None:
            raise not_found(AuthMessages.USER_NOT_FOUND)

        return AnalyticsPrincipal(
            parent=parent,
            child=child,
            token_type="child_session",
        )

    parent = get_current_user(creds=creds, db=db)
    return AnalyticsPrincipal(parent=parent, child=None, token_type="access")


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
                message=FeatureMessages.feature_not_available(feature_name, plan),
                code="FEATURE_NOT_AVAILABLE",
                extra={
                    "feature": feature_name,
                    "current_plan": plan,
                    "hint": FeatureMessages.upgrade_hint(feature_name),
                },
            )
        return user

    return check_feature
