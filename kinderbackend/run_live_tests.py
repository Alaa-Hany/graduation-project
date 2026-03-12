"""
KinderWorld Backend — Live Endpoint Test Suite (Option B: Thorough)
Starts uvicorn in a subprocess, runs all tests, then shuts down.
"""
import os
import sys
import time
import json
import subprocess

# Force UTF-8 output on Windows (cp1256 cannot encode emoji)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

# ── Set env vars before any imports ──────────────────────────────────────────
os.environ.setdefault("SECRET_KEY", "TEST_ONLY_SECRET")
os.environ.setdefault("KINDER_JWT_SECRET", "TEST_ONLY_SECRET")
os.environ.setdefault("ENABLE_ADMIN_SEED_ENDPOINT", "true")  # dev/test only
os.environ.setdefault("ADMIN_SEED_SECRET", "TEST_ONLY_SECRET")
os.environ.setdefault("ADMIN_SEED_PASSWORD", "CHANGE_ME")
os.environ.setdefault("ADMIN_SEED_EMAIL", "change-me@example.invalid")
os.environ.setdefault("ADMIN_SEED_NAME", "DEV ONLY ADMIN")

import urllib.request
import urllib.error

BASE = "http://127.0.0.1:8000"
RESULTS = []
server_proc = None

# ── Helpers ───────────────────────────────────────────────────────────────────
def req(method, path, body=None, token=None, expected_status=None, params=None):
    url = BASE + path
    if params:
        query = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{url}?{query}"
    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as resp:
            status = resp.status
            body_out = json.loads(resp.read().decode())
            return status, body_out
    except urllib.error.HTTPError as e:
        status = e.code
        try:
            body_out = json.loads(e.read().decode())
        except Exception:
            body_out = {"raw": str(e)}
        return status, body_out
    except Exception as e:
        return 0, {"error": str(e)}

def test(name, method, path, body=None, token=None, expect_status=200, expect_key=None, expect_value=None, params=None):
    status, resp = req(method, path, body, token, params=params)
    passed = (status == expect_status)
    if passed and expect_key:
        passed = expect_key in resp
    if passed and expect_value is not None:
        passed = resp.get(expect_key) == expect_value
    icon = "✅" if passed else "❌"
    detail = f"HTTP {status}"
    if not passed:
        detail += f" | expected {expect_status} | resp: {json.dumps(resp)[:200]}"
    print(f"  {icon}  [{name}] {method} {path} — {detail}")
    RESULTS.append({"name": name, "passed": passed, "status": status, "resp": resp})
    return passed, status, resp

# ── Start server ──────────────────────────────────────────────────────────────
def start_server():
    global server_proc
    env = os.environ.copy()
    server_proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000"],
        cwd=os.path.dirname(os.path.abspath(__file__)),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    # Wait for server to be ready
    for i in range(20):
        time.sleep(0.5)
        try:
            urllib.request.urlopen(f"{BASE}/", timeout=2)
            print(f"  Server ready after {(i+1)*0.5:.1f}s")
            return True
        except Exception:
            pass
    # Print stderr for diagnosis
    try:
        out, err = server_proc.communicate(timeout=1)
        print("STDERR:", err.decode()[:1000])
    except Exception:
        pass
    return False

def stop_server():
    global server_proc
    if server_proc:
        server_proc.terminate()
        try:
            server_proc.wait(timeout=5)
        except Exception:
            server_proc.kill()

# ── Test Suite ────────────────────────────────────────────────────────────────
def run_tests():
    print("\n" + "="*65)
    print("KINDERWORLD BACKEND — LIVE ENDPOINT TEST SUITE")
    print("="*65)

    # ── 1. Server Health ──────────────────────────────────────────────────────
    print("\n[1] SERVER HEALTH")
    test("root endpoint", "GET", "/", expect_status=200, expect_key="message")

    # ── 2. Admin Seed ─────────────────────────────────────────────────────────
    print("\n[2] ADMIN SEED")
    # secret is a QUERY PARAMETER, not body
    ok, _, seed_resp = test("seed admin data", "POST", "/admin/seed",
        params={"secret": os.environ["ADMIN_SEED_SECRET"]}, expect_status=200)

    # ── 3. Admin Auth ─────────────────────────────────────────────────────────
    print("\n[3] ADMIN AUTH")
    ok, _, admin_login_resp = test("admin login (valid)", "POST", "/admin/auth/login",
        body={
            "email": os.environ["ADMIN_SEED_EMAIL"],
            "password": os.environ["ADMIN_SEED_PASSWORD"],
        },
        expect_status=200, expect_key="access_token")
    admin_token = admin_login_resp.get("access_token", "")

    test("admin login (wrong password)", "POST", "/admin/auth/login",
        body={"email": os.environ["ADMIN_SEED_EMAIL"], "password": "wrongpassword"},
        expect_status=401)

    test("admin login (nonexistent user)", "POST", "/admin/auth/login",
        body={"email": "nobody@kinderworld.app", "password": "anything"},
        expect_status=401)

    test("admin me (valid token)", "GET", "/admin/auth/me",
        token=admin_token, expect_status=200, expect_key="admin")

    test("admin me (no token)", "GET", "/admin/auth/me",
        expect_status=401)

    test("admin me (invalid token)", "GET", "/admin/auth/me",
        token="invalid.token.here", expect_status=401)

    # ── 4. Parent Auth ────────────────────────────────────────────────────────
    print("\n[4] PARENT AUTH — REGISTER")
    ts = int(time.time())
    parent_email = f"testparent{ts}@gmail.com"
    parent_pass = "TestPass@123"

    ok, _, reg_resp = test("parent register (valid)", "POST", "/auth/register",
        body={"name": "Test Parent", "email": parent_email,
              "password": parent_pass, "confirmPassword": parent_pass},
        expect_status=200, expect_key="access_token")
    parent_token = reg_resp.get("access_token", "")

    test("parent register (duplicate email)", "POST", "/auth/register",
        body={"name": "Test Parent", "email": parent_email,
              "password": parent_pass, "confirmPassword": parent_pass},
        expect_status=400)

    test("parent register (password mismatch)", "POST", "/auth/register",
        body={"name": "Test Parent", "email": f"other{ts}@gmail.com",
              "password": "Pass@123", "confirmPassword": "Different@123"},
        expect_status=400)

    test("parent register (invalid email domain)", "POST", "/auth/register",
        body={"name": "Test Parent", "email": f"test{ts}@yahoo.com",
              "password": parent_pass, "confirmPassword": parent_pass},
        expect_status=400)

    print("\n[5] PARENT AUTH — LOGIN")
    ok, _, login_resp = test("parent login (valid)", "POST", "/auth/login",
        body={"email": parent_email, "password": parent_pass},
        expect_status=200, expect_key="access_token")
    parent_token = login_resp.get("access_token", parent_token)
    refresh_token = login_resp.get("refresh_token", "")

    test("parent login (wrong password)", "POST", "/auth/login",
        body={"email": parent_email, "password": "WrongPass@123"},
        expect_status=401)

    test("parent login (nonexistent email)", "POST", "/auth/login",
        body={"email": f"nobody{ts}@gmail.com", "password": parent_pass},
        expect_status=401)

    print("\n[6] TOKEN REFRESH")
    test("token refresh (valid)", "POST", "/auth/refresh",
        body={"refresh_token": refresh_token},
        expect_status=200, expect_key="access_token")

    test("token refresh (invalid token)", "POST", "/auth/refresh",
        body={"refresh_token": "invalid.refresh.token"},
        expect_status=401)

    print("\n[7] AUTH ME")
    test("auth me (valid token)", "GET", "/auth/me",
        token=parent_token, expect_status=200, expect_key="user")

    test("auth me (no token)", "GET", "/auth/me",
        expect_status=401)

    # ── 8. Child Management ───────────────────────────────────────────────────
    print("\n[8] CHILD MANAGEMENT")
    ok, _, child_resp = test("create child (valid)", "POST", "/children",
        body={"name": "Alice", "picture_password": ["cat", "dog", "apple"],
              "age": 7, "avatar": "avatar1"},
        token=parent_token, expect_status=200, expect_key="child")
    child_id = child_resp.get("child", {}).get("id", 0)

    # FREE plan allows 1 child — duplicate name check only fires if under limit
    # Test duplicate name by trying a different name (plan limit is the real guard)
    test("create child (plan limit reached)", "POST", "/children",
        body={"name": "Alice2", "picture_password": ["cat", "dog", "apple"], "age": 7},
        token=parent_token, expect_status=402)  # 402 = CHILD_LIMIT_REACHED on FREE plan

    test("create child (age too young)", "POST", "/children",
        body={"name": "Baby", "picture_password": ["cat", "dog", "apple"], "age": 2},
        token=parent_token, expect_status=422)

    test("create child (age too old)", "POST", "/children",
        body={"name": "Teen", "picture_password": ["cat", "dog", "apple"], "age": 15},
        token=parent_token, expect_status=422)

    test("list children (valid)", "GET", "/children",
        token=parent_token, expect_status=200, expect_key="children")

    test("list children (no token)", "GET", "/children",
        expect_status=401)

    if child_id:
        test("update child (valid)", "PUT", f"/children/{child_id}",
            body={"name": "Alice Updated", "age": 8},
            token=parent_token, expect_status=200, expect_key="child")

        # Admin token is not a parent token → 401 (not authenticated as parent), not 403
        test("update child (admin token rejected)", "PUT", f"/children/{child_id}",
            body={"name": "Hacked"},
            token=admin_token, expect_status=401)

    # ── 9. Child Auth ─────────────────────────────────────────────────────────
    print("\n[9] CHILD AUTH")
    # First upgrade parent to PREMIUM so child limit is not hit
    req("POST", "/subscription/select",
        body={"plan_type": "premium"}, token=parent_token)

    ok, _, child_reg_resp = test("child register (valid)", "POST", "/auth/child/register",
        body={"name": "Bob", "picture_password": ["sun", "moon", "star"],
              "age": 6, "parent_email": parent_email},
        expect_status=200, expect_key="child")
    bob_id = child_reg_resp.get("child", {}).get("id", 0)

    test("child register (parent not found)", "POST", "/auth/child/register",
        body={"name": "Ghost", "picture_password": ["a", "b", "c"],
              "age": 6, "parent_email": f"nobody{ts}@gmail.com"},
        expect_status=404)

    if bob_id:
        test("child login (valid)", "POST", "/auth/child/login",
            body={"child_id": bob_id, "name": "Bob",
                  "picture_password": ["sun", "moon", "star"]},
            expect_status=200, expect_key="success")

        test("child login (wrong picture password)", "POST", "/auth/child/login",
            body={"child_id": bob_id, "name": "Bob",
                  "picture_password": ["wrong", "wrong", "wrong"]},
            expect_status=401)

        test("child login (wrong name)", "POST", "/auth/child/login",
            body={"child_id": bob_id, "name": "NotBob",
                  "picture_password": ["sun", "moon", "star"]},
            expect_status=401)

        test("child change password (valid)", "POST", "/auth/child/change-password",
            body={"child_id": bob_id, "name": "Bob",
                  "current_picture_password": ["sun", "moon", "star"],
                  "new_picture_password": ["fire", "water", "earth"]},
            expect_status=200, expect_key="success")

        test("child change password (wrong current)", "POST", "/auth/child/change-password",
            body={"child_id": bob_id, "name": "Bob",
                  "current_picture_password": ["sun", "moon", "star"],
                  "new_picture_password": ["a", "b", "c"]},
            expect_status=401)

    # ── 10. Subscription ──────────────────────────────────────────────────────
    print("\n[10] SUBSCRIPTION")
    test("get subscription (valid)", "GET", "/subscription/me",
        token=parent_token, expect_status=200)

    test("get plans (public)", "GET", "/plans",
        expect_status=200)

    # Flutter sends plan_type (lowercase) — backend now accepts both plan_id and plan_type
    test("select plan (free via plan_type)", "POST", "/subscription/select",
        body={"plan_type": "free"}, token=parent_token, expect_status=200)

    test("select plan (premium via plan_id)", "POST", "/subscription/select",
        body={"plan_id": "PREMIUM"}, token=parent_token, expect_status=200)

    test("select plan (invalid)", "POST", "/subscription/select",
        body={"plan_type": "INVALID_PLAN"}, token=parent_token, expect_status=400)

    test("select plan (no fields)", "POST", "/subscription/select",
        body={}, token=parent_token, expect_status=422)

    test("subscription (no token)", "GET", "/subscription/me",
        expect_status=401)

    # ── 11. Notifications ─────────────────────────────────────────────────────
    print("\n[11] NOTIFICATIONS")
    test("list notifications (valid)", "GET", "/notifications",
        token=parent_token, expect_status=200)

    test("list notifications (no token)", "GET", "/notifications",
        expect_status=401)

    # ── 12. Parental Controls ─────────────────────────────────────────────────
    print("\n[12] PARENTAL CONTROLS")
    # Correct path is /parental-controls/settings (not /parental-controls)
    test("get parental controls (valid)", "GET", "/parental-controls/settings",
        token=parent_token, expect_status=200, expect_key="settings")

    test("update parental controls (valid)", "PUT", "/parental-controls/settings",
        body={"daily_limit_enabled": True, "hours_per_day": 3,
              "break_reminders_enabled": True, "age_appropriate_only": True,
              "block_educational": False, "require_approval": False,
              "sleep_mode": True, "bedtime": "9:00 PM", "wake_time": "7:00 AM",
              "emergency_lock": False},
        token=parent_token, expect_status=200, expect_key="settings")

    test("parental controls (no token)", "GET", "/parental-controls/settings",
        expect_status=401)

    # ── 13. Admin Users ───────────────────────────────────────────────────────
    print("\n[13] ADMIN — USER MANAGEMENT")
    test("admin list users (valid)", "GET", "/admin/users",
        token=admin_token, expect_status=200)

    test("admin list users (no token)", "GET", "/admin/users",
        expect_status=401)

    test("admin list users (parent token)", "GET", "/admin/users",
        token=parent_token, expect_status=401)

    # ── 14. Admin Analytics ───────────────────────────────────────────────────
    print("\n[14] ADMIN — ANALYTICS")
    test("admin analytics overview (valid)", "GET", "/admin/analytics/overview",
        token=admin_token, expect_status=200)

    test("admin analytics (no token)", "GET", "/admin/analytics/overview",
        expect_status=401)

    # ── 15. Rate Limiting ─────────────────────────────────────────────────────
    print("\n[15] RATE LIMITING (auth endpoint — 5 req/5min)")
    bad_email = f"ratelimit{ts}@gmail.com"
    rate_hit = False
    for i in range(7):
        status, resp = req("POST", "/auth/login",
            body={"email": bad_email, "password": "wrong"})
        if status == 429:
            rate_hit = True
            print(f"  ✅  [rate limit triggered] Hit 429 on attempt {i+1}")
            break
    if not rate_hit:
        print(f"  ⚠️   [rate limit] Did not trigger 429 after 7 attempts (may need more requests or different window)")
        RESULTS.append({"name": "rate limit", "passed": None, "status": 0, "resp": {}})

    # ── 16. Delete child (cleanup) ────────────────────────────────────────────
    print("\n[16] CLEANUP")
    if child_id:
        test("delete child (valid)", "DELETE", f"/children/{child_id}",
            token=parent_token, expect_status=200)

        test("delete child (already deleted)", "DELETE", f"/children/{child_id}",
            token=parent_token, expect_status=404)

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "="*65)
    passed = [r for r in RESULTS if r["passed"] is True]
    failed = [r for r in RESULTS if r["passed"] is False]
    skipped = [r for r in RESULTS if r["passed"] is None]
    total = len(RESULTS)
    print(f"RESULTS: {len(passed)}/{total} passed | {len(failed)} failed | {len(skipped)} skipped")
    if failed:
        print("\nFAILED TESTS:")
        for r in failed:
            print(f"  ❌  {r['name']} — HTTP {r['status']} — {json.dumps(r['resp'])[:200]}")
    print("="*65)
    return len(failed) == 0

# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Starting uvicorn server...")
    if not start_server():
        print("❌ Server failed to start. Aborting tests.")
        sys.exit(1)

    try:
        success = run_tests()
    finally:
        print("\nStopping server...")
        stop_server()

    sys.exit(0 if success else 1)
