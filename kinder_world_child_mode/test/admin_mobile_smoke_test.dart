import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/core/models/admin_child_record.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
import 'package:kinder_world/core/models/admin_rbac_models.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
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
  _FakeAdminAuthRepository(this.admin)
      : super(
          network: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          storage: _TestSecureStorage(),
        );

  final AdminUser admin;

  @override
  Future<AdminUser?> restoreSession() async => admin;

  @override
  Future<AdminAuthResult> getMe() async => AdminAuthResult.ok(admin: admin);
}

class _FakeAdminManagementRepository extends AdminManagementRepository {
  _FakeAdminManagementRepository()
      : super(
          network: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          storage: _TestSecureStorage(),
        );

  @override
  Future<AdminPagedResponse<AdminParentUser>> fetchUsers({
    String search = '',
    String status = 'all',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminChildRecord>> fetchChildren({
    String parentId = '',
    String age = '',
    bool? active,
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminAuditLog>> fetchAuditLogs({
    String adminId = '',
    String action = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminSupportTicket>> fetchSupportTickets({
    String status = '',
    String category = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminSubscriptionRecord>> fetchSubscriptions({
    String search = '',
    String status = '',
    String plan = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminCmsContent>> fetchContents({
    String search = '',
    String status = '',
    int? categoryId,
    String contentType = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<List<AdminCmsCategory>> fetchCategories() async => const [];

  @override
  Future<AdminPagedResponse<AdminCmsQuiz>> fetchQuizzes({
    String status = '',
    int? categoryId,
    int? contentId,
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminUser>> fetchAdminUsers({
    String search = '',
    String status = 'all',
    int page = 1,
  }) async {
    return const AdminPagedResponse(items: [], pagination: {});
  }

  @override
  Future<List<AdminRoleRecord>> fetchRoles() async => const [];

  @override
  Future<AdminPermissionsPayload> fetchPermissions() async {
    return const AdminPermissionsPayload(items: [], groups: {});
  }

  @override
  Future<AdminAnalyticsOverview> fetchAnalyticsOverview() async {
    return const AdminAnalyticsOverview(
      kpis: {},
      subscriptionsByPlan: {},
      paidSubscriptions: 0,
      freeSubscriptions: 0,
      usageSummary: {},
      recentTickets: [],
    );
  }

  @override
  Future<AdminAnalyticsUsage> fetchAnalyticsUsage(String range) async {
    return AdminAnalyticsUsage(
      range: range,
      points: const [],
    );
  }

  @override
  Future<AdminSystemSettingsPayload> fetchAdminSettings() async {
    return const AdminSystemSettingsPayload(
      settings: {},
      effective: {},
    );
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
    'admin.content.view',
    'admin.content.create',
    'admin.content.edit',
    'admin.content.delete',
    'admin.content.publish',
    'admin.analytics.view',
    'admin.support.view',
    'admin.subscription.view',
    'admin.admins.manage',
    'admin.audit.view',
    'admin.settings.edit',
  ],
);

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required String route,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(const Size(360, 780));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(_TestSecureStorage()),
        loggerProvider.overrideWithValue(Logger()),
        adminAuthRepositoryProvider.overrideWithValue(
          _FakeAdminAuthRepository(_superAdmin),
        ),
        adminManagementRepositoryProvider.overrideWithValue(
          _FakeAdminManagementRepository(),
        ),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityResult.wifi),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        home: Scaffold(
          body: SizedBox.expand(
            child: AdminDashboardScreen(activePath: route),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void _expectNoFrameworkException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception is FlutterError) {
    debugPrint(exception.toStringDeep());
  }
  expect(exception, isNull);
}

void main() {
  testWidgets('admin dashboard home renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminDashboard);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.textContaining('Admin Dashboard'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin content screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminContent);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Content management'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin admins screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminAdmins);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Admin management'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin users screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminUsers);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Users management'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin children screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminChildren);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Children management'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin support screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminSupport);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Support tickets'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin subscriptions screen renders on mobile width',
      (tester) async {
    await _pumpDashboard(tester, route: Routes.adminSubscriptions);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin audit screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminAudit);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Audit logs'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin reports screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminReports);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Analytics overview'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });

  testWidgets('admin settings screen renders on mobile width', (tester) async {
    await _pumpDashboard(tester, route: Routes.adminSettings);

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('System settings'), findsOneWidget);
    _expectNoFrameworkException(tester);
  });
}
