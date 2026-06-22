// Unit tests for the Activity model getters and the Activity catalog helper
// classes (categories/types/aspects display names).

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/activity.dart';

Activity _activity({
  String aspect = 'educational',
  String type = 'lesson',
  String difficulty = 'easy',
  List<String> ageRange = const ['4-8'],
  int duration = 10,
  double? averageRating,
}) {
  final now = DateTime(2025, 1, 1);
  return Activity(
    id: 'a1',
    title: 'Activity',
    description: 'd',
    category: 'mathematics',
    type: type,
    aspect: aspect,
    ageRange: ageRange,
    difficulty: difficulty,
    duration: duration,
    xpReward: 50,
    thumbnailUrl: '',
    tags: const [],
    learningObjectives: const [],
    isOfflineAvailable: true,
    isPremium: false,
    parentApprovalRequired: false,
    createdAt: now,
    updatedAt: now,
    playCount: 0,
    averageRating: averageRating,
  );
}

void main() {
  group('isAppropriateForAge', () {
    test('matches ranges and exact ages', () {
      expect(_activity(ageRange: const ['4-8']).isAppropriateForAge(6), isTrue);
      expect(_activity(ageRange: const ['4-8']).isAppropriateForAge(10), isFalse);
      expect(_activity(ageRange: const ['7']).isAppropriateForAge(7), isTrue);
      expect(_activity(ageRange: const ['7']).isAppropriateForAge(8), isFalse);
    });

    test('empty age range is appropriate for everyone', () {
      expect(_activity(ageRange: const []).isAppropriateForAge(3), isTrue);
    });
  });

  group('difficultyLevel', () {
    test('maps known difficulties to integers', () {
      expect(_activity(difficulty: 'beginner').difficultyLevel, 1);
      expect(_activity(difficulty: 'easy').difficultyLevel, 2);
      expect(_activity(difficulty: 'medium').difficultyLevel, 3);
      expect(_activity(difficulty: 'hard').difficultyLevel, 4);
      expect(_activity(difficulty: 'expert').difficultyLevel, 5);
      expect(_activity(difficulty: 'unknown').difficultyLevel, 2); // default
    });
  });

  group('aspectColor', () {
    test('maps aspects to hex colors with a default', () {
      expect(_activity(aspect: 'behavioral').aspectColor, '#E91E63');
      expect(_activity(aspect: 'skillful').aspectColor, '#9C27B0');
      expect(_activity(aspect: 'educational').aspectColor, '#3F51B5');
      expect(_activity(aspect: 'entertaining').aspectColor, '#00BCD4');
      expect(_activity(aspect: 'other').aspectColor, '#4A86E8');
    });
  });

  group('isInteractive', () {
    test('true only for game/quiz/interactive_story', () {
      expect(_activity(type: 'game').isInteractive, isTrue);
      expect(_activity(type: 'quiz').isInteractive, isTrue);
      expect(_activity(type: 'interactive_story').isInteractive, isTrue);
      expect(_activity(type: 'lesson').isInteractive, isFalse);
    });
  });

  group('estimatedTime', () {
    test('formats minutes and hours', () {
      expect(_activity(duration: 45).estimatedTime, '45 min');
      expect(_activity(duration: 60).estimatedTime, '1 hour');
      expect(_activity(duration: 120).estimatedTime, '2 hours');
      expect(_activity(duration: 90).estimatedTime, '1 hour 30 min');
    });
  });

  group('ratingStars', () {
    test('rounds half-star, zero when null', () {
      expect(_activity(averageRating: null).ratingStars, 0);
      expect(_activity(averageRating: 4.0).ratingStars, 4);
      expect(_activity(averageRating: 4.75).ratingStars, greaterThanOrEqualTo(4));
    });
  });

  group('catalog helpers', () {
    test('categories list and display names', () {
      expect(ActivityCategories.all, isNotEmpty);
      expect(ActivityCategories.getDisplayName('mathematics'), 'Mathematics');
      expect(ActivityCategories.getDisplayName('unknown'), 'unknown');
    });

    test('types and aspects expose lists and names', () {
      expect(ActivityTypes.all, isNotEmpty);
      expect(ActivityAspects.all, isNotEmpty);
      expect(ActivityTypes.getDisplayName(ActivityTypes.all.first), isA<String>());
      expect(
          ActivityAspects.getDisplayName(ActivityAspects.all.first), isA<String>());
    });
  });

  test('JSON round-trip preserves core fields', () {
    final a = _activity(difficulty: 'medium', averageRating: 4.5);
    final back = Activity.fromJson(a.toJson());
    expect(back.id, a.id);
    expect(back.difficulty, 'medium');
    expect(back.averageRating, 4.5);
  });
}
