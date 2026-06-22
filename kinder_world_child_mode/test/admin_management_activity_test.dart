// Unit tests for the admin management activity models
// (admin_management_activity.dart): fromJson parsing for the summary/preview/
// details/log/ai-buddy classes, the type-coercion helpers exercised through
// them, and the computed getters on AdminChildActivityEntry.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/admin_management_activity.dart';

void main() {
  group('AdminUserActivitySummary', () {
    test('parses counts and coerces string numbers', () {
      final s = AdminUserActivitySummary.fromJson({
        'child_count': 2,
        'notification_count': '5', // string coerced to int
        'support_ticket_count': 1,
        'last_updated_at': '2025-06-01',
      });
      expect(s.childCount, 2);
      expect(s.notificationCount, 5);
      expect(s.lastUpdatedAt, '2025-06-01');
    });

    test('defaults to zero / null for empty payload', () {
      final s = AdminUserActivitySummary.fromJson(const {});
      expect(s.childCount, 0);
      expect(s.lastUpdatedAt, isNull);
    });
  });

  group('AdminUserNotificationPreview', () {
    test('parses fields and bool coercion', () {
      final n = AdminUserNotificationPreview.fromJson({
        'id': 1,
        'title': 'Hi',
        'type': 'INFO',
        'is_read': 'true',
      });
      expect(n.id, 1);
      expect(n.isRead, isTrue);
    });

    test('blank/null string fields resolve sensibly', () {
      final n = AdminUserNotificationPreview.fromJson({'id': '9'});
      expect(n.id, 9);
      expect(n.title, '');
      expect(n.isRead, isFalse);
    });
  });

  group('AdminUserActivityDetails', () {
    test('parses nested lists and summary', () {
      final d = AdminUserActivityDetails.fromJson({
        'user_id': 3,
        'summary': {'child_count': 1},
        'notifications': [
          {'id': 1, 'title': 'a', 'type': 't', 'is_read': false},
        ],
        'support_tickets': [
          {'id': 2, 'subject': 'help'},
        ],
        'admin_audit': [
          {'id': 10, 'action': 'edit', 'entity_type': 'user'},
        ],
      });
      expect(d.userId, 3);
      expect(d.summary.childCount, 1);
      expect(d.notifications.single.id, 1);
      expect(d.supportTickets.single.subject, 'help');
      expect(d.adminAudit.single.id, 10);
    });

    test('missing nested collections become empty lists', () {
      final d = AdminUserActivityDetails.fromJson({'user_id': 1, 'summary': {}});
      expect(d.notifications, isEmpty);
      expect(d.supportTickets, isEmpty);
      expect(d.adminAudit, isEmpty);
    });
  });

  group('AdminChildProgressDetails', () {
    test('parses summary, milestones and audit events', () {
      final d = AdminChildProgressDetails.fromJson({
        'child_id': 7,
        'summary': {
          'days_since_profile_created': 30,
          'profile_active': false,
          'audit_events': 4,
        },
        'milestones': [
          {'title': 'First lesson', 'timestamp': '2025-01-01'},
        ],
        'audit_events': [
          {'id': 1, 'action': 'create', 'entity_type': 'child'},
        ],
      });
      expect(d.childId, 7);
      expect(d.summary.daysSinceProfileCreated, 30);
      expect(d.summary.profileActive, isFalse);
      expect(d.milestones.single.title, 'First lesson');
      expect(d.auditEvents.single.id, 1);
    });

    test('profileActive defaults to true when missing', () {
      final s = AdminChildProgressSummary.fromJson(const {});
      expect(s.profileActive, isTrue);
    });
  });

  group('AdminChildActivityEntry', () {
    test('getters derive display values', () {
      final audit = AdminChildActivityEntry.fromJson({
        'type': 'audit',
        'action': 'updated',
        'timestamp': '2025-02-02',
      });
      expect(audit.isAudit, isTrue);
      expect(audit.displayTitle, 'updated'); // falls back to action
      expect(audit.displayTimestamp, '2025-02-02'); // falls back to timestamp

      final note = AdminChildActivityEntry.fromJson({
        'type': 'notification',
        'title': 'Welcome',
        'created_at': '2025-03-03',
      });
      expect(note.isAudit, isFalse);
      expect(note.displayTitle, 'Welcome');
      expect(note.displayTimestamp, '2025-03-03');
    });

    test('displayTimestamp empty when nothing present', () {
      final e = AdminChildActivityEntry.fromJson({'type': 'x'});
      expect(e.displayTimestamp, '');
      expect(e.displayTitle, 'x'); // falls back to type
    });
  });

  group('AdminChildActivityLog', () {
    test('parses entries list', () {
      final log = AdminChildActivityLog.fromJson({
        'child_id': 4,
        'entries': [
          {'type': 'audit', 'action': 'a'},
          {'type': 'notification', 'title': 'b'},
        ],
      });
      expect(log.childId, 4);
      expect(log.entries.length, 2);
    });
  });

  group('AdminChildAiBuddySummary', () {
    test('parses usage metrics and flags', () {
      final s = AdminChildAiBuddySummary.fromJson({
        'child_id': 5,
        'child_name': 'Lily',
        'visibility_mode': 'summary',
        'transcript_access': true,
        'parent_summary': 'All good',
        'usage_metrics': {
          'sessions_count': 3,
          'messages_count': 20,
          'child_messages_count': 10,
          'assistant_messages_count': 10,
          'allowed_count': 18,
          'refusal_count': 1,
          'safe_redirect_count': 1,
          'last_session_at': '2025-04-04',
        },
        'recent_flags': [
          {'message_id': 99, 'classification': 'blocked', 'topic': 'violence'},
        ],
      });
      expect(s.childId, 5);
      expect(s.childName, 'Lily');
      expect(s.transcriptAccess, isTrue);
      expect(s.usageMetrics.sessionsCount, 3);
      expect(s.usageMetrics.refusalCount, 1);
      expect(s.recentFlags.single.messageId, 99);
    });

    test('handles missing usage metrics and flags', () {
      final s = AdminChildAiBuddySummary.fromJson({
        'child_id': 1,
        'child_name': 'X',
        'visibility_mode': 'hidden',
        'transcript_access': false,
        'parent_summary': '',
        'usage_metrics': {},
      });
      expect(s.usageMetrics.messagesCount, 0);
      expect(s.recentFlags, isEmpty);
    });
  });
}
