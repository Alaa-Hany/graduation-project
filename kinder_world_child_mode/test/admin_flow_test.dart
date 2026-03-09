import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/features/admin/auth/admin_login_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getChildSession() async => null;
}

class _FakeAdminAuthRepository extends AdminAuthRepository {
  _FakeAdminAuthRepository({
    this.restoredAdmin,
    this.restoreDelay = Duration.zero,
    this.loginAdmin,
  }) : super(
          network: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          storage: _TestSecureStorage(),
        );

  final AdminUser? restoredAdmin;
  final Duration restoreDelay;
  final AdminUser? loginAdmin;

  bool logoutCalled = false;
  String? lastLoginEmail;
  String? lastLoginPassword;

  @override
  Future<AdminUser?> restoreSession() async {
    if (restoreDelay > Duration.zero) {
      await Future<void>.delayed(restoreDelay);
    }
    return restoredAdmin;
  }

  @override
  Future<AdminAuthResult> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    return AdminAuthResult.ok(
        admin: loginAdmin ?? restoredAdmin ?? _superAdmin);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AdminAuthResult> getMe() async {
    return AdminAuthResult.ok(
        admin: restoredAdmin ?? loginAdmin ?? _superAdmin);
  }
}

const _superAdmin = AdminUser(
  id: 1,
  email: 'admin@kinderworld.app',
  name: 'Super Admin',
  isActive: true,
  roles: ['super_admin'],
  permissions: [
    'admin.users.view',
    'admin.children.view',
    'admin.content.create',
    'admin.reports.view',
    'admin.support.view',
    'admin.subscription.view',
    'admin.admins.manage',
    'admin.audit.view',
    'admin.settings.edit',
  ],
);

const _supportAdmin = AdminUser(
  id: 2,
  email: 'support@kinderworld.app',
  name: 'Support Admin',
  isActive: true,
  roles: ['support_admin'],
  permissions: [
    'admin.support.view',
  ],
);

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  _FakeAdminAuthRepository? repo,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(_TestSecureStorage()),
      loggerProvider.overrideWithValue(Logger()),
      adminAuthRepositoryProvider.overrideWithValue(
        repo ?? _FakeAdminAuthRepository(),
      ),
      connectivityProvider
          .overrideWith((ref) => Stream.value(ConnectivityResult.wifi)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const KinderWorldApp(),
    ),
  );

  return container;
}

void main() {
  testWidgets('admin login screen renders and submits successfully', (
    WidgetTester tester,
  ) async {
    final repo = _FakeAdminAuthRepository(loginAdmin: _superAdmin);
    final container = await _pumpApp(tester, repo: repo);
    final router = container.read(routerProvider);

    router.go(Routes.adminLogin);
    await tester.pumpAndSettle();

    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.text('Admin Portal'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'admin@kinderworld.app');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123456');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(repo.lastLoginEmail, 'admin@kinderworld.app');
    expect(repo.lastLoginPassword, 'Admin@123456');
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets('unauthenticated admin route redirects to admin login', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      repo: _FakeAdminAuthRepository(restoredAdmin: null),
    );
    final router = container.read(routerProvider);

    router.go(Routes.adminDashboard);
    await tester.pumpAndSettle();

    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(
        router.routerDelegate.currentConfiguration.uri.path, Routes.adminLogin);
  });

  testWidgets('restored admin session returns to dashboard after restart flow',
      (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      repo: _FakeAdminAuthRepository(
        restoredAdmin: _superAdmin,
        restoreDelay: const Duration(milliseconds: 10),
      ),
    );
    final router = container.read(routerProvider);

    router.go(Routes.adminDashboard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path,
        Routes.adminDashboard);
  });

  testWidgets('admin dashboard shell renders for authenticated admin', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      repo: _FakeAdminAuthRepository(restoredAdmin: _superAdmin),
    );
    final router = container.read(routerProvider);

    router.go(Routes.adminDashboard);
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsWidgets);
    expect(find.textContaining('Welcome back'), findsOneWidget);
  });

  testWidgets('sidebar visibility respects admin permissions', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      repo: _FakeAdminAuthRepository(restoredAdmin: _supportAdmin),
    );
    final router = container.read(routerProvider);

    router.go(Routes.adminDashboard);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    final drawerFinder = find.byType(Drawer);

    expect(
      find.descendant(of: drawerFinder, matching: find.text('Overview')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawerFinder, matching: find.text('Support')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawerFinder, matching: find.text('Users')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawerFinder, matching: find.text('Subscriptions')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawerFinder, matching: find.text('Audit Log')),
      findsNothing,
    );
  });

  testWidgets('logout flow redirects to admin login', (
    WidgetTester tester,
  ) async {
    final repo = _FakeAdminAuthRepository(restoredAdmin: _superAdmin);
    final container = await _pumpApp(tester, repo: repo);
    final router = container.read(routerProvider);

    router.go(Routes.adminDashboard);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(repo.logoutCalled, isTrue);
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(
        router.routerDelegate.currentConfiguration.uri.path, Routes.adminLogin);
  });
}
