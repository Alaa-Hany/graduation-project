// Workaround for analyzer: allow JsonKey on Freezed constructor params
// (some analyzer versions report 'invalid_annotation_target')
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/achievement.dart';

part 'child_profile.freezed.dart';
part 'child_profile.g.dart';

@freezed
class ChildProfile with _$ChildProfile {
  const factory ChildProfile({
    required String id,
    required String name,
    required int age,
    required String avatar,
    required List<String> interests,
    required int level,
    required int xp,
    required int streak,
    required List<String> favorites,
    required String parentId,
    @JsonKey(name: 'parent_email') String? parentEmail,
    @JsonKey(name: 'picture_password') required List<String> picturePassword,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'last_session') DateTime? lastSession,
    @JsonKey(name: 'total_time_spent') required int totalTimeSpent,
    @JsonKey(name: 'activities_completed') required int activitiesCompleted,
    @JsonKey(name: 'current_mood') String? currentMood,
    @JsonKey(name: 'learning_style') String? learningStyle,
    @JsonKey(name: 'special_needs') List<String>? specialNeeds,
    @JsonKey(name: 'accessibility_needs') List<String>? accessibilityNeeds,
    @Default(AppConstants.defaultChildAvatar)
    @JsonKey(name: 'avatar_path')
    String avatarPath,
  }) = _ChildProfile;

  const ChildProfile._();

  factory ChildProfile.fromJson(Map<String, dynamic> json) =>
      _$ChildProfileFromJson(json);

  // Helper methods
  int get nextLevelXP => LevelThresholds.xpForNextLevel(xp);
  double get xpProgress => LevelThresholds.progressInLevel(xp);
  String get displayAge => age <= 0 ? '—' : age.toString();

  bool get hasStreak => streak > 0;

  String get ageGroup {
    if (age <= 6) return 'early_childhood';
    if (age <= 9) return 'middle_childhood';
    return 'late_childhood';
  }
}

// Learning styles
class LearningStyles {
  static const String visual = 'visual';
  static const String auditory = 'auditory';
  static const String kinesthetic = 'kinesthetic';
  static const String reading = 'reading';

  static const List<String> all = [visual, auditory, kinesthetic, reading];
}

// Moods
class ChildMoods {
  static const String happy = 'happy';
  static const String excited = 'excited';
  static const String calm = 'calm';
  static const String tired = 'tired';
  static const String sad = 'sad';
  static const String angry = 'angry';

  static const List<String> all = [happy, excited, calm, tired, sad, angry];
}

// Backwards-compatible MoodTypes API expected by UI
class MoodTypes {
  static const String happy = ChildMoods.happy;
  static const String excited = ChildMoods.excited;
  static const String calm = ChildMoods.calm;
  static const String tired = ChildMoods.tired;
  static const String sad = ChildMoods.sad;
  static const String angry = ChildMoods.angry;

  static String getEmoji(String mood) {
    switch (mood) {
      case happy:
        return '😊';
      case excited:
        return '🤩';
      case calm:
        return '😌';
      case tired:
        return '😴';
      case sad:
        return '😢';
      case angry:
        return '😠';
      default:
        return '🙂';
    }
  }

  static String getLabel(String mood) {
    switch (mood) {
      case happy:
        return 'Happy';
      case excited:
        return 'Excited';
      case calm:
        return 'Calm';
      case tired:
        return 'Tired';
      case sad:
        return 'Sad';
      case angry:
        return 'Angry';
      default:
        return 'Neutral';
    }
  }
}
