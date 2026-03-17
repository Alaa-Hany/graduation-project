from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class AiBuddyProviderOut(BaseModel):
    configured: bool
    mode: str
    status: str
    reason: str | None = None


class AiBuddyMessageOut(BaseModel):
    id: int
    session_id: int
    child_id: int
    role: str
    content: str
    intent: str | None = None
    response_source: str
    status: str
    client_message_id: str | None = None
    safety_status: str
    metadata_json: dict[str, Any] = Field(default_factory=dict)
    retention_expires_at: str | None = None
    archived_at: str | None = None
    created_at: str | None = None


class AiBuddySessionOut(BaseModel):
    id: int
    child_id: int
    parent_user_id: int
    status: str
    title: str | None = None
    provider_mode: str
    provider_status: str
    unavailable_reason: str | None = None
    visibility_mode: str
    parent_summary: str | None = None
    started_at: str | None = None
    last_message_at: str | None = None
    ended_at: str | None = None
    retention_expires_at: str | None = None
    metadata_json: dict[str, Any] = Field(default_factory=dict)
    messages_count: int = 0


class AiBuddyConversationOut(BaseModel):
    session: AiBuddySessionOut | None = None
    messages: list[AiBuddyMessageOut] = Field(default_factory=list)
    provider: AiBuddyProviderOut


class AiBuddyStartSessionIn(BaseModel):
    child_id: int
    force_new: bool = False
    title: str | None = None


class AiBuddySendMessageIn(BaseModel):
    child_id: int
    content: str = Field(..., min_length=1, max_length=1000)
    client_message_id: str | None = Field(None, max_length=120)
    quick_action: str | None = Field(None, max_length=80)


class AiBuddySendMessageOut(BaseModel):
    session: AiBuddySessionOut
    user_message: AiBuddyMessageOut
    assistant_message: AiBuddyMessageOut
    provider: AiBuddyProviderOut


class AiBuddyRetentionPolicyOut(BaseModel):
    messages_retained_days: int
    auto_archive: bool
    delete_supported: bool


class AiBuddyUsageMetricsOut(BaseModel):
    sessions_count: int
    messages_count: int
    child_messages_count: int
    assistant_messages_count: int
    last_session_at: str | None = None
    allowed_count: int
    refusal_count: int
    safe_redirect_count: int


class AiBuddyFlagSummaryOut(BaseModel):
    message_id: int
    occurred_at: str | None = None
    classification: str
    topic: str | None = None
    reason: str | None = None
    action: str | None = None


class AiBuddyVisibilitySessionOut(BaseModel):
    id: int
    status: str
    provider_status: str
    provider_mode: str | None = None
    last_message_at: str | None = None
    parent_summary: str | None = None


class AiBuddyVisibilitySummaryOut(BaseModel):
    child_id: int
    child_name: str
    visibility_mode: str
    transcript_access: bool
    parent_summary: str
    provider: AiBuddyProviderOut
    retention_policy: AiBuddyRetentionPolicyOut
    usage_metrics: AiBuddyUsageMetricsOut
    current_session: AiBuddyVisibilitySessionOut | None = None
    recent_flags: list[AiBuddyFlagSummaryOut] = Field(default_factory=list)


class AiBuddyDeleteHistoryOut(BaseModel):
    child_id: int
    deleted_sessions: int
    deleted_messages: int
    deleted_at: str
