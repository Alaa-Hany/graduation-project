from typing import Dict, Optional

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
        # Basic features available to all free users
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        # Premium-only features
        "advanced_reports": False,  # ✓ FIXED: was True
        "ai_insights": False,
        "smart_notifications": False,
        "offline_downloads": False,
        "multiple_children": False,
        "priority_support": False,
    },
    PLAN_PREMIUM: {
        # Inherits all free tier features
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        # Premium-specific features
        "advanced_reports": True,
        "ai_insights": True,
        "smart_notifications": True,
        "offline_downloads": True,
        "multiple_children": False,  # Limited to 3 children (enforced via PLAN_LIMITS)
        "priority_support": False,
    },
    PLAN_FAMILY_PLUS: {
        # All features enabled
        "basic_reports": True,
        "basic_notifications": True,
        "basic_parental_controls": True,
        "advanced_reports": True,
        "ai_insights": True,
        "smart_notifications": True,
        "offline_downloads": True,
        "multiple_children": True,  # Unlimited children (9999)
        "priority_support": True,
    },
}

FEATURE_FLAGS = list(PLAN_FEATURES[PLAN_FREE].keys())

PLAN_CATALOG: Dict[str, Dict[str, object]] = {
    PLAN_FREE: {
        "id": PLAN_FREE,
        "name": "Free",
        "price": 0,
        "period": "month",
    },
    PLAN_PREMIUM: {
        "id": PLAN_PREMIUM,
        "name": "Premium",
        "price": 10,
        "period": "month",
    },
    PLAN_FAMILY_PLUS: {
        "id": PLAN_FAMILY_PLUS,
        "name": "Family Plus",
        "price": 20,
        "period": "month",
    },
}


def normalize_plan_value(plan: Optional[str]) -> str:
    if not plan:
        return PLAN_FREE
    value = plan.strip().upper()
    if value in PLAN_LIMITS:
        return value
    return PLAN_FREE


def get_user_plan(user: User) -> str:
    plan_value = normalize_plan_value(getattr(user, "plan", None))
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
