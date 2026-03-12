// lib/core/providers/mood_provider.dart
//
// Riverpod state management for the Mood Tracking system.
// Follows the same pattern as gamification_provider.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:kinder_world/core/repositories/mood_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class MoodState {
  /// The mood string recorded today, or null if none yet.
  final String? todayMood;

  /// The 7 most recent mood entries (newest first).
  final List<MoodEntry> recentEntries;

  /// Mood → count map for the last 7 days.
  final Map<String, int> weekCounts;

  /// True while loading from Hive.
  final bool isLoading;

  /// True for one frame after a mood is saved (triggers UI feedback).
  final bool justSaved;

  /// Non-null when an error occurred.
  final String? error;

  const MoodState({
    this.todayMood,
    this.recentEntries = const [],
    this.weekCounts = const {},
    this.isLoading = false,
    this.justSaved = false,
    this.error,
  });

  MoodState copyWith({
    String? todayMood,
    List<MoodEntry>? recentEntries,
    Map<String, int>? weekCounts,
    bool? isLoading,
    bool? justSaved,
    String? error,
    bool clearTodayMood = false,
    bool clearError = false,
  }) {
    return MoodState(
      todayMood: clearTodayMood ? null : (todayMood ?? this.todayMood),
      recentEntries: recentEntries ?? this.recentEntries,
      weekCounts: weekCounts ?? this.weekCounts,
      isLoading: isLoading ?? this.isLoading,
      justSaved: justSaved ?? this.justSaved,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// True if the child has already recorded a mood today.
  bool get hasRecordedToday => todayMood != null;

  /// Returns the most frequent mood in the last 7 days, or null.
  String? get mostFrequentMood {
    if (weekCounts.isEmpty) return null;
    return (weekCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// Total entries in the last 7 days.
  int get weekEntryCount => weekCounts.values.fold(0, (s, v) => s + v);
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class MoodNotifier extends StateNotifier<MoodState> {
  final MoodRepository _repo;
  final ChildRepository _childRepo;
  final Logger _logger;

  MoodNotifier({
    required MoodRepository moodRepository,
    required ChildRepository childRepository,
    required Logger logger,
  })  : _repo = moodRepository,
        _childRepo = childRepository,
        _logger = logger,
        super(const MoodState(isLoading: true));

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Loads mood state for the given child. Called when child session starts.
  Future<void> loadForChild(String childId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final todayEntry = await _repo.getTodayEntry(childId);
      final recent = await _repo.getRecentEntries(childId, limit: 7);
      final counts = await _repo.getMoodCounts(childId, days: 7);

      state = MoodState(
        todayMood: todayEntry?.mood,
        recentEntries: recent,
        weekCounts: counts,
        isLoading: false,
      );
      _logger.d('MoodNotifier: loaded for $childId — today=${todayEntry?.mood}');
    } catch (e) {
      _logger.e('MoodNotifier.loadForChild error: $e');
      state = MoodState(isLoading: false, error: e.toString());
    }
  }

  // ── Record ─────────────────────────────────────────────────────────────────

  /// Records a new mood entry for the child and updates the child profile's
  /// `currentMood` field via [ChildRepository].
  Future<void> recordMood(String childId, String mood) async {
    try {
      final entry = MoodEntry(
        id: '${childId}_${DateTime.now().millisecondsSinceEpoch}',
        childId: childId,
        mood: mood,
        timestamp: DateTime.now(),
      );

      await _repo.addEntry(entry);

      // Also update the child profile's currentMood field
      await _childRepo.updateMood(childId, mood);

      // Refresh state
      final recent = await _repo.getRecentEntries(childId, limit: 7);
      final counts = await _repo.getMoodCounts(childId, days: 7);

      state = state.copyWith(
        todayMood: mood,
        recentEntries: recent,
        weekCounts: counts,
        justSaved: true,
      );

      _logger.i('MoodNotifier: recorded mood "$mood" for $childId');

      // Keep feedback visible briefly without slowing down follow-up actions.
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        state = state.copyWith(justSaved: false);
      }
    } catch (e) {
      _logger.e('MoodNotifier.recordMood error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Parent-side read ───────────────────────────────────────────────────────

  /// Returns mood counts for a specific child over [days] days.
  /// Used by the parent reports screen.
  Future<Map<String, int>> getMoodCountsForPeriod(
    String childId,
    int days,
  ) async {
    try {
      return await _repo.getMoodCounts(childId, days: days);
    } catch (e) {
      _logger.e('MoodNotifier.getMoodCountsForPeriod error: $e');
      return {};
    }
  }

  /// Returns the most frequent mood for a child over [days] days.
  Future<String?> getMostFrequentMood(String childId, {int days = 7}) async {
    try {
      return await _repo.getMostFrequentMood(childId, days: days);
    } catch (e) {
      _logger.e('MoodNotifier.getMostFrequentMood error: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Hive box provider for mood entries.
final moodBoxProvider = Provider<Box>((ref) => Hive.box('mood_entries'));

/// MoodRepository provider.
final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  final box = ref.watch(moodBoxProvider);
  final logger = ref.watch(loggerProvider);
  return MoodRepository(moodBox: box, logger: logger);
});

/// Main mood state notifier — scoped to the current child session.
final moodNotifierProvider =
    StateNotifierProvider.autoDispose<MoodNotifier, MoodState>((ref) {
  final moodRepo = ref.watch(moodRepositoryProvider);
  final childRepo = ref.watch(childRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  final notifier = MoodNotifier(
    moodRepository: moodRepo,
    childRepository: childRepo,
    logger: logger,
  );

  // Auto-load when child session is active
  final childId = ref.watch(currentChildIdProvider);
  if (childId != null) {
    notifier.loadForChild(childId);
  }

  return notifier;
});

// ── Convenience providers ──────────────────────────────────────────────────

/// Today's mood for the current child, or null.
final todayMoodProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(moodNotifierProvider).todayMood;
});

/// True if the child has already recorded a mood today.
final hasRecordedMoodTodayProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(moodNotifierProvider).hasRecordedToday;
});

/// The 7 most recent mood entries for the current child.
final recentMoodEntriesProvider =
    Provider.autoDispose<List<MoodEntry>>((ref) {
  return ref.watch(moodNotifierProvider).recentEntries;
});

/// Mood → count map for the last 7 days.
final moodWeekCountsProvider =
    Provider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(moodNotifierProvider).weekCounts;
});

/// Most frequent mood in the last 7 days.
final mostFrequentMoodProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(moodNotifierProvider).mostFrequentMood;
});

/// True while mood state is loading.
final moodLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(moodNotifierProvider).isLoading;
});

/// True for ~2 seconds after a mood is saved (for UI feedback).
final moodJustSavedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(moodNotifierProvider).justSaved;
});

/// Async mood counts for a specific child (used by parent reports).
/// Family provider keyed by (childId, days).
final childMoodCountsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, ({String childId, int days})>((ref, params) async {
  final repo = ref.watch(moodRepositoryProvider);
  return repo.getMoodCounts(params.childId, days: params.days);
});

/// Async most-frequent mood for a specific child (parent reports).
final childMostFrequentMoodProvider = FutureProvider.autoDispose
    .family<String?, ({String childId, int days})>((ref, params) async {
  final repo = ref.watch(moodRepositoryProvider);
  return repo.getMostFrequentMood(params.childId, days: params.days);
});
