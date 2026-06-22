// Unit tests for [MoodRepository] — Hive-backed mood history (add/read/counts/
// most-frequent/clear). Uses an in-memory fake Box. Also exercises MoodEntry
// JSON round-trip and the isToday/isWithinDays helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:kinder_world/core/repositories/mood_repository.dart';
import 'package:logger/logger.dart';

class _FakeBox extends Fake implements Box {
  final Map<dynamic, dynamic> _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _store.remove(key);
  }
}

MoodEntry _entry(String mood, {String childId = 'c1', DateTime? at}) {
  final t = at ?? DateTime.now();
  return MoodEntry(
    id: '${childId}_${mood}_${t.microsecondsSinceEpoch}',
    childId: childId,
    mood: mood,
    timestamp: t,
  );
}

void main() {
  late _FakeBox box;
  late MoodRepository repo;

  setUp(() {
    box = _FakeBox();
    repo = MoodRepository(moodBox: box, logger: Logger(level: Level.off));
  });

  test('getEntriesForChild returns empty when none stored', () async {
    expect(await repo.getEntriesForChild('c1'), isEmpty);
  });

  test('addEntry prepends newest first and persists JSON', () async {
    await repo.addEntry(_entry('happy'));
    await repo.addEntry(_entry('sad'));

    final all = await repo.getEntriesForChild('c1');
    expect(all.length, 2);
    expect(all.first.mood, 'sad'); // newest first
    expect(box.get('entries_c1'), isA<String>()); // stored as JSON string
  });

  test('getRecentEntries respects the limit', () async {
    for (var i = 0; i < 10; i++) {
      await repo.addEntry(_entry('happy', at: DateTime.now().subtract(Duration(seconds: i))));
    }
    expect((await repo.getRecentEntries('c1', limit: 3)).length, 3);
  });

  test('getTodayEntry returns today entry or null', () async {
    await repo.addEntry(
        _entry('calm', at: DateTime.now().subtract(const Duration(days: 2))));
    expect(await repo.getTodayEntry('c1'), isNull);

    await repo.addEntry(_entry('happy'));
    expect((await repo.getTodayEntry('c1'))!.mood, 'happy');
  });

  test('getMoodCounts only counts entries within the window', () async {
    await repo.addEntry(_entry('happy'));
    await repo.addEntry(_entry('happy'));
    await repo.addEntry(
        _entry('sad', at: DateTime.now().subtract(const Duration(days: 30))));

    final counts = await repo.getMoodCounts('c1', days: 7);
    expect(counts['happy'], 2);
    expect(counts.containsKey('sad'), isFalse);
  });

  test('getMostFrequentMood returns the top mood, or null when empty', () async {
    expect(await repo.getMostFrequentMood('c1'), isNull);

    await repo.addEntry(_entry('happy'));
    await repo.addEntry(_entry('calm'));
    await repo.addEntry(_entry('calm'));
    expect(await repo.getMostFrequentMood('c1'), 'calm');
  });

  test('getEntryCount returns total stored', () async {
    await repo.addEntry(_entry('happy'));
    await repo.addEntry(_entry('sad'));
    expect(await repo.getEntryCount('c1'), 2);
  });

  test('clearForChild removes all entries', () async {
    await repo.addEntry(_entry('happy'));
    await repo.clearForChild('c1');
    expect(await repo.getEntriesForChild('c1'), isEmpty);
  });

  group('MoodEntry helpers', () {
    test('JSON round-trip preserves fields', () {
      final e = _entry('excited');
      final back = MoodEntry.fromJson(e.toJson());
      expect(back.id, e.id);
      expect(back.mood, 'excited');
      expect(back.timestamp, e.timestamp);
    });

    test('isToday and isWithinDays', () {
      expect(_entry('happy').isToday, isTrue);
      expect(
        _entry('happy', at: DateTime.now().subtract(const Duration(days: 1)))
            .isToday,
        isFalse,
      );
      expect(
        _entry('happy', at: DateTime.now().subtract(const Duration(days: 2)))
            .isWithinDays(7),
        isTrue,
      );
      expect(
        _entry('happy', at: DateTime.now().subtract(const Duration(days: 10)))
            .isWithinDays(7),
        isFalse,
      );
    });
  });
}
