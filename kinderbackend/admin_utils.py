from __future__ import annotations

from datetime import date, datetime
from typing import Any, Optional

from fastapi import Request
from sqlalchemy.orm import Session

from admin_models import (
    AuditLog,
    AdminUser,
    AdminUserRole,
    Permission,
    Role,
    RolePermission,
)
from models import (
    ChildProfile,
    ContentCategory,
    ContentItem,
    Quiz,
    SystemSetting,
    SupportTicket,
    SupportTicketMessage,
    User,
)
from plan_service import get_plan_features, get_plan_limits, get_user_plan
from serializers import child_to_json, user_to_json


def build_admin_payload(admin, db: Session) -> dict[str, Any]:
    role_rows = (
        db.query(Role.name)
        .join(AdminUserRole, AdminUserRole.role_id == Role.id)
        .filter(AdminUserRole.admin_user_id == admin.id)
        .all()
    )
    perm_rows = (
        db.query(Permission.name)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(Role, Role.id == RolePermission.role_id)
        .join(AdminUserRole, AdminUserRole.role_id == Role.id)
        .filter(AdminUserRole.admin_user_id == admin.id)
        .all()
    )

    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
        "is_active": admin.is_active,
        "roles": sorted({r.name for r in role_rows}),
        "permissions": sorted({p.name for p in perm_rows}),
        "created_at": admin.created_at.isoformat() if admin.created_at else None,
        "updated_at": admin.updated_at.isoformat() if admin.updated_at else None,
    }


def permission_group_name(permission_name: str) -> str:
    parts = permission_name.split(".")
    if len(parts) >= 2:
        return parts[1]
    return "general"


def serialize_permission(permission: Permission) -> dict[str, Any]:
    return {
        "id": permission.id,
        "name": permission.name,
        "description": permission.description,
        "group": permission_group_name(permission.name),
        "created_at": permission.created_at.isoformat() if permission.created_at else None,
    }


def serialize_role(role: Role, *, include_permissions: bool = False) -> dict[str, Any]:
    permissions = [
        role_permission.permission
        for role_permission in (role.role_permissions or [])
        if role_permission.permission is not None
    ]
    payload = {
        "id": role.id,
        "name": role.name,
        "description": role.description,
        "permission_count": len(permissions),
        "admin_count": len(role.admin_user_roles or []),
        "created_at": role.created_at.isoformat() if role.created_at else None,
    }
    if include_permissions:
        payload["permissions"] = [serialize_permission(permission) for permission in permissions]
    else:
        payload["permission_names"] = sorted({permission.name for permission in permissions})
    return payload


def serialize_admin_user(admin: AdminUser, db: Session) -> dict[str, Any]:
    return build_admin_payload(admin, db)


def serialize_user_detail(user: User) -> dict[str, Any]:
    payload = user_to_json(user)
    payload["children"] = [child_to_json(child) for child in (user.children or [])]
    payload["child_count"] = len(payload["children"])
    return payload


def serialize_child_detail(child: ChildProfile) -> dict[str, Any]:
    payload = child_to_json(child)
    payload["picture_password_length"] = len(child.picture_password or [])
    if child.parent is not None:
        payload["parent"] = {
            "id": child.parent.id,
            "email": child.parent.email,
            "name": child.parent.name,
            "is_active": bool(child.parent.is_active),
            "plan": getattr(child.parent, "plan", None),
        }
    else:
        payload["parent"] = None
    return payload


def write_audit_log(
    *,
    db: Session,
    request: Optional[Request],
    admin,
    action: str,
    entity_type: str,
    entity_id: Any,
    before_json: Optional[dict[str, Any]] = None,
    after_json: Optional[dict[str, Any]] = None,
) -> AuditLog:
    client_host = request.client.host if request and request.client else None
    user_agent = request.headers.get("user-agent") if request else None
    audit_log = AuditLog(
        admin_user_id=getattr(admin, "id", None),
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        before_json=before_json,
        after_json=after_json,
        ip_address=client_host,
        user_agent=user_agent,
    )
    db.add(audit_log)
    db.flush()
    return audit_log


def parse_optional_date(value: Optional[str]) -> Optional[date]:
    if not value:
        return None
    return date.fromisoformat(value)


def serialize_audit_log(log: AuditLog) -> dict[str, Any]:
    admin_payload = None
    if log.admin_user is not None:
        admin_payload = {
            "id": log.admin_user.id,
            "email": log.admin_user.email,
            "name": log.admin_user.name,
        }
    return {
        "id": log.id,
        "admin_user_id": log.admin_user_id,
        "admin": admin_payload,
        "action": log.action,
        "entity_type": log.entity_type,
        "entity_id": log.entity_id,
        "before_json": log.before_json,
        "after_json": log.after_json,
        "ip_address": log.ip_address,
        "user_agent": log.user_agent,
        "timestamp": log.created_at.isoformat() if log.created_at else None,
    }


def build_pagination_payload(*, page: int, page_size: int, total: int) -> dict[str, Any]:
    total_pages = max((total + page_size - 1) // page_size, 1)
    return {
        "page": page,
        "page_size": page_size,
        "total": total,
        "total_pages": total_pages,
        "has_next": page < total_pages,
        "has_previous": page > 1,
    }


def serialize_support_ticket_message(message: SupportTicketMessage) -> dict[str, Any]:
    author_type = "system"
    author_payload = None
    if message.admin_user is not None:
        author_type = "admin"
        author_payload = {
            "id": message.admin_user.id,
            "email": message.admin_user.email,
            "name": message.admin_user.name,
        }
    elif message.user is not None:
        author_type = "user"
        author_payload = {
            "id": message.user.id,
            "email": message.user.email,
            "name": message.user.name,
        }

    return {
        "id": message.id,
        "ticket_id": message.ticket_id,
        "message": message.message,
        "author_type": author_type,
        "author": author_payload,
        "created_at": message.created_at.isoformat() if message.created_at else None,
    }


def _ticket_requester_payload(ticket: SupportTicket) -> dict[str, Any] | None:
    if ticket.user is None:
        if not ticket.email:
            return None
        return {
            "id": None,
            "email": ticket.email,
            "name": None,
        }
    return {
        "id": ticket.user.id,
        "email": ticket.user.email,
        "name": ticket.user.name,
    }


def _ticket_assignee_payload(ticket: SupportTicket) -> dict[str, Any] | None:
    if ticket.assigned_admin is None:
        return None
    return {
        "id": ticket.assigned_admin.id,
        "email": ticket.assigned_admin.email,
        "name": ticket.assigned_admin.name,
    }


def serialize_support_ticket(ticket: SupportTicket, *, include_thread: bool = False) -> dict[str, Any]:
    thread = [
        {
            "id": f"root-{ticket.id}",
            "ticket_id": ticket.id,
            "message": ticket.message,
            "author_type": "user",
            "author": _ticket_requester_payload(ticket),
            "created_at": ticket.created_at.isoformat() if ticket.created_at else None,
        }
    ]
    thread.extend(serialize_support_ticket_message(message) for message in (ticket.thread_messages or []))

    last_message_at = ticket.updated_at or ticket.created_at
    if ticket.thread_messages:
        last_message_at = ticket.thread_messages[-1].created_at or last_message_at

    payload = {
        "id": ticket.id,
        "user_id": ticket.user_id,
        "subject": ticket.subject,
        "message": ticket.message,
        "email": ticket.email,
        "status": ticket.status,
        "assigned_admin_id": ticket.assigned_admin_id,
        "assigned_admin": _ticket_assignee_payload(ticket),
        "requester": _ticket_requester_payload(ticket),
        "created_at": ticket.created_at.isoformat() if ticket.created_at else None,
        "updated_at": ticket.updated_at.isoformat() if ticket.updated_at else None,
        "closed_at": ticket.closed_at.isoformat() if ticket.closed_at else None,
        "reply_count": len(ticket.thread_messages or []),
        "last_message_at": last_message_at.isoformat() if last_message_at else None,
        "preview": ticket.message,
    }
    if include_thread:
        payload["thread"] = thread
    return payload


def serialize_content_category(category: ContentCategory) -> dict[str, Any]:
    active_contents = [item for item in (category.contents or []) if item.deleted_at is None]
    active_quizzes = [item for item in (category.quizzes or []) if item.deleted_at is None]
    return {
        "id": category.id,
        "slug": category.slug,
        "title_en": category.title_en,
        "title_ar": category.title_ar,
        "description_en": category.description_en,
        "description_ar": category.description_ar,
        "content_count": len(active_contents),
        "quiz_count": len(active_quizzes),
        "created_by": category.created_by,
        "updated_by": category.updated_by,
        "created_at": category.created_at.isoformat() if category.created_at else None,
        "updated_at": category.updated_at.isoformat() if category.updated_at else None,
    }


def _content_admin_payload(admin) -> dict[str, Any] | None:
    if admin is None:
        return None
    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
    }


def serialize_quiz(quiz: Quiz) -> dict[str, Any]:
    return {
        "id": quiz.id,
        "content_id": quiz.content_id,
        "category_id": quiz.category_id,
        "status": quiz.status,
        "title_en": quiz.title_en,
        "title_ar": quiz.title_ar,
        "description_en": quiz.description_en,
        "description_ar": quiz.description_ar,
        "questions_json": quiz.questions_json or [],
        "question_count": len(quiz.questions_json or []),
        "content_title_en": quiz.content.title_en if quiz.content is not None else None,
        "content_title_ar": quiz.content.title_ar if quiz.content is not None else None,
        "category": serialize_content_category(quiz.category) if quiz.category is not None else None,
        "created_by_admin": _content_admin_payload(quiz.creator),
        "updated_by_admin": _content_admin_payload(quiz.updater),
        "published_at": quiz.published_at.isoformat() if quiz.published_at else None,
        "created_at": quiz.created_at.isoformat() if quiz.created_at else None,
        "updated_at": quiz.updated_at.isoformat() if quiz.updated_at else None,
    }


def serialize_content_item(content: ContentItem, *, include_quizzes: bool = False) -> dict[str, Any]:
    payload = {
        "id": content.id,
        "category_id": content.category_id,
        "content_type": content.content_type,
        "status": content.status,
        "title_en": content.title_en,
        "title_ar": content.title_ar,
        "description_en": content.description_en,
        "description_ar": content.description_ar,
        "body_en": content.body_en,
        "body_ar": content.body_ar,
        "thumbnail_url": content.thumbnail_url,
        "age_group": content.age_group,
        "metadata_json": content.metadata_json or {},
        "category": serialize_content_category(content.category) if content.category is not None else None,
        "quiz_count": len([quiz for quiz in (content.quizzes or []) if quiz.deleted_at is None]),
        "created_by_admin": _content_admin_payload(content.creator),
        "updated_by_admin": _content_admin_payload(content.updater),
        "published_at": content.published_at.isoformat() if content.published_at else None,
        "created_at": content.created_at.isoformat() if content.created_at else None,
        "updated_at": content.updated_at.isoformat() if content.updated_at else None,
    }
    if include_quizzes:
        payload["quizzes"] = [
            serialize_quiz(quiz) for quiz in (content.quizzes or []) if quiz.deleted_at is None
        ]
    return payload


def serialize_subscription_record(user: User) -> dict[str, Any]:
    plan = get_user_plan(user)
    payment_methods = getattr(user, "payment_methods", []) or []
    children = getattr(user, "children", []) or []
    return {
        "id": user.id,
        "user_id": user.id,
        "email": user.email,
        "name": user.name,
        "plan": plan,
        "status": "active" if user.is_active and plan != "FREE" else ("free" if user.is_active else "disabled"),
        "is_active": bool(user.is_active),
        "child_count": len(children),
        "payment_method_count": len(payment_methods),
        "limits": get_plan_limits(plan),
        "features": get_plan_features(plan),
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
    }


def serialize_system_setting(setting: SystemSetting) -> dict[str, Any]:
    return {
        "id": setting.id,
        "key": setting.key,
        "value_json": setting.value_json,
        "updated_by": setting.updated_by,
        "updated_at": setting.updated_at.isoformat() if setting.updated_at else None,
        "updated_by_admin": _content_admin_payload(setting.updater),
    }


def build_user_activity(user: User, audit_logs: list[AuditLog]) -> dict[str, Any]:
    tickets = sorted(
        user.support_tickets or [],
        key=lambda item: item.created_at or datetime.min,
        reverse=True,
    )
    notifications = sorted(
        user.notifications or [],
        key=lambda item: item.created_at or datetime.min,
        reverse=True,
    )
    return {
        "user_id": user.id,
        "summary": {
            "child_count": len(user.children or []),
            "notification_count": len(user.notifications or []),
            "support_ticket_count": len(user.support_tickets or []),
            "last_updated_at": user.updated_at.isoformat() if user.updated_at else None,
        },
        "notifications": [
            {
                "id": notification.id,
                "title": notification.title,
                "type": notification.type,
                "is_read": bool(notification.is_read),
                "created_at": notification.created_at.isoformat()
                if notification.created_at
                else None,
            }
            for notification in notifications[:10]
        ],
        "support_tickets": [
            {
                "id": ticket.id,
                "subject": ticket.subject,
                "email": ticket.email,
                "created_at": ticket.created_at.isoformat() if ticket.created_at else None,
            }
            for ticket in tickets[:10]
        ],
        "admin_audit": [serialize_audit_log(log) for log in audit_logs[:20]],
    }


def build_child_progress(child: ChildProfile, audit_logs: list[AuditLog]) -> dict[str, Any]:
    days_since_created = 0
    if child.created_at:
        days_since_created = max((datetime.utcnow().date() - child.created_at.date()).days, 0)

    return {
        "child_id": child.id,
        "summary": {
            "days_since_profile_created": days_since_created,
            "profile_active": bool(getattr(child, "is_active", True)),
            "last_updated_at": child.updated_at.isoformat() if child.updated_at else None,
            "audit_events": len(audit_logs),
        },
        "milestones": [
            {
                "title": "Profile created",
                "timestamp": child.created_at.isoformat() if child.created_at else None,
            },
            {
                "title": "Profile last updated",
                "timestamp": child.updated_at.isoformat() if child.updated_at else None,
            },
        ],
        "audit_events": [serialize_audit_log(log) for log in audit_logs[:20]],
    }


def build_child_activity_log(child: ChildProfile, audit_logs: list[AuditLog]) -> dict[str, Any]:
    parent_notifications = []
    if child.parent is not None:
        parent_notifications = [
            notification
            for notification in (child.parent.notifications or [])
            if notification.child_id == child.id
        ]
    parent_notifications.sort(
        key=lambda item: item.created_at or datetime.min,
        reverse=True,
    )
    return {
        "child_id": child.id,
        "entries": [
            {
                "type": "notification",
                "title": notification.title,
                "body": notification.body,
                "created_at": notification.created_at.isoformat()
                if notification.created_at
                else None,
            }
            for notification in parent_notifications[:20]
        ]
        + [
            {
                "type": "audit",
                **serialize_audit_log(log),
            }
            for log in audit_logs[:20]
        ],
    }
