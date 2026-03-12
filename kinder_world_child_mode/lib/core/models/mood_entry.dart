// lib/core/models/mood_entry.dart
//
// Mood tracking data model.
// Stored as JSON maps in Hive — no TypeAdapters needed.

import 'package:kinder_world/core/models/child_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOOD ENTRY MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// A single mood check-in recorded by a child.
class MoodEntry {
  final String id;
  final String childId;

  /// One of [ChildMoods] constants: happy, sad, excited, tired, calm, angry.
  final String mood;

  final DateTime timestamp;

  /// Optional free-text note (future extension).
  final String? note;

  const MoodEntry({
    required this.id,
    required this.childId,
    required this.mood,
    required this.timestamp,
    this.note,
  });

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'mood': mood,
        'timestamp': timestamp.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        childId: json['childId'] as String,
        mood: json['mood'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String?,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns true if this entry was recorded today.
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  /// Returns true if this entry was recorded within the last [days] days.
  bool isWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return timestamp.isAfter(cutoff);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MoodEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MoodEntry(id: $id, childId: $childId, mood: $mood, timestamp: $timestamp)';
}

// ─────────────────────────────────────────────────────────────────────────────
// MOOD METADATA — display helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Static display metadata for each mood type.
class MoodMeta {
  const MoodMeta._();

  static String emoji(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return '😊';
      case ChildMoods.excited:
        return '🤩';
      case ChildMoods.calm:
        return '😌';
      case ChildMoods.tired:
        return '😴';
      case ChildMoods.sad:
        return '😢';
      case ChildMoods.angry:
        return '😠';
      default:
        return '🙂';
    }
  }

  /// Returns a hex color int for each mood (used for UI accents).
  static int colorValue(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return 0xFFFFD700; // gold
      case ChildMoods.excited:
        return 0xFFFF6B35; // orange-fire
      case ChildMoods.calm:
        return 0xFF4CAF50; // green
      case ChildMoods.tired:
        return 0xFF9E9E9E; // grey
      case ChildMoods.sad:
        return 0xFF3F51B5; // blue
      case ChildMoods.angry:
        return 0xFFE91E63; // pink-red
      default:
        return 0xFF7C4DFF; // purple
    }
  }

  /// All moods in display order (happy first, angry last).
  static const List<String> displayOrder = [
    ChildMoods.happy,
    ChildMoods.excited,
    ChildMoods.calm,
    ChildMoods.tired,
    ChildMoods.sad,
    ChildMoods.angry,
  ];
}
