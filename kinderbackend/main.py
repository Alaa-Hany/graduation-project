import os
from typing import Optional, List
import logging
import logging.handlers
from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, Header
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime, date
from jose import jwt, JWTError
from fastapi.middleware.cors import CORSMiddleware

# Load environment variables from .env file
load_dotenv()

from database import engine
from db_migrations import verify_database_schema
from models import User, ChildProfile
from auth import hash_password, verify_password, create_access_token, create_refresh_token, SECRET_KEY, ALGORITHM
from deps import decode_bearer, get_db, get_current_user
from plan_service import PLAN_FREE, PLAN_LIMITS, get_user_plan
from serializers import child_to_json, user_to_json
from rate_limit import auth_rate_limit, api_rate_limit
from routers.auth import router as auth_router
from routers.notifications import router as notifications_router
from routers.privacy import router as privacy_router
from routers.content import router as content_router
from routers.support import router as support_router
from routers.features import router as features_router
from routers.parental_controls import router as parental_controls_router
from routers.billing_methods import router as billing_methods_router
from routers.subscription import (
    router as subscription_router,
    public_router as subscription_public_router,
    billing_router as subscription_billing_router,
)
from routers.admin_auth import router as admin_auth_router
from routers.admin_admins import router as admin_admins_router
from routers.admin_audit import router as admin_audit_router
from routers.admin_analytics import router as admin_analytics_router
from routers.admin_cms import router as admin_cms_router
from routers.admin_settings import router as admin_settings_router
from routers.admin_children import router as admin_children_router
from routers.admin_seed import router as admin_seed_router, SEED_ENABLED as ADMIN_SEED_ENABLED
from routers.admin_support import router as admin_support_router
from routers.admin_subscriptions import router as admin_subscriptions_router
from routers.admin_users import router as admin_users_router
# Import admin_models so SQLAlchemy registers the tables with Base.metadata
import admin_models  # noqa: F401

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

app = FastAPI()
PREMIUM_PRICE_USD = 10

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # React dev server
        "http://localhost:8080",  # Vue/Angular dev server
        "https://localhost:3000",
        "https://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "https://127.0.0.1:3000",
        "https://127.0.0.1:8080",
    ] if os.getenv("ENVIRONMENT") != "production" else [],  # No origins in production - use reverse proxy
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "X-Requested-With",
        "X-CSRF-Token",
    ],
    allow_credentials=True,  # Required for cookies/auth headers
    max_age=86400,  # Cache preflight for 24 hours
)


@app.on_event("startup")
def on_startup():
    verify_database_schema(engine, logger)


class RegisterIn(BaseModel):
    name: str
    email: EmailStr
    password: str
    confirmPassword: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Parent Name",
                "email": "parent@example.com",
                "password": "secret123",
                "confirmPassword": "secret123",
            }
        }
    )


class LoginIn(BaseModel):
    email: EmailStr
    password: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "parent@example.com",
                "password": "secret123",
            }
        }
    )


class RefreshIn(BaseModel):
    refresh_token: str


class ChildCreate(BaseModel):
    name: str
    picture_password: List[str]
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    avatar: Optional[str] = None
    parent_email: Optional[EmailStr] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Alice",
                "picture_password": ["cat", "dog", "apple"],
                "parent_email": "parent@example.com",
            }
        }
    )


class ChildLoginIn(BaseModel):
    child_id: int
    name: str
    picture_password: List[str]

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "picture_password": ["cat", "dog", "apple"],
            }
        }
    )


class ChildRegisterIn(BaseModel):
    name: str
    picture_password: List[str]
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    avatar: Optional[str] = None
    parent_email: EmailStr

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Alice",
                "picture_password": ["cat", "dog", "apple"],
                "parent_email": "parent@example.com",
            }
        }
    )


class ChildChangePasswordIn(BaseModel):
    """
    Change child picture password.

    Accepts both camelCase and snake_case:
    - currentPicturePassword / current_picture_password
    - newPicturePassword / new_picture_password
    """
    child_id: int
    name: str
    currentPicturePassword: List[str] = Field(..., alias="current_picture_password")
    newPicturePassword: List[str] = Field(..., alias="new_picture_password")

    model_config = ConfigDict(populate_by_name=True)


@app.get("/")
def root():
    return {"message": "Backend is running"}


@app.post("/auth/register")
def register(payload: RegisterIn, db: Session = Depends(get_db), rate_limit_check: None = Depends(auth_rate_limit)):
    try:
        normalized_email = normalize_email(payload.email)
        validate_email_domain(normalized_email)
        if payload.password != payload.confirmPassword:
            raise HTTPException(status_code=400, detail="Passwords do not match")

        if db.query(User).filter(func.lower(User.email) == normalized_email).first():
            raise HTTPException(status_code=400, detail="Email already registered")

        now = datetime.utcnow()
        user = User(
            email=normalized_email,
            password_hash=hash_password(payload.password),
            role="parent",
            name=payload.name,
            is_active=True,
            plan=PLAN_FREE,
            created_at=now,
            updated_at=now,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        return {
            "access_token": create_access_token(str(user.id)),
            "refresh_token": create_refresh_token(str(user.id), user.token_version),
            "token_type": "bearer",
            "user": user_to_json(user),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Register error: {exc}")


@app.post("/auth/login")
def login(payload: LoginIn, db: Session = Depends(get_db), rate_limit_check: None = Depends(auth_rate_limit)):
    normalized_email = normalize_email(payload.email)
    validate_email_domain(normalized_email)
    user = db.query(User).filter(func.lower(User.email) == normalized_email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user.updated_at = datetime.utcnow()
    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id), user.token_version),
        "token_type": "bearer",
        "user": user_to_json(user),
    }


@app.post("/auth/refresh")
def refresh(payload: RefreshIn, db: Session = Depends(get_db), rate_limit_check: None = Depends(auth_rate_limit)):
    try:
        decoded = jwt.decode(payload.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = decoded.get("sub")
        token_version = decoded.get("token_version", 0)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    if int(token_version) != int(getattr(user, "token_version", 0)):
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return {"access_token": create_access_token(str(user_id)), "token_type": "bearer"}


@app.post("/children")
def create_child(
    data: ChildCreate,
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
):
    if data.parent_email:
        validate_email_domain(normalize_email(data.parent_email))
    resolved_age = _resolve_child_age(data.age, data.date_of_birth)
    _validate_child_age(resolved_age)
    parent = _resolve_parent(data.parent_email, authorization, db)
    _enforce_child_limit(parent, db)
    _ensure_unique_child_name(parent, data.name, db)

    child = ChildProfile(
        parent_id=parent.id,
        name=data.name,
        picture_password=data.picture_password,
        date_of_birth=data.date_of_birth,
        age=resolved_age,
        avatar=data.avatar,
    )
    db.add(child)
    db.commit()
    db.refresh(child)

    return {"child": child_to_json(child)}


@app.get("/children")
def list_children(
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    children = (
        db.query(ChildProfile)
        .filter(ChildProfile.parent_id == parent.id)
        .all()
    )
    return {"children": [child_to_json(child) for child in children]}


@app.delete("/children/{child_id}")
def delete_child(
    child_id: int,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    child = db.query(ChildProfile).filter(ChildProfile.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    if child.parent_id != parent.id:
        raise HTTPException(status_code=403, detail="Forbidden")

    db.delete(child)
    db.commit()
    return {"success": True}


class ChildUpdate(BaseModel):
    name: Optional[str] = None
    picture_password: Optional[List[str]] = None
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    avatar: Optional[str] = None


@app.put("/children/{child_id}")
def update_child(
    child_id: int,
    payload: ChildUpdate,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
):
    child = db.query(ChildProfile).filter(ChildProfile.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")
    if child.parent_id != parent.id:
        raise HTTPException(status_code=403, detail="Forbidden")

    if payload.name is not None:
        child.name = payload.name
    if payload.picture_password is not None:
        child.picture_password = payload.picture_password
    if payload.date_of_birth is not None:
        child.date_of_birth = payload.date_of_birth
    if payload.age is not None or payload.date_of_birth is not None:
        resolved_age = _resolve_child_age(payload.age, payload.date_of_birth)
        _validate_child_age(resolved_age)
        child.age = resolved_age
    if payload.avatar is not None:
        child.avatar = payload.avatar

    child.updated_at = datetime.utcnow()
    db.add(child)
    db.commit()
    db.refresh(child)
    return {"child": child_to_json(child)}


@app.post("/auth/child/register")
def child_register(payload: ChildRegisterIn, db: Session = Depends(get_db), rate_limit_check: None = Depends(auth_rate_limit)):
    parent_email = normalize_email(payload.parent_email)
    validate_email_domain(parent_email)
    parent = db.query(User).filter(func.lower(User.email) == parent_email).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")

    resolved_age = _resolve_child_age(payload.age, payload.date_of_birth)
    _validate_child_age(resolved_age)
    _enforce_child_limit(parent, db)
    _ensure_unique_child_name(parent, payload.name, db)

    child = ChildProfile(
        parent_id=parent.id,
        name=payload.name,
        picture_password=payload.picture_password,
        date_of_birth=payload.date_of_birth,
        age=resolved_age,
        avatar=payload.avatar,
    )
    db.add(child)
    db.commit()
    db.refresh(child)

    return {"child": child_to_json(child)}


@app.post("/auth/child/login")
def child_login(payload: ChildLoginIn, db: Session = Depends(get_db), rate_limit_check: None = Depends(auth_rate_limit)):
    child = db.query(ChildProfile).filter(ChildProfile.id == payload.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    normalized_name = payload.name.strip().lower()
    child_name = (child.name or "").strip().lower()
    if not normalized_name or normalized_name != child_name:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    stored = child.picture_password or []
    if stored != payload.picture_password:
        raise HTTPException(status_code=401, detail="Invalid picture password")

    return {"success": True, "child_id": child.id, "name": child.name}


@app.post("/auth/child/change-password")
def child_change_password(
    payload: ChildChangePasswordIn,
    db: Session = Depends(get_db),
):
    child = db.query(ChildProfile).filter(ChildProfile.id == payload.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    normalized_name = payload.name.strip().lower()
    child_name = (child.name or "").strip().lower()
    if not normalized_name or normalized_name != child_name:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    stored = child.picture_password or []
    if stored != payload.currentPicturePassword:
        raise HTTPException(status_code=401, detail="Current picture password is incorrect")

    if not payload.newPicturePassword or len(payload.newPicturePassword) != 3:
        raise HTTPException(status_code=422, detail="Picture password must contain exactly 3 items")

    child.picture_password = payload.newPicturePassword
    child.updated_at = datetime.utcnow()
    db.add(child)
    db.commit()
    db.refresh(child)

    return {"success": True, "message": "Picture password changed successfully"}


@app.get("/auth/me")
def me(user: User = Depends(get_current_user)):
    return {"user": user_to_json(user)}


def _resolve_parent(
    parent_email: Optional[str],
    authorization: Optional[str],
    db: Session,
) -> User:
    if parent_email:
        normalized_email = normalize_email(parent_email)
        parent = db.query(User).filter(func.lower(User.email) == normalized_email).first()
        if not parent:
            raise HTTPException(status_code=404, detail="Parent not found")
        return parent

    parent_id = decode_bearer(authorization)
    if not parent_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    parent = db.query(User).filter(User.id == int(parent_id)).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")
    return parent


def normalize_email(email: str) -> str:
    return email.strip().lower()


def _resolve_child_age(age: Optional[int], dob: Optional[date]) -> Optional[int]:
    if age is not None:
        return age
    if dob is None:
        return None
    today = date.today()
    computed = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return max(computed, 0)


def _validate_child_age(age: Optional[int]) -> None:
    if age is None:
        raise HTTPException(status_code=422, detail="Child age is required")
    if age < 5 or age > 12:
        raise HTTPException(status_code=422, detail="Child age must be between 5 and 12")


ALLOWED_EMAIL_DOMAINS = {
    "gmail.com",
    "outlook.com",
    "hotmail.com",
    "live.com",
}


def validate_email_domain(email: str) -> None:
    if "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email format")
    domain = email.split("@", 1)[1].strip().lower()
    if domain not in ALLOWED_EMAIL_DOMAINS:
        raise HTTPException(
            status_code=400,
            detail="Email must be Gmail or Microsoft (outlook.com/hotmail.com/live.com)",
        )


def _enforce_child_limit(parent: User, db: Session):
    plan = get_user_plan(parent)
    limit = PLAN_LIMITS.get(plan)
    if limit is None:
        return
    child_count = (
        db.query(ChildProfile)
        .filter(ChildProfile.parent_id == parent.id)
        .count()
    )
    if child_count >= limit:
        raise HTTPException(
            status_code=402,
            detail={
                "code": "CHILD_LIMIT_REACHED",
                "message": f"Plan limit reached ({limit}). Upgrade to add more children.",
                "plan": plan,
                "limit": limit,
                "current_count": child_count,
                "price_usd": PREMIUM_PRICE_USD,
                "currency": "USD",
            },
        )


def _ensure_unique_child_name(parent: User, name: str, db: Session):
    existing = (
        db.query(ChildProfile)
        .filter(ChildProfile.parent_id == parent.id, ChildProfile.name == name)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "CHILD_NAME_EXISTS",
                "message": "Child name already exists for this parent.",
            },
        )


app.include_router(subscription_router)
app.include_router(subscription_public_router)
app.include_router(subscription_billing_router)
app.include_router(billing_methods_router)
app.include_router(auth_router)
app.include_router(notifications_router)
app.include_router(privacy_router)
app.include_router(content_router)
app.include_router(support_router)
app.include_router(features_router)
app.include_router(parental_controls_router)

# ── Admin system (Phase 1) ────────────────────────────────────────────────────
app.include_router(admin_auth_router)
app.include_router(admin_admins_router)
app.include_router(admin_users_router)
app.include_router(admin_children_router)
app.include_router(admin_audit_router)
app.include_router(admin_support_router)
app.include_router(admin_analytics_router)
app.include_router(admin_cms_router)
app.include_router(admin_subscriptions_router)
app.include_router(admin_settings_router)
if ADMIN_SEED_ENABLED:
    logger.warning("Admin seed endpoint is enabled for this environment")
    app.include_router(admin_seed_router)
