// lib/core/providers/gamification_provider.dart
//
// Riverpod providers for the Gamification system.
// Exposes: gamificationServiceProvider, gamificationStateProvider,
//          pendingRewardProvider, and convenience providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:kinder_world/core/services/gamification_service.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INFRASTRUCTURE PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the Hive box for gamification data.
/// The box must be opened in app.dart before this is accessed.
final gamificationBoxProvider = Provider<Box>((ref) {
  return Hive.box('gamification_data');
});

/// Provides the [GamificationRepository] singleton.
final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  final box = ref.watch(gamificationBoxProvider);
  return GamificationRepository(
    gamificationBox: box,
    logger: Logger(),
  );
});

/// Provides the [GamificationService] singleton.
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final gamificationRepo = ref.watch(gamificationRepositoryProvider);
  final childRepo = ref.watch(childRepositoryProvider);
  return GamificationService(
    gamificationRepository: gamificationRepo,
    childRepository: childRepo,
    logger: Logger(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION STATE PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Loads and caches the full [GamificationState] for the currently active child.
/// Auto-disposes when the child session ends.
final gamificationStateProvider =
    StateNotifierProvider.autoDispose<GamificationNotifier, GamificationNotifierState>(
  (ref) {
    final service = ref.watch(gamificationServiceProvider);
    final childId = ref.watch(currentChildIdProvider);
    final notifier = GamificationNotifier(service: service);
    if (childId != null) {
      notifier.loadForChild(childId);
    }
    return notifier;
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION NOTIFIER STATE
// ─────────────────────────────────────────────────────────────────────────────

class GamificationNotifierState {
  final GamificationState? gamificationState;
  final bool isLoading;
  final String? error;

  /// Queued rewards waiting to be shown to the user (level-up, achievements).
  final ActivityResult? pendingReward;

  const GamificationNotifierState({
    this.gamificationState,
    this.isLoading = false,
    this.error,
    this.pendingReward,
  });

  GamificationNotifierState copyWith({
    GamificationState? gamificationState,
    bool? isLoading,
    String? error,
    ActivityResult? pendingReward,
    bool clearPendingReward = false,
    bool clearError = false,
  }) {
    return GamificationNotifierState(
      gamificationState: gamificationState ?? this.gamificationState,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingReward:
          clearPendingReward ? null : (pendingReward ?? this.pendingReward),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class GamificationNotifier
    extends StateNotifier<GamificationNotifierState> {
  final GamificationService _service;

  GamificationNotifier({required GamificationService service})
      : _service = service,
        super(const GamificationNotifierState(isLoading: false));

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadForChild(String childId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final gamState = await _service.loadState(childId);
      state = state.copyWith(
        gamificationState: gamState,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Record Activity ───────────────────────────────────────────────────────

  /// Records a completed activity and updates state.
  /// The returned [ActivityResult] is also stored as [pendingReward]
  /// so the UI can show level-up / achievement dialogs.
  Future<ActivityResult> recordActivity({
    required String childId,
    required ActivityType type,
    String? category,
    int score = 0,
  }) async {
    try {
      final result = await _service.recordActivity(
        childId: childId,
        type: type,
        category: category,
        score: score,
      );

      // Reload state to reflect new XP/level/streak/achievements
      final newGamState = await _service.loadState(childId);

      state = state.copyWith(
        gamificationState: newGamState,
        pendingReward: result.hasRewards || result.leveledUp ? result : null,
      );

      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return ActivityResult.empty(
        state.gamificationState?.totalXP ?? 0,
        state.gamificationState?.level ?? 1,
        state.gamificationState?.streak ?? 0,
      );
    }
  }

  // ── Dismiss Reward ────────────────────────────────────────────────────────

  /// Called after the UI has shown the reward dialog/banner.
  void dismissPendingReward() {
    state = state.copyWith(clearPendingReward: true);
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> refresh(String childId) => loadForChild(childId);

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> resetForChild(String childId) async {
    await _service.resetChild(childId);
    await loadForChild(childId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVENIENCE PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// The current child's [GamificationState], or null if not loaded.
final currentGamificationStateProvider = Provider.autoDispose<GamificationState?>((ref) {
  return ref.watch(gamificationStateProvider).gamificationState;
});

/// Whether gamification data is loading.
final gamificationLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(gamificationStateProvider).isLoading;
});

/// Pending reward (level-up / achievement unlock) waiting to be shown.
final pendingRewardProvider = Provider.autoDispose<ActivityResult?>((ref) {
  return ref.watch(gamificationStateProvider).pendingReward;
});

/// The current child's earned badges only.
final earnedBadgesProvider = Provider.autoDispose<List<Badge>>((ref) {
  final state = ref.watch(currentGamificationStateProvider);
  return state?.earnedBadges ?? [];
});

/// The current child's unlocked achievements only.
final unlockedAchievementsProvider = Provider.autoDispose<List<Achievement>>((ref) {
  final state = ref.watch(currentGamificationStateProvider);
  return state?.unlockedAchievements ?? [];
});

/// All achievements (locked + unlocked) for the current child.
final allAchievementsProvider = Provider.autoDispose<List<Achievement>>((ref) {
  final state = ref.watch(currentGamificationStateProvider);
  return state?.achievements ?? AchievementCatalog.all;
});

/// All badges (earned + unearned) for the current child.
final allBadgesProvider = Provider.autoDispose<List<Badge>>((ref) {
  final state = ref.watch(currentGamificationStateProvider);
  return state?.badges ?? AchievementCatalog.allBadges;
});

/// Current XP total.
final currentXPProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(currentGamificationStateProvider)?.totalXP ?? 0;
});

/// Current level.
final currentLevelProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(currentGamificationStateProvider)?.level ?? 1;
});

/// Current streak.
final currentStreakProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(currentGamificationStateProvider)?.streak ?? 0;
});

/// Level progress fraction (0.0–1.0).
final levelProgressProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(currentGamificationStateProvider)?.levelProgress ?? 0.0;
});

/// XP needed to reach the next level.
final xpToNextLevelProvider = Provider.autoDispose<int>((ref) {
  final xp = ref.watch(currentXPProvider);
  return LevelThresholds.xpToNextLevel(xp);
});

/// Gamification state for a *specific* child (used in parent reports).
final childGamificationStateProvider =
    FutureProvider.autoDispose.family<GamificationState, String>((ref, childId) async {
  final service = ref.watch(gamificationServiceProvider);
  return service.loadState(childId);
});
