"""
Admin authentication router - fully separate from parent/child auth.

Endpoints:
  POST /admin/auth/login    - email + password -> access + refresh tokens
  POST /admin/auth/refresh  - refresh token -> new access token
  POST /admin/auth/logout   - invalidate refresh tokens (bump token_version)
  GET  /admin/auth/me       - return current admin profile + roles + permissions
"""

import logging

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from admin_deps import get_current_admin
from deps import get_db
from rate_limit import auth_rate_limit
from services.admin_auth_service import admin_auth_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Auth"])


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


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


@router.post("/login", response_model=AdminLoginResponse, summary="Admin login")
def admin_login(
    payload: AdminLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
    rate_limit_check: None = Depends(auth_rate_limit),
):
    return admin_auth_service.login(payload=payload, request=request, db=db)


@router.post("/refresh", response_model=AdminTokenResponse, summary="Refresh admin access token")
def admin_refresh(
    payload: AdminRefreshRequest,
    db: Session = Depends(get_db),
    rate_limit_check: None = Depends(auth_rate_limit),
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
