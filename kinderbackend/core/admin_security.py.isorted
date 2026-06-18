from __future__ import annotations

from fastapi import HTTPException, Request, status

from core.settings import settings

CONFIRMATION_HEADER = "X-Admin-Confirm"
CONFIRMATION_ACTION_HEADER = "X-Admin-Confirm-Action"
CONFIRMATION_VALUE = "CONFIRM"


def require_sensitive_action_confirmation(request: Request, *, action: str) -> None:
    if not settings.admin_sensitive_confirmation_required:
        return

    confirmation_value = (request.headers.get(CONFIRMATION_HEADER) or "").strip().upper()
    action_value = (request.headers.get(CONFIRMATION_ACTION_HEADER) or "").strip()

    if confirmation_value != CONFIRMATION_VALUE or action_value != action:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "ADMIN_CONFIRMATION_REQUIRED",
                "message": "Sensitive action confirmation is required",
                "expected_headers": {
                    CONFIRMATION_HEADER: CONFIRMATION_VALUE,
                    CONFIRMATION_ACTION_HEADER: action,
                },
            },
        )
