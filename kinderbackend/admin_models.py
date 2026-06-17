"""
Enhanced Admin system models — production-ready RBAC + audit + security.
"""

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
    true,
)
from sqlalchemy.orm import relationship

from core.field_encryption import EncryptedString
from core.sqlalchemy_types import UTCDateTime
from database import Base


# =========================================
# Admin User
# =========================================

class AdminUser(Base):
    __tablename__ = "admin_users"

    id = Column(Integer, primary_key=True, index=True)

    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    name = Column(String)

    is_active = Column(Boolean, default=True, nullable=False, server_default=true())
    is_deleted = Column(Boolean, default=False, nullable=False, server_default=text("false"))

    token_version = Column(Integer, default=0, nullable=False, server_default=text("0"))

    # 🔐 Security tracking
    last_login_at = Column(UTCDateTime())
    last_login_ip = Column(EncryptedString())
    last_login_user_agent = Column(EncryptedString())

    last_failed_login_at = Column(UTCDateTime())
    last_failed_login_ip = Column(EncryptedString())
    last_failed_login_user_agent = Column(EncryptedString())

    failed_login_attempts = Column(Integer, default=0, nullable=False, server_default=text("0"))
    suspicious_access_count = Column(Integer, default=0, nullable=False, server_default=text("0"))

    is_flagged_suspicious = Column(Boolean, default=False, nullable=False, server_default=text("false"))

    locked_until = Column(UTCDateTime())
    is_locked = Column(Boolean, default=False, nullable=False, server_default=text("false"))

    # 🔐 2FA
    two_factor_enabled = Column(Boolean, default=False, nullable=False, server_default=text("false"))
    two_factor_method = Column(String)
    two_factor_secret = Column(EncryptedString())
    two_factor_confirmed_at = Column(UTCDateTime())

    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)
    updated_at = Column(
        UTCDateTime(),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    admin_user_roles = relationship(
        "AdminUserRole",
        back_populates="admin_user",
        cascade="all, delete-orphan",
    )

    audit_logs = relationship("AuditLog", back_populates="admin_user")


# =========================================
# Roles
# =========================================

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)
    description = Column(String)

    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    role_permissions = relationship(
        "RolePermission",
        back_populates="role",
        cascade="all, delete-orphan",
    )

    admin_user_roles = relationship(
        "AdminUserRole",
        back_populates="role",
        cascade="all, delete-orphan",
    )


# =========================================
# Permissions
# =========================================

class Permission(Base):
    __tablename__ = "permissions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)
    description = Column(String)

    created_at = Column(UTCDateTime(), server_default=func.now(), nullable=False)

    role_permissions = relationship(
        "RolePermission",
        back_populates="permission",
        cascade="all, delete-orphan",
    )


# =========================================
# Role ↔ Permission
# =========================================

class RolePermission(Base):
    __tablename__ = "role_permissions"

    __table_args__ = (
        UniqueConstraint("role_id", "permission_id", name="uq_role_permission"),
    )

    id = Column(Integer, primary_key=True, index=True)

    role_id = Column(
        Integer,
        ForeignKey("roles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    permission_id = Column(
        Integer,
        ForeignKey("permissions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    role = relationship("Role", back_populates="role_permissions")
    permission = relationship("Permission", back_populates="role_permissions")


# =========================================
# Admin ↔ Role
# =========================================

class AdminUserRole(Base):
    __tablename__ = "admin_user_roles"

    __table_args__ = (
        UniqueConstraint("admin_user_id", "role_id", name="uq_admin_user_role"),
    )

    id = Column(Integer, primary_key=True, index=True)

    admin_user_id = Column(
        Integer,
        ForeignKey("admin_users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    role_id = Column(
        Integer,
        ForeignKey("roles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    admin_user = relationship("AdminUser", back_populates="admin_user_roles")
    role = relationship("Role", back_populates="admin_user_roles")


# =========================================
# Audit Logs
# =========================================

class AuditLog(Base):
    __tablename__ = "audit_logs"

    __table_args__ = (
        Index(
            "ix_audit_logs_entity_type_entity_id_created_at",
            "entity_type",
            "entity_id",
            "created_at",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)

    admin_user_id = Column(
        Integer,
        ForeignKey("admin_users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    action = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(String, nullable=False, index=True)

    before_json = Column(JSON)
    after_json = Column(JSON)

    # 🔐 encrypt sensitive metadata
    ip_address = Column(EncryptedString())
    user_agent = Column(EncryptedString())

    created_at = Column(
        UTCDateTime(),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    admin_user = relationship("AdminUser", back_populates="audit_logs")