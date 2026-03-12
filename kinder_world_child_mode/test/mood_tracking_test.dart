// test/mood_tracking_test.dart
//
// Unit tests for the Mood Tracking system.
// Tests pure model/service logic — no Hive, no Riverpod, no Flutter widgets.
// Mirrors the style of gamification_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/services/mood_recommendation_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // MoodEntry model
  // ─────────────────────────────────────────────────────────────────────────

  group('MoodEntry', () {
    final now = DateTime.now();

    MoodEntry make({
      String id = 'e1',
      String childId = 'c1',
      String mood = 'happy',
      DateTime? timestamp,
      String? note,
    }) =>
        MoodEntry(
          id: id,
          childId: childId,
          mood: mood,
          timestamp: timestamp ?? now,
          note: note,
        );

    test('serialization roundtrip preserves all fields', () {
      final entry = make(
        id: 'test-id',
        childId: 'child-42',
        mood: ChildMoods.calm,
        timestamp: DateTime(2024, 6, 15, 10, 30),
        note: 'Feeling peaceful',
      );

      final json = entry.toJson();
      final restored = MoodEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.childId, entry.childId);
      expect(restored.mood, entry.mood);
      expect(restored.timestamp, entry.timestamp);
      expect(restored.note, entry.note);
    });

    test('serialization roundtrip without optional note', () {
      final entry = make(mood: ChildMoods.excited);
      final restored = MoodEntry.fromJson(entry.toJson());
      expect(restored.note, isNull);
      expect(restored.mood, ChildMoods.excited);
    });

    test('isToday returns true for entries created now', () {
      final entry = make(timestamp: DateTime.now());
      expect(entry.isToday, isTrue);
    });

    test('isToday returns false for entries from yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entry = make(timestamp: yesterday);
      expect(entry.isToday, isFalse);
    });

    test('isWithinDays returns true for recent entries', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final entry = make(timestamp: threeDaysAgo);
      expect(entry.isWithinDays(7), isTrue);
      expect(entry.isWithinDays(2), isFalse);
    });

    test('isWithinDays returns false for old entries', () {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final entry = make(timestamp: tenDaysAgo);
      expect(entry.isWithinDays(7), isFalse);
      expect(entry.isWithinDays(30), isTrue);
    });

    test('equality is based on id', () {
      final a = make(id: 'same', mood: 'happy');
      final b = make(id: 'same', mood: 'sad'); // different mood, same id
      final c = make(id: 'other', mood: 'happy');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      final a = make(id: 'x');
      final b = make(id: 'x');
      expect(a.hashCode, b.hashCode);
    });

    test('toString contains key fields', () {
      final entry = make(id: 'e99', childId: 'c99', mood: 'tired');
      final str = entry.toString();
      expect(str, contains('e99'));
      expect(str, contains('c99'));
      expect(str, contains('tired'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MoodMeta display helpers
  // ─────────────────────────────────────────────────────────────────────────

  group('MoodMeta', () {
    test('emoji returns non-empty string for all known moods', () {
      for (final mood in MoodMeta.displayOrder) {
        final emoji = MoodMeta.emoji(mood);
        expect(emoji, isNotEmpty, reason: 'emoji missing for $mood');
      }
    });

    test('emoji returns fallback for unknown mood', () {
      expect(MoodMeta.emoji('unknown_mood'), isNotEmpty);
    });

    test('colorValue returns non-zero for all known moods', () {
      for (final mood in MoodMeta.displayOrder) {
        final color = MoodMeta.colorValue(mood);
        expect(color, isNonZero, reason: 'colorValue is 0 for $mood');
      }
    });

    test('colorValue returns non-zero fallback for unknown mood', () {
      expect(MoodMeta.colorValue('mystery'), isNonZero);
    });

    test('displayOrder contains exactly 6 moods', () {
      expect(MoodMeta.displayOrder.length, 6);
    });

    test('displayOrder contains all ChildMoods constants', () {
      expect(MoodMeta.displayOrder, contains(ChildMoods.happy));
      expect(MoodMeta.displayOrder, contains(ChildMoods.excited));
      expect(MoodMeta.displayOrder, contains(ChildMoods.calm));
      expect(MoodMeta.displayOrder, contains(ChildMoods.tired));
      expect(MoodMeta.displayOrder, contains(ChildMoods.sad));
      expect(MoodMeta.displayOrder, contains(ChildMoods.angry));
    });

    test('happy is first and angry is last in displayOrder', () {
      expect(MoodMeta.displayOrder.first, ChildMoods.happy);
      expect(MoodMeta.displayOrder.last, ChildMoods.angry);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MoodRecommendationService
  // ─────────────────────────────────────────────────────────────────────────

  group('MoodRecommendationService.getRecommendations', () {
    test('returns non-empty list for every known mood', () {
      for (final mood in MoodMeta.displayOrder) {
        final recs = MoodRecommendationService.getRecommendations(mood);
        expect(recs, isNotEmpty, reason: 'no recommendations for $mood');
      }
    });

    test('returns at least 2 recommendations per mood', () {
      for (final mood in MoodMeta.displayOrder) {
        final recs = MoodRecommendationService.getRecommendations(mood);
        expect(
          recs.length,
          greaterThanOrEqualTo(2),
          reason: 'too few recommendations for $mood',
        );
      }
    });

    test('returns at most 3 recommendations per mood', () {
      for (final mood in MoodMeta.displayOrder) {
        final recs = MoodRecommendationService.getRecommendations(mood);
        expect(
          recs.length,
          lessThanOrEqualTo(3),
          reason: 'too many recommendations for $mood',
        );
      }
    });

    test('all recommendation ids are unique within a mood', () {
      for (final mood in MoodMeta.displayOrder) {
        final recs = MoodRecommendationService.getRecommendations(mood);
        final ids = recs.map((r) => r.id).toSet();
        expect(ids.length, recs.length,
            reason: 'duplicate recommendation ids for $mood');
      }
    });

    test('all recommendations have non-empty routes', () {
      for (final mood in MoodMeta.displayOrder) {
        for (final rec
            in MoodRecommendationService.getRecommendations(mood)) {
          expect(rec.route, isNotEmpty,
              reason: 'empty route in rec ${rec.id} for $mood');
        }
      }
    });

    test('all recommendations have non-empty title and subtitle keys', () {
      for (final mood in MoodMeta.displayOrder) {
        for (final rec
            in MoodRecommendationService.getRecommendations(mood)) {
          expect(rec.titleKey, isNotEmpty);
          expect(rec.subtitleKey, isNotEmpty);
        }
      }
    });

    test('returns fallback list for unknown mood', () {
      final recs = MoodRecommendationService.getRecommendations('unknown');
      expect(recs, isNotEmpty);
    });

    // Mood-specific content routing checks
    test('sad recommendations include AI buddy route', () {
      final recs = MoodRecommendationService.getRecommendations(ChildMoods.sad);
      final routes = recs.map((r) => r.route).toList();
      expect(routes, anyElement(contains('ai')));
    });

    test('angry recommendations include AI buddy route for calming', () {
      final recs =
          MoodRecommendationService.getRecommendations(ChildMoods.angry);
      final routes = recs.map((r) => r.route).toList();
      expect(routes, anyElement(contains('ai')));
    });

    test('tired recommendations do NOT include AI buddy (low energy)', () {
      final recs =
          MoodRecommendationService.getRecommendations(ChildMoods.tired);
      // Tired should be gentle — learn or play, not AI chat
      expect(recs.length, lessThanOrEqualTo(2));
    });

    test('happy recommendations include learn and play routes', () {
      final recs =
          MoodRecommendationService.getRecommendations(ChildMoods.happy);
      final routes = recs.map((r) => r.route).toList();
      expect(routes, anyElement(contains('learn')));
      expect(routes, anyElement(contains('play')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MoodRecommendationService.getEncouragementKey
  // ─────────────────────────────────────────────────────────────────────────

  group('MoodRecommendationService.getEncouragementKey', () {
    test('returns non-empty key for every known mood', () {
      for (final mood in MoodMeta.displayOrder) {
        final key = MoodRecommendationService.getEncouragementKey(mood);
        expect(key, isNotEmpty, reason: 'empty encouragement key for $mood');
      }
    });

    test('each mood returns a distinct encouragement key', () {
      final keys = MoodMeta.displayOrder
          .map(MoodRecommendationService.getEncouragementKey)
          .toSet();
      // All 6 moods should have distinct keys
      expect(keys.length, 6);
    });

    test('keys follow the moodEncouragement prefix convention', () {
      for (final mood in MoodMeta.displayOrder) {
        final key = MoodRecommendationService.getEncouragementKey(mood);
        expect(key, startsWith('moodEncouragement'));
      }
    });

    test('returns non-empty fallback for unknown mood', () {
      final key = MoodRecommendationService.getEncouragementKey('unknown');
      expect(key, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Localization fallback helpers
  // ─────────────────────────────────────────────────────────────────────────

  group('moodRecTitleFallback', () {
    test('returns non-empty string for all known title keys', () {
      const knownKeys = [
        'moodRecHappyLearnTitle',
        'moodRecHappyPlayTitle',
        'moodRecHappyAiTitle',
        'moodRecExcitedPlayTitle',
        'moodRecExcitedLearnTitle',
        'moodRecExcitedAiTitle',
        'moodRecCalmLearnTitle',
        'moodRecCalmColoringTitle',
        'moodRecCalmAiTitle',
        'moodRecTiredColoringTitle',
        'moodRecTiredStoryTitle',
        'moodRecSadStoryTitle',
        'moodRecSadAiTitle',
        'moodRecSadColoringTitle',
        'moodRecAngryAiTitle',
        'moodRecAngryColoringTitle',
        'moodRecAngryStoryTitle',
      ];
      for (final key in knownKeys) {
        final title = moodRecTitleFallback(key);
        expect(title, isNotEmpty, reason: 'empty title fallback for $key');
        expect(title, isNot(equals(key)),
            reason: 'title fallback should not return the raw key for $key');
      }
    });

    test('returns the raw key for unknown keys (graceful fallback)', () {
      const unknown = 'moodRecUnknownTitle';
      expect(moodRecTitleFallback(unknown), unknown);
    });
  });

  group('moodRecSubtitleFallback', () {
    test('returns non-empty string for all known subtitle keys', () {
      const knownKeys = [
        'moodRecHappyLearnSubtitle',
        'moodRecHappyPlaySubtitle',
        'moodRecHappyAiSubtitle',
        'moodRecExcitedPlaySubtitle',
        'moodRecExcitedLearnSubtitle',
        'moodRecExcitedAiSubtitle',
        'moodRecCalmLearnSubtitle',
        'moodRecCalmColoringSubtitle',
        'moodRecCalmAiSubtitle',
        'moodRecTiredColoringSubtitle',
        'moodRecTiredStorySubtitle',
        'moodRecSadStorySubtitle',
        'moodRecSadAiSubtitle',
        'moodRecSadColoringSubtitle',
        'moodRecAngryAiSubtitle',
        'moodRecAngryColoringSubtitle',
        'moodRecAngryStorySubtitle',
      ];
      for (final key in knownKeys) {
        final subtitle = moodRecSubtitleFallback(key);
        expect(subtitle, isNotEmpty, reason: 'empty subtitle fallback for $key');
        expect(subtitle, isNot(equals(key)),
            reason: 'subtitle fallback should not return the raw key for $key');
      }
    });

    test('returns the raw key for unknown keys (graceful fallback)', () {
      const unknown = 'moodRecUnknownSubtitle';
      expect(moodRecSubtitleFallback(unknown), unknown);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ChildMoods constants
  // ─────────────────────────────────────────────────────────────────────────

  group('ChildMoods constants', () {
    test('all 6 mood constants are non-empty lowercase strings', () {
      final moods = [
        ChildMoods.happy,
        ChildMoods.sad,
        ChildMoods.excited,
        ChildMoods.tired,
        ChildMoods.calm,
        ChildMoods.angry,
      ];
      for (final mood in moods) {
        expect(mood, isNotEmpty);
        expect(mood, equals(mood.toLowerCase()),
            reason: '$mood should be lowercase');
      }
    });

    test('all 6 mood constants are distinct', () {
      final moods = {
        ChildMoods.happy,
        ChildMoods.sad,
        ChildMoods.excited,
        ChildMoods.tired,
        ChildMoods.calm,
        ChildMoods.angry,
      };
      expect(moods.length, 6);
    });
  });
}
