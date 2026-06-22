from datetime import date
from typing import Any, List, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field, field_validator

from core.avatar_validation import normalize_child_avatar


def _clean_picture_password(value: List[str]) -> List[str]:
    cleaned = [item.strip() for item in value if isinstance(item, str) and item.strip()]
    if len(cleaned) != len(value):
        raise ValueError("picture_password entries must be non-empty strings")
    return cleaned


class AuthSchemaBase(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    @field_validator("name", mode="before", check_fields=False)
    @classmethod
    def _normalize_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("name must not be blank")
        return normalized

    @field_validator(
        "password",
        "confirm_password",
        "refresh_token",
        "session_token",
        mode="before",
        check_fields=False,
    )
    @classmethod
    def _reject_blank_secret_strings(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("value must not be blank")
        return normalized

    @field_validator("two_factor_code", mode="before", check_fields=False)
    @classmethod
    def _normalize_two_factor_code(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = "".join(char for char in value.strip() if char.isdigit())
        return normalized or None

    @field_validator(
        "picture_password",
        "current_picture_password",
        "new_picture_password",
        mode="before",
        check_fields=False,
    )
    @classmethod
    def _normalize_picture_password(cls, value: List[str]) -> List[str]:
        return _clean_picture_password(value)


class RegisterIn(AuthSchemaBase):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=1)
    confirm_password: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("confirm_password", "confirmPassword"),
    )

    model_config = ConfigDict(
        populate_by_name=True,
        json_schema_extra={
            "example": {
                "name": "Parent Name",
                "email": "parent@example.com",
                "password": "secret123",
                "confirm_password": "secret123",
            }
        },
    )


class LoginIn(AuthSchemaBase):
    email: EmailStr
    password: str = Field(..., min_length=1)
    two_factor_code: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("two_factor_code", "twoFactorCode"),
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "parent@example.com",
                "password": "secret123",
            }
        }
    )


class VerifyEmailOtpIn(AuthSchemaBase):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "parent@example.com",
                "otp": "123456",
            }
        }
    )

    @field_validator("otp", mode="before")
    @classmethod
    def _normalize_otp(cls, value: str) -> str:
        normalized = "".join(char for char in value.strip() if char.isdigit())
        if len(normalized) != 6:
            raise ValueError("otp must be exactly 6 digits")
        return normalized


class ResendEmailOtpIn(AuthSchemaBase):
    email: EmailStr

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "parent@example.com",
            }
        }
    )


class RefreshIn(AuthSchemaBase):
    refresh_token: str = Field(..., min_length=1)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
            }
        }
    )


class ChildLoginIn(AuthSchemaBase):
    child_id: int = Field(..., gt=0)
    name: str = Field(..., min_length=1, max_length=100)
    picture_password: List[str] = Field(..., min_length=3, max_length=3)
    device_id: Optional[str] = None
    device_fingerprint: Optional[str] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "picture_password": ["cat", "dog", "apple"],
                "device_id": "tablet-kid-a",
            }
        }
    )


class ChildRegisterIn(AuthSchemaBase):
    name: str = Field(..., min_length=1, max_length=100)
    picture_password: List[str] = Field(..., min_length=3, max_length=3)
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

    @field_validator("avatar", mode="before")
    @classmethod
    def _normalize_avatar(cls, value: Optional[str]) -> Optional[str]:
        return normalize_child_avatar(value)


class ChildChangePasswordIn(AuthSchemaBase):
    child_id: int = Field(..., gt=0)
    name: str = Field(..., min_length=1, max_length=100)
    current_picture_password: List[str] = Field(
        ...,
        min_length=3,
        max_length=3,
        validation_alias=AliasChoices(
            "current_picture_password",
            "currentPicturePassword",
        ),
    )
    new_picture_password: List[str] = Field(
        ...,
        min_length=3,
        max_length=3,
        validation_alias=AliasChoices(
            "new_picture_password",
            "newPicturePassword",
        ),
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "child_id": 1,
                "name": "Alice",
                "current_picture_password": ["cat", "dog", "apple"],
                "new_picture_password": ["sun", "moon", "star"],
            }
        }
    )


class ChildSessionValidateIn(AuthSchemaBase):
    session_token: str = Field(..., min_length=1)
    device_id: Optional[str] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "session_token": "child-session-token",
                "device_id": "tablet-kid-a",
            }
        }
    )


class UserOut(BaseModel):
    id: int
    email: EmailStr
    role: str
    name: str | None = None
    is_active: bool
    email_verified: bool
    email_verified_at: str | None = None
    plan: str
    limits: dict[str, Any]
    features: dict[str, Any]
    two_factor_enabled: bool
    two_factor_method: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserOut

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.access.token",
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.refresh.token",
                "token_type": "bearer",
                "user": {
                    "id": 1,
                    "email": "parent@example.com",
                    "role": "parent",
                    "name": "Parent Name",
                    "is_active": True,
                    "plan": "FREE",
                    "limits": {"children": 1},
                    "features": {"advanced_reports": False},
                    "two_factor_enabled": False,
                    "two_factor_method": None,
                    "created_at": "2026-03-24T10:00:00+00:00",
                    "updated_at": "2026-03-24T10:00:00+00:00",
                },
            }
        }
    )


class PendingVerificationResponse(BaseModel):
    success: bool
    message: str
    email: EmailStr
    verification_required: bool
    otp_expires_at: str | None = None
    resend_available_at: str | None = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "success": True,
                "message": "Registration successful. Verify your email with the OTP we sent.",
                "email": "parent@example.com",
                "verification_required": True,
                "otp_expires_at": "2026-03-24T10:05:00+00:00",
                "resend_available_at": "2026-03-24T10:01:00+00:00",
            }
        }
    )


class OtpActionResponse(BaseModel):
    success: bool
    message: str
    email: EmailStr
    otp_expires_at: str | None = None
    resend_available_at: str | None = None


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.access.token",
                "token_type": "bearer",
            }
        }
    )


class CurrentUserResponse(BaseModel):
    user: UserOut


class ForgotPasswordIn(AuthSchemaBase):
    email: EmailStr

    model_config = ConfigDict(json_schema_extra={"example": {"email": "parent@example.com"}})


class ResetPasswordIn(AuthSchemaBase):
    token: str = Field(..., min_length=1)
    new_password: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("new_password", "newPassword"),
    )
    confirm_password: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("confirm_password", "confirmPassword"),
    )

    model_config = ConfigDict(
        populate_by_name=True,
        json_schema_extra={
            "example": {
                "token": "reset-token-here",
                "new_password": "NewPassword123!",
                "confirm_password": "NewPassword123!",
            }
        },
    )
