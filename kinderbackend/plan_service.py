import os
from datetime import timedelta
from typing import Dict, Optional

from core.time_utils import ensure_utc, utc_now
from models import User

PLAN_FREE = "FREE"
PLAN_PREMIUM = "PREMIUM"
PLAN_FAMILY_PLUS = "FAMILY_PLUS"

PLAN_ORDER = {
    PLAN_FREE: 0,
    PLAN_PREMIUM: 1,
    PLAN_FAMILY_PLUS: 2,
}

PLAN_LIMITS: Dict[str, Optional[int]] = {
    PLAN_FREE: 1,
    PLAN_PREMIUM: 3,
    PLAN_FAMILY_PLUS: 9999,
}

PLAN_FEATURES: Dict[str, Dict[str, bool]] = {
    PLAN_FREE: {
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        # Premium-only features stay disabled on the free tier.
        "advanced_reports": False,
        "ai_insights": False,
        "smart_notifications": False,
        "offline_downloads": False,
        "multiple_children": False,
        "family_dashboard": False,
        "priority_support": False,
    },
    PLAN_PREMIUM: {
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        "advanced_reports": True,
        "ai_insights": True,
        "smart_notifications": True,
        "offline_downloads": True,
        "multiple_children": False,  # Limited to 3 children (enforced via PLAN_LIMITS)
        "family_dashboard": False,
        "priority_support": False,
    },
    PLAN_FAMILY_PLUS: {
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        "advanced_reports": True,
        "ai_insights": True,
        "smart_notifications": True,
        "offline_downloads": True,
        "multiple_children": True,  # Unlimited children (9999)
        "family_dashboard": True,
        "priority_support": True,
    },
}

FEATURE_FLAGS = list(PLAN_FEATURES[PLAN_FREE].keys())

BILLING_INTERVAL_MONTHLY = "monthly"
BILLING_INTERVAL_YEARLY = "yearly"
BILLING_INTERVALS = (BILLING_INTERVAL_MONTHLY, BILLING_INTERVAL_YEARLY)
DEFAULT_BILLING_INTERVAL = BILLING_INTERVAL_MONTHLY

PLAN_CATALOG: Dict[str, Dict[str, object]] = {
    PLAN_FREE: {
        "id": PLAN_FREE,
        "name": "Free",
        "price": 0,
        "billing_type": "free",
        "access_type": "free",
        "pricing": {},
    },
    PLAN_PREMIUM: {
        "id": PLAN_PREMIUM,
        "name": "Premium",
        "price": 3,
        "billing_type": "recurring",
        "access_type": "subscription",
        "pricing": {
            BILLING_INTERVAL_MONTHLY: {"price": 3},
            BILLING_INTERVAL_YEARLY: {"price": 27, "discount_percent": 25},
        },
    },
    PLAN_FAMILY_PLUS: {
        "id": PLAN_FAMILY_PLUS,
        "name": "Family Plus",
        "price": 5,
        "billing_type": "recurring",
        "access_type": "subscription",
        "pricing": {
            BILLING_INTERVAL_MONTHLY: {"price": 5},
            BILLING_INTERVAL_YEARLY: {"price": 45, "discount_percent": 25},
        },
    },
}


def normalize_billing_interval(interval: Optional[str]) -> str:
    if not interval:
        return DEFAULT_BILLING_INTERVAL
    value = interval.strip().lower()
    return value if value in BILLING_INTERVALS else DEFAULT_BILLING_INTERVAL


def get_plan_price(plan: str, interval: Optional[str] = None) -> float:
    catalog = PLAN_CATALOG.get(plan, PLAN_CATALOG[PLAN_FREE])
    pricing = catalog.get("pricing") or {}
    normalized_interval = normalize_billing_interval(interval)
    entry = pricing.get(normalized_interval)
    if entry is None:
        return float(catalog.get("price", 0))
    return float(entry["price"])


def normalize_plan_value(plan: Optional[str]) -> str:
    if not plan:
        return PLAN_FREE
    value = plan.strip().upper()
    if value in PLAN_LIMITS:
        return value
    return PLAN_FREE


def subscription_expiry_grace() -> timedelta:
    """How long access survives past expires_at while waiting for the renewal webhook."""
    try:
        hours = int((os.getenv("SUBSCRIPTION_EXPIRY_GRACE_HOURS") or "72").strip())
    except (TypeError, ValueError):
        hours = 72
    return timedelta(hours=max(hours, 0))


def get_stored_user_plan(user: User) -> str:
    """The plan recorded on the user row, ignoring expiry (for bookkeeping)."""
    return normalize_plan_value(getattr(user, "plan", None))


def get_user_plan(user: User) -> str:
    """The plan the user may use right now.

    A paid plan whose subscription period ended (plus a grace period for a
    late renewal webhook) counts as FREE, even if nothing has downgraded the
    stored plan yet, e.g. because a cancellation webhook was missed.
    """
    plan_value = get_stored_user_plan(user)
    if plan_value == PLAN_FREE:
        return plan_value
    profile = getattr(user, "subscription_profile", None)
    expires_at = getattr(profile, "expires_at", None) if profile is not None else None
    if expires_at is not None:
        if ensure_utc(expires_at) + subscription_expiry_grace() < utc_now():
            return PLAN_FREE
    return plan_value


def plan_allows(current_plan: str, required_plan: str) -> bool:
    return PLAN_ORDER.get(current_plan, 0) >= PLAN_ORDER.get(required_plan, 0)


def get_plan_limits(plan: str) -> Dict[str, Optional[int]]:
    limit = PLAN_LIMITS.get(plan, PLAN_LIMITS[PLAN_FREE])
    return {"max_children": limit}


def get_plan_features(plan: str) -> Dict[str, bool]:
    return PLAN_FEATURES.get(plan, PLAN_FEATURES[PLAN_FREE])


def feature_enabled(plan: str, feature: str) -> bool:
    features = get_plan_features(plan)
    return features.get(feature, False)


def validate_plan_value(plan: str) -> str:
    normalized = normalize_plan_value(plan)
    if normalized not in PLAN_LIMITS:
        raise ValueError("Invalid plan value")
    return normalized


def get_plan_catalog() -> Dict[str, Dict[str, object]]:
    return PLAN_CATALOG
