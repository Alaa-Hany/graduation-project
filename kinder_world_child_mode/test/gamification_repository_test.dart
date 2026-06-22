// Unit tests for [GamificationRepository] — Hive-backed persistence for
// achievements, badges, metadata, explored categories, coins, and activity
// deduplication. Uses an in-memory fake Box.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:logger/logger.dart';

class _FakeBox extends Fake implements Box {
  final Map<dynamic, dynamic> _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _store.remove(key);
  }
}

void main() {
  late _FakeBox box;
  late GamificationRepository repo;
  const childId = 'c1';

  setUp(() {
    box = _FakeBox();
    repo = GamificationRepository(
      gamificationBox: box,
      logger: Logger(level: Level.off),
    );
  });

  group('achievements', () {
    test('returns full catalog (all locked) on first read', () async {
      final all = await repo.getAchievements(childId);
      expect(all.length, AchievementCatalog.all.length);
      expect(all.every((a) => !a.isUnlocked), isTrue);
    });

    test('unlockAchievement persists unlocked state', () async {
      final unlocked =
          await repo.unlockAchievement(childId, AchievementIds.firstLesson);
      expect(unlocked, isNotNull);
      expect(unlocked!.isUnlocked, isTrue);

      final reloaded = await repo.getAchievements(childId);
      final found =
          reloaded.firstWhere((a) => a.id == AchievementIds.firstLesson);
      expect(found.isUnlocked, isTrue);
    });

    test('unlockAchievement is idempotent', () async {
      await repo.unlockAchievement(childId, AchievementIds.firstLesson);
      final again =
          await repo.unlockAchievement(childId, AchievementIds.firstLesson);
      expect(again!.isUnlocked, isTrue);

      final unlockedList = await repo.getUnlockedAchievements(childId);
      expect(
        unlockedList.where((a) => a.id == AchievementIds.firstLesson).length,
        1,
      );
    });

    test('unlockAchievement returns null for unknown id', () async {
      expect(await repo.unlockAchievement(childId, 'does_not_exist'), isNull);
    });
  });

  group('badges', () {
    test('returns full badge catalog (all unearned) on first read', () async {
      final all = await repo.getBadges(childId);
      expect(all.length, AchievementCatalog.allBadges.length);
      expect(all.every((b) => !b.isEarned), isTrue);
    });

    test('earnBadge persists and getEarnedBadges reflects it', () async {
      final firstBadge = AchievementCatalog.allBadges.first;
      final earned = await repo.earnBadge(childId, firstBadge.id);
      expect(earned!.isEarned, isTrue);

      final earnedList = await repo.getEarnedBadges(childId);
      expect(earnedList.map((b) => b.id), contains(firstBadge.id));
    });

    test('earnBadge returns null for unknown id', () async {
      expect(await repo.earnBadge(childId, 'nope'), isNull);
    });
  });

  group('metadata', () {
    test('increment returns rising count and sets last activity date',
        () async {
      expect(await repo.getActivitiesCompleted(childId), 0);
      expect(await repo.getLastActivityDate(childId), isNull);

      expect(await repo.incrementActivitiesCompleted(childId), 1);
      expect(await repo.incrementActivitiesCompleted(childId), 2);
      expect(await repo.getActivitiesCompleted(childId), 2);
      expect(await repo.getLastActivityDate(childId), isNotNull);
    });
  });

  group('explored categories', () {
    test('starts empty, then accumulates', () async {
      expect(await repo.getExploredCategories(childId), isEmpty);

      await repo.addExploredCategory(childId, 'educational');
      final updated = await repo.addExploredCategory(childId, 'behavioral');
      expect(updated, containsAll({'educational', 'behavioral'}));
    });
  });

  group('coins', () {
    test('default is zero; addCoins accumulates', () async {
      expect(await repo.getCoins(childId), 0);
      expect(await repo.addCoins(childId, 10), 10);
      expect(await repo.addCoins(childId, 5), 15);
    });

    test('spendCoins succeeds when affordable and fails otherwise', () async {
      await repo.addCoins(childId, 10);
      expect(await repo.spendCoins(childId, 4), isTrue);
      expect(await repo.getCoins(childId), 6);
      expect(await repo.spendCoins(childId, 100), isFalse);
      expect(await repo.getCoins(childId), 6);
    });
  });

  group('completed activity ids', () {
    test('marks and detects completion', () async {
      expect(await repo.hasCompletedActivityId(childId, 'act-1'), isFalse);
      await repo.markActivityIdCompleted(childId, 'act-1');
      expect(await repo.hasCompletedActivityId(childId, 'act-1'), isTrue);
      expect(await repo.hasCompletedActivityId(childId, 'act-2'), isFalse);
    });
  });

  group('state load and reset', () {
    test('loadState carries through xp/level/streak and persisted data',
        () async {
      await repo.addCoins(childId, 25);
      await repo.incrementActivitiesCompleted(childId);
      await repo.unlockAchievement(childId, AchievementIds.firstLesson);

      final state = await repo.loadState(
        childId: childId,
        xp: 300,
        level: 3,
        streak: 5,
      );

      expect(state.totalXP, 300);
      expect(state.level, 3);
      expect(state.streak, 5);
      expect(state.coins, 25);
      expect(state.activitiesCompleted, 1);
      expect(
        state.achievements
            .firstWhere((a) => a.id == AchievementIds.firstLesson)
            .isUnlocked,
        isTrue,
      );
    });

    test('resetForChild clears all stored data', () async {
      await repo.addCoins(childId, 25);
      await repo.incrementActivitiesCompleted(childId);
      await repo.addExploredCategory(childId, 'educational');
      await repo.markActivityIdCompleted(childId, 'act-1');

      await repo.resetForChild(childId);

      expect(await repo.getCoins(childId), 0);
      expect(await repo.getActivitiesCompleted(childId), 0);
      expect(await repo.getExploredCategories(childId), isEmpty);
      expect(await repo.hasCompletedActivityId(childId, 'act-1'), isFalse);
    });
  });
}
