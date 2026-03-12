import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/l10n/app_localizations_en.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_service.dart';

ChildProfile _child({
  required String id,
  required String name,
  required int streak,
  DateTime? lastSession,
}) {
  return ChildProfile(
    id: id,
    name: name,
    age: 7,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: 2,
    xp: 240,
    streak: streak,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    lastSession: lastSession,
    totalTimeSpent: 120,
    activitiesCompleted: 5,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

ProgressRecord _record({
  required String id,
  required String childId,
  required String activityId,
  required DateTime date,
  required int duration,
  String completionStatus = CompletionStatus.completed,
  String? notes,
}) {
  return ProgressRecord(
    id: id,
    childId: childId,
    activityId: activityId,
    date: date,
    score: 100,
    duration: duration,
    xpEarned: 40,
    completionStatus: completionStatus,
    syncStatus: SyncStatus.pending,
    createdAt: date,
    updatedAt: date,
    notes: notes,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  test('buildDerivedNotifications creates lesson, streak, inactivity, and screen time notifications', () {
    final now = DateTime(2026, 3, 11, 12);
    final activeChild = _child(
      id: 'child-1',
      name: 'Dana',
      streak: 7,
      lastSession: now.subtract(const Duration(hours: 2)),
    );
    final inactiveChild = _child(
      id: 'child-2',
      name: 'Lina',
      streak: 0,
      lastSession: now.subtract(const Duration(days: 4)),
    );

    final notifications = ParentNotificationService.buildDerivedNotifications(
      children: [activeChild, inactiveChild],
      recordsByChild: {
        'child-1': [
          _record(
            id: 'r1',
            childId: 'child-1',
            activityId: 'lesson_math_1',
            date: now.subtract(const Duration(hours: 3)),
            duration: 90,
            notes: 'Counting Numbers',
          ),
          _record(
            id: 'r2',
            childId: 'child-1',
            activityId: 'lesson_science_1',
            date: now.subtract(const Duration(hours: 1)),
            duration: 50,
            notes: 'Science Time',
          ),
        ],
        'child-2': const [],
      },
      screenTimeLimitMinutes: 120,
      readDerivedIds: const {},
      l10n: l10n,
      now: now,
    );

    expect(
      notifications.any((item) => item.type == 'LESSON_COMPLETED'),
      isTrue,
    );
    expect(
      notifications.any((item) => item.type == 'STREAK_REACHED'),
      isTrue,
    );
    expect(
      notifications.any((item) => item.type == 'SCREEN_TIME_LIMIT'),
      isTrue,
    );
    expect(
      notifications.any((item) => item.type == 'INACTIVITY_REMINDER'),
      isTrue,
    );
  });

  test('buildDerivedNotifications respects read derived ids', () {
    final now = DateTime(2026, 3, 11, 12);
    final child = _child(
      id: 'child-2',
      name: 'Lina',
      streak: 3,
      lastSession: now.subtract(const Duration(hours: 6)),
    );

    final notifications = ParentNotificationService.buildDerivedNotifications(
      children: [child],
      recordsByChild: {
        'child-2': [
          _record(
            id: 'lesson-1',
            childId: 'child-2',
            activityId: 'lesson_art_1',
            date: now.subtract(const Duration(hours: 2)),
            duration: 30,
            notes: 'Art Basics',
          ),
        ],
      },
      screenTimeLimitMinutes: 180,
      readDerivedIds: const {'lesson-child-2-lesson-1'},
      l10n: l10n,
      now: now,
    );

    final lesson = notifications.firstWhere((item) => item.type == 'LESSON_COMPLETED');
    expect(lesson.isRead, isTrue);
  });
}
