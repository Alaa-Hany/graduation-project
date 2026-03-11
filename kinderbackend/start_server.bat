@echo off
if "%SECRET_KEY%"=="" set SECRET_KEY=DEV_ONLY_SECRET
if "%ENABLE_ADMIN_SEED_ENDPOINT%"=="" set ENABLE_ADMIN_SEED_ENDPOINT=true
if "%ADMIN_SEED_SECRET%"=="" set ADMIN_SEED_SECRET=DEV_ONLY_SECRET
rem ENABLE_ADMIN_SEED_ENDPOINT is for local/dev use only.
cd /d "c:\Graduation Project\kinderbackend"
.venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000

