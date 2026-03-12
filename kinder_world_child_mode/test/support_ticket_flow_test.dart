import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/support_controller.dart';
import 'package:kinder_world/core/services/support_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/support/admin_support_tickets_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/contact_us_screen.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getChildSession() async => null;

  @override
  Future<String?> getAdminToken() async => 'admin-token';
}

class _FakeSupportService extends SupportService {
  _FakeSupportService()
      : super(
          networkService: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          logger: Logger(),
        );

  final List<SupportTicketRecord> _tickets = [
    const SupportTicketRecord(
      id: 1,
      subject: 'Need help with login',
      message: 'I cannot access my account after changing the password.',
      category: 'login_issue',
      status: 'in_progress',
      replyCount: 1,
      updatedAt: '2026-03-11T10:00:00',
      thread: [
        SupportTicketThreadEntry(
          id: 'root-1',
          message: 'I cannot access my account after changing the password.',
          authorType: 'user',
          createdAt: '2026-03-11T09:00:00',
        ),
        SupportTicketThreadEntry(
          id: '2',
          message: 'We are checking the login issue.',
          authorType: 'admin',
          createdAt: '2026-03-11T10:00:00',
        ),
      ],
    ),
  ];

  String? lastSentCategory;
  String? lastSentSubject;
  String? lastReplyMessage;

  @override
  Future<List<SupportTicketRecord>> fetchTickets() async => List.of(_tickets);

  @override
  Future<SupportTicketRecord> fetchTicketDetail(int ticketId) async {
    return _tickets.firstWhere((ticket) => ticket.id == ticketId);
  }

  @override
  Future<SupportTicketRecord> sendContactMessage({
    required String subject,
    required String message,
    required String category,
  }) async {
    lastSentCategory = category;
    lastSentSubject = subject;
    final ticket = SupportTicketRecord(
      id: _tickets.length + 1,
      subject: subject,
      message: message,
      category: category,
      status: 'open',
      replyCount: 0,
      updatedAt: '2026-03-11T12:00:00',
      thread: [
        SupportTicketThreadEntry(
          id: 'root-${_tickets.length + 1}',
          message: message,
          authorType: 'user',
          createdAt: '2026-03-11T12:00:00',
        ),
      ],
    );
    _tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<SupportTicketRecord> replyToTicket({
    required int ticketId,
    required String message,
  }) async {
    lastReplyMessage = message;
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    final current = _tickets[index];
    final updated = SupportTicketRecord(
      id: current.id,
      subject: current.subject,
      message: current.message,
      category: current.category,
      status: current.status,
      replyCount: current.replyCount + 1,
      updatedAt: '2026-03-11T12:30:00',
      thread: [
        ...current.thread,
        SupportTicketThreadEntry(
          id: 'reply-${current.replyCount + 1}',
          message: message,
          authorType: 'user',
          createdAt: '2026-03-11T12:30:00',
        ),
      ],
    );
    _tickets[index] = updated;
    return updated;
  }
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

  static const AdminSupportTicket ticket = AdminSupportTicket(
    id: 7,
    subject: 'Child content issue',
    message: 'A coloring page is not loading for my child.',
    category: 'child_content_issue',
    status: 'in_progress',
    replyCount: 1,
    requester: {'email': 'parent@example.com'},
    thread: [
      AdminSupportThreadEntry(
        id: 'root-7',
        message: 'A coloring page is not loading for my child.',
        authorType: 'user',
        createdAt: '2026-03-11T09:00:00',
      ),
    ],
  );

  bool resolveCalled = false;

  @override
  Future<AdminPagedResponse<AdminSupportTicket>> fetchSupportTickets({
    String status = '',
    String category = '',
    int page = 1,
  }) async {
    return const AdminPagedResponse(
      items: [ticket],
      pagination: {
        'page': 1,
        'total_pages': 1,
        'total': 1,
        'has_previous': false,
        'has_next': false,
      },
    );
  }

  @override
  Future<AdminSupportTicket> fetchSupportTicketDetail(int ticketId) async {
    return ticket;
  }

  @override
  Future<AdminSupportTicket> resolveSupportTicket(int ticketId) async {
    resolveCalled = true;
    return AdminSupportTicket(
      id: ticket.id,
      subject: ticket.subject,
      message: ticket.message,
      category: ticket.category,
      status: 'resolved',
      replyCount: ticket.replyCount,
      requester: ticket.requester,
      thread: ticket.thread,
    );
  }

  @override
  Future<AdminSupportTicket> assignSupportTicket(int ticketId, {int? adminUserId}) async => ticket;

  @override
  Future<AdminSupportTicket> replySupportTicket(int ticketId, String message) async => ticket;

  @override
  Future<AdminSupportTicket> closeSupportTicket(int ticketId) async => ticket;
}

Future<void> _pumpLocalizedApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('parent support screen sends categorized ticket and shows history',
      (WidgetTester tester) async {
    final supportService = _FakeSupportService();

    await _pumpLocalizedApp(
      tester,
      const ParentContactUsScreen(),
      overrides: [
        supportServiceProvider.overrideWithValue(supportService),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Your support tickets'), findsOneWidget);
    expect(find.text('Need help with login'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Billing issue').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Billing follow-up');
    await tester.enterText(
      find.byType(TextField).at(1),
      'I need help with a duplicate subscription charge.',
    );
    await tester.tap(find.text('Send Message'));
    await tester.pumpAndSettle();

    expect(supportService.lastSentCategory, 'billing_issue');
    expect(find.text('Billing follow-up'), findsOneWidget);

    final ticketFinder = find.text('Need help with login');
    await tester.ensureVisible(ticketFinder);
    await tester.tap(ticketFinder);
    await tester.pumpAndSettle();
    expect(find.text('We are checking the login issue.'), findsOneWidget);
  });

  testWidgets('admin support screen shows category and resolves ticket',
      (WidgetTester tester) async {
    final repository = _FakeAdminManagementRepository();
    const admin = AdminUser(
      id: 1,
      email: 'support@kinderworld.app',
      name: 'Support Admin',
      isActive: true,
      roles: ['support_admin'],
      permissions: ['admin.support.view', 'admin.support.reply', 'admin.support.close'],
    );

    await _pumpLocalizedApp(
      tester,
      const Scaffold(body: AdminSupportTicketsScreen()),
      overrides: [
        adminManagementRepositoryProvider.overrideWithValue(repository),
        currentAdminProvider.overrideWithValue(admin),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Support tickets'), findsOneWidget);
    expect(find.text('Child content issue'), findsWidgets);

    final resolveFinder = find.text('Resolve ticket');
    await tester.ensureVisible(resolveFinder);
    await tester.tap(resolveFinder);
    await tester.pumpAndSettle();

    expect(repository.resolveCalled, isTrue);
    expect(find.text('Ticket marked as resolved'), findsOneWidget);
  });
}
