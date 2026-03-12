// lib/core/repositories/mood_repository.dart
//
// Hive-backed persistence layer for mood entries.
// Stores per-child mood history as JSON lists in the 'mood_entries' box.
// No TypeAdapters — pure JSON maps, consistent with project pattern.

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORAGE KEYS
// ─────────────────────────────────────────────────────────────────────────────

class _MoodKeys {
  _MoodKeys._();

  /// Key for the JSON-encoded list of MoodEntry objects for a child.
  static String entries(String childId) => 'entries_$childId';
}

// ─────────────────────────────────────────────────────────────────────────────
// MOOD REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class MoodRepository {
  final Box _box;
  final Logger _logger;

  MoodRepository({
    required Box moodBox,
    required Logger logger,
  })  : _box = moodBox,
        _logger = logger;

  // ══════════════════════════════════════════════════════════════════════════
  // WRITE
  // ══════════════════════════════════════════════════════════════════════════

  /// Persists a new [MoodEntry] for the given child.
  /// Prepends to the list so the most recent entry is always first.
  Future<MoodEntry> addEntry(MoodEntry entry) async {
    try {
      final existing = await getEntriesForChild(entry.childId);
      // Prepend new entry
      final updated = [entry, ...existing];
      await _box.put(
        _MoodKeys.entries(entry.childId),
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
      _logger.d('MoodRepository: saved mood "${entry.mood}" for ${entry.childId}');
      return entry;
    } catch (e) {
      _logger.e('MoodRepository.addEntry error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // READ
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns all mood entries for a child, newest first.
  Future<List<MoodEntry>> getEntriesForChild(String childId) async {
    try {
      final raw = _box.get(_MoodKeys.entries(childId));
      if (raw == null) return [];

      final List<dynamic> jsonList = raw is String
          ? List<dynamic>.from(jsonDecode(raw) as List)
          : List<dynamic>.from(raw as List);

      return jsonList
          .map((e) => MoodEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _logger.e('MoodRepository.getEntriesForChild error: $e');
      return [];
    }
  }

  /// Returns the [limit] most recent entries for a child.
  Future<List<MoodEntry>> getRecentEntries(
    String childId, {
    int limit = 7,
  }) async {
    final all = await getEntriesForChild(childId);
    return all.take(limit).toList();
  }

  /// Returns today's mood entry, or null if none recorded today.
  Future<MoodEntry?> getTodayEntry(String childId) async {
    final all = await getEntriesForChild(childId);
    try {
      return all.firstWhere((e) => e.isToday);
    } catch (_) {
      return null;
    }
  }

  /// Returns a mood → count map for entries within the last [days] days.
  Future<Map<String, int>> getMoodCounts(
    String childId, {
    int days = 7,
  }) async {
    final all = await getEntriesForChild(childId);
    final counts = <String, int>{};
    for (final entry in all) {
      if (entry.isWithinDays(days)) {
        counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Returns the most frequently recorded mood within the last [days] days.
  /// Returns null if no entries exist.
  Future<String?> getMostFrequentMood(
    String childId, {
    int days = 7,
  }) async {
    final counts = await getMoodCounts(childId, days: days);
    if (counts.isEmpty) return null;
    return (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// Returns the total number of mood entries for a child.
  Future<int> getEntryCount(String childId) async {
    final all = await getEntriesForChild(childId);
    return all.length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ══════════════════════════════════════════════════════════════════════════

  /// Removes all mood entries for a child (e.g. on profile reset).
  Future<void> clearForChild(String childId) async {
    try {
      await _box.delete(_MoodKeys.entries(childId));
      _logger.i('MoodRepository: cleared entries for $childId');
    } catch (e) {
      _logger.e('MoodRepository.clearForChild error: $e');
    }
  }
}
