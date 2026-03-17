from __future__ import annotations

from typing import Final

PERMISSION_DEFS: Final[list[tuple[str, str]]] = [
    ("admin.content.view", "View content categories, content items, and quizzes"),
    ("admin.users.view", "View parent/child user accounts"),
    ("admin.users.edit", "Edit parent/child user accounts"),
    ("admin.users.ban", "Ban/unban parent/child user accounts"),
    ("admin.children.view", "View child profiles"),
    ("admin.children.edit", "Edit child profiles"),
    ("admin.children.delete", "Delete child profiles"),
    ("admin.content.create", "Create new content items"),
    ("admin.content.edit", "Edit draft and review content items"),
    ("admin.content.publish", "Publish or unpublish content"),
    ("admin.content.delete", "Delete content items"),
    ("admin.reports.view", "View usage reports and analytics"),
    ("admin.analytics.view", "View analytics dashboards and usage summaries"),
    ("admin.support.view", "View support tickets"),
    ("admin.support.reply", "Reply to support tickets"),
    ("admin.support.close", "Close support tickets"),
    ("admin.subscription.view", "View subscription records"),
    ("admin.subscription.override", "Override subscription status"),
    ("admin.settings.edit", "Edit global app settings"),
    ("admin.audit.view", "View audit logs"),
    ("admin.admins.manage", "Create, edit, disable admin accounts"),
]

ROLE_DEFS: Final[dict[str, list[str]]] = {
    "super_admin": [name for name, _ in PERMISSION_DEFS],
    "content_admin": [
        "admin.content.view",
        "admin.content.create",
        "admin.content.edit",
        "admin.content.publish",
        "admin.content.delete",
    ],
    "support_admin": [
        "admin.users.view",
        "admin.children.view",
        "admin.support.view",
        "admin.support.reply",
        "admin.support.close",
    ],
    "analytics_admin": [
        "admin.users.view",
        "admin.children.view",
        "admin.analytics.view",
        "admin.audit.view",
    ],
    "finance_admin": [
        "admin.subscription.view",
        "admin.subscription.override",
        "admin.analytics.view",
    ],
}
