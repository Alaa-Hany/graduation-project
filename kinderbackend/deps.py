from typing import Optional
import logging

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from admin_auth import ADMIN_TOKEN_TYPE
from auth import ALGORITHM, SECRET_KEY
from database import SessionLocal
from models import User

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False, bearerFormat="JWT")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def decode_bearer(authorization: Optional[str]) -> Optional[str]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication required")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("token_type") == ADMIN_TOKEN_TYPE:
            raise HTTPException(status_code=401, detail="Invalid token type")
        return payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if creds is None or not creds.credentials:
        raise HTTPException(status_code=401, detail="Authentication required")

    token = creds.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("token_type") == ADMIN_TOKEN_TYPE:
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def require_feature(feature_name: str):
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
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "FEATURE_NOT_AVAILABLE",
                    "message": f"Feature '{feature_name}' not available in {plan} plan",
                    "feature": feature_name,
                    "current_plan": plan,
                    "hint": f"Upgrade to access {feature_name}",
                },
            )
        return user
    
    return check_feature
