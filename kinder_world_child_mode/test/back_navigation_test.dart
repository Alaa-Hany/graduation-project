import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {}

class _FakeAdminAuthRepository extends AdminAuthRepository {
  _FakeAdminAuthRepository({
    this.restoredAdmin,
  }) : super(
          network: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          storage: _TestSecureStorage(),
        );

  final AdminUser? restoredAdmin;

  bool logoutCalled = false;

  @override
  Future<AdminUser?> restoreSession() async => restoredAdmin;

  @override
  Future<AdminAuthResult> login({
    required String email,
    required String password,
  }) async {
    return AdminAuthResult.ok(admin: restoredAdmin ?? _superAdmin);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<AdminAuthResult> getMe() async {
    return AdminAuthResult.ok(admin: restoredAdmin ?? _superAdmin);
  }
}

const _superAdmin = AdminUser(
  id: 1,
  email: 'admin@kinderworld.app',
  name: 'Super Admin',
  isActive: true,
  roles: ['super_admin'],
  permissions: ['admin.users.view'],
);

class _RouteScreen extends ConsumerWidget {
  const _RouteScreen({
    required this.label,
    this.backFallback,
    this.showLogout = false,
  });

  final String label;
  final String? backFallback;
  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('back-button'),
          onPressed: () => context.appBack(fallback: backFallback),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(label),
        actions: [
          if (showLogout)
            TextButton(
              key: const Key('logout-button'),
              onPressed: () async {
                await ref.read(adminAuthProvider.notifier).logout();
                if (context.mounted) {
                  context.go(Routes.adminLogin);
                }
              },
              child: const Text('Logout'),
            ),
        ],
      ),
      body: Center(
        child: Text(label, key: Key('screen-$label')),
      ),
    );
  }
}

Future<({ProviderContainer container, GoRouter router})> _pumpHarness(
  WidgetTester tester, {
  required String initialLocation,
  _FakeAdminAuthRepository? adminRepo,
}) async {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_TestSecureStorage()),
      loggerProvider.overrideWithValue(Logger()),
      adminAuthRepositoryProvider.overrideWithValue(
        adminRepo ?? _FakeAdminAuthRepository(restoredAdmin: _superAdmin),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const _RouteScreen(label: 'welcome'),
      ),
      GoRoute(
        path: Routes.selectUserType,
        builder: (_, __) => const _RouteScreen(label: 'select-user-type'),
      ),
      GoRoute(
        path: Routes.adminLogin,
        builder: (_, __) => const _RouteScreen(
          label: 'admin-login',
          backFallback: Routes.selectUserType,
        ),
      ),
      GoRoute(
        path: Routes.adminDashboard,
        builder: (_, __) => const _RouteScreen(
          label: 'admin-dashboard',
          backFallback: Routes.selectUserType,
          showLogout: true,
        ),
      ),
      GoRoute(
        path: Routes.adminUsers,
        builder: (_, __) => const _RouteScreen(
          label: 'admin-users',
          backFallback: Routes.adminDashboard,
          showLogout: true,
        ),
      ),
      GoRoute(
        path: Routes.parentDashboard,
        builder: (_, __) => const _RouteScreen(label: 'parent-dashboard'),
      ),
      GoRoute(
        path: Routes.parentSettings,
        builder: (_, __) => const _RouteScreen(
          label: 'parent-settings',
          backFallback: Routes.parentDashboard,
        ),
      ),
      GoRoute(
        path: Routes.childHome,
        builder: (_, __) => const _RouteScreen(label: 'child-home'),
      ),
      GoRoute(
        path: Routes.childLearn,
        builder: (_, __) => const _RouteScreen(label: 'child-learn'),
        routes: [
          GoRoute(
            path: 'subject/:subject',
            builder: (_, state) => const _RouteScreen(
              label: 'child-subject',
              backFallback: Routes.childLearn,
            ),
          ),
        ],
      ),
    ],
  );

  container.read(appNavigationControllerProvider).attach(router);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) {
          return AppNavigationBackHandler(child: child!);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (container: container, router: router);
}

Future<void> _triggerBackHandler(
  WidgetTester tester,
  ProviderContainer container,
  String screenLabel,
  String fallback,
) async {
  final context = tester.element(find.byKey(Key('screen-$screenLabel')));
  await container
      .read(appNavigationControllerProvider)
      .handleBack(context, fallback: fallback);
  await tester.pumpAndSettle();
}

Future<void> _tapBackButton(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('back-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('back from admin users returns to admin dashboard', (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.adminUsers,
    );

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.adminDashboard,
    );
    expect(find.byKey(const Key('screen-admin-dashboard')), findsOneWidget);
  });

  testWidgets(
      'back prefers previous in-app route before falling back to section root',
      (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.adminDashboard,
    );

    result.router.go(Routes.adminUsers);
    await tester.pumpAndSettle();

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.adminDashboard,
    );
    expect(find.byKey(const Key('screen-admin-dashboard')), findsOneWidget);
  });

  testWidgets('back from admin dashboard returns to select user type', (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.adminDashboard,
    );

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.selectUserType,
    );
    expect(find.byKey(const Key('screen-select-user-type')), findsOneWidget);
  });

  testWidgets(
      'system back handler does not exit directly when no history exists', (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.selectUserType,
    );

    await _triggerBackHandler(
      tester,
      result.container,
      'select-user-type',
      Routes.welcome,
    );

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.welcome,
    );
    expect(find.byKey(const Key('screen-welcome')), findsOneWidget);
  });

  testWidgets('parent flow back falls back to parent dashboard', (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.parentSettings,
    );

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.parentDashboard,
    );
    expect(find.byKey(const Key('screen-parent-dashboard')), findsOneWidget);
  });

  testWidgets('child nested route back falls back to child learn', (
    WidgetTester tester,
  ) async {
    final result = await _pumpHarness(
      tester,
      initialLocation: '${Routes.childLearn}/subject/math',
    );

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.childLearn,
    );
    expect(find.byKey(const Key('screen-child-learn')), findsOneWidget);
  });

  testWidgets(
      'logout clears history and blocks back navigation to admin routes', (
    WidgetTester tester,
  ) async {
    final repo = _FakeAdminAuthRepository(restoredAdmin: _superAdmin);
    final result = await _pumpHarness(
      tester,
      initialLocation: Routes.adminUsers,
      adminRepo: repo,
    );

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(repo.logoutCalled, isTrue);
    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.adminLogin,
    );

    await _tapBackButton(tester);

    expect(
      result.router.routerDelegate.currentConfiguration.uri.path,
      Routes.selectUserType,
    );
    expect(find.byKey(const Key('screen-select-user-type')), findsOneWidget);
  });
}
