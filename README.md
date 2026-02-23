# 🌈 Kinder World - Graduation Project

🎓 **Kinder World** is a full-stack graduation project that provides a safe, engaging, and educational digital environment for children aged **5 to 12**.

It combines:
- 📱 A cross-platform Flutter application for children and parents
- ⚙️ A FastAPI backend for authentication, child management, subscription logic, and core APIs

---

## ✨ Project Vision

Kinder World is designed to support learning through play while giving parents meaningful visibility and control.

The platform focuses on:
- 🧠 Interactive learning experiences
- 👨‍👩‍👧 Parent-child role separation
- 🔐 Secure account and session workflows
- 📊 Progress-aware parent tools
- 🧩 Feature access based on subscription tiers

---

## 🏗️ Repository Structure

```text
Graduation Project/
├─ kinder_world_child_mode/      # Flutter app (child + parent interfaces)
│  ├─ lib/
│  ├─ assets/
│  ├─ android/ ios/ web/
│  ├─ windows/ macos/ linux/
│  └─ pubspec.yaml
└─ kinderbackend/                # FastAPI backend
   ├─ routers/
   ├─ main.py
   ├─ models.py
   ├─ deps.py
   ├─ auth.py
   ├─ database.py
   └─ plan_service.py
```

---

## 🧱 System Architecture

### 📱 Mobile Application (Flutter)

The mobile app follows a modular feature-oriented structure:
- `lib/core`: shared infrastructure (routing, localization, storage, networking, theme)
- `lib/features`: domain screens and flows for child mode, parent mode, auth, and system pages

Key architectural points:
- 🧭 Role-based route guarding (Parent / Child)
- 💾 Persistent local + secure storage usage
- 🪝 Riverpod-based state management
- 🔌 Service/repository separation for maintainability

### ⚙️ Backend Service (FastAPI)

The backend provides REST APIs for operational platform workflows:
- Authentication and token lifecycle
- Child profile lifecycle
- Plan and feature gating
- Parent controls, privacy, notifications, and support endpoints

Core service behavior:
- 🔑 JWT access + refresh token strategy
- 🛡️ Password hashing via bcrypt
- 🧠 Centralized plan/feature logic
- 🗄️ SQLite-based persistence layer

---

## 🚀 Functional Capabilities

### 👦 Child Experience

- Picture-password child login flow
- Child navigation with dedicated tabs:
  - 🏠 Home
  - 📚 Learn
  - 🎮 Play
  - 🤖 AI Buddy
  - 🙋 Profile
- Lesson and quiz-style educational flows
- Interactive content categories for fun + learning

### 👩‍👧 Parent Experience

- Parent registration and login
- Child profile management (add, update, delete)
- Parent dashboard with activity/progress views
- Parent modules:
  - 📈 Reports
  - 🧰 Parental Controls
  - 🔔 Notifications
  - ⚙️ Settings
  - 💳 Subscription screens
- 🌍 Multi-language and theme settings

### 🤖 AI Buddy

- Conversational child-facing UI integrated in app navigation
- Quick actions for guided interaction
- Local simulated response logic in current implementation

### 🧩 Backend Domain Coverage

- Auth endpoints for parent accounts and token refresh
- Child registration/login and picture-password update
- Child profile CRUD with age validation
- Subscription plan management and selection
- Feature-gated routes by plan entitlement
- Notification listing/read operations
- Privacy settings read/update
- Parental controls read/update
- Billing method management
- Support contact ticket submission

---

## 🛠️ Technology Stack

### 📱 Flutter Stack

- Flutter (Dart)
- Riverpod
- GoRouter
- Dio
- Connectivity Plus
- Freezed + JSON Serializable
- Flutter Secure Storage
- Hive
- FL Chart
- Lottie

### ⚙️ Backend Stack

- Python
- FastAPI
- SQLAlchemy
- Pydantic
- SQLite
- python-jose (JWT)
- bcrypt

---

## 🌐 API Surface (Summary)

- **Authentication**: `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/me`, `/auth/logout`, `/auth/change-password`
- **Child Auth**: `/auth/child/register`, `/auth/child/login`, `/auth/child/change-password`
- **Child Profiles**: `/children`, `/children/{child_id}`
- **Subscriptions**: `/subscription`, `/subscription/me`, `/subscription/upgrade`, `/subscription/cancel`, `/subscription/select`, `/plans`
- **Feature Routes**: `/reports/basic`, `/reports/advanced`, `/notifications/basic`, `/notifications/smart`, `/ai/insights`, `/downloads/offline`, `/support/priority`
- **Privacy**: `/privacy/settings`
- **Parental Controls**: `/parental-controls/settings`
- **Billing Methods**: `/billing/methods`
- **Support**: `/support/contact`

---

## ▶️ Local Development Setup

### 1) Backend Setup

From `kinderbackend`:

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install fastapi uvicorn sqlalchemy pydantic email-validator python-jose bcrypt pytest
uvicorn main:app --reload
```

Backend default URL:

`http://127.0.0.1:8000`

### 2) Flutter Setup

From `kinder_world_child_mode`:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

---

## 🧪 Testing

### Backend

From `kinderbackend`:

```bash
pytest
```

### Flutter

From `kinder_world_child_mode`:

```bash
flutter test
```

---

## 💎 Subscription and Access Model

The platform currently supports three plan tiers:
- `FREE`
- `PREMIUM`
- `FAMILY_PLUS`

Feature availability is resolved through centralized plan flags, and route access is enforced by dependency-based feature checks.

---

## 🌍 Localization and UI Configuration

The client supports:
- Arabic and English localization resources
- Theme-aware UI behavior through centralized providers
- Role-aware routing and session coordination

---

## 🗃️ Data Layer

SQLite is used as the default backend persistence engine.

SQLAlchemy models cover:
- Users
- Child profiles
- Parental controls
- Privacy settings
- Notifications
- Support tickets
- Billing methods

---

## 🎓 Graduation Project Scope

Kinder World represents a complete, runnable educational platform prototype with:
- A full mobile front end
- A functional backend service
- Authenticated parent/child flows
- Child management workflows
- Plan-aware feature control

It is structured for demonstration, extension, and academic evaluation as a graduation-level software project.

---

## ❤️ Closing Note

Built for children, guided by parents, and engineered as a serious graduation project.
