from sqlalchemy import Column, Integer, String, DateTime, Boolean, Date, func, ForeignKey, JSON, text, true, false
from sqlalchemy.orm import relationship
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
    parent_pin_failed_attempts = Column(Integer, default=0, nullable=False, server_default=text("0"))
    parent_pin_locked_until = Column(DateTime, nullable=True)
    parent_pin_updated_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

    # One-to-many: a parent can have multiple child profiles
    children = relationship("ChildProfile", back_populates="parent", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    privacy_setting = relationship("PrivacySetting", back_populates="user", uselist=False, cascade="all, delete-orphan")
    support_tickets = relationship("SupportTicket", back_populates="user", cascade="all, delete-orphan")
    payment_methods = relationship("PaymentMethod", cascade="all, delete-orphan")


class ChildProfile(Base):
    __tablename__ = "child_profiles"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    parent_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    picture_password = Column(JSON, nullable=False)  # Stored as JSON array of strings
    date_of_birth = Column(Date, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)
    age = Column(Integer, nullable=True)
    avatar = Column(String, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False, server_default=true())

    parent = relationship("User", back_populates="children")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    child_id = Column(Integer, ForeignKey("child_profiles.id"), nullable=True, index=True)
    type = Column(String, nullable=False, default="SYSTEM")
    title = Column(String, nullable=False)
    body = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
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
    status = Column(String, nullable=False, default="open", server_default=text("'open'"), index=True)
    assigned_admin_id = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    closed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

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
    ticket_id = Column(Integer, ForeignKey("support_tickets.id", ondelete="CASCADE"), nullable=False, index=True)
    admin_user_id = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    message = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

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
    created_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    updated_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)
    deleted_at = Column(DateTime, nullable=True, index=True)

    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])
    contents = relationship("ContentItem", back_populates="category")
    quizzes = relationship("Quiz", back_populates="category")


class ContentItem(Base):
    __tablename__ = "contents"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True)
    content_type = Column(String, nullable=False, default="lesson", server_default=text("'lesson'"), index=True)
    status = Column(String, nullable=False, default="draft", server_default=text("'draft'"), index=True)
    title_en = Column(String, nullable=False)
    title_ar = Column(String, nullable=False)
    description_en = Column(String, nullable=True)
    description_ar = Column(String, nullable=True)
    body_en = Column(String, nullable=True)
    body_ar = Column(String, nullable=True)
    thumbnail_url = Column(String, nullable=True)
    age_group = Column(String, nullable=True)
    metadata_json = Column(JSON, nullable=True)
    created_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    updated_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    published_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)
    deleted_at = Column(DateTime, nullable=True, index=True)

    category = relationship("ContentCategory", back_populates="contents")
    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])
    quizzes = relationship("Quiz", back_populates="content")


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    content_id = Column(Integer, ForeignKey("contents.id", ondelete="SET NULL"), nullable=True, index=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True)
    status = Column(String, nullable=False, default="draft", server_default=text("'draft'"), index=True)
    title_en = Column(String, nullable=False)
    title_ar = Column(String, nullable=False)
    description_en = Column(String, nullable=True)
    description_ar = Column(String, nullable=True)
    questions_json = Column(JSON, nullable=False, default=list)
    created_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    updated_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    published_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)
    deleted_at = Column(DateTime, nullable=True, index=True)

    content = relationship("ContentItem", back_populates="quizzes")
    category = relationship("ContentCategory", back_populates="quizzes")
    creator = relationship("AdminUser", foreign_keys=[created_by])
    updater = relationship("AdminUser", foreign_keys=[updated_by])


class SystemSetting(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    key = Column(String, unique=True, nullable=False, index=True)
    value_json = Column(JSON, nullable=False)
    updated_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True, index=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

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
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    label = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
