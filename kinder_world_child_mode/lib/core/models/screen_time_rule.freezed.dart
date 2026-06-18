// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen_time_rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScreenTimeRule _$ScreenTimeRuleFromJson(Map<String, dynamic> json) {
  return _ScreenTimeRule.fromJson(json);
}

/// @nodoc
mixin _$ScreenTimeRule {
  String get id => throw _privateConstructorUsedError;
  String get childId => throw _privateConstructorUsedError;
  @JsonKey(name: 'daily_limit_minutes')
  int get dailyLimitMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'allowed_hours')
  List<TimeSlot> get allowedHours => throw _privateConstructorUsedError;
  @JsonKey(name: 'sleep_mode_enabled')
  bool get sleepModeEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'sleep_start_time')
  String? get sleepStartTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'sleep_end_time')
  String? get sleepEndTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'emergency_lock_enabled')
  bool get emergencyLockEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'smart_control_enabled')
  bool get smartControlEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_recommendations_enabled')
  bool get aiRecommendationsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'content_restrictions')
  ContentRestrictions get contentRestrictions =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this ScreenTimeRule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScreenTimeRuleCopyWith<ScreenTimeRule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScreenTimeRuleCopyWith<$Res> {
  factory $ScreenTimeRuleCopyWith(
          ScreenTimeRule value, $Res Function(ScreenTimeRule) then) =
      _$ScreenTimeRuleCopyWithImpl<$Res, ScreenTimeRule>;
  @useResult
  $Res call(
      {String id,
      String childId,
      @JsonKey(name: 'daily_limit_minutes') int dailyLimitMinutes,
      @JsonKey(name: 'allowed_hours') List<TimeSlot> allowedHours,
      @JsonKey(name: 'sleep_mode_enabled') bool sleepModeEnabled,
      @JsonKey(name: 'sleep_start_time') String? sleepStartTime,
      @JsonKey(name: 'sleep_end_time') String? sleepEndTime,
      @JsonKey(name: 'emergency_lock_enabled') bool emergencyLockEnabled,
      @JsonKey(name: 'smart_control_enabled') bool smartControlEnabled,
      @JsonKey(name: 'ai_recommendations_enabled')
      bool aiRecommendationsEnabled,
      @JsonKey(name: 'content_restrictions')
      ContentRestrictions contentRestrictions,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      @JsonKey(name: 'is_active') bool isActive});

  $ContentRestrictionsCopyWith<$Res> get contentRestrictions;
}

/// @nodoc
class _$ScreenTimeRuleCopyWithImpl<$Res, $Val extends ScreenTimeRule>
    implements $ScreenTimeRuleCopyWith<$Res> {
  _$ScreenTimeRuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? childId = null,
    Object? dailyLimitMinutes = null,
    Object? allowedHours = null,
    Object? sleepModeEnabled = null,
    Object? sleepStartTime = freezed,
    Object? sleepEndTime = freezed,
    Object? emergencyLockEnabled = null,
    Object? smartControlEnabled = null,
    Object? aiRecommendationsEnabled = null,
    Object? contentRestrictions = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isActive = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      childId: null == childId
          ? _value.childId
          : childId // ignore: cast_nullable_to_non_nullable
              as String,
      dailyLimitMinutes: null == dailyLimitMinutes
          ? _value.dailyLimitMinutes
          : dailyLimitMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowedHours: null == allowedHours
          ? _value.allowedHours
          : allowedHours // ignore: cast_nullable_to_non_nullable
              as List<TimeSlot>,
      sleepModeEnabled: null == sleepModeEnabled
          ? _value.sleepModeEnabled
          : sleepModeEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      sleepStartTime: freezed == sleepStartTime
          ? _value.sleepStartTime
          : sleepStartTime // ignore: cast_nullable_to_non_nullable
              as String?,
      sleepEndTime: freezed == sleepEndTime
          ? _value.sleepEndTime
          : sleepEndTime // ignore: cast_nullable_to_non_nullable
              as String?,
      emergencyLockEnabled: null == emergencyLockEnabled
          ? _value.emergencyLockEnabled
          : emergencyLockEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smartControlEnabled: null == smartControlEnabled
          ? _value.smartControlEnabled
          : smartControlEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      aiRecommendationsEnabled: null == aiRecommendationsEnabled
          ? _value.aiRecommendationsEnabled
          : aiRecommendationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      contentRestrictions: null == contentRestrictions
          ? _value.contentRestrictions
          : contentRestrictions // ignore: cast_nullable_to_non_nullable
              as ContentRestrictions,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentRestrictionsCopyWith<$Res> get contentRestrictions {
    return $ContentRestrictionsCopyWith<$Res>(_value.contentRestrictions,
        (value) {
      return _then(_value.copyWith(contentRestrictions: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ScreenTimeRuleImplCopyWith<$Res>
    implements $ScreenTimeRuleCopyWith<$Res> {
  factory _$$ScreenTimeRuleImplCopyWith(_$ScreenTimeRuleImpl value,
          $Res Function(_$ScreenTimeRuleImpl) then) =
      __$$ScreenTimeRuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String childId,
      @JsonKey(name: 'daily_limit_minutes') int dailyLimitMinutes,
      @JsonKey(name: 'allowed_hours') List<TimeSlot> allowedHours,
      @JsonKey(name: 'sleep_mode_enabled') bool sleepModeEnabled,
      @JsonKey(name: 'sleep_start_time') String? sleepStartTime,
      @JsonKey(name: 'sleep_end_time') String? sleepEndTime,
      @JsonKey(name: 'emergency_lock_enabled') bool emergencyLockEnabled,
      @JsonKey(name: 'smart_control_enabled') bool smartControlEnabled,
      @JsonKey(name: 'ai_recommendations_enabled')
      bool aiRecommendationsEnabled,
      @JsonKey(name: 'content_restrictions')
      ContentRestrictions contentRestrictions,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      @JsonKey(name: 'is_active') bool isActive});

  @override
  $ContentRestrictionsCopyWith<$Res> get contentRestrictions;
}

/// @nodoc
class __$$ScreenTimeRuleImplCopyWithImpl<$Res>
    extends _$ScreenTimeRuleCopyWithImpl<$Res, _$ScreenTimeRuleImpl>
    implements _$$ScreenTimeRuleImplCopyWith<$Res> {
  __$$ScreenTimeRuleImplCopyWithImpl(
      _$ScreenTimeRuleImpl _value, $Res Function(_$ScreenTimeRuleImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? childId = null,
    Object? dailyLimitMinutes = null,
    Object? allowedHours = null,
    Object? sleepModeEnabled = null,
    Object? sleepStartTime = freezed,
    Object? sleepEndTime = freezed,
    Object? emergencyLockEnabled = null,
    Object? smartControlEnabled = null,
    Object? aiRecommendationsEnabled = null,
    Object? contentRestrictions = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? isActive = null,
  }) {
    return _then(_$ScreenTimeRuleImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      childId: null == childId
          ? _value.childId
          : childId // ignore: cast_nullable_to_non_nullable
              as String,
      dailyLimitMinutes: null == dailyLimitMinutes
          ? _value.dailyLimitMinutes
          : dailyLimitMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowedHours: null == allowedHours
          ? _value._allowedHours
          : allowedHours // ignore: cast_nullable_to_non_nullable
              as List<TimeSlot>,
      sleepModeEnabled: null == sleepModeEnabled
          ? _value.sleepModeEnabled
          : sleepModeEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      sleepStartTime: freezed == sleepStartTime
          ? _value.sleepStartTime
          : sleepStartTime // ignore: cast_nullable_to_non_nullable
              as String?,
      sleepEndTime: freezed == sleepEndTime
          ? _value.sleepEndTime
          : sleepEndTime // ignore: cast_nullable_to_non_nullable
              as String?,
      emergencyLockEnabled: null == emergencyLockEnabled
          ? _value.emergencyLockEnabled
          : emergencyLockEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smartControlEnabled: null == smartControlEnabled
          ? _value.smartControlEnabled
          : smartControlEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      aiRecommendationsEnabled: null == aiRecommendationsEnabled
          ? _value.aiRecommendationsEnabled
          : aiRecommendationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      contentRestrictions: null == contentRestrictions
          ? _value.contentRestrictions
          : contentRestrictions // ignore: cast_nullable_to_non_nullable
              as ContentRestrictions,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScreenTimeRuleImpl extends _ScreenTimeRule {
  const _$ScreenTimeRuleImpl(
      {required this.id,
      required this.childId,
      @JsonKey(name: 'daily_limit_minutes') required this.dailyLimitMinutes,
      @JsonKey(name: 'allowed_hours')
      required final List<TimeSlot> allowedHours,
      @JsonKey(name: 'sleep_mode_enabled') required this.sleepModeEnabled,
      @JsonKey(name: 'sleep_start_time') this.sleepStartTime,
      @JsonKey(name: 'sleep_end_time') this.sleepEndTime,
      @JsonKey(name: 'emergency_lock_enabled')
      required this.emergencyLockEnabled,
      @JsonKey(name: 'smart_control_enabled') required this.smartControlEnabled,
      @JsonKey(name: 'ai_recommendations_enabled')
      required this.aiRecommendationsEnabled,
      @JsonKey(name: 'content_restrictions') required this.contentRestrictions,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      @JsonKey(name: 'is_active') required this.isActive})
      : _allowedHours = allowedHours,
        super._();

  factory _$ScreenTimeRuleImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScreenTimeRuleImplFromJson(json);

  @override
  final String id;
  @override
  final String childId;
  @override
  @JsonKey(name: 'daily_limit_minutes')
  final int dailyLimitMinutes;
  final List<TimeSlot> _allowedHours;
  @override
  @JsonKey(name: 'allowed_hours')
  List<TimeSlot> get allowedHours {
    if (_allowedHours is EqualUnmodifiableListView) return _allowedHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allowedHours);
  }

  @override
  @JsonKey(name: 'sleep_mode_enabled')
  final bool sleepModeEnabled;
  @override
  @JsonKey(name: 'sleep_start_time')
  final String? sleepStartTime;
  @override
  @JsonKey(name: 'sleep_end_time')
  final String? sleepEndTime;
  @override
  @JsonKey(name: 'emergency_lock_enabled')
  final bool emergencyLockEnabled;
  @override
  @JsonKey(name: 'smart_control_enabled')
  final bool smartControlEnabled;
  @override
  @JsonKey(name: 'ai_recommendations_enabled')
  final bool aiRecommendationsEnabled;
  @override
  @JsonKey(name: 'content_restrictions')
  final ContentRestrictions contentRestrictions;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;

  @override
  String toString() {
    return 'ScreenTimeRule(id: $id, childId: $childId, dailyLimitMinutes: $dailyLimitMinutes, allowedHours: $allowedHours, sleepModeEnabled: $sleepModeEnabled, sleepStartTime: $sleepStartTime, sleepEndTime: $sleepEndTime, emergencyLockEnabled: $emergencyLockEnabled, smartControlEnabled: $smartControlEnabled, aiRecommendationsEnabled: $aiRecommendationsEnabled, contentRestrictions: $contentRestrictions, createdAt: $createdAt, updatedAt: $updatedAt, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScreenTimeRuleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.childId, childId) || other.childId == childId) &&
            (identical(other.dailyLimitMinutes, dailyLimitMinutes) ||
                other.dailyLimitMinutes == dailyLimitMinutes) &&
            const DeepCollectionEquality()
                .equals(other._allowedHours, _allowedHours) &&
            (identical(other.sleepModeEnabled, sleepModeEnabled) ||
                other.sleepModeEnabled == sleepModeEnabled) &&
            (identical(other.sleepStartTime, sleepStartTime) ||
                other.sleepStartTime == sleepStartTime) &&
            (identical(other.sleepEndTime, sleepEndTime) ||
                other.sleepEndTime == sleepEndTime) &&
            (identical(other.emergencyLockEnabled, emergencyLockEnabled) ||
                other.emergencyLockEnabled == emergencyLockEnabled) &&
            (identical(other.smartControlEnabled, smartControlEnabled) ||
                other.smartControlEnabled == smartControlEnabled) &&
            (identical(
                    other.aiRecommendationsEnabled, aiRecommendationsEnabled) ||
                other.aiRecommendationsEnabled == aiRecommendationsEnabled) &&
            (identical(other.contentRestrictions, contentRestrictions) ||
                other.contentRestrictions == contentRestrictions) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      childId,
      dailyLimitMinutes,
      const DeepCollectionEquality().hash(_allowedHours),
      sleepModeEnabled,
      sleepStartTime,
      sleepEndTime,
      emergencyLockEnabled,
      smartControlEnabled,
      aiRecommendationsEnabled,
      contentRestrictions,
      createdAt,
      updatedAt,
      isActive);

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScreenTimeRuleImplCopyWith<_$ScreenTimeRuleImpl> get copyWith =>
      __$$ScreenTimeRuleImplCopyWithImpl<_$ScreenTimeRuleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScreenTimeRuleImplToJson(
      this,
    );
  }
}

abstract class _ScreenTimeRule extends ScreenTimeRule {
  const factory _ScreenTimeRule(
      {required final String id,
      required final String childId,
      @JsonKey(name: 'daily_limit_minutes')
      required final int dailyLimitMinutes,
      @JsonKey(name: 'allowed_hours')
      required final List<TimeSlot> allowedHours,
      @JsonKey(name: 'sleep_mode_enabled') required final bool sleepModeEnabled,
      @JsonKey(name: 'sleep_start_time') final String? sleepStartTime,
      @JsonKey(name: 'sleep_end_time') final String? sleepEndTime,
      @JsonKey(name: 'emergency_lock_enabled')
      required final bool emergencyLockEnabled,
      @JsonKey(name: 'smart_control_enabled')
      required final bool smartControlEnabled,
      @JsonKey(name: 'ai_recommendations_enabled')
      required final bool aiRecommendationsEnabled,
      @JsonKey(name: 'content_restrictions')
      required final ContentRestrictions contentRestrictions,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'updated_at') required final DateTime updatedAt,
      @JsonKey(name: 'is_active')
      required final bool isActive}) = _$ScreenTimeRuleImpl;
  const _ScreenTimeRule._() : super._();

  factory _ScreenTimeRule.fromJson(Map<String, dynamic> json) =
      _$ScreenTimeRuleImpl.fromJson;

  @override
  String get id;
  @override
  String get childId;
  @override
  @JsonKey(name: 'daily_limit_minutes')
  int get dailyLimitMinutes;
  @override
  @JsonKey(name: 'allowed_hours')
  List<TimeSlot> get allowedHours;
  @override
  @JsonKey(name: 'sleep_mode_enabled')
  bool get sleepModeEnabled;
  @override
  @JsonKey(name: 'sleep_start_time')
  String? get sleepStartTime;
  @override
  @JsonKey(name: 'sleep_end_time')
  String? get sleepEndTime;
  @override
  @JsonKey(name: 'emergency_lock_enabled')
  bool get emergencyLockEnabled;
  @override
  @JsonKey(name: 'smart_control_enabled')
  bool get smartControlEnabled;
  @override
  @JsonKey(name: 'ai_recommendations_enabled')
  bool get aiRecommendationsEnabled;
  @override
  @JsonKey(name: 'content_restrictions')
  ContentRestrictions get contentRestrictions;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;

  /// Create a copy of ScreenTimeRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScreenTimeRuleImplCopyWith<_$ScreenTimeRuleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TimeSlot _$TimeSlotFromJson(Map<String, dynamic> json) {
  return _TimeSlot.fromJson(json);
}

/// @nodoc
mixin _$TimeSlot {
  String get start => throw _privateConstructorUsedError;
  String get end => throw _privateConstructorUsedError;
  List<String> get days => throw _privateConstructorUsedError;

  /// Serializes this TimeSlot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimeSlot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimeSlotCopyWith<TimeSlot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimeSlotCopyWith<$Res> {
  factory $TimeSlotCopyWith(TimeSlot value, $Res Function(TimeSlot) then) =
      _$TimeSlotCopyWithImpl<$Res, TimeSlot>;
  @useResult
  $Res call({String start, String end, List<String> days});
}

/// @nodoc
class _$TimeSlotCopyWithImpl<$Res, $Val extends TimeSlot>
    implements $TimeSlotCopyWith<$Res> {
  _$TimeSlotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimeSlot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? days = null,
  }) {
    return _then(_value.copyWith(
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as String,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _value.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TimeSlotImplCopyWith<$Res>
    implements $TimeSlotCopyWith<$Res> {
  factory _$$TimeSlotImplCopyWith(
          _$TimeSlotImpl value, $Res Function(_$TimeSlotImpl) then) =
      __$$TimeSlotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String start, String end, List<String> days});
}

/// @nodoc
class __$$TimeSlotImplCopyWithImpl<$Res>
    extends _$TimeSlotCopyWithImpl<$Res, _$TimeSlotImpl>
    implements _$$TimeSlotImplCopyWith<$Res> {
  __$$TimeSlotImplCopyWithImpl(
      _$TimeSlotImpl _value, $Res Function(_$TimeSlotImpl) _then)
      : super(_value, _then);

  /// Create a copy of TimeSlot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? start = null,
    Object? end = null,
    Object? days = null,
  }) {
    return _then(_$TimeSlotImpl(
      start: null == start
          ? _value.start
          : start // ignore: cast_nullable_to_non_nullable
              as String,
      end: null == end
          ? _value.end
          : end // ignore: cast_nullable_to_non_nullable
              as String,
      days: null == days
          ? _value._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeSlotImpl extends _TimeSlot {
  const _$TimeSlotImpl(
      {required this.start,
      required this.end,
      required final List<String> days})
      : _days = days,
        super._();

  factory _$TimeSlotImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeSlotImplFromJson(json);

  @override
  final String start;
  @override
  final String end;
  final List<String> _days;
  @override
  List<String> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  @override
  String toString() {
    return 'TimeSlot(start: $start, end: $end, days: $days)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeSlotImpl &&
            (identical(other.start, start) || other.start == start) &&
            (identical(other.end, end) || other.end == end) &&
            const DeepCollectionEquality().equals(other._days, _days));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, start, end, const DeepCollectionEquality().hash(_days));

  /// Create a copy of TimeSlot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeSlotImplCopyWith<_$TimeSlotImpl> get copyWith =>
      __$$TimeSlotImplCopyWithImpl<_$TimeSlotImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeSlotImplToJson(
      this,
    );
  }
}

abstract class _TimeSlot extends TimeSlot {
  const factory _TimeSlot(
      {required final String start,
      required final String end,
      required final List<String> days}) = _$TimeSlotImpl;
  const _TimeSlot._() : super._();

  factory _TimeSlot.fromJson(Map<String, dynamic> json) =
      _$TimeSlotImpl.fromJson;

  @override
  String get start;
  @override
  String get end;
  @override
  List<String> get days;

  /// Create a copy of TimeSlot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeSlotImplCopyWith<_$TimeSlotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ContentRestrictions _$ContentRestrictionsFromJson(Map<String, dynamic> json) {
  return _ContentRestrictions.fromJson(json);
}

/// @nodoc
mixin _$ContentRestrictions {
  @JsonKey(name: 'blocked_categories')
  List<String> get blockedCategories => throw _privateConstructorUsedError;
  @JsonKey(name: 'blocked_activities')
  List<String> get blockedActivities => throw _privateConstructorUsedError;
  @JsonKey(name: 'allowed_categories')
  List<String> get allowedCategories => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_difficulty')
  String? get maxDifficulty => throw _privateConstructorUsedError;
  @JsonKey(name: 'require_approval_for')
  List<String> get requireApprovalFor => throw _privateConstructorUsedError;
  @JsonKey(name: 'age_appropriate_only')
  bool get ageAppropriateOnly => throw _privateConstructorUsedError;
  @JsonKey(name: 'educational_focus')
  bool? get educationalFocus => throw _privateConstructorUsedError;

  /// Serializes this ContentRestrictions to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ContentRestrictions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContentRestrictionsCopyWith<ContentRestrictions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContentRestrictionsCopyWith<$Res> {
  factory $ContentRestrictionsCopyWith(
          ContentRestrictions value, $Res Function(ContentRestrictions) then) =
      _$ContentRestrictionsCopyWithImpl<$Res, ContentRestrictions>;
  @useResult
  $Res call(
      {@JsonKey(name: 'blocked_categories') List<String> blockedCategories,
      @JsonKey(name: 'blocked_activities') List<String> blockedActivities,
      @JsonKey(name: 'allowed_categories') List<String> allowedCategories,
      @JsonKey(name: 'max_difficulty') String? maxDifficulty,
      @JsonKey(name: 'require_approval_for') List<String> requireApprovalFor,
      @JsonKey(name: 'age_appropriate_only') bool ageAppropriateOnly,
      @JsonKey(name: 'educational_focus') bool? educationalFocus});
}

/// @nodoc
class _$ContentRestrictionsCopyWithImpl<$Res, $Val extends ContentRestrictions>
    implements $ContentRestrictionsCopyWith<$Res> {
  _$ContentRestrictionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContentRestrictions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blockedCategories = null,
    Object? blockedActivities = null,
    Object? allowedCategories = null,
    Object? maxDifficulty = freezed,
    Object? requireApprovalFor = null,
    Object? ageAppropriateOnly = null,
    Object? educationalFocus = freezed,
  }) {
    return _then(_value.copyWith(
      blockedCategories: null == blockedCategories
          ? _value.blockedCategories
          : blockedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      blockedActivities: null == blockedActivities
          ? _value.blockedActivities
          : blockedActivities // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allowedCategories: null == allowedCategories
          ? _value.allowedCategories
          : allowedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxDifficulty: freezed == maxDifficulty
          ? _value.maxDifficulty
          : maxDifficulty // ignore: cast_nullable_to_non_nullable
              as String?,
      requireApprovalFor: null == requireApprovalFor
          ? _value.requireApprovalFor
          : requireApprovalFor // ignore: cast_nullable_to_non_nullable
              as List<String>,
      ageAppropriateOnly: null == ageAppropriateOnly
          ? _value.ageAppropriateOnly
          : ageAppropriateOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      educationalFocus: freezed == educationalFocus
          ? _value.educationalFocus
          : educationalFocus // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ContentRestrictionsImplCopyWith<$Res>
    implements $ContentRestrictionsCopyWith<$Res> {
  factory _$$ContentRestrictionsImplCopyWith(_$ContentRestrictionsImpl value,
          $Res Function(_$ContentRestrictionsImpl) then) =
      __$$ContentRestrictionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'blocked_categories') List<String> blockedCategories,
      @JsonKey(name: 'blocked_activities') List<String> blockedActivities,
      @JsonKey(name: 'allowed_categories') List<String> allowedCategories,
      @JsonKey(name: 'max_difficulty') String? maxDifficulty,
      @JsonKey(name: 'require_approval_for') List<String> requireApprovalFor,
      @JsonKey(name: 'age_appropriate_only') bool ageAppropriateOnly,
      @JsonKey(name: 'educational_focus') bool? educationalFocus});
}

/// @nodoc
class __$$ContentRestrictionsImplCopyWithImpl<$Res>
    extends _$ContentRestrictionsCopyWithImpl<$Res, _$ContentRestrictionsImpl>
    implements _$$ContentRestrictionsImplCopyWith<$Res> {
  __$$ContentRestrictionsImplCopyWithImpl(_$ContentRestrictionsImpl _value,
      $Res Function(_$ContentRestrictionsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ContentRestrictions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? blockedCategories = null,
    Object? blockedActivities = null,
    Object? allowedCategories = null,
    Object? maxDifficulty = freezed,
    Object? requireApprovalFor = null,
    Object? ageAppropriateOnly = null,
    Object? educationalFocus = freezed,
  }) {
    return _then(_$ContentRestrictionsImpl(
      blockedCategories: null == blockedCategories
          ? _value._blockedCategories
          : blockedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      blockedActivities: null == blockedActivities
          ? _value._blockedActivities
          : blockedActivities // ignore: cast_nullable_to_non_nullable
              as List<String>,
      allowedCategories: null == allowedCategories
          ? _value._allowedCategories
          : allowedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxDifficulty: freezed == maxDifficulty
          ? _value.maxDifficulty
          : maxDifficulty // ignore: cast_nullable_to_non_nullable
              as String?,
      requireApprovalFor: null == requireApprovalFor
          ? _value._requireApprovalFor
          : requireApprovalFor // ignore: cast_nullable_to_non_nullable
              as List<String>,
      ageAppropriateOnly: null == ageAppropriateOnly
          ? _value.ageAppropriateOnly
          : ageAppropriateOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      educationalFocus: freezed == educationalFocus
          ? _value.educationalFocus
          : educationalFocus // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ContentRestrictionsImpl extends _ContentRestrictions {
  const _$ContentRestrictionsImpl(
      {@JsonKey(name: 'blocked_categories')
      required final List<String> blockedCategories,
      @JsonKey(name: 'blocked_activities')
      required final List<String> blockedActivities,
      @JsonKey(name: 'allowed_categories')
      required final List<String> allowedCategories,
      @JsonKey(name: 'max_difficulty') this.maxDifficulty,
      @JsonKey(name: 'require_approval_for')
      required final List<String> requireApprovalFor,
      @JsonKey(name: 'age_appropriate_only') required this.ageAppropriateOnly,
      @JsonKey(name: 'educational_focus') this.educationalFocus})
      : _blockedCategories = blockedCategories,
        _blockedActivities = blockedActivities,
        _allowedCategories = allowedCategories,
        _requireApprovalFor = requireApprovalFor,
        super._();

  factory _$ContentRestrictionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ContentRestrictionsImplFromJson(json);

  final List<String> _blockedCategories;
  @override
  @JsonKey(name: 'blocked_categories')
  List<String> get blockedCategories {
    if (_blockedCategories is EqualUnmodifiableListView)
      return _blockedCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedCategories);
  }

  final List<String> _blockedActivities;
  @override
  @JsonKey(name: 'blocked_activities')
  List<String> get blockedActivities {
    if (_blockedActivities is EqualUnmodifiableListView)
      return _blockedActivities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedActivities);
  }

  final List<String> _allowedCategories;
  @override
  @JsonKey(name: 'allowed_categories')
  List<String> get allowedCategories {
    if (_allowedCategories is EqualUnmodifiableListView)
      return _allowedCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allowedCategories);
  }

  @override
  @JsonKey(name: 'max_difficulty')
  final String? maxDifficulty;
  final List<String> _requireApprovalFor;
  @override
  @JsonKey(name: 'require_approval_for')
  List<String> get requireApprovalFor {
    if (_requireApprovalFor is EqualUnmodifiableListView)
      return _requireApprovalFor;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requireApprovalFor);
  }

  @override
  @JsonKey(name: 'age_appropriate_only')
  final bool ageAppropriateOnly;
  @override
  @JsonKey(name: 'educational_focus')
  final bool? educationalFocus;

  @override
  String toString() {
    return 'ContentRestrictions(blockedCategories: $blockedCategories, blockedActivities: $blockedActivities, allowedCategories: $allowedCategories, maxDifficulty: $maxDifficulty, requireApprovalFor: $requireApprovalFor, ageAppropriateOnly: $ageAppropriateOnly, educationalFocus: $educationalFocus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContentRestrictionsImpl &&
            const DeepCollectionEquality()
                .equals(other._blockedCategories, _blockedCategories) &&
            const DeepCollectionEquality()
                .equals(other._blockedActivities, _blockedActivities) &&
            const DeepCollectionEquality()
                .equals(other._allowedCategories, _allowedCategories) &&
            (identical(other.maxDifficulty, maxDifficulty) ||
                other.maxDifficulty == maxDifficulty) &&
            const DeepCollectionEquality()
                .equals(other._requireApprovalFor, _requireApprovalFor) &&
            (identical(other.ageAppropriateOnly, ageAppropriateOnly) ||
                other.ageAppropriateOnly == ageAppropriateOnly) &&
            (identical(other.educationalFocus, educationalFocus) ||
                other.educationalFocus == educationalFocus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_blockedCategories),
      const DeepCollectionEquality().hash(_blockedActivities),
      const DeepCollectionEquality().hash(_allowedCategories),
      maxDifficulty,
      const DeepCollectionEquality().hash(_requireApprovalFor),
      ageAppropriateOnly,
      educationalFocus);

  /// Create a copy of ContentRestrictions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContentRestrictionsImplCopyWith<_$ContentRestrictionsImpl> get copyWith =>
      __$$ContentRestrictionsImplCopyWithImpl<_$ContentRestrictionsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ContentRestrictionsImplToJson(
      this,
    );
  }
}

abstract class _ContentRestrictions extends ContentRestrictions {
  const factory _ContentRestrictions(
          {@JsonKey(name: 'blocked_categories')
          required final List<String> blockedCategories,
          @JsonKey(name: 'blocked_activities')
          required final List<String> blockedActivities,
          @JsonKey(name: 'allowed_categories')
          required final List<String> allowedCategories,
          @JsonKey(name: 'max_difficulty') final String? maxDifficulty,
          @JsonKey(name: 'require_approval_for')
          required final List<String> requireApprovalFor,
          @JsonKey(name: 'age_appropriate_only')
          required final bool ageAppropriateOnly,
          @JsonKey(name: 'educational_focus') final bool? educationalFocus}) =
      _$ContentRestrictionsImpl;
  const _ContentRestrictions._() : super._();

  factory _ContentRestrictions.fromJson(Map<String, dynamic> json) =
      _$ContentRestrictionsImpl.fromJson;

  @override
  @JsonKey(name: 'blocked_categories')
  List<String> get blockedCategories;
  @override
  @JsonKey(name: 'blocked_activities')
  List<String> get blockedActivities;
  @override
  @JsonKey(name: 'allowed_categories')
  List<String> get allowedCategories;
  @override
  @JsonKey(name: 'max_difficulty')
  String? get maxDifficulty;
  @override
  @JsonKey(name: 'require_approval_for')
  List<String> get requireApprovalFor;
  @override
  @JsonKey(name: 'age_appropriate_only')
  bool get ageAppropriateOnly;
  @override
  @JsonKey(name: 'educational_focus')
  bool? get educationalFocus;

  /// Create a copy of ContentRestrictions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContentRestrictionsImplCopyWith<_$ContentRestrictionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
