import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:logger/logger.dart';

/// Repository for child profile operations
class ChildRepository {
  final Box _childBox;
  final Logger _logger;
  final Map<String, ChildProfile> _profileCache = <String, ChildProfile>{};
  bool _didWarmAllProfiles = false;

  ChildRepository({
    required Box childBox,
    required Logger logger,
  })  : _childBox = childBox,
        _logger = logger;

  ChildProfile? _decodeProfile(dynamic data) {
    if (data == null) return null;
    final Map<String, dynamic> json = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : Map<String, dynamic>.from(data as Map);
    return ChildProfile.fromJson(json);
  }

  void _cacheProfile(ChildProfile profile) {
    _profileCache[profile.id] = profile;
  }

  Future<List<ChildProfile>> _loadAllProfiles() async {
    if (_didWarmAllProfiles) {
      return _profileCache.values.toList(growable: false);
    }

    final children = <ChildProfile>[];
    for (final key in _childBox.keys) {
      final data = _childBox.get(key);
      if (data == null) continue;
      try {
        final profile = _decodeProfile(data);
        if (profile == null) continue;
        children.add(profile);
        _cacheProfile(profile);
      } catch (e) {
        _logger.e('Error parsing child: $key, $e');
      }
    }
    _didWarmAllProfiles = true;
    return children;
  }

  // ==================== CRUD OPERATIONS ====================

  /// Get child profile by ID
  Future<ChildProfile?> getChildProfile(String childId) async {
    try {
      final cached = _profileCache[childId];
      if (cached != null) {
        return cached;
      }
      final data = _childBox.get(childId);
      
      if (data == null) {
        _logger.w('Child profile not found: $childId');
        return null;
      }

      final profile = _decodeProfile(data);
      if (profile != null) {
        _cacheProfile(profile);
      }
      return profile;
    } catch (e) {
      _logger.e('Error getting child profile: $childId, $e');
      return null;
    }
  }

  /// Get all child profiles for a parent
  Future<List<ChildProfile>> getChildrenForParent(String parentId) async {
    try {
      final children = (await _loadAllProfiles())
          .where((child) => child.parentId == parentId)
          .toList(growable: false);
      _logger.d('Found ${children.length} children for parent: $parentId');
      return children;
    } catch (e) {
      _logger.e('Error getting children for parent: $parentId, $e');
      return [];
    }
  }

  Future<void> linkChildrenToParent({
    required String parentId,
    required String parentEmail,
  }) async {
    if (parentId.isEmpty || parentEmail.isEmpty) return;
    try {
      for (var key in _childBox.keys) {
        final data = _childBox.get(key);
        if (data == null) continue;
        try {
          final json = data is String
              ? jsonDecode(data)
              : Map<String, dynamic>.from(data);
          final child = ChildProfile.fromJson(json);
          if (child.parentEmail == parentEmail && child.parentId != parentId) {
            final updated = child.copyWith(parentId: parentId);
            await _childBox.put(updated.id, updated.toJson());
            _cacheProfile(updated);
          }
        } catch (e) {
          _logger.e('Error linking child to parent: $key, $e');
        }
      }
    } catch (e) {
      _logger.e('Error linking children to parent: $e');
    }
  }

  /// Create new child profile
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async {
    try {
      final json = profile.toJson();
      await _childBox.put(profile.id, json);
      _cacheProfile(profile);
      
      _logger.d('Child profile created: ${profile.id}');
      return profile;
    } catch (e) {
      _logger.e('Error creating child profile: $e');
      return null;
    }
  }

  /// Update child profile
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    try {
      final updated = profile.copyWith(
        updatedAt: DateTime.now(),
      );
      
      final json = updated.toJson();
      await _childBox.put(updated.id, json);
      _cacheProfile(updated);
      
      _logger.d('Child profile updated: ${updated.id}');
      return updated;
    } catch (e) {
      _logger.e('Error updating child profile: $e');
      return null;
    }
  }

  /// Delete child profile
  Future<bool> deleteChildProfile(String childId) async {
    try {
      await _childBox.delete(childId);
      _profileCache.remove(childId);
      _logger.d('Child profile deleted: $childId');
      return true;
    } catch (e) {
      _logger.e('Error deleting child profile: $childId, $e');
      return false;
    }
  }

  // ==================== PROGRESS OPERATIONS ====================

  /// Add XP to child profile
  Future<ChildProfile?> addXP(String childId, int xpAmount) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final newXP = child.xp + xpAmount;
      final newLevel = (newXP / 1000).floor() + 1;

      final updated = child.copyWith(
        xp: newXP,
        level: newLevel > child.level ? newLevel : child.level,
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error adding XP: $childId, $e');
      return null;
    }
  }

  /// Update streak
  Future<ChildProfile?> updateStreak(String childId) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final now = DateTime.now();
      final lastSession = child.lastSession;

      int newStreak = child.streak;

      if (lastSession == null) {
        // First session
        newStreak = 1;
      } else {
        final daysDifference = now.difference(lastSession).inDays;
        
        if (daysDifference == 0) {
          // Same day, streak unchanged
          newStreak = child.streak;
        } else if (daysDifference == 1) {
          // Consecutive day, increment streak
          newStreak = child.streak + 1;
        } else {
          // Streak broken, reset to 1
          newStreak = 1;
        }
      }

      final updated = child.copyWith(
        streak: newStreak,
        lastSession: now,
        updatedAt: now,
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error updating streak: $childId, $e');
      return null;
    }
  }

  /// Complete activity
  Future<ChildProfile?> completeActivity({
    required String childId,
    required int xpEarned,
    required int timeSpent,
  }) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final updated = child.copyWith(
        xp: child.xp + xpEarned,
        totalTimeSpent: child.totalTimeSpent + timeSpent,
        activitiesCompleted: child.activitiesCompleted + 1,
        updatedAt: DateTime.now(),
      );

      // Check for level up
      final newLevel = (updated.xp / 1000).floor() + 1;
      final finalUpdated = updated.copyWith(
        level: newLevel > updated.level ? newLevel : updated.level,
      );

      return await updateChildProfile(finalUpdated);
    } catch (e) {
      _logger.e('Error completing activity: $childId, $e');
      return null;
    }
  }

  // ==================== FAVORITES & INTERESTS ====================

  /// Add activity to favorites
  Future<ChildProfile?> addToFavorites(String childId, String activityId) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      if (child.favorites.contains(activityId)) {
        _logger.d('Activity already in favorites: $activityId');
        return child;
      }

      final updated = child.copyWith(
        favorites: [...child.favorites, activityId],
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error adding to favorites: $childId, $e');
      return null;
    }
  }

  /// Remove activity from favorites
  Future<ChildProfile?> removeFromFavorites(String childId, String activityId) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final updated = child.copyWith(
        favorites: child.favorites.where((id) => id != activityId).toList(),
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error removing from favorites: $childId, $e');
      return null;
    }
  }

  /// Update child interests
  Future<ChildProfile?> updateInterests(String childId, List<String> newInterests) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final updated = child.copyWith(
        interests: newInterests,
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error updating interests: $childId, $e');
      return null;
    }
  }

  // ==================== MOOD & LEARNING STYLE ====================

  /// Update child mood
  Future<ChildProfile?> updateMood(String childId, String mood) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final updated = child.copyWith(
        currentMood: mood,
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error updating mood: $childId, $e');
      return null;
    }
  }

  /// Update learning style
  Future<ChildProfile?> updateLearningStyle(String childId, String learningStyle) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return null;

      final updated = child.copyWith(
        learningStyle: learningStyle,
        updatedAt: DateTime.now(),
      );

      return await updateChildProfile(updated);
    } catch (e) {
      _logger.e('Error updating learning style: $childId, $e');
      return null;
    }
  }

  // ==================== STATISTICS ====================

  /// Get child statistics
  Future<Map<String, dynamic>> getChildStats(String childId) async {
    try {
      final child = await getChildProfile(childId);
      if (child == null) return {};

      return {
        'totalXP': child.xp,
        'currentLevel': child.level,
        'currentStreak': child.streak,
        'totalActivities': child.activitiesCompleted,
        'totalTimeSpent': child.totalTimeSpent,
        'averageTimePerActivity': child.activitiesCompleted > 0
            ? child.totalTimeSpent / child.activitiesCompleted
            : 0,
        'nextLevelXP': child.nextLevelXP,
        'xpProgress': child.xpProgress,
        'favoriteCount': child.favorites.length,
        'interestCount': child.interests.length,
      };
    } catch (e) {
      _logger.e('Error getting child stats: $childId, $e');
      return {};
    }
  }

  // ==================== HELPERS ====================

  /// Check if child exists
  Future<bool> childExists(String childId) async {
    try {
      return _childBox.containsKey(childId);
    } catch (e) {
      _logger.e('Error checking child existence: $childId, $e');
      return false;
    }
  }

  /// Get total children count
  Future<int> getTotalChildrenCount() async {
    try {
      return _childBox.length;
    } catch (e) {
      _logger.e('Error getting total children count: $e');
      return 0;
    }
  }

  /// Get all child profiles (unfiltered)
  Future<List<ChildProfile>> getAllChildProfiles() async {
    try {
      final children = await _loadAllProfiles();
      _logger.d('Found ${children.length} children');
      return List<ChildProfile>.unmodifiable(children);
    } catch (e) {
      _logger.e('Error getting all children: $e');
      return [];
    }
  }

  /// Compatibility wrapper for getChildProfilesForParent
  Future<List<ChildProfile>> getChildProfilesForParent(String parentId) async {
    return await getChildrenForParent(parentId);
  }
}
