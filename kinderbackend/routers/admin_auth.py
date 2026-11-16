"""
Admin authentication router - fully separate from parent/child auth.

Endpoints:
  POST /admin/auth/login    - email + password -> access + refresh tokens
  POST /admin/auth/refresh  - refresh token -> new access token
  POST /admin/auth/logout   - invalidate refresh tokens (bump token_version)
  GET  /admin/auth/me       - return current admin profile + roles + permissions
"""

import hmac
import logging
import os

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import AliasChoices, BaseModel, EmailStr, Field, field_validator
from sqlalchemy.orm import Session

from admin_auth import create_admin_access_token, create_admin_refresh_token
from admin_deps import get_current_admin
from admin_models import AdminUser, AdminUserRole
from admin_utils import build_admin_payload
from auth import hash_password
from core.settings import settings
from core.time_utils import db_utc_now
from deps import get_db
from rate_limit import admin_two_factor_rate_limit, auth_rate_limit
from routers.admin_seed import ensure_builtin_admin_rbac
from services.admin_auth_service import admin_auth_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Auth"])

# auth_rate_limit is a factory: it must be *called* to get the dependency.
# Depends(auth_rate_limit) would just run the factory and never limit anything.
admin_auth_rate_limit_check = Depends(auth_rate_limit())
admin_two_factor_rate_limit_check = Depends(admin_two_factor_rate_limit())


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str
    two_factor_code: str | None = Field(
        default=None,
        validation_alias=AliasChoices("two_factor_code", "twoFactorCode"),
    )

    @field_validator("two_factor_code", mode="before")
    @classmethod
    def _normalize_two_factor_code(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = "".join(char for char in value.strip() if char.isdigit())
        return normalized or None


class AdminRefreshRequest(BaseModel):
    refresh_token: str


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AdminLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    admin: dict


class TwoFactorStatusResponse(BaseModel):
    enabled: bool
    method: str | None = None
    confirmed_at: str | None = None


class TwoFactorSetupResponse(TwoFactorStatusResponse):
    secret: str
    manual_entry_key: str
    issuer: str
    provisioning_uri: str


class TwoFactorEnableRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=12)

    @field_validator("code", mode="before")
    @classmethod
    def _normalize_code(cls, value: str) -> str:
        normalized = "".join(char for char in value.strip() if char.isdigit())
        if not normalized:
            raise ValueError("value must not be blank")
        return normalized


class TwoFactorDisableRequest(TwoFactorEnableRequest):
    """Current authenticator code, proving the caller still holds the device."""


class TwoFactorActionResponse(TwoFactorStatusResponse):
    success: bool
    message: str


class AdminBootstrapRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    name: str | None = None


class AdminBootstrapStatusResponse(BaseModel):
    can_bootstrap: bool


@router.post("/login", response_model=AdminLoginResponse, summary="Admin login")
def admin_login(
    payload: AdminLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
    rate_limit_check: None = admin_auth_rate_limit_check,
):
    return admin_auth_service.login(payload=payload, request=request, db=db)


@router.get(
    "/bootstrap/status",
    response_model=AdminBootstrapStatusResponse,
    summary="Check whether the first admin account can be created",
)
def admin_bootstrap_status(db: Session = Depends(get_db)):
    if not _bootstrap_allowed_here():
        return {"can_bootstrap": False}
    return {"can_bootstrap": db.query(AdminUser.id).first() is None}


def _bootstrap_secret() -> str:
    return (os.getenv("ADMIN_BOOTSTRAP_SECRET") or "").strip()


def _bootstrap_allowed_here() -> bool:
    """In production the bootstrap endpoint is closed unless a secret is configured.

    Otherwise, on a fresh or wiped database, the first stranger to call it
    would become super admin.
    """
    return not settings.is_production or bool(_bootstrap_secret())


def _require_bootstrap_secret(provided: str | None) -> None:
    expected = _bootstrap_secret()
    if not _bootstrap_allowed_here():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not Found")
    if expected and not hmac.compare_digest((provided or "").strip(), expected):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid bootstrap secret",
        )


@router.post(
    "/bootstrap",
    response_model=AdminLoginResponse,
    summary="Create the first admin account",
    description=(
        "Disabled in production unless ADMIN_BOOTSTRAP_SECRET is set; when it is "
        "set, the X-Admin-Bootstrap-Secret header must match it."
    ),
)
def admin_bootstrap(
    payload: AdminBootstrapRequest,
    db: Session = Depends(get_db),
    rate_limit_check: None = admin_auth_rate_limit_check,
    bootstrap_secret: str | None = Header(default=None, alias="X-Admin-Bootstrap-Secret"),
):
    _require_bootstrap_secret(bootstrap_secret)
    if db.query(AdminUser.id).first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="The first admin account has already been created",
        )

    seeded = ensure_builtin_admin_rbac(db)
    role_by_name = seeded["role_by_name"]
    now = db_utc_now()
    admin = AdminUser(
        email=payload.email.strip().lower(),
        password_hash=hash_password(payload.password),
        name=(payload.name or "").strip() or "Super Admin",
        is_active=True,
        token_version=0,
        created_at=now,
        updated_at=now,
    )
    db.add(admin)
    db.flush()

    super_admin_role = role_by_name["super_admin"]
    db.add(AdminUserRole(admin_user_id=admin.id, role_id=super_admin_role.id))
    db.commit()
    db.refresh(admin)

    return {
        "access_token": create_admin_access_token(admin.id, admin.token_version),
        "refresh_token": create_admin_refresh_token(admin.id, admin.token_version),
        "token_type": "bearer",
        "admin": build_admin_payload(admin, db),
    }


@router.post("/refresh", response_model=AdminTokenResponse, summary="Refresh admin access token")
def admin_refresh(
    payload: AdminRefreshRequest,
    db: Session = Depends(get_db),
    rate_limit_check: None = admin_auth_rate_limit_check,
):
    """
    Exchange a valid admin refresh token for a new access token.

    - Validates token_type='admin' claim.
    - Validates token_version matches the stored value (logout invalidates old tokens).
    - Disabled admins are blocked.
    """
    return admin_auth_service.refresh(payload=payload, db=db)


@router.post("/logout", summary="Admin logout - invalidates refresh tokens")
def admin_logout(
    request: Request,
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return admin_auth_service.logout(request=request, admin=admin, db=db)


@router.get("/me", summary="Get current admin profile")
def admin_me(
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return admin_auth_service.current_profile(admin=admin, db=db)


@router.get("/2fa/status", response_model=TwoFactorStatusResponse, summary="Get admin 2FA status")
def admin_two_factor_status(admin=Depends(get_current_admin)):
    return admin_auth_service.two_factor_status(admin=admin)


class AdminTwoFactorSetupRequest(BaseModel):
    password: str = Field(
        ...,
        min_length=1,
        max_length=256,
        validation_alias=AliasChoices("password", "current_password", "currentPassword"),
    )


@router.post("/2fa/setup", response_model=TwoFactorSetupResponse, summary="Start admin 2FA setup")
def admin_two_factor_setup(
    payload: AdminTwoFactorSetupRequest,
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
    rate_limit_check: None = admin_two_factor_rate_limit_check,
):
    return admin_auth_service.two_factor_setup(admin=admin, db=db, password=payload.password)


@router.post(
    "/2fa/enable",
    response_model=TwoFactorActionResponse,
    summary="Enable admin 2FA",
)
def admin_two_factor_enable(
    payload: TwoFactorEnableRequest,
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return admin_auth_service.enable_two_factor(admin=admin, code=payload.code, db=db)


@router.post(
    "/2fa/disable",
    response_model=TwoFactorActionResponse,
    summary="Disable admin 2FA",
    description="Requires a current code from the authenticator app.",
)
def admin_two_factor_disable(
    payload: TwoFactorDisableRequest,
    admin=Depends(get_current_admin),
    db: Session = Depends(get_db),
    rate_limit_check: None = admin_two_factor_rate_limit_check,
):
    return admin_auth_service.disable_two_factor(admin=admin, code=payload.code, db=db)
