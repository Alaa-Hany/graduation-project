# Kinder World

Kinder World is a graduation project that investigates the design and implementation of a multi-role digital platform for children, parents, and administrators. The project is composed of:

- a multi-role Flutter application for child, parent, and admin flows
- a FastAPI backend for accounts, children, subscriptions, settings, support, and admin management

The repository should be regarded as an advanced academic prototype rather than a finished production system. Several core workflows are connected to persistent backend and database logic, while other areas remain demo-oriented, local-first, or powered by static and mock data.

## Implemented System Scope

### 1. Flutter App

The Flutter project lives in `kinder_world_child_mode/` and currently includes:

- startup flows: splash, onboarding, language selection, welcome
- parent registration and login
- child login and child picture-password change
- child mode:
  - home
  - learning, subjects, and lesson flows
  - play categories
  - `AI Buddy`
  - daily mood tracking with mood-based recommendations
  - child profile
  - child avatar customization
  - achievements
  - reward store
- gamification system:
  - XP
  - levels
  - streaks
  - achievements
  - badges
- parent mode:
  - dashboard
  - child management
  - reports
  - parental controls
  - notifications
  - subscription
  - account, language, theme, privacy, help, and legal settings
  - accessibility settings for the child-facing UI
  - Parent PIN
  - safety dashboard
  - billing management screen
- admin mode:
  - separate admin login
  - dashboard
  - user management
  - child management
  - subscription management
  - support ticket management
  - analytics
  - content management
  - admin management
  - audit logs
  - system settings
- Arabic and English localization
- local persistence via `Hive` and `SharedPreferences`
- secure storage via `flutter_secure_storage`
- derived parent notifications built from child activity and progress data
- multiple widget and service tests under `kinder_world_child_mode/test`

### 2. Backend

The backend lives in `kinderbackend/` and currently includes:

- parent authentication:
  - register
  - login
  - refresh token
  - logout
  - profile update
  - password change
  - current user
- child authentication:
  - register
  - login
  - picture-password change
- child management:
  - create
  - list
  - update
  - delete
- parent settings:
  - privacy settings
  - parental controls
  - parent PIN status/set/verify/change/reset-request
- notifications
- support tickets
- billing methods
- subscriptions and plans
- static help/about/legal content
- a separate admin system with:
  - admin auth
  - RBAC roles and permissions
  - admin users
  - admin children
  - admin subscriptions
  - admin support
  - admin analytics
  - admin CMS categories/contents/quizzes
  - admin settings
  - audit logs
  - optional admin seed endpoint
- Alembic migrations under `kinderbackend/alembic`

## Repository Structure

```text
Graduation Project/
├─ README.md
├─ kinderbackend/
│  ├─ alembic/
│  ├─ routers/
│  ├─ main.py
│  ├─ database.py
│  ├─ models.py
│  ├─ admin_models.py
│  ├─ requirements.txt
│  ├─ start_server.bat
│  └─ test_*.py
└─ kinder_world_child_mode/
   ├─ lib/
   ├─ assets/
   ├─ test/
   ├─ android/
   ├─ ios/
   ├─ web/
   └─ pubspec.yaml
```

## Technology Stack

### Flutter App

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio
- Hive
- SharedPreferences
- flutter_secure_storage
- Freezed / json_serializable
- fl_chart

### Backend

- Python
- FastAPI
- SQLAlchemy
- Alembic
- Pydantic
- SQLite by default
- PostgreSQL via `DATABASE_URL`
- JWT using `python-jose`

## Current Implementation Status

### Areas That Are Actually Working and Persisted

- parent accounts
- child profile creation and management
- plan-based child count limits
- Parent PIN flows
- local mood tracking with in-app mood recommendations
- child avatar customization saved locally
- local gamification state for XP, levels, streaks, badges, and achievements
- privacy settings
- parental controls
- accessibility settings managed by the parent for the child UI
- support tickets
- billing methods
- notifications and read state
- safety dashboard summaries
- admin users, roles, permissions, and audit logs
- subscription changes and related notification events

### Areas That Exist but Remain Demo / Mock / Partial

- `AI Buddy` in the Flutter app is not connected to any external AI service
- mood recommendations are local app logic, not external AI inference
- gamification currently runs locally in the app and is not fully synced into backend analytics
- `/subscription/select` and `/subscription/activate` immediately activate plans in demo mode
- `/subscription/manage` and `/billing/portal` return `501 Not Implemented`
- several endpoints in `routers/features.py` return sample or partial data, including:
  - `/reports/basic`
  - `/reports/advanced`
  - `/notifications/basic`
  - `/notifications/smart`
  - `/parental-controls/basic`
  - `/parental-controls/advanced`
  - `/ai/insights`
  - `/downloads/offline`
  - `/support/priority`
- `content/about`, `content/help-faq`, and legal endpoints currently return static content defined in code
- much of the child learning/play content is asset-driven and app-defined rather than fully CMS-driven from the backend
- some parent notifications are derived locally from progress/activity data and then merged with backend notifications
- the Flutter billing management screen exists, but the backend does not yet provide a real billing portal

## Local Setup and Execution

### Backend

From `kinderbackend/`:

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m alembic upgrade head
python -m uvicorn main:app --reload
```

Or on Windows:

```powershell
start_server.bat
```

Implementation notes:

- there is currently no `.env.example` file in the repository
- if `DATABASE_URL` is not set, the backend uses local SQLite at:

```text
kinderbackend/kinder.db
```

- `database.py` also supports PostgreSQL when `DATABASE_URL` is provided
- `main.py` calls `load_dotenv()`, so you can create your own local `.env`
- `start_server.bat` sets development defaults such as:
  - `SECRET_KEY=DEV_ONLY_SECRET`
  - `ENABLE_ADMIN_SEED_ENDPOINT=true`
  - `ADMIN_SEED_SECRET=DEV_ONLY_SECRET`

### Flutter App

From `kinder_world_child_mode/`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Implementation notes:

- the app uses `API_BASE_URL` through `--dart-define`
- if not provided, the current fallback inside the code is:

```text
http://192.168.42.128:8000
```

- overriding this value is strongly recommended for local development
- `pubspec.yaml` currently declares Flutter `>=3.10.0` and Dart `>=3.0.0 <4.0.0`

## Database and Migrations

Alembic files live under:

```text
kinderbackend/alembic/
```

Current migrations include:

- `72445407446a_initial_schema.py`
- `b3f7c1d9a2e4_add_parent_pin_fields.py`
- `c12e6f8a9b41_add_support_ticket_category.py`

## Main API Areas

### End-User and Parent/Child Routes

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `GET /auth/me`
- `PUT /auth/profile`
- `POST /auth/change-password`
- `POST /auth/logout`
- `GET /children`
- `POST /children`
- `PUT /children/{child_id}`
- `DELETE /children/{child_id}`
- `POST /auth/child/register`
- `POST /auth/child/login`
- `POST /auth/child/change-password`
- `GET /privacy/settings`
- `PUT /privacy/settings`
- `GET /parental-controls/settings`
- `PUT /parental-controls/settings`
- `GET /notifications`
- `POST /notifications/mark-all-read`
- `POST /notifications/{notification_id}/read`
- `POST /support/contact`
- `GET /support/tickets`
- `GET /support/tickets/{ticket_id}`
- `POST /support/tickets/{ticket_id}/reply`
- `GET /billing/methods`
- `POST /billing/methods`
- `DELETE /billing/methods/{method_id}`
- `GET /plans`
- `GET /subscription`
- `GET /subscription/me`
- `POST /subscription/select`
- `POST /subscription/activate`
- `POST /subscription/upgrade`
- `POST /subscription/cancel`
- `POST /subscription/manage`

### Admin Routes

- `POST /admin/auth/login`
- `POST /admin/auth/refresh`
- `POST /admin/auth/logout`
- `GET /admin/auth/me`
- `GET /admin/users`
- `GET /admin/children`
- `GET /admin/support`
- `GET /admin/analytics/overview`
- `GET /admin/analytics/usage`
- `GET /admin/subscriptions`
- `GET /admin/settings`
- `PATCH /admin/settings`
- `GET /admin/audit`
- `GET /admin/admin-users`
- `GET /admin/roles`
- `GET /admin/permissions`
- CMS routes under:
  - `/admin/categories`
  - `/admin/contents`
  - `/admin/quizzes`

## Testing and Local Verification

### Backend

There are multiple `pytest` test files under `kinderbackend/`.

Local verification on **March 12, 2026**:

- `python -m pytest` was run
- `75` tests were collected
- `1` test passed
- `74` errors occurred during execution
- the current failure on this local environment is caused by a `starlette.testclient.TestClient` and `httpx` incompatibility, with the visible error:

```text
TypeError: Client.__init__() got an unexpected keyword argument 'app'
```

Accordingly, it would be inaccurate to describe the backend test suite as fully passing in the current local environment.

### Flutter

There are many Flutter tests under `kinder_world_child_mode/test/`.

Local verification on **March 12, 2026**:

- `flutter test` was run
- the suite advanced through more than `100` test cases
- the current run ended with `5` failing cases
- visible failure causes include:
  - `sharedPreferencesProvider must be overridden`
  - some tests depend on provider setup or auth/network state that is not fully initialized in the current test environment

Accordingly, the Flutter test suite is substantial, but it is not fully passing in the current workspace state.

## Development Notes

- the current workspace already contains many in-progress changes across the repository
- `kinder_world_child_mode/TODO.md` describes ongoing UI/UX work
- the Flutter project targets Android, iOS, and Web
- this codebase already covers a broad set of screens and workflows, but it should still be described as an advanced prototype rather than a finished platform

## Academic Positioning

The most accurate academic description of this repository at its current stage is:

> Kinder World is a large-scale graduation-project prototype that combines a multi-role Flutter application with a FastAPI backend and database persistence, while several subsystems remain partial or demonstrative in nature, particularly AI integration, real billing, and advanced analytics.
