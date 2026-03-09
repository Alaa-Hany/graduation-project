# KinderWorld — Demo Day Startup Guide

> Run these steps **in order** on the demo machine before the presentation.

---

## Step 1 — Start the Backend

```powershell
# Navigate to backend
cd kinderbackend

# (First time only) Create and activate virtual environment
python -m venv .venv
.venv\Scripts\Activate.ps1

# (First time only) Install dependencies
pip install -r requirements.txt

# Set environment variables and start the server
$env:SECRET_KEY = "demo-secret-key-change-in-production"
$env:ENABLE_ADMIN_SEED_ENDPOINT = "true"
$env:ADMIN_SEED_SECRET = "demo-seed-secret"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Step 2 — Seed the Admin User (First Time Only)

While the backend is running, open a **new terminal** and run:

```powershell
# Seed permissions, roles, and default super-admin account
Invoke-RestMethod -Uri "http://localhost:8000/admin/seed" `
  -Method POST `
  -Headers @{ "X-Seed-Secret" = "demo-seed-secret" }
```

Expected response: `{"message": "Seed completed successfully"}`

Then **restart the backend without the seed env var**:

```powershell
# Stop the server (Ctrl+C), then restart without seed endpoint
Remove-Item Env:\ENABLE_ADMIN_SEED_ENDPOINT
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Step 3 — Run the Flutter App

```powershell
cd kinder_world_child_mode

# Get the demo machine's local IP address
ipconfig
# Note the IPv4 address, e.g. 192.168.1.100

# Run with the correct backend URL
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000

# OR if running backend and Flutter on the same machine:
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# OR for Android emulator (backend on host machine):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

---

## Step 4 — Verify Everything Works

Open a browser and check:
- Backend health: http://localhost:8000/docs  (FastAPI Swagger UI)
- Admin login: use credentials seeded in Step 2

---

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Super Admin | admin@kinderworld.com | (set during seed) |
| Test Parent | Register via app | Any valid email |

---

## Known Demo Limitations (Disclose to Evaluators)

| Feature | Status |
|---------|--------|
| AI Buddy responses | Simulated (no real LLM) |
| Voice mode | UI toggle only (no speech recognition) |
| Payment / billing portal | Mock flow (no real payment processor) |
| Activities history on child home | Demo data (not from API) |
| Arabic localization | ~65% complete (English fallback for missing strings) |

---

## Quick Troubleshooting

| Problem | Fix |
|---------|-----|
| App shows "Connection error" | Check `API_BASE_URL` dart-define matches backend IP |
| Backend fails to start | Run `pip install -r requirements.txt` again |
| Admin login fails | Re-run the seed step (Step 2) |
| Flutter build error | Run `flutter pub get` first |
