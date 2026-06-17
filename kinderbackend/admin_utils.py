from __future__ import annotations

from datetime import date, datetime
from typing import Any

from fastapi import Request
from sqlalchemy.orm import Session

from admin_models import AdminUser, AdminUserRole, AuditLog, Permission, Role, RolePermission
from core.time_utils import ensure_utc
from models import ChildProfile, ContentCategory, ContentItem, Quiz, SupportTicket, SystemSetting, User
from serializers import child_to_json, user_to_json


CONTENT_AXIS_METADATA = {
    "behavioral": {"key": "behavioral", "title_en": "Behavioral", "title_ar": "سلوكي"},
    "educational": {"key": "educational", "title_en": "Educational", "title_ar": "تعليمي"},
    "skillful": {"key": "skillful", "title_en": "Skillful", "title_ar": "مهاري"},
    "entertaining": {"key": "entertaining", "title_en": "Entertaining", "title_ar": "ترفيهي"},
}


def to_iso(value: date | datetime | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return ensure_utc(value).isoformat()
    return value.isoformat()


def parse_optional_date(value: str | None) -> date | None:
    if value is None:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    return date.fromisoformat(normalized)


def base_admin(admin: AdminUser | None) -> dict[str, Any] | None:
    if admin is None:
        return None
    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
        "is_active": bool(admin.is_active),
    }


def build_pagination_payload(*, page: int, page_size: int, total: int) -> dict[str, Any]:
    total_pages = max(1, (total + page_size - 1) // page_size) if page_size else 1
    return {
        "page": page,
        "page_size": page_size,
        "total": total,
        "total_pages": total_pages,
        "has_previous": page > 1,
        "has_next": page < total_pages,
    }


def build_pagination(page: int, size: int, total: int) -> dict[str, Any]:
    return build_pagination_payload(page=page, page_size=size, total=total)


def normalize_content_axis_key(value: str | None) -> str:
    key = (value or "").strip().lower()
    if key not in CONTENT_AXIS_METADATA:
        raise ValueError("Invalid axis")
    return key


def normalize_axis(value: str | None) -> str:
    return normalize_content_axis_key(value)


def serialize_content_axis_summary(
    axis_key: str,
    *,
    categories: list[ContentCategory] | None = None,
) -> dict[str, Any]:
    normalized = normalize_content_axis_key(axis_key)
    payload = dict(CONTENT_AXIS_METADATA[normalized])
    category_items = categories or []
    payload["category_count"] = len(category_items)
    payload["content_count"] = sum(
        1 for category in category_items for item in (category.contents or []) if item.deleted_at is None
    )
    payload["quiz_count"] = sum(
        1 for category in category_items for item in (category.quizzes or []) if item.deleted_at is None
    )
    return payload


def serialize_axis_dashboard(axis_key: str, db: Session) -> dict[str, Any]:
    categories = (
        db.query(ContentCategory)
        .filter(
            ContentCategory.axis_key == normalize_content_axis_key(axis_key),
            ContentCategory.deleted_at.is_(None),
        )
        .all()
    )
    return {
        "axis": normalize_content_axis_key(axis_key),
        "title": CONTENT_AXIS_METADATA[normalize_content_axis_key(axis_key)],
        "stats": {
            "categories": len(categories),
            "contents": sum(
                1 for category in categories for item in (category.contents or []) if item.deleted_at is None
            ),
            "quizzes": sum(
                1 for category in categories for item in (category.quizzes or []) if item.deleted_at is None
            ),
        },
    }


def _collect_role_names(admin: AdminUser, db: Session | None = None) -> list[str]:
    if db is not None:
        rows = (
            db.query(Role.name)
            .join(AdminUserRole, AdminUserRole.role_id == Role.id)
            .filter(AdminUserRole.admin_user_id == admin.id)
            .all()
        )
        return sorted({row[0] for row in rows})
    return sorted(
        {
            link.role.name
            for link in (admin.admin_user_roles or [])
            if getattr(link, "role", None) is not None and getattr(link.role, "name", None)
        }
    )


def _collect_permission_names(admin: AdminUser, db: Session | None = None) -> list[str]:
    if db is not None:
        rows = (
            db.query(Permission.name)
            .join(RolePermission, RolePermission.permission_id == Permission.id)
            .join(AdminUserRole, AdminUserRole.role_id == RolePermission.role_id)
            .filter(AdminUserRole.admin_user_id == admin.id)
            .all()
        )
        return sorted({row[0] for row in rows})
    permissions: set[str] = set()
    for link in admin.admin_user_roles or []:
        role = getattr(link, "role", None)
        if role is None:
            continue
        for role_permission in role.role_permissions or []:
            permission = getattr(role_permission, "permission", None)
            if permission is not None and permission.name:
                permissions.add(permission.name)
    return sorted(permissions)


def build_admin_payload(admin: AdminUser, db: Session) -> dict[str, Any]:
    return serialize_admin_user(admin, db)


def serialize_admin_user(admin: AdminUser, db: Session | None = None) -> dict[str, Any]:
    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
        "is_active": bool(admin.is_active),
        "is_deleted": bool(getattr(admin, "is_deleted", False)),
        "token_version": int(admin.token_version or 0),
        "roles": _collect_role_names(admin, db),
        "permissions": _collect_permission_names(admin, db),
        "two_factor_enabled": bool(getattr(admin, "two_factor_enabled", False)),
        "two_factor_method": getattr(admin, "two_factor_method", None),
        "last_login_at": to_iso(getattr(admin, "last_login_at", None)),
        "locked_until": to_iso(getattr(admin, "locked_until", None)),
        "failed_login_attempts": int(getattr(admin, "failed_login_attempts", 0) or 0),
        "suspicious_access_count": int(getattr(admin, "suspicious_access_count", 0) or 0),
        "created_at": to_iso(getattr(admin, "created_at", None)),
        "updated_at": to_iso(getattr(admin, "updated_at", None)),
    }


def serialize_permission(permission: Permission) -> dict[str, Any]:
    group = permission.name.split(".", 1)[0] if "." in permission.name else permission.name
    return {
        "id": permission.id,
        "name": permission.name,
        "description": permission.description,
        "group": group,
        "created_at": to_iso(getattr(permission, "created_at", None)),
    }


def serialize_role(role: Role, *, include_permissions: bool = False) -> dict[str, Any]:
    permissions = sorted(
        {
            role_permission.permission.name
            for role_permission in (role.role_permissions or [])
            if getattr(role_permission, "permission", None) is not None
            and getattr(role_permission.permission, "name", None)
        }
    )
    payload = {
        "id": role.id,
        "name": role.name,
        "description": role.description,
        "admin_count": len(role.admin_user_roles or []),
        "permission_count": len(permissions),
        "created_at": to_iso(getattr(role, "created_at", None)),
    }
    if include_permissions:
        payload["permissions"] = permissions
    return payload


def write_audit_log(
    *,
    db: Session,
    request: Request | None,
    admin: AdminUser | None,
    action: str,
    entity_type: str,
    entity_id: Any,
    before_json: Any = None,
    after_json: Any = None,
) -> AuditLog:
    ip_address = None
    user_agent = None
    if request is not None:
        ip_address = getattr(request.client, "host", None)
        user_agent = request.headers.get("user-agent")

    log = AuditLog(
        admin_user_id=getattr(admin, "id", None),
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        before_json=before_json,
        after_json=after_json,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(log)
    db.flush()
    return log


def serialize_audit_log(item: AuditLog) -> dict[str, Any]:
    return {
        "id": item.id,
        "action": item.action,
        "entity_type": item.entity_type,
        "entity_id": item.entity_id,
        "before_json": item.before_json,
        "after_json": item.after_json,
        "ip_address": getattr(item, "ip_address", None),
        "user_agent": getattr(item, "user_agent", None),
        "created_at": to_iso(item.created_at),
        "admin": base_admin(getattr(item, "admin_user", None)),
        "admin_user_id": getattr(item, "admin_user_id", None),
    }


def serialize_content_category(category: ContentCategory) -> dict[str, Any]:
    axis_key = normalize_content_axis_key(category.axis_key)
    contents = [item for item in (category.contents or []) if item.deleted_at is None]
    quizzes = [item for item in (category.quizzes or []) if item.deleted_at is None]
    return {
        "id": category.id,
        "axis_key": axis_key,
        "axis": serialize_content_axis_summary(axis_key),
        "slug": category.slug,
        "title_en": category.title_en,
        "title_ar": category.title_ar,
        "description_en": category.description_en,
        "description_ar": category.description_ar,
        "content_count": len(contents),
        "quiz_count": len(quizzes),
        "created_by": getattr(category, "created_by", None),
        "updated_by": getattr(category, "updated_by", None),
        "creator": base_admin(getattr(category, "creator", None)),
        "updater": base_admin(getattr(category, "updater", None)),
        "created_at": to_iso(category.created_at),
        "updated_at": to_iso(getattr(category, "updated_at", None)),
        "deleted_at": to_iso(getattr(category, "deleted_at", None)),
    }


def serialize_category(category: ContentCategory) -> dict[str, Any]:
    return serialize_content_category(category)


def serialize_quiz(quiz: Quiz) -> dict[str, Any]:
    axis_key = normalize_content_axis_key(quiz.category.axis_key) if getattr(quiz, "category", None) else None
    return {
        "id": quiz.id,
        "content_id": quiz.content_id,
        "category_id": quiz.category_id,
        "axis_key": axis_key,
        "title_en": quiz.title_en,
        "title_ar": quiz.title_ar,
        "description_en": getattr(quiz, "description_en", None),
        "description_ar": getattr(quiz, "description_ar", None),
        "status": quiz.status,
        "question_count": len(quiz.questions_json or []),
        "questions_json": quiz.questions_json or [],
        "created_by": getattr(quiz, "created_by", None),
        "updated_by": getattr(quiz, "updated_by", None),
        "creator": base_admin(getattr(quiz, "creator", None)),
        "updater": base_admin(getattr(quiz, "updater", None)),
        "published_at": to_iso(getattr(quiz, "published_at", None)),
        "created_at": to_iso(quiz.created_at),
        "updated_at": to_iso(getattr(quiz, "updated_at", None)),
        "deleted_at": to_iso(getattr(quiz, "deleted_at", None)),
    }


def serialize_content_item(
    content: ContentItem,
    *,
    include_quizzes: bool = False,
) -> dict[str, Any]:
    axis_key = None
    if getattr(content, "category", None) is not None:
        axis_key = normalize_content_axis_key(content.category.axis_key)
    payload = {
        "id": content.id,
        "category_id": content.category_id,
        "axis_key": axis_key,
        "slug": content.slug,
        "content_type": content.content_type,
        "status": content.status,
        "title_en": content.title_en,
        "title_ar": content.title_ar,
        "description_en": getattr(content, "description_en", None),
        "description_ar": getattr(content, "description_ar", None),
        "body_en": getattr(content, "body_en", None),
        "body_ar": getattr(content, "body_ar", None),
        "thumbnail_url": getattr(content, "thumbnail_url", None),
        "video_url": getattr(content, "video_url", None),
        "video_provider": getattr(content, "video_provider", None),
        "video_public_id": getattr(content, "video_public_id", None),
        "video_duration_seconds": getattr(content, "video_duration_seconds", None),
        "age_group": getattr(content, "age_group", None),
        "metadata_json": getattr(content, "metadata_json", None) or {},
        "category": (
            serialize_content_category(content.category)
            if getattr(content, "category", None) is not None
            else None
        ),
        "created_by": getattr(content, "created_by", None),
        "updated_by": getattr(content, "updated_by", None),
        "creator": base_admin(getattr(content, "creator", None)),
        "updater": base_admin(getattr(content, "updater", None)),
        "published_at": to_iso(getattr(content, "published_at", None)),
        "created_at": to_iso(content.created_at),
        "updated_at": to_iso(getattr(content, "updated_at", None)),
        "deleted_at": to_iso(getattr(content, "deleted_at", None)),
    }
    if include_quizzes:
        payload["quizzes"] = [
            serialize_quiz(quiz) for quiz in (getattr(content, "quizzes", None) or []) if quiz.deleted_at is None
        ]
    return payload


def serialize_content(content: ContentItem) -> dict[str, Any]:
    return serialize_content_item(content)


def serialize_system_setting(item: SystemSetting) -> dict[str, Any]:
    return {
        "id": item.id,
        "key": item.key,
        "value_json": item.value_json,
        "updated_by": item.updated_by,
        "updated_at": to_iso(item.updated_at),
        "updater": base_admin(getattr(item, "updater", None)),
    }


def _build_user_axis_engagement(user: User, db: Session) -> dict[str, Any]:
    """Build axis engagement data for a user based on their children's activities."""
    child_ids = [child.id for child in getattr(user, "children", None) or []]
    if not child_ids:
        return {axis_key: {"activities": 0, "completed_lessons": 0} for axis_key in CONTENT_AXIS_METADATA.keys()}

    engagement = {}

    for axis_key in CONTENT_AXIS_METADATA.keys():
        # Get categories for this axis
        categories = (
            db.query(ContentCategory)
            .filter(
                ContentCategory.axis_key == axis_key,
                ContentCategory.deleted_at.is_(None),
            )
            .all()
        )
        category_ids = [cat.id for cat in categories]

        # Get content items for these categories
        content_items = (
            db.query(ContentItem)
            .filter(
                ContentItem.category_id.in_(category_ids),
                ContentItem.deleted_at.is_(None),
                ContentItem.status == "published",
            )
            .all()
        )
        lesson_ids = [item.slug for item in content_items]

        # Count activities by children in this axis
        activities_count = (
            db.query(ChildActivityEvent)
            .filter(
                ChildActivityEvent.child_id.in_(child_ids),
                ChildActivityEvent.lesson_id.in_(lesson_ids),
            )
            .count()
        )

        # Count completed lessons by children in this axis
        completed_lessons_count = (
            db.query(LessonProgress)
            .filter(
                LessonProgress.child_id.in_(child_ids),
                LessonProgress.lesson_id.in_(lesson_ids),
                LessonProgress.status == "completed",
            )
            .count()
        )

        engagement[axis_key] = {
            "activities": activities_count,
            "completed_lessons": completed_lessons_count,
        }

    return engagement


def serialize_user_detail(user: User, db: Session | None = None) -> dict[str, Any]:
    payload = user_to_json(user)
    payload.update(
        {
            "children_count": len(getattr(user, "children", None) or []),
            "support_ticket_count": len(getattr(user, "support_tickets", None) or []),
            "notification_count": len(getattr(user, "notifications", None) or []),
            "children": [child_to_json(child) for child in (getattr(user, "children", None) or [])],
        }
    )

    # Add axis engagement data if db is provided
    if db is not None:
        axis_engagement = _build_user_axis_engagement(user, db)
        payload["axis_engagement"] = axis_engagement

    return payload


def build_user_activity(user: User, audit_logs: list[AuditLog], db: Session | None = None) -> dict[str, Any]:
    return {
        "user": serialize_user_detail(user, db),
        "summary": {
            "audit_count": len(audit_logs),
            "children_count": len(getattr(user, "children", None) or []),
            "support_ticket_count": len(getattr(user, "support_tickets", None) or []),
        },
        "activity": [serialize_audit_log(item) for item in audit_logs],
    }


def serialize_child_detail(child: ChildProfile) -> dict[str, Any]:
    payload = child_to_json(child)
    payload.update(
        {
            "deleted_at": to_iso(getattr(child, "deleted_at", None)),
            "parent": user_to_json(child.parent) if getattr(child, "parent", None) is not None else None,
        }
    )
    return payload


def build_child_progress(child: ChildProfile, audit_logs: list[AuditLog]) -> dict[str, Any]:
    actions = [item.action for item in audit_logs]
    return {
        "child": serialize_child_detail(child),
        "summary": {
            "audit_count": len(audit_logs),
            "edit_count": sum(1 for action in actions if "edit" in action),
            "disable_count": sum(1 for action in actions if "deactivate" in action or "disable" in action),
        },
        "recent_activity": [serialize_audit_log(item) for item in audit_logs[:20]],
    }


def build_child_activity_log(child: ChildProfile, audit_logs: list[AuditLog]) -> dict[str, Any]:
    return {
        "child": serialize_child_detail(child),
        "items": [serialize_audit_log(item) for item in audit_logs],
    }


def _support_author_payload(user: User | None = None, admin: AdminUser | None = None) -> dict[str, Any] | None:
    if admin is not None:
        return {"id": admin.id, "email": admin.email, "name": admin.name}
    if user is not None:
        return {"id": user.id, "email": user.email, "name": user.name}
    return None


def serialize_support_ticket(
    ticket: SupportTicket,
    *,
    include_thread: bool = False,
) -> dict[str, Any]:
    thread_messages = getattr(ticket, "thread_messages", None) or []
    preview = (ticket.message or "").strip()
    payload = {
        "id": ticket.id,
        "user_id": ticket.user_id,
        "subject": ticket.subject,
        "message": ticket.message,
        "email": ticket.email,
        "category": ticket.category,
        "status": ticket.status,
        "deleted_at": to_iso(getattr(ticket, "deleted_at", None)),
        "assigned_admin_id": getattr(ticket, "assigned_admin_id", None),
        "assigned_admin": _support_author_payload(admin=getattr(ticket, "assigned_admin", None)),
        "requester": _support_author_payload(user=getattr(ticket, "user", None)),
        "created_at": to_iso(ticket.created_at),
        "updated_at": to_iso(getattr(ticket, "updated_at", None)),
        "closed_at": to_iso(getattr(ticket, "closed_at", None)),
        "reply_count": len(thread_messages),
        "last_message_at": to_iso(thread_messages[-1].created_at if thread_messages else ticket.updated_at),
        "preview": preview[:160],
        "priority_level": "normal",
        "priority_score": 0,
        "priority_reason": "Default priority",
    }
    if include_thread:
        payload["thread"] = [
            {
                "id": item.id,
                "ticket_id": item.ticket_id,
                "message": item.message,
                "author_type": "admin" if item.admin_user_id else "user",
                "author": _support_author_payload(user=getattr(item, "user", None), admin=getattr(item, "admin_user", None)),
                "created_at": to_iso(item.created_at),
            }
            for item in thread_messages
        ]
    return payload


def serialize_subscription_record(user: User, db: Session | None = None) -> dict[str, Any]:
    profile = getattr(user, "subscription_profile", None)
    return {
        "user": serialize_user_detail(user, db),
        "subscription_profile": (
            {
                "id": profile.id,
                "current_plan_id": profile.current_plan_id,
                "selected_plan_id": profile.selected_plan_id,
                "status": profile.status,
                "provider": profile.provider,
                "provider_customer_id": profile.provider_customer_id,
                "provider_subscription_id": profile.provider_subscription_id,
                "started_at": to_iso(profile.started_at),
                "expires_at": to_iso(profile.expires_at),
                "cancel_at": to_iso(profile.cancel_at),
                "will_renew": bool(profile.will_renew),
                "last_payment_status": profile.last_payment_status,
                "created_at": to_iso(profile.created_at),
                "updated_at": to_iso(profile.updated_at),
            }
            if profile is not None
            else None
        ),
        "billing_transaction_count": len(getattr(user, "billing_transactions", None) or []),
        "payment_attempt_count": len(getattr(user, "payment_attempts", None) or []),
        "subscription_event_count": len(getattr(user, "subscription_events", None) or []),
    }
