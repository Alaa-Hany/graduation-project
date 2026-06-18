// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_time_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScreenTimeRuleImpl _$$ScreenTimeRuleImplFromJson(Map<String, dynamic> json) =>
    _$ScreenTimeRuleImpl(
      id: json['id'] as String,
      childId: json['childId'] as String,
      dailyLimitMinutes: (json['daily_limit_minutes'] as num).toInt(),
      allowedHours: (json['allowed_hours'] as List<dynamic>)
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      sleepModeEnabled: json['sleep_mode_enabled'] as bool,
      sleepStartTime: json['sleep_start_time'] as String?,
      sleepEndTime: json['sleep_end_time'] as String?,
      emergencyLockEnabled: json['emergency_lock_enabled'] as bool,
      smartControlEnabled: json['smart_control_enabled'] as bool,
      aiRecommendationsEnabled: json['ai_recommendations_enabled'] as bool,
      contentRestrictions: ContentRestrictions.fromJson(
          json['content_restrictions'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool,
    );

Map<String, dynamic> _$$ScreenTimeRuleImplToJson(
        _$ScreenTimeRuleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'childId': instance.childId,
      'daily_limit_minutes': instance.dailyLimitMinutes,
      'allowed_hours': instance.allowedHours,
      'sleep_mode_enabled': instance.sleepModeEnabled,
      'sleep_start_time': instance.sleepStartTime,
      'sleep_end_time': instance.sleepEndTime,
      'emergency_lock_enabled': instance.emergencyLockEnabled,
      'smart_control_enabled': instance.smartControlEnabled,
      'ai_recommendations_enabled': instance.aiRecommendationsEnabled,
      'content_restrictions': instance.contentRestrictions,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'is_active': instance.isActive,
    };

_$TimeSlotImpl _$$TimeSlotImplFromJson(Map<String, dynamic> json) =>
    _$TimeSlotImpl(
      start: json['start'] as String,
      end: json['end'] as String,
      days: (json['days'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$TimeSlotImplToJson(_$TimeSlotImpl instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
      'days': instance.days,
    };

_$ContentRestrictionsImpl _$$ContentRestrictionsImplFromJson(
        Map<String, dynamic> json) =>
    _$ContentRestrictionsImpl(
      blockedCategories: (json['blocked_categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      blockedActivities: (json['blocked_activities'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      allowedCategories: (json['allowed_categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      maxDifficulty: json['max_difficulty'] as String?,
      requireApprovalFor: (json['require_approval_for'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      ageAppropriateOnly: json['age_appropriate_only'] as bool,
      educationalFocus: json['educational_focus'] as bool?,
    );

Map<String, dynamic> _$$ContentRestrictionsImplToJson(
        _$ContentRestrictionsImpl instance) =>
    <String, dynamic>{
      'blocked_categories': instance.blockedCategories,
      'blocked_activities': instance.blockedActivities,
      'allowed_categories': instance.allowedCategories,
      'max_difficulty': instance.maxDifficulty,
      'require_approval_for': instance.requireApprovalFor,
      'age_appropriate_only': instance.ageAppropriateOnly,
      'educational_focus': instance.educationalFocus,
    };
