import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_service.dart';

ChildProfile _child({
  required String id,
  required String name,
  DateTime? lastSession,
  int totalTimeSpent = 40,
}) {
  return ChildProfile(
    id: id,
    name: name,
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
    lastSession: lastSession,
    totalTimeSpent: totalTimeSpent,
    activitiesCompleted: 6,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

ProgressRecord _record({
  required String id,
  required String childId,
  required DateTime date,
  required int duration,
  String activityId = 'lesson_math_1',
  String? notes,
}) {
  return ProgressRecord(
    id: id,
    childId: childId,
    activityId: activityId,
    date: date,
    score: 95,
    duration: duration,
    xpEarned: 30,
    completionStatus: CompletionStatus.completed,
    syncStatus: SyncStatus.pending,
    createdAt: date,
    updatedAt: date,
    notes: notes,
  );
}

void main() {
  test('build aggregates screen time, alerts, support, and last activity', () {
    final now = DateTime(2026, 3, 12, 12);
    final snapshot = SafetyDashboardSnapshot.build(
      children: [
        _child(
          id: 'child-1',
          name: 'Dana',
          lastSession: now.subtract(const Duration(hours: 1)),
        ),
      ],
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
          createdAt: now.subtract(const Duration(minutes: 20)),
          isRead: false,
          isRemote: false,
          childId: 'child-1',
        ),
        ParentNotificationEntry(
          id: 'alert-2',
          type: 'LESSON_COMPLETED',
          title: 'Lesson completed',
          body: 'Dana completed math',
          createdAt: now.subtract(const Duration(minutes: 40)),
          isRead: true,
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
      records: [
        _record(
          id: 'r1',
          childId: 'child-1',
          date: now.subtract(const Duration(hours: 2)),
          duration: 25,
          notes: 'Counting Numbers',
        ),
        _record(
          id: 'r2',
          childId: 'child-1',
          date: now.subtract(const Duration(days: 2)),
          duration: 20,
          activityId: 'game_shapes_1',
        ),
      ],
      now: now,
    );

    expect(snapshot.todayScreenTimeMinutes, 25);
    expect(snapshot.weeklyScreenTimeMinutes, 45);
    expect(snapshot.unreadAlertsCount, 1);
    expect(snapshot.openSupportTicketsCount, 1);
    expect(snapshot.privacyGuardsEnabledCount, 2);
    expect(snapshot.lastActivity?.childName, 'Dana');
    expect(snapshot.lastActivity?.title, 'Counting Numbers');
    expect(snapshot.highlightedAlerts.single.type, 'SCREEN_TIME_LIMIT');
  });

  test('build falls back to child totals when records are missing', () {
    final now = DateTime(2026, 3, 12, 12);
    final snapshot = SafetyDashboardSnapshot.build(
      children: [
        _child(
          id: 'child-1',
          name: 'Dana',
          lastSession: now.subtract(const Duration(hours: 3)),
          totalTimeSpent: 90,
        ),
      ],
      controls: SafetyControlsSummary.defaults(),
      privacySettings: PrivacySettings.defaults(),
      notifications: const [],
      supportTickets: const [],
      hasParentPin: false,
      records: const [],
      now: now,
    );

    expect(snapshot.weeklyScreenTimeMinutes, 90);
    expect(snapshot.todayScreenTimeMinutes, 0);
    expect(snapshot.lastActivity?.childName, 'Dana');
  });
}
