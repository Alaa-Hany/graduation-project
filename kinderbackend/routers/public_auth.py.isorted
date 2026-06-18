from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from rate_limit import auth_rate_limit, email_otp_resend_rate_limit, email_otp_verify_rate_limit
from schemas.auth import (
    AccessTokenResponse,
    AuthTokenResponse,
    ChildChangePasswordIn,
    ChildLoginIn,
    ChildRegisterIn,
    ChildSessionValidateIn,
    CurrentUserResponse,
    LoginIn,
    OtpActionResponse,
    PendingVerificationResponse,
    RefreshIn,
    RegisterIn,
    ResendEmailOtpIn,
    VerifyEmailOtpIn,
)
from serializers import user_to_json
from services.auth_service import auth_service
from services.child_service import (
    change_child_password,
    login_child,
    register_child,
    validate_child_session,
)

router = APIRouter()
auth_rate_limit_check = Depends(auth_rate_limit())
email_otp_verify_rate_limit_check = Depends(email_otp_verify_rate_limit())
email_otp_resend_rate_limit_check = Depends(email_otp_resend_rate_limit())


@router.post(
    "/auth/register",
    response_model=PendingVerificationResponse,
    summary="Register Parent Account",
    description="Create a new parent account, send a 6-digit OTP to the email address, and keep the account inactive until verification succeeds.",
    response_description="Pending verification payload with OTP timing metadata.",
)
def register(
    payload: RegisterIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = auth_rate_limit_check,
):
    return auth_service.register_parent(payload, db)


@router.post(
    "/auth/verify-email-otp",
    response_model=AuthTokenResponse,
    summary="Verify Parent Email OTP",
    description="Verify the OTP sent during registration, activate the parent account, and return access and refresh tokens.",
    response_description="Parent authentication payload after successful email verification.",
)
def verify_email_otp(
    payload: VerifyEmailOtpIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = email_otp_verify_rate_limit_check,
):
    return auth_service.verify_parent_email_otp(payload, db)


@router.post(
    "/auth/resend-email-otp",
    response_model=OtpActionResponse,
    summary="Resend Parent Email OTP",
    description="Resend the registration OTP email for a pending parent account, respecting resend cooldown rules.",
    response_description="OTP resend status with updated expiry and cooldown timestamps.",
)
def resend_email_otp(
    payload: ResendEmailOtpIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = email_otp_resend_rate_limit_check,
):
    return auth_service.resend_parent_email_otp(payload, db)


@router.post(
    "/auth/login",
    response_model=AuthTokenResponse,
    summary="Parent Login",
    description="Authenticate a parent account. If two-factor authentication is enabled, include `two_factor_code`.",
    response_description="Parent authentication payload with fresh access and refresh tokens.",
)
def login(
    payload: LoginIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = auth_rate_limit_check,
):
    return auth_service.login_parent(payload, db)


@router.post(
    "/auth/refresh",
    response_model=AccessTokenResponse,
    summary="Refresh Parent Access Token",
    description="Exchange a valid refresh token for a new parent access token.",
    response_description="New access token for the existing parent session.",
)
def refresh(
    payload: RefreshIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = auth_rate_limit_check,
):
    return auth_service.refresh_parent_access_token(payload, db)


@router.post(
    "/auth/child/register",
    summary="Register Child Profile",
    description="Create a child profile for the currently authenticated parent.",
    response_description="Created child authentication/profile payload.",
)
def child_register(
    payload: ChildRegisterIn,
    db: Session = Depends(get_db),
    parent: User = Depends(get_current_user),
    rate_limit_check: None = auth_rate_limit_check,
):
    return register_child(payload, parent, db)


@router.post(
    "/auth/child/login",
    summary="Child Login",
    description="Authenticate a child profile using the picture-password flow and optional device context.",
    response_description="Child session/authentication payload.",
)
def child_login(
    payload: ChildLoginIn,
    request: Request,
    db: Session = Depends(get_db),
    rate_limit_check: None = auth_rate_limit_check,
):
    client_ip = request.client.host if request.client else "unknown"
    user_agent = request.headers.get("User-Agent")
    return login_child(payload, db, client_ip=client_ip, user_agent=user_agent)


@router.post(
    "/auth/child/session/validate",
    summary="Validate Child Session",
    description="Validate a previously issued child session token and optional device binding.",
    response_description="Validation result for the supplied child session token.",
)
def child_session_validate(
    payload: ChildSessionValidateIn,
    db: Session = Depends(get_db),
):
    return validate_child_session(payload, db)


@router.post(
    "/auth/child/change-password",
    summary="Change Child Picture Password",
    description="Rotate the child's picture-password sequence after validating the current sequence.",
    response_description="Success status for the password rotation request.",
)
def child_change_password(
    payload: ChildChangePasswordIn,
    db: Session = Depends(get_db),
    rate_limit_check: None = auth_rate_limit_check,
):
    return change_child_password(payload, db)


@router.get(
    "/auth/me",
    response_model=CurrentUserResponse,
    summary="Get Current Parent",
    description="Return the currently authenticated parent profile and plan capabilities.",
    response_description="Current authenticated parent payload.",
)
def me(user: User = Depends(get_current_user)):
    return {"user": user_to_json(user)}
