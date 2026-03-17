from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import timedelta
from typing import Any
from uuid import uuid4

import httpx


@dataclass(frozen=True)
class CheckResult:
    name: str
    status: str
    reason: str | None = None
    details: dict[str, Any] | None = None


def _print_result(result: CheckResult) -> None:
    suffix = f" - {result.reason}" if result.reason else ""
    print(f"[{result.status}] {result.name}{suffix}")
    if result.details:
        print(json.dumps(result.details, indent=2, sort_keys=True))


def _build_client(base_url: str, timeout: float) -> httpx.Client:
    return httpx.Client(base_url=base_url, timeout=timeout)


def _check_config_validation() -> CheckResult:
    try:
        from core.settings import settings  # noqa: F401
    except Exception as exc:  # pragma: no cover - runtime guard
        return CheckResult(
            name="config_validation",
            status="FAIL",
            reason=str(exc),
        )
    return CheckResult(name="config_validation", status="PASS")


def _get_json(client: httpx.Client, path: str) -> tuple[int, dict[str, Any] | None]:
    response = client.get(path)
    payload = None
    if response.headers.get("content-type", "").startswith("application/json"):
        payload = response.json()
    return response.status_code, payload


def _post_json(
    client: httpx.Client,
    path: str,
    payload: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, dict[str, Any] | None]:
    response = client.post(path, json=payload, headers=headers)
    data = None
    if response.headers.get("content-type", "").startswith("application/json"):
        data = response.json()
    return response.status_code, data


def _check_health(client: httpx.Client) -> list[CheckResult]:
    results: list[CheckResult] = []
    status, payload = _get_json(client, "/health")
    if status != 200 or not payload:
        results.append(CheckResult("health", "FAIL", reason="Health endpoint failed"))
    else:
        results.append(CheckResult("health", "PASS"))

    status, payload = _get_json(client, "/health/db")
    if status != 200 or not payload or payload.get("status") != "ok":
        results.append(
            CheckResult(
                "health_db",
                "FAIL",
                reason="Database readiness failed",
                details=payload,
            )
        )
    else:
        results.append(CheckResult("health_db", "PASS"))

    status, payload = _get_json(client, "/health/ready")
    if status == 200:
        results.append(CheckResult("health_ready", "PASS", details=payload))
        ai = payload.get("ai", {}) if payload else {}
    else:
        results.append(
            CheckResult(
                "health_ready",
                "FAIL",
                reason="Readiness endpoint failed",
                details=payload,
            )
        )
        ai = (payload or {}).get("detail", {}).get("ai", {}) if payload else {}

    if ai:
        if ai.get("configured"):
            results.append(CheckResult("ai_readiness", "PASS", details=ai))
        elif "fallback" in str(ai.get("mode", "")).lower():
            results.append(
                CheckResult(
                    "ai_readiness",
                    "WARN",
                    reason="AI provider is in fallback mode",
                    details=ai,
                )
            )
        else:
            results.append(
                CheckResult(
                    "ai_readiness",
                    "FAIL",
                    reason="AI provider is not configured",
                    details=ai,
                )
            )
    return results


def _smoke_register_parent(client: httpx.Client) -> tuple[str | None, CheckResult]:
    email = f"launchcheck+{uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Launch Check Parent",
        "email": email,
        "password": "Password123!",
        "confirm_password": "Password123!",
    }
    status, data = _post_json(client, "/auth/register", payload)
    if status == 200 and data:
        token = data.get("access_token")
        if token:
            return token, CheckResult("smoke_parent_register", "PASS")
        return None, CheckResult("smoke_parent_register", "FAIL", reason="Missing token")
    if status == 403 and isinstance(data, dict):
        detail = data.get("detail")
        if isinstance(detail, dict) and detail.get("code") == "REGISTRATION_DISABLED":
            return None, CheckResult(
                "smoke_parent_register",
                "WARN",
                reason="Registration disabled by system settings",
                details=detail,
            )
    return None, CheckResult("smoke_parent_register", "FAIL", details=data)


def _smoke_me(client: httpx.Client, token: str) -> CheckResult:
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    if response.status_code == 200:
        return CheckResult("smoke_parent_me", "PASS")
    return CheckResult(
        "smoke_parent_me",
        "FAIL",
        reason=f"Unexpected status {response.status_code}",
        details=response.json()
        if response.headers.get("content-type", "").startswith("application/json")
        else None,
    )


def _smoke_child_and_content(client: httpx.Client, token: str) -> list[CheckResult]:
    results: list[CheckResult] = []
    child_payload = {
        "name": "Launch Check Kid",
        "picture_password": ["cat", "dog", "apple"],
        "age": 7,
    }
    status, data = _post_json(
        client,
        "/children",
        child_payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    if status != 200 or not data:
        results.append(CheckResult("smoke_child_create", "FAIL", details=data))
        return results
    child_id = data.get("child", {}).get("id")
    if not child_id:
        results.append(CheckResult("smoke_child_create", "FAIL", reason="Missing child id"))
        return results
    results.append(CheckResult("smoke_child_create", "PASS"))

    status, data = _get_json(client, "/content/child/categories")
    if status == 200:
        results.append(CheckResult("smoke_child_categories", "PASS"))
    else:
        results.append(CheckResult("smoke_child_categories", "FAIL", details=data))

    status, data = _get_json(client, "/content/child/items")
    if status == 200:
        results.append(CheckResult("smoke_child_items", "PASS"))
    else:
        results.append(CheckResult("smoke_child_items", "FAIL", details=data))

    return results


def _smoke_reports(client: httpx.Client, token: str, child_id: int) -> list[CheckResult]:
    results: list[CheckResult] = []
    headers = {"Authorization": f"Bearer {token}"}

    event_payload = {
        "child_id": child_id,
        "event_type": "lesson_completed",
        "lesson_id": "launch-check-lesson",
        "activity_name": "Launch Check Lesson",
        "duration_seconds": 120,
    }
    status, data = _post_json(client, "/analytics/events", event_payload, headers=headers)
    results.append(
        CheckResult(
            "smoke_activity_event",
            "PASS" if status == 200 else "FAIL",
            details=data,
        )
    )

    session_payload = {
        "child_id": child_id,
        "session_id": f"launch-check-{uuid4().hex[:6]}",
        "started_at": "2024-01-01T00:00:00Z",
        "ended_at": "2024-01-01T00:15:00Z",
        "source": "child_mode",
    }
    status, data = _post_json(client, "/analytics/sessions", session_payload, headers=headers)
    results.append(
        CheckResult(
            "smoke_activity_session",
            "PASS" if status == 200 else "FAIL",
            details=data,
        )
    )

    response = client.get("/reports/basic", headers=headers)
    status = response.status_code
    data = (
        response.json()
        if response.headers.get("content-type", "").startswith("application/json")
        else None
    )
    results.append(
        CheckResult(
            "smoke_reports_basic",
            "PASS" if status == 200 else "FAIL",
            details=data,
        )
    )
    return results


def _smoke_subscription_and_payments(client: httpx.Client, token: str) -> list[CheckResult]:
    results: list[CheckResult] = []
    headers = {"Authorization": f"Bearer {token}"}

    response = client.get("/subscription/me", headers=headers)
    status = response.status_code
    data = (
        response.json()
        if response.headers.get("content-type", "").startswith("application/json")
        else None
    )
    results.append(CheckResult("smoke_subscription_me", "PASS" if status == 200 else "FAIL", details=data))

    response = client.get("/subscription/history", headers=headers)
    status = response.status_code
    data = (
        response.json()
        if response.headers.get("content-type", "").startswith("application/json")
        else None
    )
    results.append(CheckResult("smoke_subscription_history", "PASS" if status == 200 else "FAIL", details=data))

    status, data = _post_json(
        client,
        "/subscription/checkout",
        {"plan_type": "premium"},
        headers=headers,
    )
    results.append(
        CheckResult(
            "smoke_subscription_checkout",
            "PASS" if status == 200 else "FAIL",
            details=data,
        )
    )

    status, data = _post_json(client, "/billing/portal", None, headers=headers)
    if status == 200:
        results.append(CheckResult("smoke_billing_portal", "PASS", details=data))
    elif status in {409, 501, 503}:
        results.append(
            CheckResult(
                "smoke_billing_portal",
                "WARN",
                reason="Portal not configured or provider unavailable",
                details=data,
            )
        )
    else:
        results.append(CheckResult("smoke_billing_portal", "FAIL", details=data))

    return results


def _smoke_ai_buddy(client: httpx.Client, token: str, child_id: int) -> CheckResult:
    headers = {"Authorization": f"Bearer {token}"}
    status, data = _post_json(
        client,
        "/ai-buddy/sessions",
        {"child_id": child_id},
        headers=headers,
    )
    if status == 200:
        return CheckResult("smoke_ai_buddy_session", "PASS")
    if status == 503 and isinstance(data, dict):
        detail = data.get("detail")
        if isinstance(detail, dict) and detail.get("code") == "AI_BUDDY_DISABLED":
            return CheckResult(
                "smoke_ai_buddy_session",
                "WARN",
                reason="AI Buddy disabled by system settings",
                details=detail,
            )
    return CheckResult("smoke_ai_buddy_session", "FAIL", details=data)


def _run_smoke_tests(client: httpx.Client) -> list[CheckResult]:
    results: list[CheckResult] = []
    token, register_result = _smoke_register_parent(client)
    results.append(register_result)
    if not token:
        return results

    results.append(_smoke_me(client, token))
    child_results = _smoke_child_and_content(client, token)
    results.extend(child_results)

    child_id = None
    for item in child_results:
        if item.name == "smoke_child_create" and item.status == "PASS":
            break

    # Retrieve child id by listing children (avoids carrying state)
    response = client.get("/children", headers={"Authorization": f"Bearer {token}"})
    if response.status_code == 200:
        payload = response.json()
        children = payload.get("children") or []
        if children:
            child_id = children[0].get("id")

    if child_id:
        results.extend(_smoke_reports(client, token, child_id))
        results.append(_smoke_ai_buddy(client, token, child_id))
    else:
        results.append(CheckResult("smoke_reports_basic", "SKIP", reason="No child id"))
        results.append(CheckResult("smoke_ai_buddy_session", "SKIP", reason="No child id"))

    results.extend(_smoke_subscription_and_payments(client, token))
    return results


def _summarize(results: list[CheckResult]) -> int:
    summary = {"PASS": 0, "FAIL": 0, "WARN": 0, "SKIP": 0}
    for result in results:
        summary[result.status] = summary.get(result.status, 0) + 1
    print("\nSummary:")
    for key in ("PASS", "FAIL", "WARN", "SKIP"):
        print(f"  {key}: {summary.get(key, 0)}")
    return 1 if summary.get("FAIL", 0) else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch verification checks")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8000",
        help="Base URL for the running backend",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="HTTP timeout seconds",
    )
    parser.add_argument(
        "--skip-smoke",
        action="store_true",
        help="Skip smoke tests (auth/content/subscription/AI)",
    )
    args = parser.parse_args()

    results: list[CheckResult] = []
    results.append(_check_config_validation())

    try:
        with _build_client(args.base_url, args.timeout) as client:
            results.extend(_check_health(client))
            if not args.skip_smoke:
                results.extend(_run_smoke_tests(client))
    except httpx.HTTPError as exc:
        results.append(
            CheckResult(
                "http_connectivity",
                "FAIL",
                reason=str(exc),
            )
        )

    for result in results:
        _print_result(result)
    return _summarize(results)


if __name__ == "__main__":
    sys.exit(main())
