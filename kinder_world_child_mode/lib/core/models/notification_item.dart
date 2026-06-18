import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

// Workaround for analyzer: allow JsonKey on Freezed constructor params
// (some analyzer versions report 'invalid_annotation_target')
// ignore_for_file: invalid_annotation_target

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String type,
    required String title,
    required String body,
    required String recipientId,
    required String recipientRole,
    @JsonKey(name: 'related_child_id') String? relatedChildId,
    @JsonKey(name: 'related_activity_id') String? relatedActivityId,
    @JsonKey(name: 'is_read') required bool isRead,
    @JsonKey(name: 'is_sent') required bool isSent,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'priority') required String priority,
    Map<String, dynamic>? data,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _NotificationItem;

  const NotificationItem._();

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);

  // Check if notification is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Check if notification is urgent
  bool get isUrgent {
    return priority == NotificationPriority.high;
  }

  // Check if notification is for parent
  bool get isForParent {
    return recipientRole == 'parent';
  }

  // Check if notification is for child
  bool get isForChild {
    return recipientRole == 'child';
  }

  // Get time since notification was created
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final weeks = difference.inDays ~/ 7;
      return '$weeks weeks ago';
    }
  }

  // Mark as read
  NotificationItem markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  // Mark as sent
  NotificationItem markAsSent() {
    return copyWith(
      isSent: true,
      sentAt: DateTime.now(),
    );
  }
}

// Notification types
class NotificationTypes {
  static const String achievement = 'achievement';
  static const String milestone = 'milestone';
  static const String reminder = 'reminder';
  static const String warning = 'warning';
  static const String reportReady = 'report_ready';
  static const String contentRecommended = 'content_recommended';
  static const String timeLimitWarning = 'time_limit_warning';
  static const String approvalRequired = 'approval_required';
  static const String subscription = 'subscription';
  static const String system = 'system';
  static const String aiInsight = 'ai_insight';

  static const List<String> all = [
    achievement,
    milestone,
    reminder,
    warning,
    reportReady,
    contentRecommended,
    timeLimitWarning,
    approvalRequired,
    subscription,
    system,
    aiInsight
  ];

  static String getDisplayName(String type) {
    switch (type) {
      case achievement:
        return 'Achievement';
      case milestone:
        return 'Milestone';
      case reminder:
        return 'Reminder';
      case warning:
        return 'Warning';
      case reportReady:
        return 'Report Ready';
      case contentRecommended:
        return 'Content Recommended';
      case timeLimitWarning:
        return 'Time Limit Warning';
      case approvalRequired:
        return 'Approval Required';
      case subscription:
        return 'Subscription';
      case system:
        return 'System';
      case aiInsight:
        return 'AI Insight';
      default:
        return type;
    }
  }

  static IconData getIcon(String type) {
    switch (type) {
      case achievement:
        return Icons.emoji_events;
      case milestone:
        return Icons.flag;
      case reminder:
        return Icons.notifications;
      case warning:
        return Icons.warning;
      case reportReady:
        return Icons.assessment;
      case contentRecommended:
        return Icons.recommend;
      case timeLimitWarning:
        return Icons.timer;
      case approvalRequired:
        return Icons.approval;
      case subscription:
        return Icons.payment;
      case system:
        return Icons.settings;
      case aiInsight:
        return Icons.psychology;
      default:
        return Icons.notifications;
    }
  }
}

// Notification priorities
class NotificationPriority {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';

  static const List<String> all = [low, medium, high];
}

// Notification data keys
class NotificationDataKeys {
  static const String activityId = 'activity_id';
  static const String childId = 'child_id';
  static const String reportId = 'report_id';
  static const String achievementType = 'achievement_type';
  static const String xpEarned = 'xp_earned';
  static const String streakCount = 'streak_count';
  static const String timeRemaining = 'time_remaining';
  static const String recommendedContent = 'recommended_content';
}
