"""
Admin system models — fully separate from parent/child user tables.
Tables: admin_users, roles, permissions, role_permissions, admin_user_roles
"""

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
    true,
)
from sqlalchemy.orm import relationship

from core.sqlalchemy_types import UTCDateTime
from database import Base


class AdminUser(Base):
    """
    Standalone admin user table — completely separate from the 'users' table
    used by parents/children. Admin tokens carry token_type='admin' to prevent
    cross-authentication.
    """

    __tablename__ = "admin_users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    name = Column(String, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False, server_default=true())
    # Bump token_version on logout to invalidate all existing refresh tokens
    token_version = Column(Integer, default=0, nullable=False, server_default=text("0"))
    last_login_at = Column(UTCDateTime(), nullable=True)
    last_login_ip = Column(String, nullable=True)
    last_login_user_agent = Column(String, nullable=True)
    last_failed_login_at = Column(UTCDateTime(), nullable=True)
    last_failed_login_ip = Column(String, nullable=True)
    last_failed_login_user_agent = Column(String, nullable=True)
    failed_login_attempts = Column(Integer, default=0, nullable=False, server_default=text("0"))
    suspicious_access_count = Column(Integer, default=0, nullable=False, server_default=text("0"))
    is_flagged_suspicious = Column(
        Boolean, default=False, nullable=False, server_default=text("false")
    )
    locked_until = Column(UTCDateTime(), nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    admin_user_roles = relationship(
        "AdminUserRole", back_populates="admin_user", cascade="all, delete-orphan"
    )
    audit_logs = relationship("AuditLog", back_populates="admin_user", cascade="all, delete-orphan")


class Role(Base):
    """
    Named roles: super_admin, content_admin, support_admin, analytics_admin, finance_admin
    """

    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    description = Column(String, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    # Relationships
    role_permissions = relationship(
        "RolePermission", back_populates="role", cascade="all, delete-orphan"
    )
    admin_user_roles = relationship(
        "AdminUserRole", back_populates="role", cascade="all, delete-orphan"
    )


class Permission(Base):
    """
    Granular permission keys using dot-notation:
    e.g. admin.users.view, admin.content.publish, admin.admins.manage
    """

    __tablename__ = "permissions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False, index=True)
    description = Column(String, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    # Relationships
    role_permissions = relationship(
        "RolePermission", back_populates="permission", cascade="all, delete-orphan"
    )


class RolePermission(Base):
    """
    Many-to-many join: roles ↔ permissions
    """

    __tablename__ = "role_permissions"
    __table_args__ = (UniqueConstraint("role_id", "permission_id", name="uq_role_permission"),)

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    role_id = Column(
        Integer, ForeignKey("roles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    permission_id = Column(
        Integer, ForeignKey("permissions.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    role = relationship("Role", back_populates="role_permissions")
    permission = relationship("Permission", back_populates="role_permissions")


class AdminUserRole(Base):
    """
    Many-to-many join: admin_users ↔ roles
    """

    __tablename__ = "admin_user_roles"
    __table_args__ = (UniqueConstraint("admin_user_id", "role_id", name="uq_admin_user_role"),)

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    admin_user_id = Column(
        Integer, ForeignKey("admin_users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role_id = Column(
        Integer, ForeignKey("roles.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    admin_user = relationship("AdminUser", back_populates="admin_user_roles")
    role = relationship("Role", back_populates="admin_user_roles")


class AuditLog(Base):
    """
    Immutable audit trail for sensitive admin actions.
    """

    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    admin_user_id = Column(
        Integer,
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    action = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(String, nullable=False, index=True)
    before_json = Column(JSON, nullable=True)
    after_json = Column(JSON, nullable=True)
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False, index=True)

    admin_user = relationship("AdminUser", back_populates="audit_logs")
