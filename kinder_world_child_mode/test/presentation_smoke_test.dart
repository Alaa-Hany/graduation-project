import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/api/ai_buddy_api.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/api/children_api.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/providers/ai_buddy_provider.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/services/ai_buddy_service.dart';
import 'package:kinder_world/core/services/children_cache_service.dart';
import 'package:kinder_world/core/services/gamification_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/features/admin/auth/admin_login_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:kinder_world/features/auth/child_login_screen.dart';
import 'package:kinder_world/features/auth/parent_login_screen.dart';
import 'package:kinder_world/features/child_mode/learn/lesson_content_provider.dart';
import 'package:kinder_world/features/child_mode/learn/lesson_flow_screen.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:kinder_world/features/parent_mode/reports/report_service.dart';
import 'package:kinder_world/features/parent_mode/reports/reports_screen.dart';
import 'package:kinder_world/features/parent_mode/subscription/subscription_screen.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';

import 'support/test_harness.dart';

class _DummyBox implements Box<dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SmokeAuthRepository extends AuthRepository {
  _SmokeAuthRepository({
    required SecureStorage storage,
    this.parentLoginHandler,
    this.childLoginHandler,
  }) : super(
          secureStorage: storage,
          authApi: AuthApi(
            TestNetworkService(
              secureStorage: storage,
              logger: Logger(),
            ),
          ),
          logger: Logger(),
        );

  Future<User?> Function({
    required String email,
    required String password,
    String? twoFactorCode,
  })? parentLoginHandler;

  Future<User?> Function({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  })? childLoginHandler;

  @override
  Future<void> clearParentPinVerification() async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> loginParent({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    return parentLoginHandler!(
      email: email,
      password: password,
      twoFactorCode: twoFactorCode,
    );
  }

  @override
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    return childLoginHandler!(
      childId: childId,
      childName: childName,
      picturePassword: picturePassword,
    );
  }
}

class _MemoryChildRepository extends ChildRepository {
  _MemoryChildRepository()
      : super(
          childBox: _DummyBox(),
          logger: Logger(),
        );

  final Map<String, ChildProfile> profiles = <String, ChildProfile>{};

  @override
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<ChildProfile?> getChildProfile(String childId) async =>
      profiles[childId];

  @override
  Future<List<ChildProfile>> getChildProfilesForParent(String parentId) async {
    return profiles.values
        .where((child) => child.parentId == parentId)
        .toList(growable: false);
  }

  @override
  Future<List<ChildProfile>> getAllChildProfiles() async {
    return profiles.values.toList(growable: false);
  }

  @override
  Future<void> linkChildrenToParent({
    required String parentId,
    required String parentEmail,
  }) async {}
}

class _FakeChildrenCacheService extends ChildrenCacheService {
  _FakeChildrenCacheService({
    required this.result,
    required super.secureStorage,
    required super.cacheStore,
  }) : super(
          childRepository: _MemoryChildRepository(),
          childrenApi: ChildrenApi(
            TestNetworkService(
              secureStorage: secureStorage,
              logger: Logger(),
            ),
          ),
          logger: Logger(),
        );

  final ChildrenCacheResult result;

  @override
  Future<ChildrenCacheResult> loadChildrenForParent(
    String parentId, {
    String? parentEmail,
    bool forceRefresh = false,
  }) async {
    return result;
  }
}

class _FakeParentReportService extends ParentReportService {
  _FakeParentReportService({
    required this.result,
    required super.secureStorage,
    required super.cacheStore,
  }) : super(
          reportsApi: ReportsApi(
            TestNetworkService(
              secureStorage: secureStorage,
              logger: Logger(),
            ),
          ),
          logger: Logger(),
          loadProgressRecords: (_) async => const [],
        );

  final ChildReportLoadResult result;

  @override
  Future<ChildReportLoadResult> loadChildReport({
    required ChildProfile child,
    required ReportPeriod period,
    bool forceRefresh = false,
    bool includeAdvancedReports = true,
  }) async {
    return result;
  }
}

class _FakeAiBuddyService extends AiBuddyService {
  _FakeAiBuddyService({
    required this.summary,
    required SecureStorage storage,
  }) : super(
          api: AiBuddyApi(
            TestNetworkService(
              secureStorage: storage,
              logger: Logger(),
            ),
          ),
          secureStorage: storage,
          logger: Logger(),
        );

  final AiBuddyVisibilitySummary summary;

  @override
  Future<AiBuddyVisibilitySummary> getChildVisibilitySummary({
    required int childId,
  }) async {
    return summary;
  }
}

class _SmokeProgressController extends ProgressController {
  _SmokeProgressController({required super.childRepository})
      : super(
          progressRepository: ProgressRepository(
            progressBox: _DummyBox(),
            logger: Logger(),
          ),
          reportsApi: ReportsApi(
            TestNetworkService(
              secureStorage: TestSecureStorage(),
              logger: Logger(),
            ),
          ),
          secureStorage: TestSecureStorage(),
          logger: Logger(),
        );

  int completionCalls = 0;

  @override
  Future<ProgressRecord?> recordActivityCompletion({
    required String childId,
    required String activityId,
    required int score,
    required int duration,
    required int xpEarned,
    String? notes,
    String completionStatus = CompletionStatus.completed,
    Map<String, dynamic>? performanceMetrics,
    String? aiFeedback,
    String? moodBefore,
    String? moodAfter,
    bool? difficultyAdjusted,
    bool? helpRequested,
    bool? parentApproved,
  }) async {
    completionCalls++;
    return null;
  }
}

class _SmokeGamificationNotifier extends GamificationNotifier {
  _SmokeGamificationNotifier({required ChildRepository childRepository})
      : super(
          service: GamificationService(
            gamificationRepository: GamificationRepository(
              gamificationBox: _DummyBox(),
              logger: Logger(),
            ),
            childRepository: childRepository,
            logger: Logger(),
          ),
        );

  int activityCalls = 0;

  @override
  Future<ActivityResult> recordActivity({
    required String childId,
    required ActivityType type,
    String? category,
    int score = 0,
    bool awardXp = true,
    String? activityId,
  }) async {
    activityCalls++;
    return ActivityResult.empty(0, 1, 0);
  }
}

class _FakeAdminAuthRepository extends AdminAuthRepository {
  _FakeAdminAuthRepository({
    required super.storage,
    this.loginAdmin,
  }) : super(
          adminApi: AdminApi(
            TestNetworkService(
              secureStorage: storage,
              logger: Logger(),
            ),
          ),
        );

  final AdminUser? loginAdmin;
  String? lastLoginEmail;
  String? lastLoginPassword;

  @override
  Future<AdminUser?> restoreSession() async => loginAdmin ?? _superAdmin;

  @override
  Future<AdminAuthResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    return AdminAuthResult.ok(admin: loginAdmin ?? _superAdmin);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AdminAuthResult> getMe() async {
    return AdminAuthResult.ok(admin: loginAdmin ?? _superAdmin);
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
    'admin.support.view',
    'admin.audit.view',
  ],
);

ChildProfile _childProfile({
  required String id,
  required String parentId,
  required String name,
}) {
  final now = DateTime(2026, 3, 25, 10);
  return ChildProfile(
    id: id,
    name: name,
    age: 8,
    avatar: 'assets/images/avatars/av1.png',
    avatarPath: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: 2,
    xp: 220,
    streak: 3,
    favorites: const [],
    parentId: parentId,
    parentEmail: 'parent@example.com',
    picturePassword: const ['apple', 'cat', 'dog'],
    createdAt: now,
    updatedAt: now,
    lastSession: now,
    totalTimeSpent: 45,
    activitiesCompleted: 6,
    currentMood: 'happy',
    learningStyle: null,
    specialNeeds: null,
    accessibilityNeeds: null,
  );
}

User _parentUser() => User(
      id: 'parent-1',
      email: 'parent@example.com',
      role: UserRoles.parent,
      name: 'Presentation Parent',
      createdAt: DateTime(2026, 3, 25),
      updatedAt: DateTime(2026, 3, 25),
      isActive: true,
    );

User _childUser(String childId, String name) => User(
      id: childId,
      email: '$childId@child.local',
      role: UserRoles.child,
      name: name,
      createdAt: DateTime(2026, 3, 25),
      updatedAt: DateTime(2026, 3, 25),
      isActive: true,
    );

ChildReportLoadResult _reportResult(ChildProfile child) {
  return ChildReportLoadResult(
    report: ChildReportData(
      child: child,
      period: ReportPeriod.week,
      filteredRecords: const [],
      dailyPoints: [
        ReportDailyPoint(
          date: DateTime(2026, 3, 24),
          activitiesCompleted: 3,
          lessonsCompleted: 2,
          screenTimeMinutes: 24,
        ),
      ],
      totalActivitiesCompleted: 6,
      totalSessions: 3,
      totalLessonsCompleted: 4,
      totalScreenTimeMinutes: 45,
      averageScore: 92,
      completionRate: 0.88,
      topContentType: 'lessons',
      moodCounts: const {'happy': 2},
      currentMood: 'happy',
      achievements: const [
        ReportAchievement(
          titleKey: 'lessons',
          detail: '4',
          achieved: true,
        ),
      ],
      recentSessions: [
        ReportRecentSession(
          title: 'Alphabet Lesson',
          contentType: 'lessons',
          score: 95,
          durationMinutes: 14,
          completedAt: DateTime(2026, 3, 24, 14),
          completionStatus: 'completed',
        ),
      ],
      usesRecordedSessions: true,
    ),
    source: ChildReportSource.liveServer,
  );
}

AiBuddyVisibilitySummary _visibilitySummary(ChildProfile child) {
  return AiBuddyVisibilitySummary(
    childId: int.parse(child.id.replaceAll(RegExp(r'[^0-9]'), '')),
    childName: child.name,
    visibilityMode: 'summary_and_metrics',
    transcriptAccess: false,
    parentSummary: 'Positive and safe conversations',
    provider: const AiBuddyProviderStatus(
      configured: true,
      mode: 'online',
      status: 'ready',
      reason: null,
      providerKey: 'internal',
      model: 'test',
    ),
    retentionPolicy: const AiBuddyRetentionPolicy(
      messagesRetainedDays: 30,
      autoArchive: true,
      deleteSupported: true,
    ),
    usageMetrics: const AiBuddyUsageMetrics(
      sessionsCount: 1,
      messagesCount: 4,
      childMessagesCount: 2,
      assistantMessagesCount: 2,
      lastSessionAt: null,
      allowedCount: 2,
      refusalCount: 0,
      safeRedirectCount: 0,
    ),
    currentSession: null,
    recentFlags: const [],
  );
}

SubscriptionSnapshot _subscriptionSnapshot({
  required String planId,
  required bool hasPaidAccess,
  required String status,
  String? selectedPlanId,
  String? lastPaymentStatus,
  List<SubscriptionEventRecord>? recentEvents,
  List<BillingTransactionRecord>? billingHistory,
  List<PaymentAttemptRecord>? paymentAttempts,
}) {
  return SubscriptionSnapshot(
    planId: planId,
    currentPlanId: planId,
    limits: {
      'max_children':
          planId == 'FAMILY_PLUS' ? 9999 : (planId == 'PREMIUM' ? 3 : 1),
    },
    features: {
      'basic_reports': true,
      'advanced_reports': planId != 'FREE',
      'ai_insights': planId != 'FREE',
      'offline_downloads': planId != 'FREE',
    },
    lifecycle: SubscriptionLifecycle(
      currentPlanId: planId,
      selectedPlanId: selectedPlanId,
      status: status,
      startedAt: DateTime(2026, 3, 25, 9),
      expiresAt: null,
      cancelAt: null,
      willRenew: false,
      lastPaymentStatus:
          lastPaymentStatus ?? (hasPaidAccess ? 'succeeded' : 'not_applicable'),
      provider: 'stripe',
      isActive: hasPaidAccess,
      hasPaidAccess: hasPaidAccess,
    ),
    historySummary: const SubscriptionHistorySummary(
      eventCount: 1,
      billingTransactionCount: 1,
      paymentAttemptCount: 1,
    ),
    recentEvents: recentEvents ??
        const [
          SubscriptionEventRecord(
            id: 1,
            eventType: 'checkout_completed',
            previousPlanId: 'FREE',
            planId: 'PREMIUM',
            previousStatus: 'free',
            status: 'active',
            paymentStatus: 'succeeded',
            source: 'webhook_checkout_completed',
            details: {},
            occurredAt: null,
          ),
        ],
    billingHistory: billingHistory ??
        const [
          BillingTransactionRecord(
            id: 1,
            planId: 'PREMIUM',
            transactionType: 'activation',
            amountCents: 3900,
            currency: 'USD',
            status: 'succeeded',
            effectiveAt: null,
            metadata: {},
          ),
        ],
    paymentAttempts: paymentAttempts ??
        const [
          PaymentAttemptRecord(
            id: 1,
            planId: 'PREMIUM',
            attemptType: 'checkout',
            status: 'succeeded',
            amountCents: 3900,
            currency: 'USD',
            providerReference: 'pi_test',
            failureCode: null,
            failureMessage: null,
            requestedAt: null,
            completedAt: null,
            metadata: {},
          ),
        ],
  );
}

SubscriptionHistorySnapshot _subscriptionHistory({
  String currentPlanId = 'PREMIUM',
  String status = 'active',
  List<SubscriptionEventRecord>? events,
  List<BillingTransactionRecord>? billingTransactions,
  List<PaymentAttemptRecord>? paymentAttempts,
}) {
  return SubscriptionHistorySnapshot(
    userId: 1,
    currentPlanId: currentPlanId,
    status: status,
    events: events ??
        const [
          SubscriptionEventRecord(
            id: 1,
            eventType: 'checkout_completed',
            previousPlanId: 'FREE',
            planId: 'PREMIUM',
            previousStatus: 'free',
            status: 'active',
            paymentStatus: 'succeeded',
            source: 'webhook_checkout_completed',
            details: {},
            occurredAt: null,
          ),
        ],
    billingTransactions: billingTransactions ??
        const [
          BillingTransactionRecord(
            id: 1,
            planId: 'PREMIUM',
            transactionType: 'activation',
            amountCents: 3900,
            currency: 'USD',
            status: 'succeeded',
            effectiveAt: null,
            metadata: {},
          ),
        ],
    paymentAttempts: paymentAttempts ??
        const [
          PaymentAttemptRecord(
            id: 1,
            planId: 'PREMIUM',
            attemptType: 'checkout',
            status: 'succeeded',
            amountCents: 3900,
            currency: 'USD',
            providerReference: 'pi_test',
            failureCode: null,
            failureMessage: null,
            requestedAt: null,
            completedAt: null,
            metadata: {},
          ),
        ],
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('presentation smoke: parent login reaches dashboard',
      (tester) async {
    _setLargeViewport(tester);
    final storage = TestSecureStorage();
    final repo = _SmokeAuthRepository(
      storage: storage,
      parentLoginHandler: ({
        required email,
        required password,
        String? twoFactorCode,
      }) async {
        return _parentUser();
      },
    );
    final harness = await TestHarness.create(secureStorage: storage);
    final router = GoRouter(
      initialLocation: Routes.parentLogin,
      routes: [
        GoRoute(
          path: Routes.parentLogin,
          builder: (context, state) => const ParentLoginScreen(),
        ),
        GoRoute(
          path: Routes.parentDashboard,
          builder: (context, state) =>
              const Scaffold(body: Text('parent-dashboard')),
        ),
        GoRoute(
          path: Routes.parentForgotPassword,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: Routes.parentRegister,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

    await harness.pumpRouterApp(
      tester,
      router: router,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 400),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ParentLoginScreen)))!;
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'parent@example.com');
    await tester.enterText(fields.at(1), 'Password123!');
    await tester.tap(find.text(l10n.login));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('parent-dashboard'), findsOneWidget);
  });

  testWidgets('presentation smoke: child login reaches home', (tester) async {
    _setLargeViewport(tester);
    final storage = TestSecureStorage();
    final childRepository = _MemoryChildRepository();
    final repo = _SmokeAuthRepository(
      storage: storage,
      childLoginHandler: ({
        required childId,
        required childName,
        required picturePassword,
      }) async {
        return _childUser(childId, childName);
      },
    );
    final harness = await TestHarness.create(secureStorage: storage);
    final router = GoRouter(
      initialLocation: Routes.childLogin,
      routes: [
        GoRoute(
          path: Routes.childLogin,
          builder: (context, state) => const ChildLoginScreen(),
        ),
        GoRoute(
          path: Routes.childHome,
          builder: (context, state) => const Scaffold(body: Text('child-home')),
        ),
        GoRoute(
          path: Routes.childForgotPassword,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: Routes.selectUserType,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

    await harness.pumpRouterApp(
      tester,
      router: router,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        childRepositoryProvider.overrideWithValue(childRepository),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 400),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ChildLoginScreen)))!;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ayla');
    await tester.enterText(fields.at(1), 'child-9');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('child-home'), findsOneWidget);
    expect(storage.childSession, 'child-9');
  });

  testWidgets(
      'presentation smoke: child activity flow completes and returns home',
      (tester) async {
    _setLargeViewport(tester);
    final child = _childProfile(id: '9', parentId: 'parent-1', name: 'Ayla');
    final childRepository = _MemoryChildRepository()
      ..profiles[child.id] = child;
    final progressController =
        _SmokeProgressController(childRepository: childRepository);
    final gamificationNotifier =
        _SmokeGamificationNotifier(childRepository: childRepository);
    final harness = await TestHarness.create(
      currentChild: child,
      overrides: [
        childRepositoryProvider.overrideWithValue(childRepository),
      ],
    );

    final router = GoRouter(
      initialLocation: '${Routes.childLearn}/lesson/math_01',
      routes: [
        GoRoute(
          path: '${Routes.childLearn}/lesson/:lessonId',
          builder: (context, state) => LessonFlowScreen(
            lessonId: state.pathParameters['lessonId']!,
          ),
        ),
        GoRoute(
          path: Routes.childLearn,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: Routes.childHome,
          builder: (context, state) =>
              const Scaffold(body: Text('child-home-after-activity')),
        ),
      ],
    );

    await harness.pumpRouterApp(
      tester,
      router: router,
      overrides: [
        childRepositoryProvider.overrideWithValue(childRepository),
        progressControllerProvider.overrideWith(
          (ref) => progressController,
        ),
        gamificationStateProvider.overrideWith(
          (ref) => gamificationNotifier,
        ),
        lessonContentProvider('math_01').overrideWith(
          (ref) async => const LearnLessonContent(
            id: 'math_01',
            title: 'Counting Numbers 1-10',
            description: 'Learn to count from 1 to 10',
            content: 'Count each object carefully.',
            durationMinutes: 15,
            xpReward: 50,
            difficulty: 'beginner',
            category: 'educational',
          ),
        ),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 700),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(LessonFlowScreen)))!;

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(l10n.next).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
    }

    await tester.tap(find.text(l10n.lessonFinish).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('child-home-after-activity'), findsOneWidget);
    expect(progressController.completionCalls, 1);
    expect(gamificationNotifier.activityCalls, 1);
  });

  testWidgets('presentation smoke: reports screen renders child report',
      (tester) async {
    _setLargeViewport(tester);
    final storage = TestSecureStorage(
      userId: 'parent-1',
      userEmail: 'parent@example.com',
      authToken: 'parent-token',
    );
    final harness = await TestHarness.create(secureStorage: storage);
    final child = _childProfile(id: '7', parentId: 'parent-1', name: 'Mira');
    final cacheStore = AppCacheStore(harness.sharedPreferences);

    await harness.pumpApp(
      tester,
      home: const ReportsScreen(),
      overrides: [
        planInfoProvider
            .overrideWith((ref) async => PlanInfo.fromTier(PlanTier.premium)),
        childrenCacheServiceProvider.overrideWithValue(
          _FakeChildrenCacheService(
            result: ChildrenCacheResult(
              children: [child],
              snapshot: const CacheSnapshot(
                hasData: true,
                freshness: CacheFreshness.freshServerBacked,
                syncState: CacheSyncState.synced,
              ),
            ),
            secureStorage: storage,
            cacheStore: cacheStore,
          ),
        ),
        parentReportServiceProvider.overrideWithValue(
          _FakeParentReportService(
            result: _reportResult(child),
            secureStorage: storage,
            cacheStore: cacheStore,
          ),
        ),
        aiBuddyServiceProvider.overrideWithValue(
          _FakeAiBuddyService(
            summary: _visibilitySummary(child),
            storage: storage,
          ),
        ),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 800),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ReportsScreen)))!;
    expect(find.text(l10n.reportsAndAnalytics), findsOneWidget);
    expect(find.text(l10n.reportInsightsTitle), findsOneWidget);
    expect(find.text(l10n.reportNextStepsTitle), findsOneWidget);
    expect(find.text('Mira'), findsWidgets);
    expect(find.text('Alphabet Lesson'), findsOneWidget);
  });

  testWidgets('presentation smoke: admin login reaches dashboard shell',
      (tester) async {
    _setLargeViewport(tester);
    final storage = TestSecureStorage();
    final repo = _FakeAdminAuthRepository(
      storage: storage,
      loginAdmin: _superAdmin,
    );
    final harness = await TestHarness.create(secureStorage: storage);
    final router = GoRouter(
      initialLocation: Routes.adminLogin,
      routes: [
        GoRoute(
          path: Routes.adminLogin,
          builder: (context, state) => const AdminLoginScreen(),
        ),
        GoRoute(
          path: Routes.adminDashboard,
          builder: (context, state) =>
              const AdminDashboardScreen(activePath: Routes.adminDashboard),
        ),
        GoRoute(
          path: Routes.selectUserType,
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

    await harness.pumpRouterApp(
      tester,
      router: router,
      overrides: [
        adminAuthRepositoryProvider.overrideWithValue(repo),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 500),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(AdminLoginScreen)))!;
    await tester.enterText(
        find.byType(TextFormField).at(0), 'admin@kinderworld.app');
    await tester.enterText(find.byType(TextFormField).at(1), 'Admin@123456');
    await tester.tap(find.widgetWithText(FilledButton, l10n.adminSignIn));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets(
      'presentation smoke: subscription screen reflects one-time purchase and unlocked premium',
      (tester) async {
    _setLargeViewport(tester);
    final harness = await TestHarness.create(
      secureStorage: TestSecureStorage(
          userId: 'parent-1', userEmail: 'parent@example.com'),
    );

    await harness.pumpApp(
      tester,
      home: const SubscriptionScreen(),
      overrides: [
        subscriptionSnapshotProvider.overrideWith(
          (ref) async => _subscriptionSnapshot(
            planId: 'FREE',
            hasPaidAccess: false,
            status: 'free',
          ),
        ),
        subscriptionHistoryProvider
            .overrideWith((ref) async => _subscriptionHistory()),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 600),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(SubscriptionScreen)))!;
    expect(find.textContaining(l10n.oneTimePurchaseLabel), findsWidgets);
    expect(find.textContaining(l10n.lifetimeAccessLabel), findsWidgets);
    expect(find.text(l10n.unlockPremiumLabel), findsOneWidget);

    await harness.pumpApp(
      tester,
      home: const SubscriptionScreen(),
      overrides: [
        subscriptionSnapshotProvider.overrideWith(
          (ref) async => _subscriptionSnapshot(
            planId: 'PREMIUM',
            hasPaidAccess: true,
            status: 'active',
          ),
        ),
        subscriptionHistoryProvider
            .overrideWith((ref) async => _subscriptionHistory()),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 600),
    );

    expect(find.text(l10n.planPremium), findsWidgets);
    expect(find.textContaining(l10n.lifetimeAccessLabel), findsWidgets);
    expect(find.text(l10n.subscriptionEventsTitle), findsNothing);
    expect(find.text(l10n.subscriptionBillingHistoryTitle), findsNothing);
    expect(find.text(l10n.subscriptionPaymentAttemptsTitle), findsNothing);
  });

  testWidgets(
      'presentation smoke: subscription screen surfaces failed purchase state',
      (tester) async {
    _setLargeViewport(tester);
    final harness = await TestHarness.create(
      secureStorage: TestSecureStorage(
          userId: 'parent-1', userEmail: 'parent@example.com'),
    );

    const failedEvent = SubscriptionEventRecord(
      id: 11,
      eventType: 'checkout_failed',
      previousPlanId: 'FREE',
      planId: 'PREMIUM',
      previousStatus: 'free',
      status: 'pending_activation',
      paymentStatus: 'failed',
      source: 'parent_select',
      details: {'code': 'CARD_DECLINED'},
      occurredAt: null,
    );
    const failedAttempt = PaymentAttemptRecord(
      id: 12,
      planId: 'PREMIUM',
      attemptType: 'checkout',
      status: 'failed',
      amountCents: 3900,
      currency: 'USD',
      providerReference: 'pi_failed',
      failureCode: 'CARD_DECLINED',
      failureMessage: 'Card was declined',
      requestedAt: null,
      completedAt: null,
      metadata: {},
    );

    await harness.pumpApp(
      tester,
      home: const SubscriptionScreen(),
      overrides: [
        subscriptionSnapshotProvider.overrideWith(
          (ref) async => _subscriptionSnapshot(
            planId: 'FREE',
            hasPaidAccess: false,
            status: 'pending_activation',
            selectedPlanId: 'PREMIUM',
            lastPaymentStatus: 'failed',
            recentEvents: const [failedEvent],
            billingHistory: const [],
            paymentAttempts: const [failedAttempt],
          ),
        ),
        subscriptionHistoryProvider.overrideWith(
          (ref) async => _subscriptionHistory(
            currentPlanId: 'FREE',
            status: 'pending_activation',
            events: const [failedEvent],
            billingTransactions: const [],
            paymentAttempts: const [failedAttempt],
          ),
        ),
      ],
      surfaceSize: const Size(1400, 2400),
      settleDuration: const Duration(milliseconds: 600),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(SubscriptionScreen)))!;
    expect(find.textContaining(l10n.subscriptionStatusLabel('failed')),
        findsWidgets);
    expect(find.text(l10n.unlockPremiumLabel), findsOneWidget);
  });
}
