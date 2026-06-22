// Smoke/render tests for the stateless category screens in
// learn_support_screens.dart (EntertainingScreen, BehavioralScreen,
// SkillfulScreen, EducationalScreen) and the simple prop-driven detail screens
// (ValueDetailsScreen, SkillVideoScreen). These exercise the build methods and
// their card/grid sub-widgets without touching the interactive games.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/features/child_mode/learn/learn_screen.dart';

import 'support/test_harness.dart';

ChildProfile _child() {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: 'kid-1',
    name: 'Lily',
    age: 6,
    avatar: '🦊',
    interests: const [],
    level: 2,
    xp: 120,
    streak: 3,
    favorites: const [],
    parentId: 'p1',
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create(currentChild: _child());
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await harness.pumpApp(
      tester,
      home: screen,
      surfaceSize: const Size(1200, 2000),
    );
  }

  testWidgets('EntertainingScreen renders its grid', (tester) async {
    await pump(tester, const EntertainingScreen());
    expect(find.byType(EntertainingScreen), findsOneWidget);
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('BehavioralScreen renders', (tester) async {
    await pump(tester, const BehavioralScreen());
    expect(find.byType(BehavioralScreen), findsOneWidget);
  });

  testWidgets('SkillfulScreen renders', (tester) async {
    await pump(tester, const SkillfulScreen());
    expect(find.byType(SkillfulScreen), findsOneWidget);
  });

  testWidgets('EducationalScreen renders', (tester) async {
    await pump(tester, const EducationalScreen());
    expect(find.byType(EducationalScreen), findsOneWidget);
  });

  testWidgets('ValueDetailsScreen renders with a title', (tester) async {
    await pump(tester, const ValueDetailsScreen(valueTitle: 'Kindness'));
    expect(find.byType(ValueDetailsScreen), findsOneWidget);
    expect(find.text('Kindness'), findsWidgets);
  });

  testWidgets('SkillVideoScreen renders with metadata', (tester) async {
    await pump(
      tester,
      const SkillVideoScreen(
        videoTitle: 'Tie your shoes',
        videoUrl: null,
        thumbnailUrl: null,
        description: 'A simple how-to',
      ),
    );
    expect(find.byType(SkillVideoScreen), findsOneWidget);
    expect(find.text('Tie your shoes'), findsWidgets);
  });
}
