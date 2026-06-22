// Unit tests for [GamificationService] — the central XP/coins/streak/achievement
// engine. These cover the service logic itself (recordActivity, streak rules,
// deduplication, achievement unlocking, public helpers), complementing
// gamification_test.dart which only covers the underlying models.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/children_api.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:kinder_world/core/services/gamification_service.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAKES — override only the methods GamificationService actually calls.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeChildRepository extends Fake implements ChildRepository {
  ChildProfile? profile;
  int addXpCalls = 0;
  int updateStreakCalls = 0;

  @override
  Future<ChildProfile?> getChildProfile(String childId) async => profile;

  @override
  Future<ChildProfile?> addXP(String childId, int xpAmount) async {
    addXpCalls++;
    final p = profile;
    if (p == null) return null;
    profile = p.copyWith(xp: p.xp + xpAmount, level: p.level);
    return profile;
  }

  @override
  Future<ChildProfile?> updateStreak(String childId) async {
    updateStreakCalls++;
    return profile;
  }
}

class _FakeGamificationRepository extends Fake implements GamificationRepository {
  DateTime? lastActivityDate;
  final Set<String> completedActivityIds = {};
  final Set<String> exploredCategories = {};
  final List<Badge> earnedBadges = [];
  int activitiesCompleted = 0;
  int coins = 0;
  List<Achievement> achievements =
      AchievementCatalog.all.map((a) => a.copyWith()).toList();

  @override
  Future<bool> hasCompletedActivityId(String childId, String activityId) async =>
      completedActivityIds.contains(activityId);

  @override
  Future<void> markActivityIdCompleted(
      String childId, String activityId) async {
    completedActivityIds.add(activityId);
  }

  @override
  Future<DateTime?> getLastActivityDate(String childId) async =>
      lastActivityDate;

  @override
  Future<int> addCoins(String childId, int amount) async {
    coins += amount;
    return coins;
  }

  @override
  Future<int> incrementActivitiesCompleted(String childId) async {
    activitiesCompleted++;
    return activitiesCompleted;
  }

  @override
  Future<Set<String>> addExploredCategory(
      String childId, String category) async {
    exploredCategories.add(category);
    return exploredCategories;
  }

  @override
  Future<Set<String>> getExploredCategories(String childId) async =>
      exploredCategories;

  @override
  Future<List<Achievement>> getAchievements(String childId) async =>
      achievements;

  @override
  Future<Achievement?> unlockAchievement(
      String childId, String achievementId) async {
    final idx = achievements.indexWhere((a) => a.id == achievementId);
    if (idx == -1 || achievements[idx].isUnlocked) return null;
    final unlocked =
        achievements[idx].copyWith(isUnlocked: true, unlockedAt: DateTime.now());
    achievements[idx] = unlocked;
    return unlocked;
  }

  @override
  Future<Badge?> earnBadge(String childId, String badgeId) async {
    final badge = Badge(
      id: badgeId,
      nameKey: badgeId,
      descriptionKey: badgeId,
      iconEmoji: '🏅',
      color: const Color(0xFF000000),
      isEarned: true,
      earnedAt: DateTime.now(),
    );
    earnedBadges.add(badge);
    return badge;
  }

  @override
  Future<List<Badge>> getEarnedBadges(String childId) async => earnedBadges;

  @override
  Future<void> resetForChild(String childId) async {
    achievements = AchievementCatalog.all.map((a) => a.copyWith()).toList();
    earnedBadges.clear();
    exploredCategories.clear();
    completedActivityIds.clear();
    activitiesCompleted = 0;
    coins = 0;
  }
}

ChildProfile _child({int xp = 0, int level = 1, int streak = 0}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: 'c1',
    name: 'Test',
    age: 6,
    avatar: '🦊',
    interests: const [],
    level: level,
    xp: xp,
    streak: streak,
    favorites: const [],
    parentId: 'p1',
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

class _FakeChildrenApi extends Fake implements ChildrenApi {
  @override
  Future<Map<String, dynamic>> updateChild({
    required String childId,
    required Map<String, dynamic> payload,
  }) async =>
      const {};
}

void main() {
  late _FakeChildRepository childRepo;
  late _FakeGamificationRepository gamiRepo;
  late GamificationService service;

  setUp(() {
    childRepo = _FakeChildRepository();
    gamiRepo = _FakeGamificationRepository();
    service = GamificationService(
      gamificationRepository: gamiRepo,
      childRepository: childRepo,
      childrenApi: _FakeChildrenApi(),
      logger: Logger(level: Level.off),
    );
  });

  group('recordActivity — guards', () {
    test('returns empty result when child not found', () async {
      childRepo.profile = null;

      final result = await service.recordActivity(
        childId: 'missing',
        type: ActivityType.lesson,
      );

      expect(result.xpAwarded, 0);
      expect(result.coinsAwarded, 0);
      expect(result.newLevel, 1);
      expect(result.leveledUp, isFalse);
      expect(childRepo.addXpCalls, 0);
    });

    test('deduplicates by activityId — second call awards nothing', () async {
      childRepo.profile = _child();
      gamiRepo.lastActivityDate = DateTime.now(); // avoid streak bonus noise

      final first = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
        activityId: 'lesson-42',
      );
      expect(first.alreadyCompleted, isFalse);
      expect(first.xpAwarded, XPRewards.completeLesson);

      final second = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
        activityId: 'lesson-42',
      );
      expect(second.alreadyCompleted, isTrue);
      expect(second.xpAwarded, 0);
      expect(second.coinsAwarded, 0);
    });
  });

  group('recordActivity — XP & coins', () {
    test('awards base lesson XP/coins plus first-streak bonus', () async {
      childRepo.profile = _child();
      gamiRepo.lastActivityDate = null; // first ever activity

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      // base 50 + daily streak bonus 20
      expect(result.xpAwarded, XPRewards.completeLesson + XPRewards.dailyStreak);
      expect(result.newXP, XPRewards.completeLesson + XPRewards.dailyStreak);
      expect(result.coinsAwarded, CoinRewards.completeLesson);
      expect(result.streakUpdated, isTrue);
      expect(result.newStreak, 1);
    });

    test('perfect quiz grants score bonus XP', () async {
      childRepo.profile = _child();
      gamiRepo.lastActivityDate = DateTime.now(); // no streak bonus

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.quiz,
        score: 100,
      );

      expect(result.xpAwarded, XPRewards.completeQuiz + XPRewards.perfectScore);
      expect(
        result.coinsAwarded,
        CoinRewards.completeQuiz + CoinRewards.perfectScore,
      );
    });

    test('level-up grants bonus coins per level gained', () async {
      // 180 XP -> a 50 XP lesson pushes to 230 (level 1 -> 2)
      childRepo.profile = _child(xp: 180, level: 1);
      gamiRepo.lastActivityDate = DateTime.now(); // no streak bonus

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      expect(result.leveledUp, isTrue);
      expect(result.newLevel, 2);
      expect(
        result.coinsAwarded,
        CoinRewards.completeLesson + CoinRewards.levelUpBonus,
      );
    });

    test('awardXp:false skips XP but still grants coins', () async {
      childRepo.profile = _child();

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
        awardXp: false,
      );

      expect(result.xpAwarded, 0);
      expect(result.streakUpdated, isFalse);
      expect(result.coinsAwarded, CoinRewards.completeLesson);
      expect(childRepo.addXpCalls, 0);
    });
  });

  group('streak logic', () {
    test('same-day activity does not change streak or add bonus', () async {
      childRepo.profile = _child(streak: 3);
      gamiRepo.lastActivityDate = DateTime.now();

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      expect(result.streakUpdated, isFalse);
      expect(result.newStreak, 3);
      expect(result.xpAwarded, XPRewards.completeLesson); // no bonus
    });

    test('consecutive day extends streak and adds bonus', () async {
      childRepo.profile = _child(streak: 3);
      gamiRepo.lastActivityDate =
          DateTime.now().subtract(const Duration(days: 1));

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      expect(result.streakUpdated, isTrue);
      expect(result.newStreak, 4);
      expect(result.xpAwarded, XPRewards.completeLesson + XPRewards.dailyStreak);
    });

    test('gap of more than one day resets streak to 1', () async {
      childRepo.profile = _child(streak: 9);
      gamiRepo.lastActivityDate =
          DateTime.now().subtract(const Duration(days: 5));

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      expect(result.streakUpdated, isTrue);
      expect(result.newStreak, 1);
    });
  });

  group('achievements', () {
    test('first lesson unlocks firstLesson and firstActivity', () async {
      childRepo.profile = _child();
      gamiRepo.lastActivityDate = DateTime.now();

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.lesson,
      );

      final unlockedIds =
          result.newlyUnlockedAchievements.map((a) => a.id).toSet();
      expect(unlockedIds, contains(AchievementIds.firstLesson));
      expect(unlockedIds, contains(AchievementIds.firstActivity));
      expect(result.hasRewards, isTrue);
    });

    test('exploring all four categories unlocks explorer', () async {
      childRepo.profile = _child();
      gamiRepo.lastActivityDate = DateTime.now();
      gamiRepo.exploredCategories
          .addAll({'educational', 'behavioral', 'skillful'});

      final result = await service.recordActivity(
        childId: 'c1',
        type: ActivityType.activity,
        category: 'entertaining',
      );

      final unlockedIds =
          result.newlyUnlockedAchievements.map((a) => a.id).toSet();
      expect(unlockedIds, contains(AchievementIds.explorer));
    });
  });

  group('public helpers', () {
    test('level helpers delegate to LevelThresholds', () {
      expect(service.levelForXP(200), LevelThresholds.levelForXP(200));
      expect(service.xpToNextLevel(0), LevelThresholds.xpToNextLevel(0));
      expect(service.levelProgress(150), inInclusiveRange(0.0, 1.0));
      expect(service.levelTitle(1), isA<String>());
    });

    test('loadState returns default state when child not found', () async {
      childRepo.profile = null;

      final state = await service.loadState('missing');

      expect(state.totalXP, 0);
      expect(state.level, 1);
      expect(state.achievements, isNotEmpty);
    });

    test('resetChild clears gamification data', () async {
      gamiRepo.coins = 99;
      gamiRepo.activitiesCompleted = 7;

      await service.resetChild('c1');

      expect(gamiRepo.coins, 0);
      expect(gamiRepo.activitiesCompleted, 0);
    });
  });
}
