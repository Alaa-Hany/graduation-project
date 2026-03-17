from datetime import date
from typing import List, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field, field_validator


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

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "parent@example.com",
                "password": "secret123",
            }
        }
    )


class RefreshIn(AuthSchemaBase):
    refresh_token: str = Field(..., min_length=1)


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


class ChildSessionValidateIn(AuthSchemaBase):
    session_token: str = Field(..., min_length=1)
    device_id: Optional[str] = None
