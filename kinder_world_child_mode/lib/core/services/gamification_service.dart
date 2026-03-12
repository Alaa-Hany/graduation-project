// lib/core/services/gamification_service.dart
//
// The central logic engine for the Gamification system.
// Handles: XP awards, level-up detection, streak updates,
//          achievement checking, badge granting.
//
// Called by: GamificationProvider (Riverpod) and directly from
//            learn/play/coloring flows via the provider.

import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────

/// Returned by [GamificationService.recordActivity] — summarises what changed.
class ActivityResult {
  final int xpAwarded;
  final bool leveledUp;
  final int newLevel;
  final int newXP;
  final List<Achievement> newlyUnlockedAchievements;
  final List<Badge> newlyEarnedBadges;
  final bool streakUpdated;
  final int newStreak;

  const ActivityResult({
    required this.xpAwarded,
    required this.leveledUp,
    required this.newLevel,
    required this.newXP,
    required this.newlyUnlockedAchievements,
    required this.newlyEarnedBadges,
    required this.streakUpdated,
    required this.newStreak,
  });

  bool get hasRewards =>
      newlyUnlockedAchievements.isNotEmpty || newlyEarnedBadges.isNotEmpty;

  static ActivityResult empty(int xp, int level, int streak) => ActivityResult(
        xpAwarded: 0,
        leveledUp: false,
        newLevel: level,
        newXP: xp,
        newlyUnlockedAchievements: const [],
        newlyEarnedBadges: const [],
        streakUpdated: false,
        newStreak: streak,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TYPES — what triggered the XP award
// ─────────────────────────────────────────────────────────────────────────────

enum ActivityType {
  lesson,
  activity,
  quiz,
  perfectQuiz,   // quiz with 100% score
  play,
  coloring,
  aiBuddy,
  dailyStreak,
  firstLogin,
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class GamificationService {
  final GamificationRepository _gamificationRepo;
  final ChildRepository _childRepo;
  final Logger _logger;

  GamificationService({
    required GamificationRepository gamificationRepository,
    required ChildRepository childRepository,
    required Logger logger,
  })  : _gamificationRepo = gamificationRepository,
        _childRepo = childRepository,
        _logger = logger;

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN ENTRY POINT — called from UI flows
  // ══════════════════════════════════════════════════════════════════════════

  /// Records a completed activity for a child.
  ///
  /// [childId]      — the child's profile ID
  /// [type]         — what kind of activity was completed
  /// [category]     — content category (e.g. 'educational', 'behavioral')
  ///                  used for the Explorer achievement
  /// [score]        — quiz score 0–100 (optional, used for perfectScore check)
  ///
  /// Returns an [ActivityResult] describing all changes made.
  Future<ActivityResult> recordActivity({
    required String childId,
    required ActivityType type,
    String? category,
    int score = 0,
  }) async {
    try {
      // 1. Load current child profile
      final child = await _childRepo.getChildProfile(childId);
      if (child == null) {
        _logger.w('GamificationService: child not found: $childId');
        return ActivityResult.empty(0, 1, 0);
      }

      final oldXP    = child.xp;
      final oldLevel = child.level;

      // 2. Calculate XP to award
      final xpToAward = _xpForActivity(type, score: score);

      // 3. Update streak
      final streakResult = await _updateStreak(childId, child.streak);
      final newStreak = streakResult.newStreak;
      final streakBonusXP = streakResult.bonusXP;

      // 4. Award XP (base + streak bonus)
      final totalXPToAward = xpToAward + streakBonusXP;
      final newXP = oldXP + totalXPToAward;
      final newLevel = LevelThresholds.levelForXP(newXP);
      final leveledUp = newLevel > oldLevel;

      // 5. Persist XP + level + streak to ChildProfile
      await _childRepo.addXP(childId, totalXPToAward);
      if (streakResult.streakUpdated) {
        await _childRepo.updateStreak(childId);
      }

      // 6. Increment activities counter in gamification repo
      final activitiesCompleted =
          await _gamificationRepo.incrementActivitiesCompleted(childId);

      // 7. Track explored category
      if (category != null && category.isNotEmpty) {
        await _gamificationRepo.addExploredCategory(childId, category);
      }

      // 8. Check and unlock achievements
      final exploredCategories =
          await _gamificationRepo.getExploredCategories(childId);

      final achievementContext = _AchievementContext(
        xp: newXP,
        level: newLevel,
        streak: newStreak,
        activitiesCompleted: activitiesCompleted,
        exploredCategories: exploredCategories,
        activityType: type,
        score: score,
        isFirstLesson: type == ActivityType.lesson && activitiesCompleted == 1,
        isFirstActivity: activitiesCompleted == 1,
      );

      final unlockResult = await _checkAndUnlockAchievements(
          childId, achievementContext);

      _logger.i(
        'GamificationService.recordActivity: child=$childId '
        'type=$type xp+$totalXPToAward newXP=$newXP '
        'level=$oldLevel→$newLevel streak=$newStreak '
        'achievements=${unlockResult.newAchievements.length} '
        'badges=${unlockResult.newBadges.length}',
      );

      return ActivityResult(
        xpAwarded: totalXPToAward,
        leveledUp: leveledUp,
        newLevel: newLevel,
        newXP: newXP,
        newlyUnlockedAchievements: unlockResult.newAchievements,
        newlyEarnedBadges: unlockResult.newBadges,
        streakUpdated: streakResult.streakUpdated,
        newStreak: newStreak,
      );
    } catch (e) {
      _logger.e('GamificationService.recordActivity error: $e');
      return ActivityResult.empty(0, 1, 0);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // XP CALCULATION
  // ══════════════════════════════════════════════════════════════════════════

  int _xpForActivity(ActivityType type, {int score = 0}) {
    switch (type) {
      case ActivityType.lesson:
        return XPRewards.completeLesson;
      case ActivityType.activity:
        return XPRewards.completeActivity;
      case ActivityType.quiz:
        // Base quiz XP + bonus for perfect score
        const base = XPRewards.completeQuiz;
        final bonus = score >= 100 ? XPRewards.perfectScore : 0;
        return base + bonus;
      case ActivityType.perfectQuiz:
        return XPRewards.completeQuiz + XPRewards.perfectScore;
      case ActivityType.play:
        return XPRewards.playActivity;
      case ActivityType.coloring:
        return XPRewards.coloringPage;
      case ActivityType.aiBuddy:
        return XPRewards.aiBuddySession;
      case ActivityType.dailyStreak:
        return XPRewards.dailyStreak;
      case ActivityType.firstLogin:
        return XPRewards.firstLogin;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAK LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<_StreakResult> _updateStreak(String childId, int currentStreak) async {
    try {
      final lastDate = await _gamificationRepo.getLastActivityDate(childId);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastDate == null) {
        // First ever activity — start streak at 1
        return const _StreakResult(
          newStreak: 1,
          streakUpdated: true,
          bonusXP: XPRewards.dailyStreak,
        );
      }

      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 0) {
        // Already active today — no streak change, no bonus
        return _StreakResult(
          newStreak: currentStreak,
          streakUpdated: false,
          bonusXP: 0,
        );
      } else if (diff == 1) {
        // Consecutive day — extend streak
        return _StreakResult(
          newStreak: currentStreak + 1,
          streakUpdated: true,
          bonusXP: XPRewards.dailyStreak,
        );
      } else {
        // Streak broken — reset to 1
        return const _StreakResult(
          newStreak: 1,
          streakUpdated: true,
          bonusXP: XPRewards.dailyStreak,
        );
      }
    } catch (e) {
      _logger.e('GamificationService._updateStreak error: $e');
      return _StreakResult(newStreak: currentStreak, streakUpdated: false, bonusXP: 0);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACHIEVEMENT CHECKING
  // ══════════════════════════════════════════════════════════════════════════

  Future<_UnlockResult> _checkAndUnlockAchievements(
    String childId,
    _AchievementContext ctx,
  ) async {
    final newAchievements = <Achievement>[];
    final newBadges = <Badge>[];

    final achievements = await _gamificationRepo.getAchievements(childId);
    final lockedIds = achievements
        .where((a) => !a.isUnlocked)
        .map((a) => a.id)
        .toSet();

    // Helper: try to unlock an achievement
    Future<void> tryUnlock(String id) async {
      if (!lockedIds.contains(id)) return; // already unlocked
      final unlocked = await _gamificationRepo.unlockAchievement(childId, id);
      if (unlocked != null) {
        newAchievements.add(unlocked);
        // If this achievement grants a badge, earn it
        if (unlocked.badgeId != null) {
          final badge =
              await _gamificationRepo.earnBadge(childId, unlocked.badgeId!);
          if (badge != null) {
            newBadges.add(badge);
          }
        }
      }
    }

    // ── First lesson ──────────────────────────────────────────────────────
    if (ctx.isFirstLesson || ctx.activityType == ActivityType.lesson) {
      if (ctx.activitiesCompleted >= 1) {
        await tryUnlock(AchievementIds.firstLesson);
      }
    }

    // ── First activity ────────────────────────────────────────────────────
    if (ctx.activitiesCompleted >= 1) {
      await tryUnlock(AchievementIds.firstActivity);
    }

    // ── Streak milestones ─────────────────────────────────────────────────
    if (ctx.streak >= 3)  await tryUnlock(AchievementIds.streak3);
    if (ctx.streak >= 7)  await tryUnlock(AchievementIds.streak7);
    if (ctx.streak >= 30) await tryUnlock(AchievementIds.streak30);

    // ── Activity count milestones ─────────────────────────────────────────
    if (ctx.activitiesCompleted >= 10) await tryUnlock(AchievementIds.activities10);
    if (ctx.activitiesCompleted >= 50) await tryUnlock(AchievementIds.activities50);

    // ── Level milestone ───────────────────────────────────────────────────
    if (ctx.level >= 5) await tryUnlock(AchievementIds.level5);

    // ── XP milestone ──────────────────────────────────────────────────────
    if (ctx.xp >= 1000) await tryUnlock(AchievementIds.xp1000);

    // ── Perfect score ─────────────────────────────────────────────────────
    if (ctx.score >= 100 &&
        (ctx.activityType == ActivityType.quiz ||
            ctx.activityType == ActivityType.perfectQuiz)) {
      await tryUnlock(AchievementIds.perfectScore);
    }

    // ── Explorer (tried all 4 categories) ────────────────────────────────
    const requiredCategories = {
      'educational', 'behavioral', 'skillful', 'entertaining'
    };
    if (ctx.exploredCategories.containsAll(requiredCategories)) {
      await tryUnlock(AchievementIds.explorer);
    }

    // ── First badge ───────────────────────────────────────────────────────
    if (newBadges.isNotEmpty) {
      await tryUnlock(AchievementIds.firstBadge);
    } else {
      // Check if they already have any badge from before
      final earnedBadges = await _gamificationRepo.getEarnedBadges(childId);
      if (earnedBadges.isNotEmpty) {
        await tryUnlock(AchievementIds.firstBadge);
      }
    }

    return _UnlockResult(
      newAchievements: newAchievements,
      newBadges: newBadges,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads the full GamificationState for a child.
  Future<GamificationState> loadState(String childId) async {
    final child = await _childRepo.getChildProfile(childId);
    if (child == null) {
      return GamificationState(
        childId: childId,
        totalXP: 0,
        level: 1,
        streak: 0,
        achievements: AchievementCatalog.all,
        badges: AchievementCatalog.allBadges,
      );
    }
    return _gamificationRepo.loadState(
      childId: childId,
      xp: child.xp,
      level: child.level,
      streak: child.streak,
    );
  }

  /// Returns XP needed to reach the next level from current XP.
  int xpToNextLevel(int currentXP) =>
      LevelThresholds.xpToNextLevel(currentXP);

  /// Returns the level for a given XP total.
  int levelForXP(int xp) => LevelThresholds.levelForXP(xp);

  /// Returns the progress fraction (0.0–1.0) within the current level.
  double levelProgress(int xp) => LevelThresholds.progressInLevel(xp);

  /// Returns the human-readable title for a level.
  String levelTitle(int level) => LevelThresholds.titleForLevel(level);

  /// Resets all gamification data for a child (used in profile reset).
  Future<void> resetChild(String childId) async {
    await _gamificationRepo.resetForChild(childId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _StreakResult {
  final int newStreak;
  final bool streakUpdated;
  final int bonusXP;

  const _StreakResult({
    required this.newStreak,
    required this.streakUpdated,
    required this.bonusXP,
  });
}

class _AchievementContext {
  final int xp;
  final int level;
  final int streak;
  final int activitiesCompleted;
  final Set<String> exploredCategories;
  final ActivityType activityType;
  final int score;
  final bool isFirstLesson;
  final bool isFirstActivity;

  const _AchievementContext({
    required this.xp,
    required this.level,
    required this.streak,
    required this.activitiesCompleted,
    required this.exploredCategories,
    required this.activityType,
    required this.score,
    required this.isFirstLesson,
    required this.isFirstActivity,
  });
}

class _UnlockResult {
  final List<Achievement> newAchievements;
  final List<Badge> newBadges;

  const _UnlockResult({
    required this.newAchievements,
    required this.newBadges,
  });
}
