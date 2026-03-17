import os
from datetime import date
from typing import Optional

from core.errors import bad_request, unprocessable

EMAIL_DOMAIN_ALLOWLIST_ENV = "EMAIL_DOMAIN_ALLOWLIST"
EMAIL_DOMAIN_DENYLIST_ENV = "EMAIL_DOMAIN_DENYLIST"

PASSWORD_COMPLEXITY_RULES = {
    "min_length": 8,
    "require_uppercase": True,
    "require_digit": True,
    "require_special": True,
}


def normalize_email(email: str) -> str:
    return email.strip().lower()


def _parse_domain_csv(value: str | None) -> set[str]:
    if not value:
        return set()
    return {item.strip().lower() for item in value.split(",") if item and item.strip()}


def validate_email_domain(email: str) -> None:
    if "@" not in email:
        raise bad_request("Invalid email format")
    domain = email.split("@", 1)[1].strip().lower()

    allowlist = _parse_domain_csv(os.getenv(EMAIL_DOMAIN_ALLOWLIST_ENV))
    denylist = _parse_domain_csv(os.getenv(EMAIL_DOMAIN_DENYLIST_ENV))

    if domain in denylist:
        raise bad_request("Email domain is not allowed")

    if allowlist and domain not in allowlist:
        raise bad_request("Email domain is not allowed by policy")


def resolve_child_age(age: Optional[int], dob: Optional[date]) -> Optional[int]:
    if age is not None:
        return age
    if dob is None:
        return None
    today = date.today()
    computed = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return max(computed, 0)


def validate_child_age(age: Optional[int]) -> None:
    if age is None:
        raise unprocessable("Child age is required")
    if age < 5 or age > 12:
        raise unprocessable("Child age must be between 5 and 12")


def validate_password_policy(password: str) -> tuple[bool, str]:
    if len(password) < PASSWORD_COMPLEXITY_RULES["min_length"]:
        return (
            False,
            f"Password must be at least {PASSWORD_COMPLEXITY_RULES['min_length']} characters",
        )

    if PASSWORD_COMPLEXITY_RULES["require_uppercase"] and not any(c.isupper() for c in password):
        return False, "Password must contain at least one uppercase letter"

    if PASSWORD_COMPLEXITY_RULES["require_digit"] and not any(c.isdigit() for c in password):
        return False, "Password must contain at least one digit"

    if PASSWORD_COMPLEXITY_RULES["require_special"]:
        special_chars = set("!@#$%^&*()-_=+[]{};:,.<>?")
        if not any(c in special_chars for c in password):
            return (
                False,
                "Password must contain at least one special character (!@#$%^&*)",
            )

    return True, ""


def validate_pin_format(pin: str, *, length: int = 4) -> None:
    if len(pin) != length or not pin.isdigit():
        raise unprocessable(f"PIN must be exactly {length} digits")


def validate_picture_password_length(items: list[str], *, length: int = 3) -> None:
    if not items or len(items) != length:
        raise unprocessable(f"Picture password must contain exactly {length} items")
