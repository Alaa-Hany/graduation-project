import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_overview_screen.dart';

void main() {
  testWidgets('child profile overview renders the child content',
      (WidgetTester tester) async {
    final child = ChildProfile(
      id: 'child-1',
      name: 'Lina',
      age: 7,
      avatar: 'avatar_1',
      interests: const ['Math', 'Stories'],
      level: 3,
      xp: 240,
      streak: 5,
      favorites: const [],
      parentId: 'parent-1',
      parentEmail: 'parent@example.com',
      picturePassword: const ['cat', 'dog', 'apple'],
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
      totalTimeSpent: 25,
      activitiesCompleted: 9,
      avatarPath: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentChildProvider.overrideWithValue(child),
          childLoadingProvider.overrideWithValue(false),
          childErrorProvider.overrideWithValue(null),
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
          home: const ChildProfileOverviewScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Lina'), findsOneWidget);
    expect(find.text('Your Progress'), findsOneWidget);
    expect(find.text('Customize Profile'), findsOneWidget);
  });
}
