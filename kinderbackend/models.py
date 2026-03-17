from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    false,
    func,
    text,
    true,
)
from sqlalchemy.orm import relationship

from core.sqlalchemy_types import UTCDateTime
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    name = Column(String, nullable=True)
    role = Column(String, nullable=False, default="parent")
    is_active = Column(Boolean, default=True, nullable=False)
    is_premium = Column(Boolean, default=False, nullable=False, server_default=false())
    plan = Column(String, nullable=False, default="FREE", server_default=text("'FREE'"))

    token_version = Column(Integer, default=0, nullable=False, server_default=text("0"))
    parent_pin_hash = Column(String, nullable=True)
    parent_pin_failed_attempts = Column(
        Integer, default=0, nullable=False, server_default=text("0")
    )
    parent_pin_locked_until = Column(UTCDateTime(), nullable=True)
    parent_pin_updated_at = Column(UTCDateTime(), nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # One-to-many: a parent can have multiple child profiles
    children = relationship("ChildProfile", back_populates="parent", cascade="all, delete-orphan")
    notifications = relationship(
        "Notification", back_populates="user", cascade="all, delete-orphan"
    )
    privacy_setting = relationship(
        "PrivacySetting", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    support_tickets = relationship(
        "SupportTicket", back_populates="user", cascade="all, delete-orphan"
    )
    payment_methods = relationship("PaymentMethod", cascade="all, delete-orphan")
    subscription_profile = relationship(
        "SubscriptionProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    subscription_events = relationship(
        "SubscriptionEvent", back_populates="user", cascade="all, delete-orphan"
    )
    billing_transactions = relationship(
        "BillingTransaction", back_populates="user", cascade="all, delete-orphan"
    )
    payment_attempts = relationship(
        "PaymentAttempt", back_populates="user", cascade="all, delete-orphan"
    )
    ai_buddy_sessions = relationship(
        "AiBuddySession", back_populates="parent_user", cascade="all, delete-orphan"
    )


class SubscriptionProfile(Base):
    __tablename__ = "subscription_profiles"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    current_plan_id = Column(
        String, nullable=False, default="FREE", server_default=text("'FREE'"), index=True
    )
    selected_plan_id = Column(String, nullable=True, index=True)
    started_at = Column(UTCDateTime(), nullable=True, index=True)
    expires_at = Column(UTCDateTime(), nullable=True, index=True)
    cancel_at = Column(UTCDateTime(), nullable=True, index=True)
    will_renew = Column(Boolean, nullable=False, default=False, server_default=false())
    status = Column(
        String, nullable=False, default="free", server_default=text("'free'"), index=True
    )
    last_payment_status = Column(
        String,
        nullable=False,
        default="not_applicable",
        server_default=text("'not_applicable'"),
        index=True,
    )
    provider = Column(
        String, nullable=False, default="internal", server_default=text("'internal'")
    )
    provider_customer_id = Column(String, nullable=True, index=True)
    provider_subscription_id = Column(String, nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user = relationship("User", back_populates="subscription_profile")
    events = relationship(
        "SubscriptionEvent", back_populates="subscription_profile", cascade="all, delete-orphan"
    )
    billing_transactions = relationship(
        "BillingTransaction",
        back_populates="subscription_profile",
        cascade="all, delete-orphan",
    )
    payment_attempts = relationship(
        "PaymentAttempt", back_populates="subscription_profile", cascade="all, delete-orphan"
    )


class SubscriptionEvent(Base):
    __tablename__ = "subscription_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subscription_profile_id = Column(
        Integer,
        ForeignKey("subscription_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type = Column(String, nullable=False, index=True)
    previous_plan_id = Column(String, nullable=True, index=True)
    plan_id = Column(String, nullable=False, index=True)
    previous_status = Column(String, nullable=True, index=True)
    status = Column(String, nullable=False, index=True)
    payment_status = Column(String, nullable=True, index=True)
    source = Column(
        String, nullable=False, default="internal", server_default=text("'internal'"), index=True
    )
    provider_reference = Column(String, nullable=True, index=True)
    details_json = Column(JSON, nullable=True)
    occurred_at = Column(UTCDateTime(), nullable=False, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    user = relationship("User", back_populates="subscription_events")
    subscription_profile = relationship("SubscriptionProfile", back_populates="events")


class BillingTransaction(Base):
    __tablename__ = "billing_transactions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subscription_profile_id = Column(
        Integer,
        ForeignKey("subscription_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plan_id = Column(String, nullable=False, index=True)
    transaction_type = Column(String, nullable=False, index=True)
    amount_cents = Column(Integer, nullable=False, default=0, server_default=text("0"))
    currency = Column(String, nullable=False, default="USD", server_default=text("'USD'"))
    status = Column(String, nullable=False, index=True)
    provider_reference = Column(String, nullable=True, index=True)
    effective_at = Column(UTCDateTime(), nullable=False, index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    user = relationship("User", back_populates="billing_transactions")
    subscription_profile = relationship("SubscriptionProfile", back_populates="billing_transactions")


class PaymentAttempt(Base):
    __tablename__ = "payment_attempts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subscription_profile_id = Column(
        Integer,
        ForeignKey("subscription_profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plan_id = Column(String, nullable=False, index=True)
    attempt_type = Column(String, nullable=False, index=True)
    status = Column(String, nullable=False, index=True)
    amount_cents = Column(Integer, nullable=False, default=0, server_default=text("0"))
    currency = Column(String, nullable=False, default="USD", server_default=text("'USD'"))
    provider_reference = Column(String, nullable=True, index=True)
    failure_code = Column(String, nullable=True, index=True)
    failure_message = Column(String, nullable=True)
    requested_at = Column(UTCDateTime(), nullable=False, index=True)
    completed_at = Column(UTCDateTime(), nullable=True, index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user = relationship("User", back_populates="payment_attempts")
    subscription_profile = relationship("SubscriptionProfile", back_populates="payment_attempts")


class PaymentWebhookEvent(Base):
    __tablename__ = "payment_webhook_events"
    __table_args__ = (
        UniqueConstraint("provider", "event_id", name="uq_payment_webhook_events_provider_event"),
    )

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    provider = Column(String, nullable=False, index=True)
    event_id = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False, index=True)
    status = Column(
        String, nullable=False, default="received", server_default=text("'received'"), index=True
    )
    signature_valid = Column(Boolean, nullable=False, default=True, server_default=true())
    duplicate_of_event_id = Column(String, nullable=True, index=True)
    error_message = Column(String, nullable=True)
    provider_customer_id = Column(String, nullable=True, index=True)
    provider_subscription_id = Column(String, nullable=True, index=True)
    provider_invoice_id = Column(String, nullable=True, index=True)
    provider_session_id = Column(String, nullable=True, index=True)
    subscription_profile_id = Column(
        Integer,
        ForeignKey("subscription_profiles.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    payload_json = Column(JSON, nullable=True)
    received_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    processed_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), nullable=False, server_default=func.now())
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class ChildProfile(Base):
    __tablename__ = "child_profiles"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    picture_password = Column(JSON, nullable=False)  # Stored as JSON array of strings
    date_of_birth = Column(Date, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    age = Column(Integer, nullable=True)
    avatar = Column(String, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False, server_default=true())
    deleted_at = Column(UTCDateTime(), nullable=True, index=True)

    parent = relationship("User", back_populates="children")
    activity_events = relationship(
        "ChildActivityEvent", back_populates="child", cascade="all, delete-orphan"
    )
    session_logs = relationship(
        "ChildSessionLog", back_populates="child", cascade="all, delete-orphan"
    )
    parental_control_setting = relationship(
        "ChildParentalControlSetting",
        back_populates="child",
        uselist=False,
        cascade="all, delete-orphan",
    )
    activity_sessions = relationship(
        "ActivitySession", back_populates="child", cascade="all, delete-orphan"
    )
    lesson_progress_records = relationship(
        "LessonProgress", back_populates="child", cascade="all, delete-orphan"
    )
    mood_entries = relationship(
        "ChildMoodEntry", back_populates="child", cascade="all, delete-orphan"
    )
    reward_redemptions = relationship(
        "RewardRedemption", back_populates="child", cascade="all, delete-orphan"
    )
    screen_time_logs = relationship(
        "ScreenTimeLog", back_populates="child", cascade="all, delete-orphan"
    )
    ai_interactions = relationship(
        "AiInteraction", back_populates="child", cascade="all, delete-orphan"
    )
    ai_buddy_sessions = relationship(
        "AiBuddySession", back_populates="child", cascade="all, delete-orphan"
    )
    ai_buddy_messages = relationship(
        "AiBuddyMessage", back_populates="child", cascade="all, delete-orphan"
    )
    daily_activity_summaries = relationship(
        "ChildDailyActivitySummary",
        back_populates="child",
        cascade="all, delete-orphan",
    )


class ChildSessionLog(Base):
    __tablename__ = "child_session_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    session_id = Column(String, nullable=True, index=True)
    source = Column(String, nullable=False, default="app", server_default=text("'app'"))
    started_at = Column(UTCDateTime(), nullable=False, index=True)
    ended_at = Column(UTCDateTime(), nullable=False, index=True)
    duration_seconds = Column(Integer, nullable=False, default=0, server_default=text("0"))
    metadata_json = Column(JSON, nullable=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    child = relationship("ChildProfile", back_populates="session_logs")


class ChildActivityEvent(Base):
    __tablename__ = "child_activity_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    event_type = Column(String, nullable=False, index=True)
    occurred_at = Column(UTCDateTime(), nullable=False, index=True)
    source = Column(String, nullable=False, default="app", server_default=text("'app'"))
    activity_name = Column(String, nullable=True)
    lesson_id = Column(String, nullable=True)
    mood_value = Column(Integer, nullable=True)
    achievement_key = Column(String, nullable=True)
    points = Column(Integer, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    metadata_json = Column(JSON, nullable=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    child = relationship("ChildProfile", back_populates="activity_events")


class ActivitySession(Base):
    __tablename__ = "activity_sessions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    activity_type = Column(String, nullable=False, index=True)
    source = Column(String, nullable=False, default="app", server_default=text("'app'"), index=True)
    context = Column(String, nullable=True)
    session_key = Column(String, nullable=True, index=True)
    status = Column(
        String, nullable=False, default="active", server_default=text("'active'"), index=True
    )
    started_at = Column(UTCDateTime(), nullable=False, index=True)
    ended_at = Column(UTCDateTime(), nullable=True, index=True)
    duration_seconds = Column(Integer, nullable=False, default=0, server_default=text("0"))
    metadata_json = Column(JSON, nullable=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    child = relationship("ChildProfile", back_populates="activity_sessions")


class LessonProgress(Base):
    __tablename__ = "lesson_progress"
    __table_args__ = (
        UniqueConstraint("child_id", "lesson_id", name="uq_lesson_progress_child_lesson"),
    )

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    lesson_id = Column(String, nullable=False, index=True)
    status = Column(
        String,
        nullable=False,
        default="not_started",
        server_default=text("'not_started'"),
        index=True,
    )
    progress_percent = Column(Integer, nullable=False, default=0, server_default=text("0"))
    attempt_count = Column(Integer, nullable=False, default=0, server_default=text("0"))
    score = Column(Integer, nullable=True)
    started_at = Column(UTCDateTime(), nullable=True)
    last_activity_at = Column(UTCDateTime(), nullable=True, index=True)
    completed_at = Column(UTCDateTime(), nullable=True, index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    child = relationship("ChildProfile", back_populates="lesson_progress_records")


class ChildMoodEntry(Base):
    __tablename__ = "child_mood_entries"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    mood_category = Column(String, nullable=False, index=True)
    mood_value = Column(Integer, nullable=True)
    note = Column(String, nullable=True)
    metadata_json = Column(JSON, nullable=True)
    recorded_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    child = relationship("ChildProfile", back_populates="mood_entries")


class RewardRedemption(Base):
    __tablename__ = "reward_redemptions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    reward_id = Column(String, nullable=True, index=True)
    reward_name = Column(String, nullable=False)
    points_spent = Column(Integer, nullable=False, default=0, server_default=text("0"))
    status = Column(
        String, nullable=False, default="pending", server_default=text("'pending'"), index=True
    )
    requested_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    redeemed_at = Column(UTCDateTime(), nullable=True, index=True)
    fulfilled_at = Column(UTCDateTime(), nullable=True, index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    child = relationship("ChildProfile", back_populates="reward_redemptions")


class ScreenTimeLog(Base):
    __tablename__ = "screen_time_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    usage_date = Column(Date, nullable=False, index=True)
    minutes_used = Column(Integer, nullable=False, default=0, server_default=text("0"))
    source = Column(String, nullable=False, default="app", server_default=text("'app'"), index=True)
    device_id = Column(String, nullable=True, index=True)
    category = Column(String, nullable=True, index=True)
    session_key = Column(String, nullable=True, index=True)
    logged_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    metadata_json = Column(JSON, nullable=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    child = relationship("ChildProfile", back_populates="screen_time_logs")


class AiInteraction(Base):
    __tablename__ = "ai_interactions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    interaction_type = Column(String, nullable=False, index=True)
    intent = Column(String, nullable=True, index=True)
    input_preview = Column(String, nullable=True)
    response_category = Column(String, nullable=True)
    safety_status = Column(
        String, nullable=False, default="unknown", server_default=text("'unknown'"), index=True
    )
    source = Column(
        String, nullable=False, default="ai_buddy", server_default=text("'ai_buddy'"), index=True
    )
    safety_flags_json = Column(JSON, nullable=True)
    metadata_json = Column(JSON, nullable=True)
    occurred_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    child = relationship("ChildProfile", back_populates="ai_interactions")


class AiBuddySession(Base):
    __tablename__ = "ai_buddy_sessions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    parent_user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status = Column(
        String, nullable=False, default="active", server_default=text("'active'"), index=True
    )
    title = Column(String, nullable=True)
    provider_mode = Column(
        String,
        nullable=False,
        default="internal_fallback",
        server_default=text("'internal_fallback'"),
        index=True,
    )
    provider_status = Column(
        String,
        nullable=False,
        default="fallback",
        server_default=text("'fallback'"),
        index=True,
    )
    unavailable_reason = Column(String, nullable=True)
    visibility_mode = Column(
        String,
        nullable=False,
        default="summary_and_metrics",
        server_default=text("'summary_and_metrics'"),
        index=True,
    )
    parent_summary = Column(String, nullable=True)
    started_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)
    last_message_at = Column(UTCDateTime(), nullable=True, index=True)
    ended_at = Column(UTCDateTime(), nullable=True, index=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    child = relationship("ChildProfile", back_populates="ai_buddy_sessions")
    parent_user = relationship("User", back_populates="ai_buddy_sessions")
    messages = relationship(
        "AiBuddyMessage", back_populates="session", cascade="all, delete-orphan"
    )


class AiBuddyMessage(Base):
    __tablename__ = "ai_buddy_messages"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(
        Integer,
        ForeignKey("ai_buddy_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role = Column(String, nullable=False, index=True)
    content = Column(String, nullable=False)
    intent = Column(String, nullable=True, index=True)
    response_source = Column(
        String,
        nullable=False,
        default="internal_fallback",
        server_default=text("'internal_fallback'"),
        index=True,
    )
    status = Column(
        String,
        nullable=False,
        default="completed",
        server_default=text("'completed'"),
        index=True,
    )
    client_message_id = Column(String, nullable=True, index=True)
    safety_status = Column(
        String, nullable=False, default="allowed", server_default=text("'allowed'"), index=True
    )
    metadata_json = Column(JSON, nullable=True)
    retention_expires_at = Column(UTCDateTime(), nullable=True, index=True)
    archived_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), nullable=False, server_default=func.now(), index=True)

    session = relationship("AiBuddySession", back_populates="messages")
    child = relationship("ChildProfile", back_populates="ai_buddy_messages")


class ChildDailyActivitySummary(Base):
    __tablename__ = "child_daily_activity_summaries"
    __table_args__ = (
        UniqueConstraint("child_id", "summary_date", name="uq_child_daily_activity_summary"),
    )

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    child_id = Column(
        Integer, ForeignKey("child_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    summary_date = Column(Date, nullable=False, index=True)
    screen_time_minutes = Column(Integer, nullable=False, default=0, server_default=text("0"))
    activities_completed = Column(Integer, nullable=False, default=0, server_default=text("0"))
    lessons_completed = Column(Integer, nullable=False, default=0, server_default=text("0"))
    mood_entries = Column(Integer, nullable=False, default=0, server_default=text("0"))
    achievements_unlocked = Column(Integer, nullable=False, default=0, server_default=text("0"))
    ai_interactions_count = Column(Integer, nullable=False, default=0, server_default=text("0"))
    data_source = Column(
        String, nullable=False, default="realtime", server_default=text("'realtime'")
    )
    last_event_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    archived_at = Column(UTCDateTime(), nullable=True, index=True)

    child = relationship("ChildProfile", back_populates="daily_activity_summaries")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    child_id = Column(Integer, ForeignKey("child_profiles.id"), nullable=True, index=True)
    type = Column(String, nullable=False, default="SYSTEM")
    title = Column(String, nullable=False)
    body = Column(String, nullable=False)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)

    user = relationship("User", back_populates="notifications")


class PrivacySetting(Base):
    __tablename__ = "privacy_settings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    data_collection_opt_out = Column(Boolean, default=False, nullable=False)
    personalized_recommendations = Column(Boolean, default=True, nullable=False)
    analytics_enabled = Column(Boolean, default=True, nullable=False)

    user = relationship("User", back_populates="privacy_setting")


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    subject = Column(String, nullable=False)
    message = Column(String, nullable=False)
    email = Column(String, nullable=True)
    category = Column(
        String,
        nullable=False,
        default="general_inquiry",
        server_default=text("'general_inquiry'"),
        index=True,
    )
    status = Column(
        String, nullable=False, default="open", server_default=text("'open'"), index=True
    )
    assigned_admin_id = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    closed_at = Column(UTCDateTime(), nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user = relationship("User", back_populates="support_tickets")
    assigned_admin = relationship("AdminUser", foreign_keys=[assigned_admin_id])
    thread_messages = relationship(
        "SupportTicketMessage",
        back_populates="ticket",
        cascade="all, delete-orphan",
        order_by="SupportTicketMessage.created_at",
    )


class SupportTicketMessage(Base):
    __tablename__ = "support_ticket_messages"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    ticket_id = Column(
        Integer, ForeignKey("support_tickets.id", ondelete="CASCADE"), nullable=False, index=True
    )
    admin_user_id = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    message = Column(String, nullable=False)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    ticket = relationship("SupportTicket", back_populates="thread_messages")
    admin_user = relationship("AdminUser", foreign_keys=[admin_user_id])
    user = relationship("User")


class ContentCategory(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    slug = Column(String, unique=True, nullable=False, index=True)
    title_en = Column(String, nullable=False)
    title_ar = Column(String, nullable=False)
    description_en = Column(String, nullable=True)
    description_ar = Column(String, nullable=True)
    created_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    updated_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at = Column(UTCDateTime(), nullable=True, index=True)

    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])
    contents = relationship("ContentItem", back_populates="category")
    quizzes = relationship("Quiz", back_populates="category")


class ContentItem(Base):
    __tablename__ = "contents"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    category_id = Column(
        Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    slug = Column(String, unique=True, nullable=False, index=True)
    content_type = Column(
        String, nullable=False, default="lesson", server_default=text("'lesson'"), index=True
    )
    status = Column(
        String, nullable=False, default="draft", server_default=text("'draft'"), index=True
    )
    title_en = Column(String, nullable=False)
    title_ar = Column(String, nullable=False)
    description_en = Column(String, nullable=True)
    description_ar = Column(String, nullable=True)
    body_en = Column(String, nullable=True)
    body_ar = Column(String, nullable=True)
    thumbnail_url = Column(String, nullable=True)
    age_group = Column(String, nullable=True)
    metadata_json = Column(JSON, nullable=True)
    created_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    updated_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    published_at = Column(UTCDateTime(), nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at = Column(UTCDateTime(), nullable=True, index=True)

    category = relationship("ContentCategory", back_populates="contents")
    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])
    quizzes = relationship("Quiz", back_populates="content")


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    content_id = Column(
        Integer, ForeignKey("contents.id", ondelete="SET NULL"), nullable=True, index=True
    )
    category_id = Column(
        Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    status = Column(
        String, nullable=False, default="draft", server_default=text("'draft'"), index=True
    )
    title_en = Column(String, nullable=False)
    title_ar = Column(String, nullable=False)
    description_en = Column(String, nullable=True)
    description_ar = Column(String, nullable=True)
    questions_json = Column(JSON, nullable=False, default=list)
    created_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    updated_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    published_at = Column(UTCDateTime(), nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at = Column(UTCDateTime(), nullable=True, index=True)

    content = relationship("ContentItem", back_populates="quizzes")
    category = relationship("ContentCategory", back_populates="quizzes")
    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])


class SystemSetting(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    key = Column(String, unique=True, nullable=False, index=True)
    value_json = Column(JSON, nullable=False)
    updated_by = Column(
        Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    updater = relationship("AdminUser", foreign_keys=[updated_by])


class ParentalControl(Base):
    __tablename__ = "parental_controls"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    daily_limit_enabled = Column(Boolean, default=True, nullable=False)
    hours_per_day = Column(Integer, default=2, nullable=False)
    break_reminders_enabled = Column(Boolean, default=True, nullable=False)
    age_appropriate_only = Column(Boolean, default=True, nullable=False)
    block_educational = Column(Boolean, default=False, nullable=False)
    require_approval = Column(Boolean, default=False, nullable=False)
    sleep_mode = Column(Boolean, default=True, nullable=False)
    bedtime = Column(String, nullable=True)
    wake_time = Column(String, nullable=True)
    emergency_lock = Column(Boolean, default=False, nullable=False)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class ChildParentalControlSetting(Base):
    __tablename__ = "child_parental_control_settings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    parent_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    child_id = Column(
        Integer,
        ForeignKey("child_profiles.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    daily_limit_enabled = Column(Boolean, default=True, nullable=False, server_default=true())
    daily_limit_minutes = Column(Integer, default=120, nullable=False, server_default=text("120"))
    break_reminders_enabled = Column(Boolean, default=True, nullable=False, server_default=true())
    age_appropriate_only = Column(Boolean, default=True, nullable=False, server_default=true())
    require_approval = Column(Boolean, default=False, nullable=False, server_default=false())
    sleep_mode = Column(Boolean, default=True, nullable=False, server_default=true())
    bedtime_start = Column(String, nullable=True)
    bedtime_end = Column(String, nullable=True)
    emergency_lock = Column(Boolean, default=False, nullable=False, server_default=false())

    enforcement_mode = Column(
        String, nullable=False, default="monitor", server_default=text("'monitor'")
    )
    device_status = Column(
        String, nullable=False, default="unknown", server_default=text("'unknown'")
    )
    pending_changes = Column(Boolean, default=True, nullable=False, server_default=true())
    last_synced_at = Column(UTCDateTime(), nullable=True)

    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    child = relationship("ChildProfile", back_populates="parental_control_setting")
    schedule_rules = relationship(
        "ChildScheduleRule", back_populates="setting", cascade="all, delete-orphan"
    )
    blocked_apps = relationship(
        "ChildBlockedApp", back_populates="setting", cascade="all, delete-orphan"
    )
    blocked_sites = relationship(
        "ChildBlockedSite", back_populates="setting", cascade="all, delete-orphan"
    )


class ChildScheduleRule(Base):
    __tablename__ = "child_schedule_rules"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    setting_id = Column(
        Integer,
        ForeignKey("child_parental_control_settings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    day_of_week = Column(Integer, nullable=False, index=True)  # 0=Mon ... 6=Sun
    start_time = Column(String, nullable=False)  # HH:MM
    end_time = Column(String, nullable=False)  # HH:MM
    is_allowed = Column(Boolean, default=True, nullable=False, server_default=true())
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    setting = relationship("ChildParentalControlSetting", back_populates="schedule_rules")


class ChildBlockedApp(Base):
    __tablename__ = "child_blocked_apps"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    setting_id = Column(
        Integer,
        ForeignKey("child_parental_control_settings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    app_identifier = Column(String, nullable=False, index=True)
    app_name = Column(String, nullable=True)
    reason = Column(String, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    setting = relationship("ChildParentalControlSetting", back_populates="blocked_apps")


class ChildBlockedSite(Base):
    __tablename__ = "child_blocked_sites"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    setting_id = Column(
        Integer,
        ForeignKey("child_parental_control_settings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    domain = Column(String, nullable=False, index=True)
    label = Column(String, nullable=True)
    reason = Column(String, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    setting = relationship("ChildParentalControlSetting", back_populates="blocked_sites")


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    label = Column(String, nullable=False)
    provider = Column(
        String, nullable=False, default="internal", server_default=text("'internal'"), index=True
    )
    provider_customer_id = Column(String, nullable=True, index=True)
    provider_method_id = Column(String, nullable=True, index=True)
    method_type = Column(String, nullable=True, index=True)
    brand = Column(String, nullable=True)
    last4 = Column(String, nullable=True)
    exp_month = Column(Integer, nullable=True)
    exp_year = Column(Integer, nullable=True)
    is_default = Column(Boolean, nullable=False, default=False, server_default=false())
    fingerprint = Column(String, nullable=True, index=True)
    metadata_json = Column(JSON, nullable=True)
    deleted_at = Column(UTCDateTime(), nullable=True, index=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
