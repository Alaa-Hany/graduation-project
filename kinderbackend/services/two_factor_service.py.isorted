from __future__ import annotations

from typing import Any, Protocol

from fastapi import HTTPException

from core.errors import http_error
from core.message_catalog import AdminAuthMessages, AuthMessages
from core.time_utils import db_utc_now
from core.two_factor import (
    DEFAULT_TWO_FACTOR_ISSUER,
    TWO_FACTOR_TOTP_METHOD,
    generate_totp_secret,
    normalize_totp_code,
    provisioning_uri,
    verify_totp_code,
)


class TwoFactorAccount(Protocol):
    id: int
    email: str | None
    name: str | None
    two_factor_enabled: bool
    two_factor_method: str | None
    two_factor_secret: str | None
    two_factor_confirmed_at: object | None


class TwoFactorService:
    issuer_name = DEFAULT_TWO_FACTOR_ISSUER

    def status_payload(self, *, account: TwoFactorAccount) -> dict[str, Any]:
        confirmed_at = getattr(account, "two_factor_confirmed_at", None)
        return {
            "enabled": bool(getattr(account, "two_factor_enabled", False)),
            "method": getattr(account, "two_factor_method", None),
            "confirmed_at": confirmed_at.isoformat() if confirmed_at is not None else None,
        }

    def setup_totp(self, *, account: TwoFactorAccount) -> dict[str, Any]:
        if bool(getattr(account, "two_factor_enabled", False)):
            raise http_error(
                status_code=409,
                message=AuthMessages.TWO_FACTOR_ALREADY_ENABLED,
                code="TWO_FACTOR_ALREADY_ENABLED",
            )

        secret = generate_totp_secret()
        account.two_factor_enabled = False
        account.two_factor_method = TWO_FACTOR_TOTP_METHOD
        account.two_factor_secret = secret
        account.two_factor_confirmed_at = None

        account_label = (getattr(account, "email", None) or f"account-{account.id}").strip()
        return {
            **self.status_payload(account=account),
            "secret": secret,
            "manual_entry_key": secret,
            "issuer": self.issuer_name,
            "provisioning_uri": provisioning_uri(
                secret=secret,
                account_name=account_label,
                issuer=self.issuer_name,
            ),
        }

    def enable_totp(self, *, account: TwoFactorAccount, code: str | None) -> dict[str, Any]:
        if getattr(account, "two_factor_method", None) != TWO_FACTOR_TOTP_METHOD or not getattr(
            account, "two_factor_secret", None
        ):
            raise http_error(
                status_code=400,
                message=AuthMessages.TWO_FACTOR_SETUP_REQUIRED,
                code="TWO_FACTOR_SETUP_REQUIRED",
            )

        normalized_code = normalize_totp_code(code)
        if not verify_totp_code(account.two_factor_secret, normalized_code):
            raise http_error(
                status_code=422,
                message=AuthMessages.INVALID_TWO_FACTOR_CODE,
                code="INVALID_TWO_FACTOR_CODE",
            )

        account.two_factor_enabled = True
        account.two_factor_confirmed_at = db_utc_now()
        return {
            **self.status_payload(account=account),
            "success": True,
            "message": AuthMessages.TWO_FACTOR_ENABLED_SUCCESSFULLY,
        }

    def disable_two_factor(self, *, account: TwoFactorAccount) -> dict[str, Any]:
        account.two_factor_enabled = False
        account.two_factor_method = None
        account.two_factor_secret = None
        account.two_factor_confirmed_at = None
        return {
            **self.status_payload(account=account),
            "success": True,
            "message": AuthMessages.TWO_FACTOR_DISABLED_SUCCESSFULLY,
        }

    def require_parent_login_code(self, *, account: TwoFactorAccount, code: str | None) -> None:
        if not bool(getattr(account, "two_factor_enabled", False)):
            return

        if not verify_totp_code(getattr(account, "two_factor_secret", None) or "", code):
            detail = {
                "code": (
                    "PARENT_TWO_FACTOR_REQUIRED"
                    if normalize_totp_code(code) is None
                    else "PARENT_INVALID_TWO_FACTOR_CODE"
                ),
                "message": (
                    AuthMessages.TWO_FACTOR_REQUIRED
                    if normalize_totp_code(code) is None
                    else AuthMessages.INVALID_TWO_FACTOR_CODE
                ),
                "two_factor_method": getattr(account, "two_factor_method", TWO_FACTOR_TOTP_METHOD),
            }
            raise HTTPException(status_code=401, detail=detail)

    def require_admin_login_code(self, *, account: TwoFactorAccount, code: str | None) -> None:
        if not bool(getattr(account, "two_factor_enabled", False)):
            return

        if not verify_totp_code(getattr(account, "two_factor_secret", None) or "", code):
            detail = {
                "code": (
                    "ADMIN_TWO_FACTOR_REQUIRED"
                    if normalize_totp_code(code) is None
                    else "ADMIN_INVALID_TWO_FACTOR_CODE"
                ),
                "message": (
                    AdminAuthMessages.TWO_FACTOR_REQUIRED
                    if normalize_totp_code(code) is None
                    else AdminAuthMessages.INVALID_TWO_FACTOR_CODE
                ),
                "two_factor_method": getattr(account, "two_factor_method", TWO_FACTOR_TOTP_METHOD),
            }
            raise HTTPException(status_code=401, detail=detail)


two_factor_service = TwoFactorService()
