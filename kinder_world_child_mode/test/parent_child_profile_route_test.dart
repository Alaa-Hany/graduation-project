import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/parent_mode/child_management/parent_child_profile_screen.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';

final _testChild = ChildProfile(
  id: 'child-1',
  name: 'Nour',
  age: 9,
  avatar: 'assets/images/avatars/av1.png',
  interests: ['Math', 'Art'],
  level: 3,
  xp: 2450,
  streak: 5,
  favorites: ['lesson-1'],
  parentId: 'parent-1',
  parentEmail: 'parent@example.com',
  picturePassword: ['cat', 'dog', 'apple'],
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 2),
  totalTimeSpent: 120,
  activitiesCompleted: 14,
  avatarPath: 'assets/images/avatars/av1.png',
);

class _NoopBox implements Box<dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChildRepository extends ChildRepository {
  _FakeChildRepository(this.child)
      : super(
          childBox: _NoopBox(),
          logger: Logger(),
        );

  final ChildProfile? child;

  @override
  Future<ChildProfile?> getChildProfile(String childId) async {
    if (child?.id == childId) {
      return child;
    }
    return null;
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: Routes.parentChildManagement,
    routes: [
      GoRoute(
        path: Routes.parentChildManagement,
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: Routes.parentReports,
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '${Routes.parentChildProfile}/:childId',
        builder: (context, state) => ParentChildProfileScreen(
          childId: state.pathParameters['childId']!,
          initialChild:
              state.extra is ChildProfile ? state.extra as ChildProfile : null,
        ),
      ),
    ],
  );
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required ChildRepository repository,
}) async {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = _buildRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        childRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
        routerConfig: router,
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
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('parent child profile route opens with path id and extra child',
      (WidgetTester tester) async {
    final router = await _pumpApp(
      tester,
      repository: _FakeChildRepository(null),
    );

    router.go(
      Routes.parentChildProfileById(_testChild.id),
      extra: _testChild,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nour'), findsWidgets);
    expect(find.textContaining('Level 3'), findsOneWidget);
  });

  testWidgets(
      'parent child profile route loads child from repository without extra',
      (WidgetTester tester) async {
    final router = await _pumpApp(
      tester,
      repository: _FakeChildRepository(_testChild),
    );

    router.go(Routes.parentChildProfileById(_testChild.id));
    await tester.pumpAndSettle();

    expect(find.text('Nour'), findsWidgets);
    expect(find.textContaining('120m'), findsOneWidget);
  });
}
