from datetime import date
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class ChildCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    picture_password: List[str] = Field(..., min_length=3, max_length=3)
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

    @field_validator("name", mode="before")
    @classmethod
    def _normalize_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("name must not be blank")
        return normalized

    @field_validator("picture_password", mode="before")
    @classmethod
    def _normalize_picture_password(cls, value: List[str]) -> List[str]:
        cleaned = [item.strip() for item in value if isinstance(item, str) and item.strip()]
        if len(cleaned) != len(value):
            raise ValueError("picture_password entries must be non-empty strings")
        return cleaned


class ChildUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    picture_password: Optional[List[str]] = Field(default=None, min_length=3, max_length=3)
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    avatar: Optional[str] = None

    @field_validator("name", mode="before")
    @classmethod
    def _normalize_name(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("name must not be blank")
        return normalized

    @field_validator("picture_password", mode="before")
    @classmethod
    def _normalize_picture_password(cls, value: Optional[List[str]]) -> Optional[List[str]]:
        if value is None:
            return None
        cleaned = [item.strip() for item in value if isinstance(item, str) and item.strip()]
        if len(cleaned) != len(value):
            raise ValueError("picture_password entries must be non-empty strings")
        return cleaned
