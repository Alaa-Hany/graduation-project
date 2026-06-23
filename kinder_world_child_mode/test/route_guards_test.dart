// Tests for routing/route_guards.dart
//
// Covers:
//  - Pure helper functions: isPublicRoute, isAdminRoute, isAnyChildRoute,
//    isAnyParentRoute, isParentAuthRoute, isParentPinProtectedRoute,
//    requiredAdminPermissionForPath
//  - appRedirect redirect behaviour via the full router + KinderWorldApp:
//    unauthenticated, authenticated parent (with/without PIN), child,
//    maintenance mode.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/maintenance_mode_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/routing/route_guards.dart';
import 'package:kinder_world/routing/route_paths.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/test_admin_auth_helpers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeStorage extends SecureStorage {
  _FakeStorage({
    this.authToken,
    this.userRole,
    this.childSession,
    this.parentPinVerified = false,
  });

  final String? authToken;
  final String? userRole;
  final String? childSession;
  final bool parentPinVerified;

  @override
  bool get hasCachedSessionSnapshot => true;

  @override
  SecureSessionSnapshot get cachedSessionSnapshot => SecureSessionSnapshot(
        authToken: authToken,
        userRole: userRole,
        childSession: childSession,
        parentPinVerified: parentPinVerified,
      );

  @override
  Future<String?> getAuthToken() async => authToken;
  @override
  Future<String?> getUserRole() async => userRole;
  @override
  Future<String?> getChildSession() async => childSession;
  @override
  Future<bool> isParentPinVerified() async => parentPinVerified;
  @override
  Future<bool> clearParentPinVerification() async => true;
}

final _testRefProvider = Provider<Ref>((ref) => ref);
Ref _testRef() => ProviderContainer().read(_testRefProvider);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(SecureStorage storage)
      : super(
          secureStorage: storage,
          authApi: AuthApi(
            NetworkService(secureStorage: storage, logger: Logger()),
          ),
          logger: Logger(),
          ref: _testRef(),
        );

  @override
  Future<void> clearParentPinVerification() async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<User?> getCurrentUser() async => null;
}

class _FakeAdminAuthRepository extends AdminAuthRepository {
  _FakeAdminAuthRepository()
      : super(
          adminApi: AdminApi(
            NetworkService(
              secureStorage: _FakeStorage(),
              logger: Logger(),
            ),
          ),
          storage: _FakeStorage(),
        );

  @override
  Future<bool> canBootstrap() async => false;

  @override
  Future<AdminUser?> restoreSession() async => null;
}

// ---------------------------------------------------------------------------
// KinderWorldApp pump helper (mirrors startup_and_mode_entry_test.dart)
// ---------------------------------------------------------------------------

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required _FakeStorage storage,
  bool maintenanceMode = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeAuthRepository(storage);

  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      loggerProvider.overrideWithValue(Logger()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
      adminAuthRepositoryProvider.overrideWithValue(_FakeAdminAuthRepository()),
      connectivityProvider.overrideWith(
        (ref) => Stream.value(ConnectivityResult.wifi),
      ),
      // Override adminAuthProvider with a mock that doesn't make HTTP calls
      ...createMockAdminAuthOverrides(),
    ],
  );
  addTearDown(container.dispose);

  if (maintenanceMode) {
    container
        .read(maintenanceModeControllerProvider.notifier)
        .setMaintenanceMode(true);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const KinderWorldApp(),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

// ---------------------------------------------------------------------------
// Pure-function tests — no widget tree required
// ---------------------------------------------------------------------------

void main() {
  // ── isPublicRoute ──────────────────────────────────────────────────────────
  group('isPublicRoute', () {
    test('splash', () => expect(isPublicRoute(Routes.splash), isTrue));
    test('welcome', () => expect(isPublicRoute(Routes.welcome), isTrue));
    test('select-user-type',
        () => expect(isPublicRoute(Routes.selectUserType), isTrue));
    test('language', () => expect(isPublicRoute(Routes.language), isTrue));
    test('onboarding', () => expect(isPublicRoute(Routes.onboarding), isTrue));
    test('parentForgotPassword',
        () => expect(isPublicRoute(Routes.parentForgotPassword), isTrue));
    test('childForgotPassword',
        () => expect(isPublicRoute(Routes.childForgotPassword), isTrue));
    test('error', () => expect(isPublicRoute(Routes.error), isTrue));
    test('maintenance',
        () => expect(isPublicRoute(Routes.maintenance), isTrue));
    test('no-internet',
        () => expect(isPublicRoute(Routes.noInternet), isTrue));

    test('parent dashboard is NOT public',
        () => expect(isPublicRoute(Routes.parentDashboard), isFalse));
    test('child home is NOT public',
        () => expect(isPublicRoute(Routes.childHome), isFalse));
    test('admin dashboard is NOT public',
        () => expect(isPublicRoute(Routes.adminDashboard), isFalse));
    test('parentLogin is NOT public',
        () => expect(isPublicRoute(Routes.parentLogin), isFalse));
  });

  // ── isAdminRoute ───────────────────────────────────────────────────────────
  group('isAdminRoute', () {
    test('/admin/login', () => expect(isAdminRoute(Routes.adminLogin), isTrue));
    test('/admin/dashboard',
        () => expect(isAdminRoute(Routes.adminDashboard), isTrue));
    test('/admin/users/123',
        () => expect(isAdminRoute('/admin/users/123'), isTrue));
    test('/parent/dashboard is not admin',
        () => expect(isAdminRoute(Routes.parentDashboard), isFalse));
    test('/child/home is not admin',
        () => expect(isAdminRoute(Routes.childHome), isFalse));
    test('/welcome is not admin',
        () => expect(isAdminRoute(Routes.welcome), isFalse));
  });

  // ── isAnyChildRoute ────────────────────────────────────────────────────────
  group('isAnyChildRoute', () {
    test('/child/home', () => expect(isAnyChildRoute(Routes.childHome), isTrue));
    test('/child/login', () => expect(isAnyChildRoute(Routes.childLogin), isTrue));
    test('/child/learn/math',
        () => expect(isAnyChildRoute('/child/learn/math'), isTrue));
    test('/parent/dashboard is not child',
        () => expect(isAnyChildRoute(Routes.parentDashboard), isFalse));
    test('/admin/dashboard is not child',
        () => expect(isAnyChildRoute(Routes.adminDashboard), isFalse));
  });

  // ── isAnyParentRoute ───────────────────────────────────────────────────────
  group('isAnyParentRoute', () {
    test('/parent/dashboard',
        () => expect(isAnyParentRoute(Routes.parentDashboard), isTrue));
    test('/parent/settings',
        () => expect(isAnyParentRoute(Routes.parentSettings), isTrue));
    test('/parent/login',
        () => expect(isAnyParentRoute(Routes.parentLogin), isTrue));
    test('/child/home is not parent',
        () => expect(isAnyParentRoute(Routes.childHome), isFalse));
    test('/admin/dashboard is not parent',
        () => expect(isAnyParentRoute(Routes.adminDashboard), isFalse));
  });

  // ── isParentAuthRoute ─────────────────────────────────────────────────────
  group('isParentAuthRoute', () {
    test('parentLogin',
        () => expect(isParentAuthRoute(Routes.parentLogin), isTrue));
    test('parentRegister',
        () => expect(isParentAuthRoute(Routes.parentRegister), isTrue));
    test('parentVerifyEmail',
        () => expect(isParentAuthRoute(Routes.parentVerifyEmail), isTrue));
    test('parentDashboard is NOT a parent auth route',
        () => expect(isParentAuthRoute(Routes.parentDashboard), isFalse));
    test('parentForgotPassword is NOT a parent auth route',
        () => expect(isParentAuthRoute(Routes.parentForgotPassword), isFalse));
  });

  // ── isParentPinProtectedRoute ─────────────────────────────────────────────
  group('isParentPinProtectedRoute', () {
    test('parentDashboard is pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentDashboard), isTrue));
    test('parentSettings is pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentSettings), isTrue));
    test('parentChildManagement is pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentChildManagement), isTrue));
    test('parentReports is pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentReports), isTrue));

    test('parentPin route itself is NOT pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentPin), isFalse));
    test('parentLogin is NOT pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentLogin), isFalse));
    test('parentRegister is NOT pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentRegister), isFalse));
    test('parentForgotPassword is NOT pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.parentForgotPassword), isFalse));
    test('childHome is NOT parent-pin-protected',
        () => expect(isParentPinProtectedRoute(Routes.childHome), isFalse));
  });

  // ── requiredAdminPermissionForPath ────────────────────────────────────────
  group('requiredAdminPermissionForPath', () {
    test('adminUsers → admin.users.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminUsers), 'admin.users.view'));
    test('adminChildren → admin.children.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminChildren), 'admin.children.view'));
    test('adminContent → admin.content.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminContent), 'admin.content.view'));
    test('adminReports → admin.analytics.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminReports), 'admin.analytics.view'));
    test('adminSupport → admin.support.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminSupport), 'admin.support.view'));
    test('adminSubscriptions → admin.subscription.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminSubscriptions), 'admin.subscription.view'));
    test('adminAdmins → admin.admins.manage',
        () => expect(requiredAdminPermissionForPath(Routes.adminAdmins), 'admin.admins.manage'));
    test('adminAudit → admin.audit.view',
        () => expect(requiredAdminPermissionForPath(Routes.adminAudit), 'admin.audit.view'));
    test('adminSettings → admin.settings.edit',
        () => expect(requiredAdminPermissionForPath(Routes.adminSettings), 'admin.settings.edit'));
    test('adminDashboard has no permission requirement',
        () => expect(requiredAdminPermissionForPath(Routes.adminDashboard), isNull));
    test('adminLogin has no permission requirement',
        () => expect(requiredAdminPermissionForPath(Routes.adminLogin), isNull));
    test('nested users path → admin.users.view',
        () => expect(requiredAdminPermissionForPath('${Routes.adminUsers}/user-1'), 'admin.users.view'));
    test('nested children path → admin.children.view',
        () => expect(requiredAdminPermissionForPath('${Routes.adminChildren}/child-1'), 'admin.children.view'));
  });

  // ── appRedirect integration — smoke tests via KinderWorldApp ─────────────
  group('appRedirect integration smoke tests', () {
    testWidgets(
        'unauthenticated cold start: no exception and router handles redirect',
        (tester) async {
      await _pumpApp(tester, storage: _FakeStorage());
      await _pumpPastSplash(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'authenticated parent with PIN verified: no exception',
        (tester) async {
      await _pumpApp(
        tester,
        storage: _FakeStorage(
          authToken: 'parent.jwt',
          userRole: 'parent',
          parentPinVerified: true,
        ),
      );
      await _pumpPastSplash(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'authenticated parent without PIN: no exception',
        (tester) async {
      await _pumpApp(
        tester,
        storage: _FakeStorage(
          authToken: 'parent.jwt',
          userRole: 'parent',
          parentPinVerified: false,
        ),
      );
      await _pumpPastSplash(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('authenticated child without session: no exception',
        (tester) async {
      await _pumpApp(
        tester,
        storage: _FakeStorage(
          authToken: 'child.jwt',
          userRole: 'child',
          childSession: null,
        ),
      );
      await _pumpPastSplash(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('maintenance mode enabled: no exception', (tester) async {
      await _pumpApp(
        tester,
        storage: _FakeStorage(
          authToken: 'parent.jwt',
          userRole: 'parent',
          parentPinVerified: true,
        ),
        maintenanceMode: true,
      );
      // Use bounded pumps instead of pumpAndSettle: MaintenanceScreen has a
      // repeating AnimationController that never settles, so pumpAndSettle
      // would time out.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
