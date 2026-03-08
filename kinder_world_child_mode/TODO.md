# Phase 1 Admin System - TODO

## Status: ✅ COMPLETE

## Backend
- [x] Create kinderbackend/admin_models.py — 5 tables: admin_users, roles, permissions, role_permissions, admin_user_roles
- [x] Create kinderbackend/admin_auth.py — JWT helpers with token_type='admin' isolation claim
- [x] Create kinderbackend/admin_deps.py — get_current_admin(), require_admin(), require_permission() RBAC deps
- [x] Create kinderbackend/routers/admin_auth.py — POST /admin/auth/login, /refresh, /logout, GET /admin/auth/me
- [x] Create kinderbackend/routers/admin_seed.py — POST /admin/seed (18 permissions, 5 roles, default super_admin)
- [x] Modify kinderbackend/main.py — admin routers registered, admin_models imported for table auto-creation

## Frontend
- [x] Create lib/core/models/admin_user.dart — AdminUser model with hasPermission()/hasRole() helpers
- [x] Modify lib/core/storage/secure_storage.dart — admin access/refresh token + user keys added
- [x] Create lib/features/admin/auth/admin_auth_repository.dart — Dio-based API calls to all admin endpoints
- [x] Create lib/features/admin/auth/admin_auth_provider.dart — Riverpod StateNotifier with session restore on startup
- [x] Create lib/features/admin/auth/admin_login_screen.dart — Admin login UI (email/password, error display, localized)
- [x] Create lib/features/admin/dashboard/admin_dashboard_screen.dart — Shell with AppBar, Drawer, avatar popup
- [x] Create lib/features/admin/dashboard/admin_sidebar.dart — Permission-filtered nav drawer with logout confirm
- [x] Create lib/features/admin/dashboard/admin_home_tab.dart — Overview: stats grid + permissions chip list
- [x] Create lib/features/admin/shared/admin_access_denied_screen.dart — 403 screen with dashboard/logout actions
- [x] Modify lib/router.dart — 12 admin routes + guard (unauthenticated → /admin/login)
- [x] Modify lib/core/localization/app_localizations.dart — admin keys added to abstract class
- [x] Modify lib/core/localization/l10n/app_localizations_en.dart — EN admin strings
- [x] Modify lib/core/localization/l10n/app_localizations_ar.dart — AR admin strings

## Verification
- [x] Backend endpoints compile and function — `python -c "import main"` → Backend imports OK
- [x] Admin login works — POST /admin/auth/login with email+password, returns access+refresh tokens
- [x] Disabled admin blocked — is_active=False → 403 ADMIN_DISABLED before token issued
- [x] RBAC permission checks work — require_permission() queries role→permission chain per request
- [x] Admin route guard works — GoRouter redirect checks adminAuthProvider state, redirects to /admin/login
- [x] Sidebar respects permissions — _SidebarItem.requiredPermission filters nav items via hasPermission()
- [x] flutter analyze passes — 0 admin-specific errors (6 pre-existing errors in unrelated files)
- [x] context.mounted fix applied — admin_dashboard_screen.dart logout handler uses context.mounted

## Phase 2 Next Steps
- [ ] Admin user management screens (list/ban/edit parent accounts)
- [ ] Admin child management screens
- [ ] Content moderation screens
- [ ] Analytics/reports screens
- [ ] Support ticket management screens
- [ ] Subscription override screens
- [ ] Audit log viewer
- [ ] Admin account management (create/disable admins)
- [ ] Pagination + search for all list screens
