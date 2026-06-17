import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/core/models/admin_cms_models.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/dashboard/admin_home_tab.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getChildSession() async => null;
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
  Future<AdminAnalyticsOverview> fetchAnalyticsOverview() async {
    return const AdminAnalyticsOverview(
      kpis: {
        'total_users': 12,
        'active_children': 7,
        'open_tickets': 1,
      },
      subscriptionsByPlan: {},
      paidSubscriptions: 2,
      freeSubscriptions: 10,
      usageSummary: {},
      recentTickets: [],
    );
  }

  @override
  Future<AdminPagedResponse<AdminAuditLog>> fetchAuditLogs({
    String adminId = '',
    String action = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse<AdminAuditLog>(items: [], pagination: {});
  }

  @override
  Future<AdminPagedResponse<AdminSupportTicket>> fetchSupportTickets({
    String status = 'all',
    String category = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse<AdminSupportTicket>(
      items: [],
      pagination: {},
    );
  }

  @override
  Future<AdminPagedResponse<AdminSubscriptionRecord>> fetchSubscriptions({
    String search = '',
    String status = '',
    String plan = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse<AdminSubscriptionRecord>(
      items: [],
      pagination: {},
    );
  }

  @override
  Future<AdminPagedResponse<AdminCmsContent>> fetchContents({
    String search = '',
    String status = 'all',
    int? categoryId,
    String axisKey = '',
    String contentType = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse<AdminCmsContent>(
      items: [],
      pagination: {},
    );
  }
}

void main() {
  testWidgets('admin home tab renders overview content',
      (WidgetTester tester) async {
    const admin = AdminUser(
      id: 1,
      email: 'admin@kinderworld.app',
      name: 'Super Admin',
      isActive: true,
      roles: ['super_admin'],
      permissions: [
        'admin.users.view',
        'admin.children.view',
        'admin.content.view',
        'admin.analytics.view',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAdminProvider.overrideWithValue(admin),
          adminManagementRepositoryProvider
              .overrideWithValue(_FakeAdminManagementRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en'),
            Locale('ar'),
          ],
          home: Scaffold(
            body: AdminHomeTab(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Content'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
    expect(find.text('Your permissions'), findsOneWidget);
  });
}
