// lib/core/models/achievement.dart
//
// Core data models for the Gamification system.
// Covers: Achievement, Badge, GamificationState, XP/Level definitions.

import 'dart:ui';

// ─────────────────────────────────────────────────────────────────────────────
// XP CONSTANTS — how much XP each action awards
// ─────────────────────────────────────────────────────────────────────────────

class XPRewards {
  XPRewards._();

  static const int completeLesson    = 50;
  static const int completeActivity  = 30;
  static const int completeQuiz      = 40;
  static const int perfectScore      = 60;  // bonus on top of quiz XP
  static const int dailyStreak       = 20;
  static const int playActivity      = 25;
  static const int coloringPage      = 15;
  static const int aiBuddySession    = 10;
  static const int firstLogin        = 100; // one-time welcome bonus
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

/// Defines the XP threshold to *reach* each level.
/// Level 1 starts at 0 XP.
class LevelThresholds {
  LevelThresholds._();

  static const List<int> thresholds = [
    0,      // Level 1
    200,    // Level 2
    500,    // Level 3
    1000,   // Level 4
    2000,   // Level 5
    4000,   // Level 6
    8000,   // Level 7
    15000,  // Level 8
    25000,  // Level 9
    40000,  // Level 10
  ];

  static const int maxLevel = 10;

  /// Returns the level (1-based) for a given total XP.
  static int levelForXP(int xp) {
    int level = 1;
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (xp >= thresholds[i]) {
        level = i + 1;
        break;
      }
    }
    return level.clamp(1, maxLevel);
  }

  /// Returns the XP required to reach the *next* level from current XP.
  /// Returns 0 if already at max level.
  static int xpToNextLevel(int xp) {
    final level = levelForXP(xp);
    if (level >= maxLevel) return 0;
    return thresholds[level] - xp; // thresholds[level] = threshold for level+1
  }

  /// Returns the XP threshold for the current level (floor).
  static int xpForCurrentLevel(int xp) {
    final level = levelForXP(xp);
    return thresholds[level - 1];
  }

  /// Returns the XP threshold for the next level (ceiling).
  static int xpForNextLevel(int xp) {
    final level = levelForXP(xp);
    if (level >= maxLevel) return thresholds.last;
    return thresholds[level];
  }

  /// Progress within the current level as a 0.0–1.0 fraction.
  static double progressInLevel(int xp) {
    final level = levelForXP(xp);
    if (level >= maxLevel) return 1.0;
    final floor = thresholds[level - 1];
    final ceiling = thresholds[level];
    if (ceiling == floor) return 1.0;
    return ((xp - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  }

  /// Human-readable title for a level.
  static String titleForLevel(int level) {
    const titles = [
      'Explorer',       // 1
      'Adventurer',     // 2
      'Learner',        // 3
      'Scholar',        // 4
      'Champion',       // 5
      'Hero',           // 6
      'Master',         // 7
      'Legend',         // 8
      'Genius',         // 9
      'KinderStar',     // 10
    ];
    final idx = (level - 1).clamp(0, titles.length - 1);
    return titles[idx];
  }

  /// Emoji for a level.
  static String emojiForLevel(int level) {
    const emojis = ['🌱', '🌿', '📚', '🎓', '🏆', '⚡', '🌟', '💎', '🧠', '👑'];
    final idx = (level - 1).clamp(0, emojis.length - 1);
    return emojis[idx];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT IDs — canonical string keys
// ─────────────────────────────────────────────────────────────────────────────

class AchievementIds {
  AchievementIds._();

  static const String firstLesson      = 'first_lesson';
  static const String firstActivity    = 'first_activity';
  static const String firstBadge       = 'first_badge';
  static const String streak3          = 'streak_3';
  static const String streak7          = 'streak_7';
  static const String streak30         = 'streak_30';
  static const String activities10     = 'activities_10';
  static const String activities50     = 'activities_50';
  static const String level5           = 'level_5';
  static const String xp1000          = 'xp_1000';
  static const String perfectScore     = 'perfect_score';
  static const String explorer         = 'explorer';
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE IDs
// ─────────────────────────────────────────────────────────────────────────────

class BadgeIds {
  BadgeIds._();

  static const String starLearner       = 'star_learner';
  static const String streakHero        = 'streak_hero';
  static const String activityChampion  = 'activity_champion';
  static const String quizMaster        = 'quiz_master';
  static const String explorer          = 'explorer';
  static const String levelMaster       = 'level_master';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String iconEmoji;
  final int xpReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final String? badgeId; // if unlocking this achievement also grants a badge

  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.iconEmoji,
    required this.xpReward,
    this.isUnlocked = false,
    this.unlockedAt,
    this.badgeId,
  });

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      iconEmoji: iconEmoji,
      xpReward: xpReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      badgeId: badgeId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleKey': titleKey,
        'descriptionKey': descriptionKey,
        'iconEmoji': iconEmoji,
        'xpReward': xpReward,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'badgeId': badgeId,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        titleKey: json['titleKey'] as String,
        descriptionKey: json['descriptionKey'] as String,
        iconEmoji: json['iconEmoji'] as String,
        xpReward: (json['xpReward'] as num).toInt(),
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.tryParse(json['unlockedAt'] as String)
            : null,
        badgeId: json['badgeId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Achievement && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class Badge {
  final String id;
  final String nameKey;
  final String descriptionKey;
  final String iconEmoji;
  final Color color;
  final bool isEarned;
  final DateTime? earnedAt;

  const Badge({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.iconEmoji,
    required this.color,
    this.isEarned = false,
    this.earnedAt,
  });

  Badge copyWith({
    bool? isEarned,
    DateTime? earnedAt,
  }) {
    return Badge(
      id: id,
      nameKey: nameKey,
      descriptionKey: descriptionKey,
      iconEmoji: iconEmoji,
      color: color,
      isEarned: isEarned ?? this.isEarned,
      earnedAt: earnedAt ?? this.earnedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameKey': nameKey,
        'descriptionKey': descriptionKey,
        'iconEmoji': iconEmoji,
        'colorValue': color.toARGB32(),
        'isEarned': isEarned,
        'earnedAt': earnedAt?.toIso8601String(),
      };

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
        id: json['id'] as String,
        nameKey: json['nameKey'] as String,
        descriptionKey: json['descriptionKey'] as String,
        iconEmoji: json['iconEmoji'] as String,
        color: Color((json['colorValue'] as num).toInt()),
        isEarned: json['isEarned'] as bool? ?? false,
        earnedAt: json['earnedAt'] != null
            ? DateTime.tryParse(json['earnedAt'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Badge && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION STATE — full snapshot for a child
// ─────────────────────────────────────────────────────────────────────────────

class GamificationState {
  final String childId;
  final int totalXP;
  final int level;
  final int streak;
  final List<Achievement> achievements;
  final List<Badge> badges;
  final DateTime? lastActivityDate;
  final int activitiesCompleted;
  final Set<String> exploredCategories; // tracks which content categories visited

  const GamificationState({
    required this.childId,
    required this.totalXP,
    required this.level,
    required this.streak,
    required this.achievements,
    required this.badges,
    this.lastActivityDate,
    this.activitiesCompleted = 0,
    this.exploredCategories = const {},
  });

  // Computed helpers
  double get levelProgress => LevelThresholds.progressInLevel(totalXP);
  int get xpToNextLevel => LevelThresholds.xpToNextLevel(totalXP);
  int get xpForCurrentLevel => LevelThresholds.xpForCurrentLevel(totalXP);
  int get xpForNextLevel => LevelThresholds.xpForNextLevel(totalXP);
  String get levelTitle => LevelThresholds.titleForLevel(level);
  String get levelEmoji => LevelThresholds.emojiForLevel(level);

  List<Achievement> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();
  List<Achievement> get lockedAchievements =>
      achievements.where((a) => !a.isUnlocked).toList();
  List<Badge> get earnedBadges => badges.where((b) => b.isEarned).toList();

  int get unlockedCount => unlockedAchievements.length;
  int get totalAchievements => achievements.length;

  GamificationState copyWith({
    int? totalXP,
    int? level,
    int? streak,
    List<Achievement>? achievements,
    List<Badge>? badges,
    DateTime? lastActivityDate,
    int? activitiesCompleted,
    Set<String>? exploredCategories,
  }) {
    return GamificationState(
      childId: childId,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      achievements: achievements ?? this.achievements,
      badges: badges ?? this.badges,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      activitiesCompleted: activitiesCompleted ?? this.activitiesCompleted,
      exploredCategories: exploredCategories ?? this.exploredCategories,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP EVENT — records what triggered an XP award (for display/history)
// ─────────────────────────────────────────────────────────────────────────────

enum XPEventType {
  lessonCompleted,
  activityCompleted,
  quizCompleted,
  perfectScore,
  dailyStreak,
  playActivity,
  coloringPage,
  aiBuddySession,
  achievementUnlocked,
  firstLogin,
}

class XPEvent {
  final XPEventType type;
  final int xpAmount;
  final DateTime timestamp;
  final String? label;

  const XPEvent({
    required this.type,
    required this.xpAmount,
    required this.timestamp,
    this.label,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT CATALOG — the master list of all achievements in the app
// ─────────────────────────────────────────────────────────────────────────────

class AchievementCatalog {
  AchievementCatalog._();

  static const Color _gold    = Color(0xFFFFD700);
  static const Color _fire    = Color(0xFFFF6B35);
  static const Color _purple  = Color(0xFF7C4DFF);
  static const Color _green   = Color(0xFF4CAF50);
  static const Color _blue    = Color(0xFF3F51B5);
  static const Color _pink    = Color(0xFFE91E63);

  /// Returns the full catalog of achievements with default (locked) state.
  static List<Achievement> get all => [
        const Achievement(
          id: AchievementIds.firstLesson,
          titleKey: 'achievementFirstLessonTitle',
          descriptionKey: 'achievementFirstLessonDesc',
          iconEmoji: '📖',
          xpReward: 50,
          badgeId: BadgeIds.starLearner,
        ),
        const Achievement(
          id: AchievementIds.firstActivity,
          titleKey: 'achievementFirstActivityTitle',
          descriptionKey: 'achievementFirstActivityDesc',
          iconEmoji: '🎯',
          xpReward: 30,
        ),
        const Achievement(
          id: AchievementIds.streak3,
          titleKey: 'achievementStreak3Title',
          descriptionKey: 'achievementStreak3Desc',
          iconEmoji: '🔥',
          xpReward: 60,
        ),
        const Achievement(
          id: AchievementIds.streak7,
          titleKey: 'achievementStreak7Title',
          descriptionKey: 'achievementStreak7Desc',
          iconEmoji: '🔥',
          xpReward: 150,
          badgeId: BadgeIds.streakHero,
        ),
        const Achievement(
          id: AchievementIds.streak30,
          titleKey: 'achievementStreak30Title',
          descriptionKey: 'achievementStreak30Desc',
          iconEmoji: '🌟',
          xpReward: 500,
        ),
        const Achievement(
          id: AchievementIds.activities10,
          titleKey: 'achievementActivities10Title',
          descriptionKey: 'achievementActivities10Desc',
          iconEmoji: '🏅',
          xpReward: 100,
          badgeId: BadgeIds.activityChampion,
        ),
        const Achievement(
          id: AchievementIds.activities50,
          titleKey: 'achievementActivities50Title',
          descriptionKey: 'achievementActivities50Desc',
          iconEmoji: '🏆',
          xpReward: 300,
        ),
        const Achievement(
          id: AchievementIds.level5,
          titleKey: 'achievementLevel5Title',
          descriptionKey: 'achievementLevel5Desc',
          iconEmoji: '⚡',
          xpReward: 200,
          badgeId: BadgeIds.levelMaster,
        ),
        const Achievement(
          id: AchievementIds.xp1000,
          titleKey: 'achievementXP1000Title',
          descriptionKey: 'achievementXP1000Desc',
          iconEmoji: '💰',
          xpReward: 100,
        ),
        const Achievement(
          id: AchievementIds.perfectScore,
          titleKey: 'achievementPerfectScoreTitle',
          descriptionKey: 'achievementPerfectScoreDesc',
          iconEmoji: '💯',
          xpReward: 80,
          badgeId: BadgeIds.quizMaster,
        ),
        const Achievement(
          id: AchievementIds.explorer,
          titleKey: 'achievementExplorerTitle',
          descriptionKey: 'achievementExplorerDesc',
          iconEmoji: '🗺️',
          xpReward: 120,
          badgeId: BadgeIds.explorer,
        ),
        const Achievement(
          id: AchievementIds.firstBadge,
          titleKey: 'achievementFirstBadgeTitle',
          descriptionKey: 'achievementFirstBadgeDesc',
          iconEmoji: '🎖️',
          xpReward: 50,
        ),
      ];

  /// Returns the full catalog of badges with default (unearned) state.
  static List<Badge> get allBadges => [
        const Badge(
          id: BadgeIds.starLearner,
          nameKey: 'badgeStarLearnerName',
          descriptionKey: 'badgeStarLearnerDesc',
          iconEmoji: '⭐',
          color: _gold,
        ),
        const Badge(
          id: BadgeIds.streakHero,
          nameKey: 'badgeStreakHeroName',
          descriptionKey: 'badgeStreakHeroDesc',
          iconEmoji: '🔥',
          color: _fire,
        ),
        const Badge(
          id: BadgeIds.activityChampion,
          nameKey: 'badgeActivityChampionName',
          descriptionKey: 'badgeActivityChampionDesc',
          iconEmoji: '🏅',
          color: _purple,
        ),
        const Badge(
          id: BadgeIds.quizMaster,
          nameKey: 'badgeQuizMasterName',
          descriptionKey: 'badgeQuizMasterDesc',
          iconEmoji: '💯',
          color: _blue,
        ),
        const Badge(
          id: BadgeIds.explorer,
          nameKey: 'badgeExplorerName',
          descriptionKey: 'badgeExplorerDesc',
          iconEmoji: '🗺️',
          color: _green,
        ),
        const Badge(
          id: BadgeIds.levelMaster,
          nameKey: 'badgeLevelMasterName',
          descriptionKey: 'badgeLevelMasterDesc',
          iconEmoji: '👑',
          color: _pink,
        ),
      ];
}
