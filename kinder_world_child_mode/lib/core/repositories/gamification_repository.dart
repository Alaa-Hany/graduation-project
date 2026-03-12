// lib/core/repositories/gamification_repository.dart
//
// Hive-backed persistence layer for the Gamification system.
// Stores per-child achievements, badges, and gamification metadata.

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORAGE KEYS
// ─────────────────────────────────────────────────────────────────────────────

class _Keys {
  _Keys._();

  static String achievements(String childId) => 'achievements_$childId';
  static String badges(String childId)        => 'badges_$childId';
  static String metadata(String childId)      => 'meta_$childId';
  static String categories(String childId)    => 'categories_$childId';
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class GamificationRepository {
  final Box _box;
  final Logger _logger;

  GamificationRepository({
    required Box gamificationBox,
    required Logger logger,
  })  : _box = gamificationBox,
        _logger = logger;

  // ══════════════════════════════════════════════════════════════════════════
  // ACHIEVEMENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the full achievement list for a child, merging catalog defaults
  /// with any persisted unlock state.
  Future<List<Achievement>> getAchievements(String childId) async {
    try {
      final raw = _box.get(_Keys.achievements(childId));
      if (raw == null) {
        // First time — return catalog defaults (all locked)
        return AchievementCatalog.all;
      }

      final List<dynamic> jsonList = raw is String
          ? List<dynamic>.from(jsonDecode(raw) as List)
          : List<dynamic>.from(raw as List);

      // Build a map of persisted state keyed by id
      final Map<String, Achievement> persisted = {};
      for (final item in jsonList) {
        final a = Achievement.fromJson(Map<String, dynamic>.from(item as Map));
        persisted[a.id] = a;
      }

      // Merge: catalog defines structure, persisted defines unlock state
      return AchievementCatalog.all.map((catalogItem) {
        final saved = persisted[catalogItem.id];
        if (saved != null) {
          return catalogItem.copyWith(
            isUnlocked: saved.isUnlocked,
            unlockedAt: saved.unlockedAt,
          );
        }
        return catalogItem;
      }).toList();
    } catch (e) {
      _logger.e('GamificationRepository.getAchievements error: $e');
      return AchievementCatalog.all;
    }
  }

  /// Persists the full achievement list for a child.
  Future<void> saveAchievements(
      String childId, List<Achievement> achievements) async {
    try {
      final jsonList = achievements.map((a) => a.toJson()).toList();
      await _box.put(_Keys.achievements(childId), jsonEncode(jsonList));
    } catch (e) {
      _logger.e('GamificationRepository.saveAchievements error: $e');
    }
  }

  /// Marks a single achievement as unlocked and persists.
  /// Returns the updated achievement, or null if not found.
  Future<Achievement?> unlockAchievement(
      String childId, String achievementId) async {
    try {
      final achievements = await getAchievements(childId);
      final idx = achievements.indexWhere((a) => a.id == achievementId);
      if (idx == -1) {
        _logger.w('Achievement not found: $achievementId');
        return null;
      }

      final existing = achievements[idx];
      if (existing.isUnlocked) {
        _logger.d('Achievement already unlocked: $achievementId');
        return existing; // idempotent
      }

      final updated = existing.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      );
      achievements[idx] = updated;
      await saveAchievements(childId, achievements);

      _logger.i('Achievement unlocked: $achievementId for child $childId');
      return updated;
    } catch (e) {
      _logger.e('GamificationRepository.unlockAchievement error: $e');
      return null;
    }
  }

  /// Returns only unlocked achievements for a child.
  Future<List<Achievement>> getUnlockedAchievements(String childId) async {
    final all = await getAchievements(childId);
    return all.where((a) => a.isUnlocked).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BADGES
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the full badge list for a child, merging catalog defaults
  /// with any persisted earned state.
  Future<List<Badge>> getBadges(String childId) async {
    try {
      final raw = _box.get(_Keys.badges(childId));
      if (raw == null) {
        return AchievementCatalog.allBadges;
      }

      final List<dynamic> jsonList = raw is String
          ? List<dynamic>.from(jsonDecode(raw) as List)
          : List<dynamic>.from(raw as List);

      final Map<String, Badge> persisted = {};
      for (final item in jsonList) {
        final b = Badge.fromJson(Map<String, dynamic>.from(item as Map));
        persisted[b.id] = b;
      }

      return AchievementCatalog.allBadges.map((catalogItem) {
        final saved = persisted[catalogItem.id];
        if (saved != null) {
          return catalogItem.copyWith(
            isEarned: saved.isEarned,
            earnedAt: saved.earnedAt,
          );
        }
        return catalogItem;
      }).toList();
    } catch (e) {
      _logger.e('GamificationRepository.getBadges error: $e');
      return AchievementCatalog.allBadges;
    }
  }

  /// Persists the full badge list for a child.
  Future<void> saveBadges(String childId, List<Badge> badges) async {
    try {
      final jsonList = badges.map((b) => b.toJson()).toList();
      await _box.put(_Keys.badges(childId), jsonEncode(jsonList));
    } catch (e) {
      _logger.e('GamificationRepository.saveBadges error: $e');
    }
  }

  /// Marks a badge as earned and persists.
  /// Returns the updated badge, or null if not found.
  Future<Badge?> earnBadge(String childId, String badgeId) async {
    try {
      final badges = await getBadges(childId);
      final idx = badges.indexWhere((b) => b.id == badgeId);
      if (idx == -1) {
        _logger.w('Badge not found: $badgeId');
        return null;
      }

      final existing = badges[idx];
      if (existing.isEarned) {
        _logger.d('Badge already earned: $badgeId');
        return existing;
      }

      final updated = existing.copyWith(
        isEarned: true,
        earnedAt: DateTime.now(),
      );
      badges[idx] = updated;
      await saveBadges(childId, badges);

      _logger.i('Badge earned: $badgeId for child $childId');
      return updated;
    } catch (e) {
      _logger.e('GamificationRepository.earnBadge error: $e');
      return null;
    }
  }

  /// Returns only earned badges for a child.
  Future<List<Badge>> getEarnedBadges(String childId) async {
    final all = await getBadges(childId);
    return all.where((b) => b.isEarned).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA (activities count, last activity date, explored categories)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _getMeta(String childId) async {
    try {
      final raw = _box.get(_Keys.metadata(childId));
      if (raw == null) return {};
      return raw is String
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      _logger.e('GamificationRepository._getMeta error: $e');
      return {};
    }
  }

  Future<void> _saveMeta(String childId, Map<String, dynamic> meta) async {
    try {
      await _box.put(_Keys.metadata(childId), jsonEncode(meta));
    } catch (e) {
      _logger.e('GamificationRepository._saveMeta error: $e');
    }
  }

  /// Increments the activities-completed counter and returns the new count.
  Future<int> incrementActivitiesCompleted(String childId) async {
    final meta = await _getMeta(childId);
    final current = (meta['activitiesCompleted'] as num?)?.toInt() ?? 0;
    final updated = current + 1;
    meta['activitiesCompleted'] = updated;
    meta['lastActivityDate'] = DateTime.now().toIso8601String();
    await _saveMeta(childId, meta);
    return updated;
  }

  /// Returns the stored activities-completed count.
  Future<int> getActivitiesCompleted(String childId) async {
    final meta = await _getMeta(childId);
    return (meta['activitiesCompleted'] as num?)?.toInt() ?? 0;
  }

  /// Returns the last activity date, or null.
  Future<DateTime?> getLastActivityDate(String childId) async {
    final meta = await _getMeta(childId);
    final raw = meta['lastActivityDate'] as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPLORED CATEGORIES (for Explorer achievement)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Set<String>> getExploredCategories(String childId) async {
    try {
      final raw = _box.get(_Keys.categories(childId));
      if (raw == null) return {};
      final List<dynamic> list = raw is String
          ? List<dynamic>.from(jsonDecode(raw) as List)
          : List<dynamic>.from(raw as List);
      return list.map((e) => e.toString()).toSet();
    } catch (e) {
      _logger.e('GamificationRepository.getExploredCategories error: $e');
      return {};
    }
  }

  /// Adds a category to the explored set. Returns the updated set.
  Future<Set<String>> addExploredCategory(
      String childId, String category) async {
    try {
      final categories = await getExploredCategories(childId);
      categories.add(category);
      await _box.put(
          _Keys.categories(childId), jsonEncode(categories.toList()));
      return categories;
    } catch (e) {
      _logger.e('GamificationRepository.addExploredCategory error: $e');
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FULL STATE LOAD
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads the complete GamificationState for a child.
  /// Requires the child's current XP, level, and streak from ChildProfile.
  Future<GamificationState> loadState({
    required String childId,
    required int xp,
    required int level,
    required int streak,
  }) async {
    final achievements = await getAchievements(childId);
    final badges = await getBadges(childId);
    final activitiesCompleted = await getActivitiesCompleted(childId);
    final lastActivityDate = await getLastActivityDate(childId);
    final exploredCategories = await getExploredCategories(childId);

    return GamificationState(
      childId: childId,
      totalXP: xp,
      level: level,
      streak: streak,
      achievements: achievements,
      badges: badges,
      activitiesCompleted: activitiesCompleted,
      lastActivityDate: lastActivityDate,
      exploredCategories: exploredCategories,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESET (for testing / profile reset)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> resetForChild(String childId) async {
    try {
      await _box.delete(_Keys.achievements(childId));
      await _box.delete(_Keys.badges(childId));
      await _box.delete(_Keys.metadata(childId));
      await _box.delete(_Keys.categories(childId));
      _logger.i('Gamification data reset for child $childId');
    } catch (e) {
      _logger.e('GamificationRepository.resetForChild error: $e');
    }
  }
}
