// Regression test for the "daily goal resets on refresh" bug.
//
// Game completions are stored with a `performance_metrics` map. Hive returns
// nested maps as Map<dynamic, dynamic> when the box is reopened (app refresh),
// and ProgressRecord.fromJson casts performance_metrics to Map<String, dynamic>.
// That cast threw, so _warmRecords silently skipped every game record after a
// refresh — wiping today's progress (and the daily goal) even though the data
// was on disk the whole time. This test reopens a real Hive box to lock that in.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:logger/logger.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('kw_progress_hive');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
      'today\'s progress with performance_metrics survives a box reopen (refresh)',
      () async {
    const boxName = 'progress_records_persist_test';

    // ── Session 1: complete a "game" activity that carries metrics. ──────────
    var box = await Hive.openBox<dynamic>(boxName);
    var repo = ProgressRepository(
      progressBox: box,
      logger: Logger(level: Level.off),
    );
    final created = await repo.createProgressRecord(
      childId: 'child-1',
      activityId: 'game_puzzle_3',
      score: 100,
      duration: 2,
      xpEarned: 40,
      notes: 'Puzzle level 3',
      performanceMetrics: const {
        'stars': 3,
        'moves': 12,
        'board_size': 4,
        'nested': {'deep': 'value'},
      },
    );
    expect(created, isNotNull);
    expect(await repo.getTodayProgress('child-1'), hasLength(1));

    // ── Simulate an app refresh: close and reopen the box from disk. ─────────
    await box.close();
    box = await Hive.openBox<dynamic>(boxName);
    repo = ProgressRepository(
      progressBox: box,
      logger: Logger(level: Level.off),
    );

    final todayAfterReopen = await repo.getTodayProgress('child-1');
    expect(
      todayAfterReopen,
      hasLength(1),
      reason: 'Game record must still count toward the daily goal after refresh',
    );
    expect(todayAfterReopen.first.activityId, 'game_puzzle_3');
    expect(todayAfterReopen.first.performanceMetrics?['stars'], 3);

    await box.close();
  });
}
