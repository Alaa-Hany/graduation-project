import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';

// ==================== CHILD SESSION STATE ====================

/// Child session state
class ChildSessionState {
  static const Object _sentinel = Object();
  final String? childId;
  final ChildProfile? childProfile;
  final bool isLoading;
  final String? error;

  const ChildSessionState({
    this.childId,
    this.childProfile,
    this.isLoading = false,
    this.error,
  });

  ChildSessionState copyWith({
    String? childId,
    ChildProfile? childProfile,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ChildSessionState(
      childId: childId ?? this.childId,
      childProfile: childProfile ?? this.childProfile,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  bool get hasActiveSession => childId != null;
  bool get hasProfile => childProfile != null;
}

// ==================== CHILD SESSION CONTROLLER ====================

/// Child session controller - SINGLE SOURCE OF TRUTH
class ChildSessionController extends StateNotifier<ChildSessionState> {
  final ChildRepository _childRepository;
  final SecureStorage _secureStorage;
  final Logger _logger;

  ChildSessionController({
    required ChildRepository childRepository,
    required SecureStorage secureStorage,
    required Logger logger,
  })  : _childRepository = childRepository,
        _secureStorage = secureStorage,
        _logger = logger,
        super(const ChildSessionState(isLoading: true)) {
    _restorePersistedSession();
  }

  Future<void> _restorePersistedSession() async {
    try {
      final role = _secureStorage.hasCachedSessionSnapshot
          ? _secureStorage.cachedSessionSnapshot.userRole
          : await _secureStorage.getUserRole();
      final childId = _secureStorage.hasCachedSessionSnapshot
          ? _secureStorage.cachedSessionSnapshot.childSession
          : await _secureStorage.getChildSession();

      if (role != 'child' || childId == null || childId.isEmpty) {
        state = const ChildSessionState();
        return;
      }

      final profile = await _childRepository.getChildProfile(childId);
      if (profile == null) {
        await _secureStorage.clearAuthOnly();
        state = const ChildSessionState();
        return;
      }

      state = ChildSessionState(
        childId: childId,
        childProfile: profile,
        isLoading: false,
      );
      _logger.d('Child session restored: ${profile.name}');
    } catch (e) {
      _logger.e('Error restoring child session: $e');
      state = const ChildSessionState();
    }
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Start child session
  Future<bool> startChildSession({
    required String childId,
    ChildProfile? childProfile,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load profile if not provided
      final profile =
          childProfile ?? await _childRepository.getChildProfile(childId);

      if (profile == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Child profile not found',
        );
        return false;
      }

      state = ChildSessionState(
        childId: childId,
        childProfile: profile,
        isLoading: false,
      );
      await _secureStorage.saveChildSession(childId);

      _logger.d('Child session started: ${profile.name}');
      return true;
    } catch (e) {
      _logger.e('Error starting child session: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start child session',
      );
      return false;
    }
  }

  /// End child session
  Future<bool> endChildSession() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _secureStorage.clearChildSession();
      state = const ChildSessionState(
        childId: null,
        childProfile: null,
        isLoading: false,
      );

      _logger.d('Child session ended');
      return true;
    } catch (e) {
      _logger.e('Error ending child session: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to end child session',
      );
      return false;
    }
  }

  // ==================== PROFILE MANAGEMENT ====================

  /// Load child profile
  Future<bool> loadChildProfile(String childId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final child = await _childRepository.getChildProfile(childId);

      if (child != null) {
        state = ChildSessionState(
          childId: childId,
          childProfile: child,
          isLoading: false,
        );

        _logger.d('Child profile loaded: ${child.name}');
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Child profile not found',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error loading child profile: $childId, $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load child profile',
      );
      return false;
    }
  }

  /// Update child profile
  Future<bool> updateChildProfile(ChildProfile updatedProfile) async {
    try {
      final updated = await _childRepository.updateChildProfile(updatedProfile);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Child profile updated: ${updated.name}');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error updating child profile: $e');
      return false;
    }
  }

  /// Refresh current profile
  Future<void> refreshProfile() async {
    if (state.childId == null) return;

    try {
      final child = await _childRepository.getChildProfile(state.childId!);
      if (child != null) {
        state = state.copyWith(childProfile: child);
      }
    } catch (e) {
      _logger.e('Error refreshing profile: $e');
    }
  }

  // ==================== PROGRESS OPERATIONS ====================

  /// Add XP to current child
  Future<bool> addXP(int xpAmount) async {
    if (!state.hasActiveSession || state.childProfile == null) {
      _logger.w('Cannot add XP: No active child session');
      return false;
    }

    try {
      final updated = await _childRepository.addXP(state.childId!, xpAmount);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('XP added: $xpAmount, new total: ${updated.xp}');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error adding XP: $e');
      return false;
    }
  }

  /// Update streak for current child
  Future<bool> updateStreak() async {
    if (!state.hasActiveSession || state.childProfile == null) {
      _logger.w('Cannot update streak: No active child session');
      return false;
    }

    try {
      final updated = await _childRepository.updateStreak(state.childId!);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Streak updated: ${updated.streak} days');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error updating streak: $e');
      return false;
    }
  }

  /// Complete activity for current child
  Future<bool> completeActivity({
    required int xpEarned,
    required int timeSpent,
  }) async {
    if (!state.hasActiveSession || state.childProfile == null) {
      _logger.w('Cannot complete activity: No active child session');
      return false;
    }

    try {
      final updated = await _childRepository.completeActivity(
        childId: state.childId!,
        xpEarned: xpEarned,
        timeSpent: timeSpent,
      );

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Activity completed: +$xpEarned XP, +$timeSpent min');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error completing activity: $e');
      return false;
    }
  }

  // ==================== FAVORITES & INTERESTS ====================

  /// Add activity to favorites
  Future<bool> addToFavorites(String activityId) async {
    if (!state.hasActiveSession) return false;

    try {
      final updated =
          await _childRepository.addToFavorites(state.childId!, activityId);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Added to favorites: $activityId');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove activity from favorites
  Future<bool> removeFromFavorites(String activityId) async {
    if (!state.hasActiveSession) return false;

    try {
      final updated = await _childRepository.removeFromFavorites(
          state.childId!, activityId);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Removed from favorites: $activityId');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error removing from favorites: $e');
      return false;
    }
  }

  /// Update child interests
  Future<bool> updateInterests(List<String> newInterests) async {
    if (!state.hasActiveSession) return false;

    try {
      final updated =
          await _childRepository.updateInterests(state.childId!, newInterests);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Interests updated: $newInterests');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error updating interests: $e');
      return false;
    }
  }

  // ==================== MOOD & LEARNING STYLE ====================

  /// Update child mood
  Future<bool> updateMood(String mood) async {
    if (!state.hasActiveSession) return false;

    try {
      final updated = await _childRepository.updateMood(state.childId!, mood);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Mood updated: $mood');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error updating mood: $e');
      return false;
    }
  }

  /// Update learning style
  Future<bool> updateLearningStyle(String learningStyle) async {
    if (!state.hasActiveSession) return false;

    try {
      final updated = await _childRepository.updateLearningStyle(
          state.childId!, learningStyle);

      if (updated != null) {
        state = state.copyWith(childProfile: updated);
        _logger.d('Learning style updated: $learningStyle');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error updating learning style: $e');
      return false;
    }
  }

  // ==================== STATISTICS ====================

  /// Get child statistics
  Future<Map<String, dynamic>> getChildStats() async {
    if (!state.hasActiveSession) return {};

    try {
      return await _childRepository.getChildStats(state.childId!);
    } catch (e) {
      _logger.e('Error getting child stats: $e');
      return {};
    }
  }

  // ==================== ERROR HANDLING ====================

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ==================== PROVIDERS ====================

/// Main child repository provider
final childRepositoryProvider = Provider<ChildRepository>((ref) {
  final childBox = Hive.box('child_profiles');
  final logger = ref.watch(loggerProvider);

  return ChildRepository(
    childBox: childBox,
    logger: logger,
  );
});

/// Main child session controller provider - SINGLE SOURCE OF TRUTH
final childSessionControllerProvider =
    StateNotifierProvider<ChildSessionController, ChildSessionState>((ref) {
  final childRepository = ref.watch(childRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);

  return ChildSessionController(
    childRepository: childRepository,
    secureStorage: secureStorage,
    logger: logger,
  );
});

// ==================== HELPER PROVIDERS ====================

/// Check if there's an active child session
final hasChildSessionProvider = Provider<bool>((ref) {
  return ref.watch(childSessionControllerProvider).hasActiveSession;
});

/// Get current child profile
final currentChildProvider = Provider<ChildProfile?>((ref) {
  return ref.watch(childSessionControllerProvider).childProfile;
});

/// Get current child ID
final currentChildIdProvider = Provider<String?>((ref) {
  return ref.watch(childSessionControllerProvider).childId;
});

/// Get child loading state
final childLoadingProvider = Provider<bool>((ref) {
  return ref.watch(childSessionControllerProvider).isLoading;
});

/// Get child error
final childErrorProvider = Provider<String?>((ref) {
  return ref.watch(childSessionControllerProvider).error;
});

/// Get child statistics (async)
final childStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final controller = ref.watch(childSessionControllerProvider.notifier);
  return await controller.getChildStats();
});
