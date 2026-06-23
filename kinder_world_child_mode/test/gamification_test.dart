import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/achievement.dart';

void main() {
  group('LevelThresholds', () {
    test('levelForXP returns expected levels', () {
      expect(LevelThresholds.levelForXP(0), 1);
      expect(LevelThresholds.levelForXP(999), 1);
      expect(LevelThresholds.levelForXP(1000), 2);
      expect(LevelThresholds.levelForXP(2000), 3);
      expect(LevelThresholds.levelForXP(3000), 4);
      expect(LevelThresholds.levelForXP(5000), 6);
      expect(LevelThresholds.levelForXP(9000), 10);
      expect(LevelThresholds.levelForXP(999999), 10);
    });

    test('xpToNextLevel and progress are bounded', () {
      expect(LevelThresholds.xpToNextLevel(0), 1000);
      expect(LevelThresholds.xpToNextLevel(999), 1);
      expect(LevelThresholds.xpToNextLevel(9000), 0);

      final p1 = LevelThresholds.progressInLevel(0);
      final p2 = LevelThresholds.progressInLevel(777);
      final p3 = LevelThresholds.progressInLevel(999999);

      expect(p1, inInclusiveRange(0.0, 1.0));
      expect(p2, inInclusiveRange(0.0, 1.0));
      expect(p3, inInclusiveRange(0.0, 1.0));
    });
  });

  group('AchievementCatalog', () {
    test('has seeded achievements and badges', () {
      expect(AchievementCatalog.all.length, greaterThanOrEqualTo(10));
      expect(AchievementCatalog.allBadges.length, greaterThanOrEqualTo(5));
    });

    test('all seed achievements start locked and badges unearned', () {
      for (final a in AchievementCatalog.all) {
        expect(a.isUnlocked, isFalse);
      }
      for (final b in AchievementCatalog.allBadges) {
        expect(b.isEarned, isFalse);
      }
    });
  });

  group('GamificationState', () {
    test('computed getters are consistent', () {
      final state = GamificationState(
        childId: 'c1',
        totalXP: 1320,
        level: LevelThresholds.levelForXP(1320),
        streak: 3,
        achievements: AchievementCatalog.all,
        badges: AchievementCatalog.allBadges,
        activitiesCompleted: 5,
        exploredCategories: const {'learn', 'play'},
      );

      expect(state.level, 2);
      expect(state.levelProgress, inInclusiveRange(0.0, 1.0));
      expect(state.xpToNextLevel, greaterThanOrEqualTo(0));
      expect(
        state.unlockedAchievements.where((a) => a.isUnlocked).length,
        state.unlockedAchievements.length,
      );
      expect(
        state.earnedBadges.where((b) => b.isEarned).length,
        state.earnedBadges.length,
      );
    });
  });
}
