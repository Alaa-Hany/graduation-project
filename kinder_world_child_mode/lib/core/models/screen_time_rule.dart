// Workaround for analyzer: allow JsonKey on Freezed constructor params
// (some analyzer versions report 'invalid_annotation_target')
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'screen_time_rule.freezed.dart';
part 'screen_time_rule.g.dart';

@freezed
class ScreenTimeRule with _$ScreenTimeRule {
  const factory ScreenTimeRule({
    required String id,
    required String childId,
    @JsonKey(name: 'daily_limit_minutes') required int dailyLimitMinutes,
    @JsonKey(name: 'allowed_hours') required List<TimeSlot> allowedHours,
    @JsonKey(name: 'sleep_mode_enabled') required bool sleepModeEnabled,
    @JsonKey(name: 'sleep_start_time') String? sleepStartTime,
    @JsonKey(name: 'sleep_end_time') String? sleepEndTime,
    @JsonKey(name: 'emergency_lock_enabled') required bool emergencyLockEnabled,
    @JsonKey(name: 'smart_control_enabled') required bool smartControlEnabled,
    @JsonKey(name: 'ai_recommendations_enabled')
    required bool aiRecommendationsEnabled,
    @JsonKey(name: 'content_restrictions')
    required ContentRestrictions contentRestrictions,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _ScreenTimeRule;

  const ScreenTimeRule._();

  factory ScreenTimeRule.fromJson(Map<String, dynamic> json) =>
      _$ScreenTimeRuleFromJson(json);

  // Check if current time is within allowed hours
  bool isTimeAllowed(DateTime time) {
    if (allowedHours.isEmpty) return true;

    final currentTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    for (final slot in allowedHours) {
      if (slot.containsTime(currentTime)) {
        return true;
      }
    }
    return false;
  }

  // Check if sleep mode is active
  bool isSleepModeActive(DateTime time) {
    if (!sleepModeEnabled || sleepStartTime == null || sleepEndTime == null) {
      return false;
    }

    final currentTime = time.hour * 60 + time.minute;
    final startParts = sleepStartTime!.split(':');
    final endParts = sleepEndTime!.split(':');

    final startTime = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endTime = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    // Handle overnight sleep periods
    if (startTime > endTime) {
      return currentTime >= startTime || currentTime <= endTime;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  // Get remaining time for today
  int getRemainingTime(int timeUsedToday) {
    return (dailyLimitMinutes - timeUsedToday).clamp(0, dailyLimitMinutes);
  }

  // Check if daily limit is exceeded
  bool isDailyLimitExceeded(int timeUsedToday) {
    return timeUsedToday >= dailyLimitMinutes;
  }
}

@freezed
class TimeSlot with _$TimeSlot {
  const factory TimeSlot({
    required String start,
    required String end,
    required List<String> days,
  }) = _TimeSlot;

  const TimeSlot._();

  factory TimeSlot.fromJson(Map<String, dynamic> json) =>
      _$TimeSlotFromJson(json);

  // Check if time falls within this slot
  bool containsTime(String time) {
    final timeMinutes = _timeToMinutes(time);
    final startMinutes = _timeToMinutes(start);
    final endMinutes = _timeToMinutes(end);

    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  // Check if slot is active on a specific day
  bool isActiveOnDay(String day) {
    return days.contains(day.toLowerCase());
  }

  // Convert HH:MM time to minutes
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

@freezed
class ContentRestrictions with _$ContentRestrictions {
  const factory ContentRestrictions({
    @JsonKey(name: 'blocked_categories')
    required List<String> blockedCategories,
    @JsonKey(name: 'blocked_activities')
    required List<String> blockedActivities,
    @JsonKey(name: 'allowed_categories')
    required List<String> allowedCategories,
    @JsonKey(name: 'max_difficulty') String? maxDifficulty,
    @JsonKey(name: 'require_approval_for')
    required List<String> requireApprovalFor,
    @JsonKey(name: 'age_appropriate_only') required bool ageAppropriateOnly,
    @JsonKey(name: 'educational_focus') bool? educationalFocus,
  }) = _ContentRestrictions;

  const ContentRestrictions._();

  factory ContentRestrictions.fromJson(Map<String, dynamic> json) =>
      _$ContentRestrictionsFromJson(json);

  // Check if activity is allowed
  bool isActivityAllowed(
      String activityCategory, String activityId, String difficulty) {
    // Check if activity is explicitly blocked
    if (blockedActivities.contains(activityId)) {
      return false;
    }

    // Check if category is blocked
    if (blockedCategories.contains(activityCategory)) {
      return false;
    }

    // Check if category is in allowed list (if list is not empty)
    if (allowedCategories.isNotEmpty &&
        !allowedCategories.contains(activityCategory)) {
      return false;
    }

    // Check difficulty limit
    if (maxDifficulty != null) {
      final activityDiff = _getDifficultyValue(difficulty);
      final maxDiff = _getDifficultyValue(maxDifficulty!);
      if (activityDiff > maxDiff) {
        return false;
      }
    }

    return true;
  }

  // Check if activity requires approval
  bool requiresApproval(String activityCategory, String activityId) {
    return requireApprovalFor.contains(activityCategory) ||
        requireApprovalFor.contains(activityId);
  }

  // Convert difficulty string to numeric value
  int _getDifficultyValue(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return 1;
      case 'easy':
        return 2;
      case 'medium':
        return 3;
      case 'hard':
        return 4;
      case 'expert':
        return 5;
      default:
        return 2;
    }
  }
}

// Days of week
class DaysOfWeek {
  static const String monday = 'monday';
  static const String tuesday = 'tuesday';
  static const String wednesday = 'wednesday';
  static const String thursday = 'thursday';
  static const String friday = 'friday';
  static const String saturday = 'saturday';
  static const String sunday = 'sunday';

  static const List<String> all = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday
  ];

  static String getDisplayName(String day, String language) {
    if (language == 'ar') {
      switch (day) {
        case monday:
          return 'الاثنين';
        case tuesday:
          return 'الثلاثاء';
        case wednesday:
          return 'الأربعاء';
        case thursday:
          return 'الخميس';
        case friday:
          return 'الجمعة';
        case saturday:
          return 'السبت';
        case sunday:
          return 'الأحد';
        default:
          return day;
      }
    } else {
      return day[0].toUpperCase() + day.substring(1);
    }
  }
}
