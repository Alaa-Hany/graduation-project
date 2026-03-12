import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/ai_buddy/ai_buddy_screen.dart';

Future<void> _pumpAiBuddy(WidgetTester tester) async {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('A RenderFlex overflowed')) {
      return;
    }
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final child = ChildProfile(
    id: 'child-1',
    name: 'Lina',
    age: 7,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math', 'stories'],
    level: 2,
    xp: 150,
    streak: 2,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: 25,
    activitiesCompleted: 4,
    avatarPath: 'assets/images/avatars/av1.png',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentChildProvider.overrideWithValue(child),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
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
        home: const AiBuddyScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('AI Buddy renders welcome state and quick actions',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiBuddyScreen)),
    )!;

    expect(find.text(l10n.aiWelcomeGreeting), findsOneWidget);
    expect(find.text(l10n.aiBuddyName), findsOneWidget);
    expect(find.text(l10n.quickActions), findsOneWidget);
    expect(find.text(l10n.recommendLesson), findsOneWidget);
    expect(find.text(l10n.suggestGame), findsOneWidget);
  });

  testWidgets('quick action adds the current canned response immediately',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiBuddyScreen)),
    )!;

    await tester.tap(find.text(l10n.recommendLesson));
    await tester.pump();

    expect(find.text(l10n.aiQuickActionLessonResponse), findsOneWidget);
  });

  testWidgets('sending a math message shows typing then simulated math reply',
      (WidgetTester tester) async {
    await _pumpAiBuddy(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiBuddyScreen)),
    )!;

    await tester.enterText(find.byType(TextField), 'math game');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('math game'), findsOneWidget);
    expect(find.byType(TypingDotsIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();

    expect(find.byType(TypingDotsIndicator), findsNothing);
    expect(find.text(l10n.aiMathResponse), findsOneWidget);
  });
}
