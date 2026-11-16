# Security fixes, round 2 (`security-fixes-2`)

Branch `security-fixes-2`, based on `security-fixes` (`cd367d0`, already live on
Render via PR #19). Everything here is a **local commit only** — nothing has been
pushed, merged or deployed.

## 1. Items and where they were fixed

| # | Item | Status | Commit |
|---|------|--------|--------|
| 1 | Subscription activation checks the checkout session belongs to the caller and plan; no replay | Fixed | `df143e6` |
| 3 | Real client IP via `CF-Connecting-IP` (only when `TRUST_CF_CONNECTING_IP=true`) | Fixed | `df143e6` |
| 4 | Child login: lockout per child id, one generic error, change-password needs the parent token | Fixed | `df143e6` |
| 13 | Unsigned Stripe webhooks are logged only, never written to the DB | Fixed | `df143e6` |
| 2 | Account deletion, child data purge, analytics opt-out | Fixed | `dbb452a` |
| 12 | Wrong 2FA codes count toward the login lockout | Fixed | `d116a99` |
| 26 | 2FA setup needs the current password | Fixed | `d116a99` |
| 5 | Admin bootstrap closed in production unless `ADMIN_BOOTSTRAP_SECRET` is set | Fixed | `d116a99` |
| 8 | Expired plan (past expiry + grace) treated as FREE | Fixed | `d116a99` |
| 6 | Refresh tokens are per-device sessions; logout ends only this device | Fixed | `d116a99` |
| 11 | Analytics input limits + 120 writes/min per child | Fixed | `a77d016` |
| 25 | Video upload: early 413, chunked size check, streamed to Cloudinary | Fixed | `a77d016` |
| 16 | `/ready` hides DB/Redis details in production | Fixed | `a77d016` |
| 17 | No account enumeration on register / OTP / forgot-password / login | Fixed | `a77d016` |
| 18 | No email addresses in logs | Fixed | `a77d016` |
| 19 | User-typed names HTML-escaped in emails | Fixed | `a77d016` |
| — | Re-signup on an unverified email can't overwrite name/password (needs the emailed code **and** the registration token) | Fixed | `4dea921` |
| — | Default video upload limit 100 MB in code | Fixed | `4dea921` |
| — | Fixed `Temp@123456` removed — admin reset now makes a random 16-char password | Fixed | `4dea921` |
| — | `/subscription/me` shows FREE after the grace period ends | Fixed | `4dea921` |
| 7 | Auto-retry only for GET/HEAD/OPTIONS (or requests with an `Idempotency-Key`); analytics events/sessions send an `Idempotency-Key`, stored once thanks to a DB unique constraint | Fixed | `c91d21a` |
| 10 | Parent gate (simple maths question) before YouTube / any external link from child mode; YouTube iframe on web is sandboxed | Fixed | `c91d21a` |
| 9 | Security headers in `firebase.json` (CSP, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy) + `no-cache` for `index.html` / JS | Fixed | `c91d21a` |
| 23 | Zoom allowed (removed `user-scalable=no`), real description, `lang="en"` | Fixed | `c91d21a` |
| 24 | Bluetooth permissions removed; `RECORD_AUDIO` kept (AI Buddy mic) | Fixed | `c91d21a` |

> Known limit of #7: when a parent has analytics **turned off**, only daily
> totals are kept (no rows), so there is nothing to de-duplicate against — a
> retried request in that mode can add to the day's totals twice. Rare and
> only affects counters, never stored activity data.

> UI note for the design chat: the **delete-account dialog** and the **parent
> gate dialog** (`lib/core/widgets/parent_gate_dialog.dart`) are plain
> `AlertDialog`s on purpose — restyle them freely, just keep the widget keys
> `parent_gate_answer` / `parent_gate_continue` (used by tests).

## 2. Render — what to do, in order

Nothing below is optional unless marked so. "Variable" = Render → service →
Environment.

### Before the deploy

1. **Take a DB backup** (Render dashboard → database → Backups, or `run_db_backup.py`).
   The deploy runs 4 new migrations.
2. Check `AUTO_RUN_MIGRATIONS=true` (it already is). It applies, in order:
   `q13_summary_unlogged_20261116`, `r14_refresh_sessions_20261116`,
   `s15_pending_signup_20261116`, `t16_analytics_idem_20261116`.
   All only **add** columns / tables / a unique constraint; nothing is dropped.
3. Check `KINDER_JWT_SECRET` is **at least 32 characters** (the app refuses to
   start in production otherwise — this came with `security-fixes`).
4. Leave `ENFORCE_ADMIN_2FA` **unset / false** (see "later" below).
5. Do **not** set `PAYMENT_RECONCILIATION_ENABLED=true` on its own: if you ever
   turn it on, set `PAYMENT_RECONCILIATION_SCHEDULE` in the same edit.
   (Nothing currently runs the schedule, so leaving both off is fine.)

### With the deploy (same save as the deploy)

6. `TRUST_CF_CONNECTING_IP=true`.
   Verified on 2026-11-16 against the live service: responses carry
   `Server: cloudflare` + `CF-RAY`, and a request that sends its own
   `CF-Connecting-IP` header is **rejected by Cloudflare with 403** before it
   reaches the app — so the header can't be forged from outside. Render's
   origin is not reachable except through that edge.
   Without this variable, rate limits use the uvicorn peer IP, which is
   forgeable through `X-Forwarded-For` when `FORWARDED_ALLOW_IPS="*"`.
7. Optional: `HEALTH_DETAILS_TOKEN=<long random string>` — only if you want to
   see DB/Redis details on `/ready` (send it as the `X-Health-Token` header).
   Without it `/ready` returns just `{"status": ...}` in production.

### After the deploy

8. Open the Render logs and check:
   - the 4 migrations ran (`Running upgrade ... -> t16_analytics_idem_20261116`);
   - there is **no** `client_ip_cf_header_not_trusted` warning at startup.
9. Run the checks in section 4.
10. Only if you need to create the very first admin on a fresh DB:
    set `ADMIN_BOOTSTRAP_SECRET`, call the bootstrap endpoint with header
    `X-Admin-Bootstrap-Secret`, then **delete the variable**.

### Later (not part of this deploy)

11. `ENFORCE_ADMIN_2FA=true` — only **after every admin has turned on 2FA**,
    otherwise admins without 2FA are locked out.
12. Optional tuning (sane defaults exist): `SUBSCRIPTION_EXPIRY_GRACE_HOURS`,
    `CHILD_PURGE_GRACE_DAYS`, `DATA_PURGE_ENABLED`, `DATA_PURGE_INTERVAL_HOURS`,
    `MEDIA_MAX_UPLOAD_SIZE_MB` (default is now 100 — no need to set it).

### Firebase (frontend)

13. Deploy the web app with `deploy.ps1` (it passes
    `--dart-define=API_BASE_URL=...`). The new headers in `firebase.json` go
    live with that deploy — no console change needed.

## 3. Deferred (not done in this branch)

- **#14 Sentry** — needs a Sentry account and a DSN (`SENTRY_DSN`).
- **#15 assets and sounds** — cleanup of unused/heavy assets.
- **#27 package upgrades** — separate PR, needs its own test pass.
- **#20, #21, #22 UI items** — belong to the `design-upgrade` branch.
- **Suggestion: direct upload to Cloudinary.** Today a video goes
  browser → backend → Cloudinary (now streamed, 100 MB cap). Better later:
  the backend signs an upload (`/admin/media/videos/upload-signature`), the
  admin panel uploads straight to Cloudinary, then tells the backend the
  resulting `public_id`. Removes the backend from the heavy path and lifts the
  size limit to Cloudinary's.

## 4. Post-deploy checks

Backend:
- [ ] `GET /health` → 200; `GET /ready` → only `{"status":"ok"}`.
- [ ] Sign up with a new email → code arrives → verify → login works.
- [ ] Sign up again with an **unverified** email from another browser, then
      verify with the code in the first browser → the **first** password still works.
- [ ] Sign up with an already-verified email → same "check your email" answer
      (no "already exists"), and the owner gets a notice email.
- [ ] Forgot password for an unknown email → same success message.
- [ ] Admin → reset a user's password without typing one → a random password
      is shown (never `Temp@123456`).
- [ ] An expired subscription past the grace period shows FREE in the app.
- [ ] Admin video upload of a ~10 MB file works; a >100 MB file gets 413.
- [ ] Child finishes an activity → parent report shows it **once** (not doubled).

Web (Firebase):
- [ ] Open the site, DevTools → Console: no `Content-Security-Policy` errors.
- [ ] Response headers on `/` include `Content-Security-Policy`,
      `X-Frame-Options: DENY`, `Cache-Control: no-cache`.
- [ ] Play a YouTube lesson inside the app — it plays.
- [ ] Tap "open on YouTube" from child mode → parent gate appears; wrong answer
      blocks, right answer opens.
- [ ] Pinch-zoom works on a phone.
- [ ] AI Buddy mic still works (browser asks for the mic once).

Android:
- [ ] Install the new APK → AI Buddy mic asks only for the microphone, never Bluetooth.

## 5. Merge plan (approved order; **not executed**)

1. `git fetch`; fast-forward local `main` to `origin/main`.
2. PR `security-fixes-2` → `main`. Do section 2 (Render) around that deploy.
   Verify with section 4.
3. Update `design-upgrade` from the new `main`, re-check the 3 localization
   files (`app_localizations*.dart`, the only files both branches touch),
   restyle the delete-account dialog and the parent gate, run
   `flutter analyze` + `flutter test`, then PR → `main` and deploy the web
   app with `deploy.ps1`.

Why security first: it carries the migrations and the Render changes; landing
it alone makes any problem easy to pin down. The design branch needs nothing
on the server.

### Trial merge (2026-11-16, in a throw-away detached worktree — no branch changed)

`origin/main` (`432110c`) + `security-fixes-2` (`c91d21a`) + `design-upgrade` (`384fb2e`):

- **No conflicts** (both merges automatic).
- `flutter analyze`: 2 `info` notes (`curly_braces_in_flow_control_structures`,
  `learn_support_screens.dart`), both from design commit `f02ad4e` — not errors,
  for the design chat to tidy.
- `flutter test`: **757 passed**.
- Backend `pytest` (with the 70% coverage gate): **881 passed, 2 skipped**.

`design-upgrade` has moved on since (now `03e0da4`), so repeat this trial
right before the real merge.
