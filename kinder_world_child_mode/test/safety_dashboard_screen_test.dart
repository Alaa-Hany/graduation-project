import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_screen.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_service.dart';

ChildProfile _child() {
  return ChildProfile(
    id: 'child-1',
    name: 'Dana',
    age: 8,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: 2,
    xp: 200,
    streak: 3,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: 90,
    activitiesCompleted: 6,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

void main() {
  testWidgets('renders safety dashboard sections from aggregated snapshot', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snapshot = SafetyDashboardSnapshot(
      children: [_child()],
      controls: SafetyControlsSummary.defaults(),
      privacySettings: const PrivacySettings(
        analyticsEnabled: false,
        personalizedRecommendations: true,
        dataCollectionOptOut: true,
      ),
      notifications: [
        ParentNotificationEntry(
          id: 'alert-1',
          type: 'SCREEN_TIME_LIMIT',
          title: 'Screen time alert',
          body: 'Dana exceeded the daily limit',
          createdAt: DateTime(2026, 3, 12, 10),
          isRead: false,
          isRemote: false,
          childId: 'child-1',
        ),
      ],
      supportTickets: const [
        SupportTicketRecord(
          id: 1,
          subject: 'PIN reset',
          message: 'Need help',
          category: 'technical_issue',
          status: 'open',
          replyCount: 0,
        ),
      ],
      hasParentPin: true,
      weeklyScreenTimeMinutes: 90,
      todayScreenTimeMinutes: 30,
      lastActivity: SafetyLastActivity(
        childName: 'Dana',
        title: 'Counting Numbers',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: SafetyDashboardScreen(initialSnapshot: snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safety Dashboard'), findsNWidgets(2));
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Parent PIN'), findsWidgets);
    expect(find.text('Screen time alert'), findsOneWidget);
    expect(find.text('Your support tickets'), findsOneWidget);
  });
}
