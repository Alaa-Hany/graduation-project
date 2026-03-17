"""
Import validation test - verifies all modules load without errors.
Run from kinderbackend/ directory with the venv activated.
"""

import os
import sys

os.environ.setdefault("SECRET_KEY", "TEST_ONLY_SECRET")
os.environ.setdefault("ENABLE_ADMIN_SEED_ENDPOINT", "true")  # dev/test only
os.environ.setdefault("ADMIN_SEED_SECRET", "TEST_ONLY_SECRET")

MODULES = [
    ("database", "database"),
    ("models", "models"),
    ("auth", "auth"),
    ("admin_auth", "admin_auth"),
    ("admin_models", "admin_models"),
    ("admin_deps", "admin_deps"),
    ("deps", "deps"),
    ("plan_service", "plan_service"),
    ("serializers", "serializers"),
    ("rate_limit", "rate_limit"),
    ("routers.auth", "routers.auth"),
    ("routers.notifications", "routers.notifications"),
    ("routers.privacy", "routers.privacy"),
    ("routers.content", "routers.content"),
    ("routers.support", "routers.support"),
    ("routers.features", "routers.features"),
    ("routers.parental_controls", "routers.parental_controls"),
    ("routers.billing_methods", "routers.billing_methods"),
    ("routers.subscription", "routers.subscription"),
    ("routers.admin_auth", "routers.admin_auth"),
    ("routers.admin_admins", "routers.admin_admins"),
    ("routers.admin_audit", "routers.admin_audit"),
    ("routers.admin_analytics", "routers.admin_analytics"),
    ("routers.admin_cms", "routers.admin_cms"),
    ("routers.admin_settings", "routers.admin_settings"),
    ("routers.admin_children", "routers.admin_children"),
    ("routers.admin_seed", "routers.admin_seed"),
    ("routers.admin_support", "routers.admin_support"),
    ("routers.admin_subscriptions", "routers.admin_subscriptions"),
    ("routers.admin_users", "routers.admin_users"),
    ("main", "main"),
]


def run_import_validation() -> int:
    print("=" * 60)
    print("KINDERWORLD BACKEND IMPORT VALIDATION")
    print("=" * 60)

    errors = []

    for label, module_name in MODULES:
        try:
            __import__(module_name)
            print(f"  [OK]  {label}")
        except Exception as exc:
            print(f"  [FAIL] {label}: {exc}")
            errors.append((label, str(exc)))

    print()
    if errors:
        print(f"RESULT: {len(errors)} IMPORT ERROR(S) FOUND")
        for label, err in errors:
            print(f"  - {label}: {err}")
        return 1

    print(f"RESULT: ALL {len(MODULES)} MODULES IMPORTED SUCCESSFULLY")
    return 0


def test_all_modules_import() -> None:
    assert run_import_validation() == 0


if __name__ == "__main__":
    sys.exit(run_import_validation())
