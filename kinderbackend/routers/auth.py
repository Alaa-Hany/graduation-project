from fastapi import APIRouter, Depends
from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from deps import get_current_user, get_db
from models import User
from rate_limit import (
    parent_pin_mutation_rate_limit,
    parent_pin_verify_rate_limit,
    password_change_rate_limit,
)
from schemas.common import SuccessResponse
from services.auth_service import (
    change_parent_pin,
    change_password,
    disable_two_factor,
    enable_two_factor,
    get_parent_pin_status,
    logout,
    request_parent_pin_reset,
    set_parent_pin,
    setup_two_factor,
    two_factor_status,
    update_profile,
    verify_parent_pin,
)

router = APIRouter(tags=["auth"])
password_change_rate_limit_check = Depends(password_change_rate_limit())
parent_pin_mutation_rate_limit_check = Depends(parent_pin_mutation_rate_limit())
parent_pin_verify_rate_limit_check = Depends(parent_pin_verify_rate_limit())

PARENT_PIN_LENGTH = 4


class ProfileUpdate(BaseModel):
    name: str = Field(..., description="Updated display name for the parent account.")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Parent Name Updated",
            }
        }
    )


class ChangePasswordRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    current_password: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("current_password", "currentPassword"),
    )
    new_password: str = Field(
        ...,
        description="Must contain uppercase, digit, and special character",
        validation_alias=AliasChoices("new_password", "newPassword"),
    )
    confirm_password: str = Field(
        ...,
        validation_alias=AliasChoices("confirm_password", "confirmPassword"),
    )

    model_config = ConfigDict(
        populate_by_name=True,
        json_schema_extra={
            "example": {
                "current_password": "OldPassword123!",
                "new_password": "NewPassword123!",
                "confirm_password": "NewPassword123!",
            }
        },
    )


class ChangePasswordResponse(BaseModel):
    success: bool
    message: str = "Password changed successfully"


ChangePassword = ChangePasswordRequest


class ParentPinStatusResponse(BaseModel):
    has_pin: bool
    is_locked: bool
    failed_attempts: int
    locked_until: str | None = None


class ParentPinSetRequest(BaseModel):
    pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)
    confirm_pin: str = Field(
        ...,
        min_length=PARENT_PIN_LENGTH,
        max_length=PARENT_PIN_LENGTH,
    )

    model_config = ConfigDict(json_schema_extra={"example": {"pin": "1234", "confirm_pin": "1234"}})


class ParentPinVerifyRequest(BaseModel):
    pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)

    model_config = ConfigDict(json_schema_extra={"example": {"pin": "1234"}})


class ParentPinChangeRequest(BaseModel):
    current_pin: str = Field(
        ...,
        min_length=PARENT_PIN_LENGTH,
        max_length=PARENT_PIN_LENGTH,
    )
    new_pin: str = Field(..., min_length=PARENT_PIN_LENGTH, max_length=PARENT_PIN_LENGTH)
    confirm_pin: str = Field(
        ...,
        min_length=PARENT_PIN_LENGTH,
        max_length=PARENT_PIN_LENGTH,
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "current_pin": "1234",
                "new_pin": "5678",
                "confirm_pin": "5678",
            }
        }
    )


class ParentPinResetRequest(BaseModel):
    note: str | None = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "note": "I forgot the PIN and need help resetting it.",
            }
        }
    )


class ParentPinActionResponse(BaseModel):
    success: bool
    message: str
    locked_until: str | None = None


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

    model_config = ConfigDict(json_schema_extra={"example": {"code": "123456"}})

    @field_validator("code", mode="before")
    @classmethod
    def _normalize_code(cls, value: str) -> str:
        normalized = "".join(char for char in value.strip() if char.isdigit())
        if not normalized:
            raise ValueError("value must not be blank")
        return normalized


class TwoFactorActionResponse(TwoFactorStatusResponse):
    success: bool
    message: str


@router.put(
    "/auth/profile",
    summary="Update Parent Profile",
    description="Update editable profile fields for the currently authenticated parent.",
    response_description="Updated parent profile payload.",
)
def update_profile_endpoint(
    payload: ProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return update_profile(payload=payload, db=db, user=user)


@router.post(
    "/auth/change-password",
    response_model=ChangePasswordResponse,
    summary="Change Parent Password",
    description="Change the authenticated parent's password after validating the current password and password policy.",
    response_description="Password change result.",
)
def change_password_endpoint(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    rate_limit_check: None = password_change_rate_limit_check,
):
    return change_password(payload=payload, db=db, user=user)


@router.post(
    "/auth/logout",
    response_model=SuccessResponse,
    summary="Logout Parent",
    description="Invalidate the current parent session by rotating the token version.",
    response_description="Logout success status.",
)
def logout_endpoint(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return logout(db=db, user=user)


@router.get(
    "/auth/parent-pin/status",
    response_model=ParentPinStatusResponse,
    summary="Get Parent PIN Status",
    description="Return whether a parent PIN is configured and whether it is currently locked.",
    response_description="Current parent PIN state.",
)
def get_parent_pin_status_endpoint(user: User = Depends(get_current_user)):
    return get_parent_pin_status(user=user)


@router.post(
    "/auth/parent-pin/set",
    response_model=ParentPinActionResponse,
    summary="Set Parent PIN",
    description="Create the 4-digit parent PIN used to protect sensitive child-mode actions.",
    response_description="Parent PIN creation result.",
)
def set_parent_pin_endpoint(
    payload: ParentPinSetRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    rate_limit_check: None = parent_pin_mutation_rate_limit_check,
):
    return set_parent_pin(payload=payload, db=db, user=user)


@router.post(
    "/auth/parent-pin/verify",
    response_model=ParentPinActionResponse,
    summary="Verify Parent PIN",
    description="Verify the current parent PIN and return lockout information when applicable.",
    response_description="Parent PIN verification result.",
)
def verify_parent_pin_endpoint(
    payload: ParentPinVerifyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    rate_limit_check: None = parent_pin_verify_rate_limit_check,
):
    return verify_parent_pin(payload=payload, db=db, user=user)


@router.post(
    "/auth/parent-pin/change",
    response_model=ParentPinActionResponse,
    summary="Change Parent PIN",
    description="Rotate the 4-digit parent PIN after validating the current PIN.",
    response_description="Parent PIN change result.",
)
def change_parent_pin_endpoint(
    payload: ParentPinChangeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    rate_limit_check: None = parent_pin_mutation_rate_limit_check,
):
    return change_parent_pin(payload=payload, db=db, user=user)


@router.post(
    "/auth/parent-pin/reset-request",
    response_model=ParentPinActionResponse,
    summary="Request Parent PIN Reset",
    description="Create a support-backed reset request for the current parent's PIN.",
    response_description="Reset-request creation result.",
)
def request_parent_pin_reset_endpoint(
    payload: ParentPinResetRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    rate_limit_check: None = parent_pin_mutation_rate_limit_check,
):
    return request_parent_pin_reset(payload=payload, db=db, user=user)


@router.get(
    "/auth/2fa/status",
    response_model=TwoFactorStatusResponse,
    summary="Get Parent 2FA Status",
    description="Return whether time-based one-time-password (TOTP) 2FA is enabled for the current parent.",
    response_description="Current 2FA state for the parent account.",
)
def get_two_factor_status_endpoint(user: User = Depends(get_current_user)):
    return two_factor_status(user=user)


@router.post(
    "/auth/2fa/setup",
    response_model=TwoFactorSetupResponse,
    summary="Setup Parent 2FA",
    description="Generate TOTP setup details for the current parent account.",
    response_description="TOTP provisioning details and current 2FA state.",
)
def setup_two_factor_endpoint(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return setup_two_factor(db=db, user=user)


@router.post(
    "/auth/2fa/enable",
    response_model=TwoFactorActionResponse,
    summary="Enable Parent 2FA",
    description="Enable TOTP-based two-factor authentication using a valid verification code.",
    response_description="2FA enablement result.",
)
def enable_two_factor_endpoint(
    payload: TwoFactorEnableRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return enable_two_factor(db=db, user=user, code=payload.code)


@router.post(
    "/auth/2fa/disable",
    response_model=TwoFactorActionResponse,
    summary="Disable Parent 2FA",
    description="Disable TOTP-based two-factor authentication for the current parent account.",
    response_description="2FA disablement result.",
)
def disable_two_factor_endpoint(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return disable_two_factor(db=db, user=user)
