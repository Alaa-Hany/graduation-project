// Complements safety_dashboard_service_test.dart: focuses on
// SafetyControlsSummary parsing/defaults and the build/getter branches not
// already exercised (activityId-derived titles, last-session fallback, empty
// state, prioritized-vs-unread alerts, privacy guard counting).

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_service.dart';

ProgressRecord _record({
  String id = 'r1',
  String childId = 'c1',
  String activityId = 'math_quiz',
  String? notes,
  required DateTime date,
  int duration = 10,
}) {
  return ProgressRecord(
    id: id,
    childId: childId,
    activityId: activityId,
    date: date,
    score: 80,
    duration: duration,
    xpEarned: 50,
    notes: notes,
    completionStatus: CompletionStatus.completed,
    syncStatus: SyncStatus.synced,
    createdAt: date,
    updatedAt: date,
  );
}

ChildProfile _child({
  String id = 'c1',
  String name = 'Kid',
  DateTime? lastSession,
  int totalTimeSpent = 0,
}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: id,
    name: name,
    age: 6,
    avatar: '🦊',
    interests: const [],
    level: 1,
    xp: 0,
    streak: 0,
    favorites: const [],
    parentId: 'p1',
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    lastSession: lastSession,
    totalTimeSpent: totalTimeSpent,
    activitiesCompleted: 0,
  );
}

ParentNotificationEntry _note({
  String id = 'n1',
  String type = 'GENERIC',
  bool isRead = false,
}) {
  return ParentNotificationEntry(
    id: id,
    type: type,
    title: 't',
    body: 'b',
    createdAt: DateTime(2025, 1, 1),
    isRead: isRead,
    isRemote: false,
  );
}

void main() {
  group('SafetyControlsSummary', () {
    test('defaults have protection active', () {
      final c = SafetyControlsSummary.defaults();
      expect(c.dailyLimitEnabled, isTrue);
      expect(c.hoursPerDay, 2);
      expect(c.hasActiveProtection, isTrue);
    });

    test('fromJson respects explicit flags', () {
      final c = SafetyControlsSummary.fromJson({
        'daily_limit_enabled': false,
        'hours_per_day': 5,
        'age_appropriate_only': false,
        'require_approval': true,
        'sleep_mode': true,
        'bedtime': '9:00 PM',
        'wake_time': '6:30 AM',
        'emergency_lock': true,
      });
      expect(c.dailyLimitEnabled, isFalse);
      expect(c.hoursPerDay, 5);
      expect(c.requireApproval, isTrue);
      expect(c.bedtime, '9:00 PM');
      expect(c.emergencyLock, isTrue);
    });

    test('fromJson falls back to safe defaults for missing keys', () {
      final c = SafetyControlsSummary.fromJson(const {});
      expect(c.dailyLimitEnabled, isTrue); // != false => true
      expect(c.hoursPerDay, 2);
      expect(c.bedtime, '8:00 PM');
      expect(c.requireApproval, isFalse);
    });

    test('hasActiveProtection is false when everything is off', () {
      const c = SafetyControlsSummary(
        dailyLimitEnabled: false,
        hoursPerDay: 2,
        ageAppropriateOnly: false,
        requireApproval: false,
        sleepMode: false,
        bedtime: '8:00 PM',
        wakeTime: '7:00 AM',
        emergencyLock: false,
      );
      expect(c.hasActiveProtection, isFalse);
    });
  });

  group('SafetyDashboardSnapshot.build branches', () {
    final now = DateTime(2025, 6, 15, 12);

    SafetyDashboardSnapshot buildWith({
      List<ChildProfile> children = const [],
      List<ProgressRecord> records = const [],
    }) {
      return SafetyDashboardSnapshot.build(
        children: children,
        controls: SafetyControlsSummary.defaults(),
        privacySettings: PrivacySettings.defaults(),
        notifications: const [],
        supportTickets: const [],
        hasParentPin: true,
        records: records,
        now: now,
      );
    }

    test('activity title derives from activityId when no notes', () {
      final snap = buildWith(
        children: [_child(id: 'c1', name: 'Lily')],
        records: [_record(id: 'a', date: now, activityId: 'shape_sorter')],
      );
      expect(snap.lastActivity!.title, 'shape sorter');
    });

    test('falls back to most-recent last-session child when no records', () {
      final snap = buildWith(
        children: [
          _child(id: 'c1', name: 'NoSession'),
          _child(
              id: 'c2',
              name: 'Active',
              lastSession: now.subtract(const Duration(hours: 2))),
        ],
      );
      expect(snap.lastActivity!.childName, 'Active');
    });

    test('no last activity when no records and no sessions', () {
      final snap = buildWith(children: [_child()]);
      expect(snap.lastActivity, isNull);
    });
  });

  group('snapshot getter branches', () {
    SafetyDashboardSnapshot snapWith({
      List<ParentNotificationEntry> notifications = const [],
      List<SupportTicketRecord> tickets = const [],
      PrivacySettings? privacy,
    }) {
      return SafetyDashboardSnapshot(
        children: const [],
        controls: SafetyControlsSummary.defaults(),
        privacySettings: privacy ?? PrivacySettings.defaults(),
        notifications: notifications,
        supportTickets: tickets,
        hasParentPin: true,
        weeklyScreenTimeMinutes: 0,
        todayScreenTimeMinutes: 0,
        lastActivity: null,
      );
    }

    test('privacyGuardsEnabledCount reflects all opted-out settings', () {
      final snap = snapWith(
        privacy: const PrivacySettings(
          analyticsEnabled: false,
          personalizedRecommendations: false,
          dataCollectionOptOut: true,
        ),
      );
      expect(snap.privacyGuardsEnabledCount, 3);
    });

    test('highlightedAlerts falls back to unread when none prioritized', () {
      final snap = snapWith(notifications: [
        _note(id: 'a', type: 'GENERIC', isRead: false),
        _note(id: 'b', type: 'GENERIC', isRead: false),
      ]);
      expect(snap.highlightedAlerts.length, 2);
    });

    test('highlightedAlerts caps prioritized alerts at three', () {
      final snap = snapWith(notifications: [
        for (var i = 0; i < 5; i++)
          _note(id: 'p$i', type: 'SCREEN_TIME_LIMIT', isRead: false),
      ]);
      expect(snap.highlightedAlerts.length, 3);
    });
  });
}
