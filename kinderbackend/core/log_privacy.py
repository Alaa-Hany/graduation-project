"""Helpers for keeping personal data out of application logs.

Logs are shipped to third parties (Render, Sentry) and kept longer than the
data itself, so they should identify people by internal id, not by email.
When there is no account to point at (e.g. a login attempt for an unknown
email), log a short, stable fingerprint instead: the same email always gives
the same value, so repeated attempts can still be correlated.
"""

from __future__ import annotations

import hashlib


def email_fingerprint(email: str | None) -> str:
    normalized = (email or "").strip().lower()
    if not normalized:
        return "email:none"
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:12]
    return f"email:{digest}"
