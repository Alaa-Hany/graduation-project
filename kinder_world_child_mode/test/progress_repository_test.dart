// Unit tests for [ProgressRepository] — CRUD, queries, statistics, analytics,
// streak calculation and sync. Backed by an in-memory fake Hive Box so no real
// storage is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:logger/logger.dart';

class _FakeBox extends Fake implements Box {
  final Map<dynamic, dynamic> _store = {};

  @override
  Iterable get keys => _store.keys;

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

ProgressRecord _record({
  required String id,
  String childId = 'c1',
  String activityId = 'a1',
  DateTime? date,
  int score = 80,
  int duration = 10,
  int xpEarned = 50,
  String completionStatus = CompletionStatus.completed,
  String syncStatus = SyncStatus.pending,
  String? moodBefore,
  String? moodAfter,
}) {
  final d = date ?? DateTime.now();
  return ProgressRecord(
    id: id,
    childId: childId,
    activityId: activityId,
    date: d,
    score: score,
    duration: duration,
    xpEarned: xpEarned,
    completionStatus: completionStatus,
    syncStatus: syncStatus,
    moodBefore: moodBefore,
    moodAfter: moodAfter,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  late _FakeBox box;
  late ProgressRepository repo;

  setUp(() {
    box = _FakeBox();
    repo = ProgressRepository(progressBox: box, logger: Logger(level: Level.off));
  });

  // Seed a record straight into the fake box (so warm-up reads it).
  void seed(ProgressRecord r) => box._store[r.id] = r.toJson();

  group('CRUD', () {
    test('create stores and returns a record', () async {
      final r = await repo.createProgressRecord(
        childId: 'c1',
        activityId: 'a1',
        score: 90,
        duration: 12,
        xpEarned: 60,
      );

      expect(r, isNotNull);
      expect(r!.childId, 'c1');
      expect(r.syncStatus, SyncStatus.pending);
      expect(box._store.containsKey(r.id), isTrue);
    });

    test('getProgressRecord returns null for unknown id', () async {
      expect(await repo.getProgressRecord('nope'), isNull);
    });

    test('getProgressRecord reads from box when not cached', () async {
      seed(_record(id: 'r1'));
      final r = await repo.getProgressRecord('r1');
      expect(r, isNotNull);
      expect(r!.id, 'r1');
    });

    test('update changes fields and persists', () async {
      final created = await repo.createProgressRecord(
        childId: 'c1',
        activityId: 'a1',
        score: 50,
        duration: 5,
        xpEarned: 10,
      );
      final updated =
          await repo.updateProgressRecord(created!.copyWith(score: 95));
      expect(updated!.score, 95);

      final reFetched = await repo.getProgressRecord(created.id);
      expect(reFetched!.score, 95);
    });

    test('delete removes the record', () async {
      final created = await repo.createProgressRecord(
        childId: 'c1',
        activityId: 'a1',
        score: 50,
        duration: 5,
        xpEarned: 10,
      );
      final ok = await repo.deleteProgressRecord(created!.id);
      expect(ok, isTrue);
      expect(await repo.getProgressRecord(created.id), isNull);
    });
  });

  group('queries', () {
    test('getProgressForChild returns only that child, newest first', () async {
      seed(_record(
          id: 'old', date: DateTime.now().subtract(const Duration(days: 2))));
      seed(_record(id: 'new', date: DateTime.now()));
      seed(_record(id: 'other', childId: 'c2'));

      final records = await repo.getProgressForChild('c1');
      expect(records.map((r) => r.id), ['new', 'old']);
    });

    test('getProgressForChildren merges multiple children', () async {
      seed(_record(id: 'r1', childId: 'c1'));
      seed(_record(id: 'r2', childId: 'c2'));

      final records = await repo.getProgressForChildren(['c1', 'c2']);
      expect(records.map((r) => r.id).toSet(), {'r1', 'r2'});
    });

    test('getTodayProgress filters to today only', () async {
      seed(_record(id: 'today', date: DateTime.now()));
      seed(_record(
          id: 'yesterday',
          date: DateTime.now().subtract(const Duration(days: 1))));

      final records = await repo.getTodayProgress('c1');
      expect(records.map((r) => r.id), ['today']);
    });

    test('getProgressForDateRange filters by window', () async {
      final base = DateTime(2025, 6, 15);
      seed(_record(id: 'inside', date: base));
      seed(_record(id: 'before', date: DateTime(2025, 6, 1)));
      seed(_record(id: 'after', date: DateTime(2025, 6, 30)));

      final records = await repo.getProgressForDateRange(
        childId: 'c1',
        startDate: DateTime(2025, 6, 10),
        endDate: DateTime(2025, 6, 20),
      );
      expect(records.map((r) => r.id), ['inside']);
    });
  });

  group('statistics', () {
    test('getChildStats returns zeros when no records', () async {
      final stats = await repo.getChildStats('c1');
      expect(stats['totalXP'], 0);
      expect(stats['totalActivities'], 0);
    });

    test('getChildStats aggregates totals and averages', () async {
      seed(_record(id: 'r1', score: 80, duration: 10, xpEarned: 50));
      seed(_record(id: 'r2', score: 100, duration: 20, xpEarned: 70));

      final stats = await repo.getChildStats('c1');
      expect(stats['totalXP'], 120);
      expect(stats['totalActivities'], 2);
      expect(stats['averageScore'], 90.0);
      expect(stats['totalTimeSpent'], 30);
      expect(stats['completionRate'], 1.0);
    });

    test('weekly and monthly summaries return structured maps', () async {
      seed(_record(id: 'r1', date: DateTime.now(), xpEarned: 50));

      final weekly = await repo.getWeeklySummary('c1');
      expect(weekly['dailyStats'], isA<Map>());
      expect((weekly['dailyStats'] as Map).length, 7);

      final monthly = await repo.getMonthlySummary('c1');
      expect(monthly.containsKey('totalActivities'), isTrue);
    });
  });

  group('analytics', () {
    test('getPerformanceTrends reports improving when recent scores higher',
        () async {
      // 7 recent high-score records (newest) + 7 older low-score records.
      for (var i = 0; i < 7; i++) {
        seed(_record(
            id: 'recent$i',
            score: 95,
            date: DateTime.now().subtract(Duration(days: i))));
      }
      for (var i = 0; i < 7; i++) {
        seed(_record(
            id: 'old$i',
            score: 40,
            date: DateTime.now().subtract(Duration(days: 10 + i))));
      }

      final trends = await repo.getPerformanceTrends('c1');
      expect(trends['trend'], 'improving');
    });

    test('getPerformanceTrends empty when no records', () async {
      expect(await repo.getPerformanceTrends('c1'), isEmpty);
    });

    test('getMoodAnalysis counts moods and improvement rate', () async {
      seed(_record(id: 'r1', moodBefore: 'sad', moodAfter: 'happy'));
      seed(_record(id: 'r2', moodBefore: 'happy', moodAfter: 'happy'));

      final mood = await repo.getMoodAnalysis('c1');
      expect((mood['moodCounts'] as Map)['happy'], 2);
      expect(mood['moodImprovedCount'], 1);
      expect(mood['moodImprovementRate'], 0.5);
    });
  });

  group('streak', () {
    test('returns 0 for empty list', () async {
      expect(await repo.calculateStreakDays([]), 0);
    });

    test('counts consecutive days including today', () async {
      final records = [
        _record(id: 'd0', date: DateTime.now()),
        _record(id: 'd1', date: DateTime.now().subtract(const Duration(days: 1))),
        _record(id: 'd2', date: DateTime.now().subtract(const Duration(days: 2))),
      ];
      expect(await repo.calculateStreakDays(records), 3);
    });

    test('returns 0 when neither today nor yesterday has activity', () async {
      final records = [
        _record(id: 'd', date: DateTime.now().subtract(const Duration(days: 5))),
      ];
      expect(await repo.calculateStreakDays(records), 0);
    });
  });

  group('sync', () {
    test('getRecordsNeedingSync returns only pending/failed', () async {
      seed(_record(id: 'p', syncStatus: SyncStatus.pending));
      seed(_record(id: 's', syncStatus: SyncStatus.synced));
      // Warm the cache via a query.
      await repo.getProgressForChild('c1');

      final needing = await repo.getRecordsNeedingSync();
      expect(needing.map((r) => r.id), ['p']);
    });

    test('syncWithServer marks pending records synced', () async {
      seed(_record(id: 'p', syncStatus: SyncStatus.pending));
      await repo.getProgressForChild('c1');

      final ok = await repo.syncWithServer();
      expect(ok, isTrue);
      expect(await repo.getRecordsNeedingSync(), isEmpty);
    });
  });
}
