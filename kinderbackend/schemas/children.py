from datetime import date
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from core.avatar_validation import normalize_child_avatar


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

    @field_validator("avatar", mode="before")
    @classmethod
    def _normalize_avatar(cls, value: Optional[str]) -> Optional[str]:
        return normalize_child_avatar(value)


class ChildListItem(BaseModel):
    """Slim child shape for the parent's child-list card.

    Excludes ``parent_id`` (raw FK), ``date_of_birth``, and the
    ``created_at``/``updated_at`` audit timestamps that the list card never
    renders. Used as ``response_model`` so Pydantic drops the extra fields
    from each serialized child, trimming both CPU and wire payload.

    The progress fields (``xp``..``activities_completed``) are aggregated
    server-side from the child's analytics events/sessions so the parent
    dashboard and child-management cards show the same real progress the
    child sees in child mode, even on a fresh parent device.
    """

    id: int
    name: str
    age: Optional[int] = None
    avatar: Optional[str] = None
    is_active: bool = True
    xp: int = 0
    level: int = 1
    streak: int = 0
    total_time_spent: int = 0
    activities_completed: int = 0


class ChildListResponse(BaseModel):
    children: List[ChildListItem]


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

    @field_validator("avatar", mode="before")
    @classmethod
    def _normalize_avatar(cls, value: Optional[str]) -> Optional[str]:
        return normalize_child_avatar(value)
