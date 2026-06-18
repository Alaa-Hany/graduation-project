from typing import Any, Generic, TypeVar

from pydantic import BaseModel

DataT = TypeVar("DataT")


class SuccessResponse(BaseModel):
    success: bool


class ActionResponse(SuccessResponse):
    message: str | None = None


class ErrorResponse(BaseModel):
    detail: Any


class ResponseMeta(BaseModel):
    """Standard metadata included in every enveloped response."""

    request_id: str
    timestamp: str  # ISO-8601 UTC


class EnvelopedResponse(BaseModel, Generic[DataT]):
    """
    Standard response envelope applied to all authenticated endpoints::

        {
            "data": <payload>,
            "meta": {
                "request_id": "...",
                "timestamp": "2026-06-18T10:00:00.000Z"
            }
        }
    """

    data: DataT
    meta: ResponseMeta
