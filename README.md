# Kinder World

Kinder World is a multi-role educational and parental-control platform built with Flutter (client) and FastAPI (backend).

This README reflects the current codebase as of the latest backend/Flutter updates. It is technical, accurate, and intended for reviewers and new contributors.

## Project Overview

The system supports three user contexts:

- Parent: manages children, subscription, reports, and settings
- Child: signs in with a picture-password flow and uses child-facing learning/play experiences
- Admin: manages users, content, subscriptions, analytics, and system settings via RBAC

Repository layout:

- `kinderbackend/`: FastAPI backend, SQLAlchemy models, services, and pytest tests
- `kinder_world_child_mode/`: Flutter app with Riverpod, GoRouter, local storage, and widget/unit tests

## Current Architecture

### Backend

Layered FastAPI app:

- `routers/`: HTTP endpoints
- `services/`: business logic and orchestration
- `schemas/`: Pydantic request/response models
- `models.py` + `admin_models.py`: SQLAlchemy models
- `core/`: settings, logging, exceptions, system settings, validators, observability

Key infrastructure:

- Request ID middleware
- Centralized exception handling
- Startup config validation and schema verification
- Health/readiness endpoints
- Admin diagnostics endpoints
- Observability event hooks (in-memory buffer + diagnostics access)

### Frontend (Flutter)

Client architecture:

- Riverpod for state and DI
- GoRouter with auth + role guards
- Hive + SharedPreferences for caching
- SecureStorage for auth/session data
- Backend-driven subscription gating (no local entitlement source of truth)

## Implemented Features (Current State)

### Parent Flows

- Registration, login, refresh, logout
- Parent PIN lifecycle (set/verify/change/reset)
- Child creation, update, list, delete
- Parent dashboard and reports (backend-driven)
- Subscription lifecycle view, checkout, cancel, manage portal, billing history
- Notifications, privacy settings, parental controls
- Support ticket creation and replies

### Child Flows

- Picture-password child login + session validation
- Learning/play flows driven by backend content APIs
- AI Buddy session UI connected to backend
- Local coloring gallery (explicitly labeled as local content pack)

### Admin Flows

- Admin auth (separate from parent/child)
- RBAC-permission enforcement
- Admin user and child management
- Admin analytics and audit logs
- Admin support triage
- Admin CMS management (categories, content, quizzes)
- Admin subscriptions overview and actions
- Admin system settings
- Admin diagnostics endpoints
- Optional admin seed endpoint for dev/test only

## Payment & Subscription Status

Implemented now:

- Subscription lifecycle with status and timestamps
- Billing history, subscription events, payment attempts
- Stripe provider integration with checkout session and billing portal
- Provider webhooks integration with signature verification + idempotency
- Reconciliation job/service to detect provider/local drift
- Refund workflow from admin
- Backend snapshot and history endpoints consumed in Flutter

Key endpoints (backend):

- `GET /subscription/me`, `GET /subscription/history`
- `POST /subscription/checkout`, `POST /subscription/activate`, `POST /subscription/cancel`
- `POST /subscription/manage`, `POST /billing/portal`
- `POST /webhooks/stripe`

Provider status:

- Production requires Stripe (`PAYMENT_PROVIDER=stripe`)
- Internal/mock provider is allowed only in dev/test and blocked in production

Operational requirement:

- Run `run_payment_reconciliation.py` on a schedule when enabled
- Configure Stripe webhook secret and URL in production

## AI Buddy Status

Current implementation:

- Backend session + message persistence
- Input/output moderation with refusal/safe-redirect handling
- Parental visibility summary (metrics + summary text, no transcript access by default)
- Retention policy enforced (messages retained for 30 days)
- Fallback-only response generator (no external AI provider integrated)

UI behavior:

- Flutter UI shows explicit “fallback mode” messaging
- Parent/admin surfaces show provider status and fallback details

Provider integration:

- External AI provider is not yet wired in code.
- `AI_PROVIDER_MODE` and `AI_PROVIDER_API_KEY` are validated, but no external model adapter is implemented.

## Content & CMS Status

Backend:

- CMS-style content models with publish/draft states
- Public pages via `/content/about`, `/content/help-faq`, `/legal/*`
- Child content via `/content/child/*` (categories, items, quizzes)

Flutter:

- Legal/help/about are fetched from backend and show empty states if not published
- Child content flows rely on backend APIs for learn/play
- Coloring gallery is a local asset pack and is explicitly labeled as local

## Analytics & Reports

Backend:

- Activity and session ingestion via `/analytics/events` and `/analytics/sessions`
- Reports via `/reports/basic` and `/reports/advanced`
- Analytics retention window configurable via env

Flutter:

- Parent reports and progress are backend-driven
- Premium insight surfaces use rules-based backend outputs (not ML)

## Observability & Diagnostics

Implemented:

- Request IDs on all API responses
- Structured observability events captured in backend
- Health endpoints:
  - `/health`
  - `/health/db`
  - `/health/ready`
- Admin diagnostics endpoints:
  - `/admin/diagnostics/health`
  - `/admin/diagnostics/events`

## Testing / CI

Backend:

- `pytest` suite with coverage
- Smoke test suite in `test_smoke_suite.py`
- Launch verification runner: `run_launch_verification.py`

Frontend:

- Flutter widget/unit tests under `kinder_world_child_mode/test/`
- Tests cover model parsing and UI states, including AI Buddy widgets

CI:

- GitHub Actions for backend lint/tests and Flutter analyze/tests

## Environment Configuration

### Backend (`kinderbackend/.env`)

Core runtime:

- `ENVIRONMENT` (development|production)
- `APP_LOG_LEVEL`, `APP_LOG_FILE`
- `SKIP_SCHEMA_VERIFY`, `AUTO_RUN_MIGRATIONS`
- `ALLOWED_ORIGINS`, `ALLOWED_ORIGIN_REGEX`, `CORS_ALLOW_CREDENTIALS`

Auth:

- `KINDER_JWT_SECRET` (required)
- `JWT_ALGORITHM`
- `JWT_PREVIOUS_SECRETS`
- `JWT_ACTIVE_KID`

Database:

- `DATABASE_URL`
- `DB_POOL_SIZE`, `DB_MAX_OVERFLOW`, `DB_POOL_RECYCLE_SECONDS`

Payment (Stripe):

- `PAYMENT_PROVIDER` (internal|stripe)
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY` (optional for backend readiness checks)
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_CHECKOUT_SUCCESS_URL`
- `STRIPE_CHECKOUT_CANCEL_URL`
- `STRIPE_PORTAL_RETURN_URL`
- `STRIPE_PRICE_PREMIUM_MONTHLY`
- `STRIPE_PRICE_FAMILY_PLUS_MONTHLY`
- `PAYMENT_RECONCILIATION_ENABLED`
- `PAYMENT_RECONCILIATION_SCHEDULE`

AI:

- `AI_PROVIDER_MODE` (fallback|external|openai)
- `AI_PROVIDER_API_KEY` (required for external modes)

Admin seed (dev/test only):

- `ENABLE_ADMIN_SEED_ENDPOINT`
- `ADMIN_SEED_SECRET`
- `ADMIN_SEED_EMAIL`
- `ADMIN_SEED_PASSWORD`
- `ADMIN_SEED_NAME`

Security and policy:

- `EMAIL_DOMAIN_ALLOWLIST`
- `EMAIL_DOMAIN_DENYLIST`
- `CHILD_AUTH_RATE_LIMIT_MAX_ATTEMPTS`
- `CHILD_AUTH_RATE_LIMIT_WINDOW_SECONDS`
- `ADMIN_AUTH_MAX_FAILED_ATTEMPTS`
- `ADMIN_AUTH_LOCKOUT_MINUTES`
- `ADMIN_SUSPICIOUS_FAILED_THRESHOLD`
- `ADMIN_SENSITIVE_CONFIRMATION_REQUIRED`

Analytics lifecycle:

- `ANALYTICS_RETENTION_DAYS`

### Frontend (Flutter)

- `API_BASE_URL` (build-time)

Example:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Operational Scripts

Backend scripts (repository root under `kinderbackend/`):

- `run_launch_verification.py` – config + health + smoke checks
- `run_payment_reconciliation.py` – reconciliation job for payment drift
- `run_db_backup.py` / `run_db_restore.py` – backup + restore helpers

## Known Limitations

These are real and current:

- AI Buddy is fallback-only; no external AI provider adapter exists yet.
- Production payments require Stripe configuration; internal provider is blocked in production.
- CMS content must be published for public pages and child content to appear; otherwise UI shows empty states.
- Coloring gallery content is local-only (explicitly labeled in UI).
- Flutter still defaults to a LAN IP for `API_BASE_URL` if not overridden.

## Next Steps (Optional)

If needed for production readiness:

- Wire an external AI provider adapter for AI Buddy.
- Ensure Stripe secrets + webhook + reconciliation schedule are configured in production.
- Publish CMS content for legal/help/about and child learning content.

## Notes

This README is a technical status document. It intentionally avoids marketing language and reflects the current behavior of the repository.
