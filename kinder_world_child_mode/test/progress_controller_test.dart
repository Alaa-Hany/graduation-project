// Unit tests for [ProgressController] — recording activity completion (incl.
// backend-sync gating), record loading, statistics/analytics delegation,
// achievement progress, parent report aggregation, and sync. ProgressRepository,
// ChildRepository, ReportsApi and SecureStorage are faked.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

ProgressRecord _record({
  String id = 'r1',
  String childId = '42',
  String activityId = 'lesson_math',
  String syncStatus = SyncStatus.pending,
}) {
  final now = DateTime.now();
  return ProgressRecord(
    id: id,
    childId: childId,
    activityId: activityId,
    date: now,
    score: 80,
    duration: 10,
    xpEarned: 50,
    completionStatus: CompletionStatus.completed,
    syncStatus: syncStatus,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeProgressRepository extends Fake implements ProgressRepository {
  ProgressRecord? createResult;
  List<ProgressRecord> forChild = [];
  List<ProgressRecord> today = [];
  List<ProgressRecord> needingSync = [];
  Map<String, dynamic> stats = {};
  Map<String, dynamic> weekly = {};
  Map<String, dynamic> monthly = {};
  Map<String, dynamic> trends = {};
  Map<String, dynamic> mood = {};
  int streakDays = 0;
  final List<ProgressRecord> updates = [];

  @override
  Future<ProgressRecord?> createProgressRecord({
    required String childId,
    required String activityId,
    required int score,
    required int duration,
    required int xpEarned,
    String? notes,
    String completionStatus = CompletionStatus.completed,
    Map<String, dynamic>? performanceMetrics,
    String? aiFeedback,
    String? moodBefore,
    String? moodAfter,
    bool? difficultyAdjusted,
    bool? helpRequested,
    bool? parentApproved,
  }) async =>
      createResult;

  @override
  Future<ProgressRecord?> updateProgressRecord(ProgressRecord record) async {
    updates.add(record);
    return record;
  }

  @override
  Future<List<ProgressRecord>> getProgressForChild(String childId) async =>
      forChild;
  @override
  Future<List<ProgressRecord>> getTodayProgress(String childId) async => today;
  @override
  Future<List<ProgressRecord>> getRecordsNeedingSync() async => needingSync;
  @override
  Future<Map<String, dynamic>> getChildStats(String childId) async => stats;
  @override
  Future<Map<String, dynamic>> getWeeklySummary(String childId) async => weekly;
  @override
  Future<Map<String, dynamic>> getMonthlySummary(String childId) async =>
      monthly;
  @override
  Future<Map<String, dynamic>> getPerformanceTrends(String childId) async =>
      trends;
  @override
  Future<Map<String, dynamic>> getMoodAnalysis(String childId) async => mood;
  @override
  Future<int> calculateStreakDays(List<ProgressRecord> records) async =>
      streakDays;
}

class _FakeChildRepository extends Fake implements ChildRepository {
  int completeCalls = 0;
  int streakCalls = 0;
  @override
  Future<ChildProfile?> completeActivity({
    required String childId,
    required int xpEarned,
    required int timeSpent,
  }) async {
    completeCalls++;
    return null;
  }

  @override
  Future<ChildProfile?> updateStreak(String childId) async {
    streakCalls++;
    return null;
  }
}

class _FakeReportsApi extends Fake implements ReportsApi {
  int sessionLogs = 0;
  int activityEvents = 0;
  bool throwOnIngest = false;

  @override
  Future<Map<String, dynamic>> ingestSessionLog(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    if (throwOnIngest) throw Exception('net');
    sessionLogs++;
    return {};
  }

  @override
  Future<Map<String, dynamic>> ingestActivityEvent(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    if (throwOnIngest) throw Exception('net');
    activityEvents++;
    return {};
  }
}

class _FakeSecureStorage extends Fake implements SecureStorage {
  String? parentAccessToken;
  String? authToken;
  @override
  Future<String?> getParentAccessToken() async => parentAccessToken;
  @override
  Future<String?> getAuthToken() async => authToken;
}

void main() {
  late _FakeProgressRepository progressRepo;
  late _FakeChildRepository childRepo;
  late _FakeReportsApi reportsApi;
  late _FakeSecureStorage storage;

  ProgressController build() => ProgressController(
        progressRepository: progressRepo,
        childRepository: childRepo,
        reportsApi: reportsApi,
        secureStorage: storage,
        logger: Logger(level: Level.off),
      );

  setUp(() {
    progressRepo = _FakeProgressRepository();
    childRepo = _FakeChildRepository();
    reportsApi = _FakeReportsApi();
    storage = _FakeSecureStorage();
  });

  group('recordActivityCompletion', () {
    test('records, updates child, and syncs to backend when authed', () async {
      progressRepo.createResult = _record(childId: '42');
      storage.parentAccessToken = 'ptoken';

      final c = build();
      final result = await c.recordActivityCompletion(
        childId: '42',
        activityId: 'lesson_math',
        score: 90,
        duration: 10,
        xpEarned: 50,
      );

      expect(result, isNotNull);
      expect(childRepo.completeCalls, 1);
      expect(childRepo.streakCalls, 1);
      expect(reportsApi.sessionLogs, 1);
      expect(reportsApi.activityEvents, 1);
      expect(result!.syncStatus, SyncStatus.synced);
      expect(c.state.isLoading, isFalse);
    });

    test('marks record failed when child id is non-numeric (no sync)', () async {
      progressRepo.createResult = _record(childId: 'child-x');
      storage.parentAccessToken = 'ptoken';

      final c = build();
      final result = await c.recordActivityCompletion(
        childId: 'child-x',
        activityId: 'lesson_math',
        score: 90,
        duration: 10,
        xpEarned: 50,
      );

      expect(result, isNotNull);
      expect(reportsApi.sessionLogs, 0);
      expect(result!.syncStatus, SyncStatus.failed);
    });

    test('sets error when create returns null', () async {
      progressRepo.createResult = null;
      final c = build();
      final result = await c.recordActivityCompletion(
        childId: '42',
        activityId: 'a',
        score: 1,
        duration: 1,
        xpEarned: 1,
      );
      expect(result, isNull);
      expect(c.state.error, isNotNull);
    });

    test('marks record failed when backend ingest throws', () async {
      progressRepo.createResult = _record(childId: '42');
      storage.parentAccessToken = 'ptoken';
      reportsApi.throwOnIngest = true;

      final c = build();
      final result = await c.recordActivityCompletion(
        childId: '42',
        activityId: 'lesson_math',
        score: 90,
        duration: 10,
        xpEarned: 50,
      );
      expect(result!.syncStatus, SyncStatus.failed);
    });
  });

  group('loading & queries', () {
    test('loadRecentRecords caps at 20 and sets loadedChildId', () async {
      progressRepo.forChild =
          List.generate(25, (i) => _record(id: 'r$i'));
      final c = build();
      await c.loadRecentRecords('42');
      expect(c.state.recentRecords.length, 20);
      expect(c.state.loadedChildId, '42');
    });

    test('loadTodayProgress delegates', () async {
      progressRepo.today = [_record(id: 't1')];
      final c = build();
      expect((await c.loadTodayProgress('42')).single.id, 't1');
    });

    test('summaries and analytics delegate to repo', () async {
      progressRepo.weekly = {'totalXP': 10};
      progressRepo.monthly = {'totalXP': 40};
      progressRepo.trends = {'trend': 'improving'};
      progressRepo.mood = {'moodImprovedCount': 2};
      final c = build();
      expect((await c.getWeeklySummary('42'))['totalXP'], 10);
      expect((await c.getMonthlySummary('42'))['totalXP'], 40);
      expect((await c.getPerformanceTrends('42'))['trend'], 'improving');
      expect((await c.getMoodAnalysis('42'))['moodImprovedCount'], 2);
    });
  });

  group('streak & achievements', () {
    test('calculateStreak delegates through repo', () async {
      progressRepo.forChild = [_record()];
      progressRepo.streakDays = 5;
      final c = build();
      expect(await c.calculateStreak('42'), 5);
    });

    test('getAchievementProgress computes tiers', () async {
      progressRepo.stats = {
        'totalXP': 600,
        'totalActivities': 12,
        'currentLevel': 3,
        'completionRate': 0.9,
      };
      progressRepo.streakDays = 8;
      final c = build();
      final progress = await c.getAchievementProgress('42');

      expect(progress['totalXP'], 600);
      expect(progress['currentStreak'], 8);
      final xpAch = progress['xpAchievements'] as List;
      // 600 XP unlocks "First Steps" (100) and "Rising Star" (500)
      expect(xpAch.where((a) => a['achieved'] == true).length, 2);
      final streakAch = progress['streakAchievements'] as List;
      // streak 8 unlocks "First Day" (1) and "Week Warrior" (7)
      expect(streakAch.where((a) => a['achieved'] == true).length, 2);
    });

    test('generateParentReport aggregates all sections', () async {
      progressRepo.stats = {'totalXP': 100};
      progressRepo.weekly = {'a': 1};
      progressRepo.monthly = {'b': 2};
      progressRepo.trends = {'trend': 'stable'};
      progressRepo.mood = {'c': 3};
      final c = build();
      final report = await c.generateParentReport('42');
      expect(report['stats'], isA<Map>());
      expect(report['weeklySummary'], {'a': 1});
      expect(report['moodAnalysis'], {'c': 3});
      expect(report['generatedAt'], isA<DateTime>());
    });
  });

  group('sync', () {
    test('syncWithServer returns true when nothing pending', () async {
      progressRepo.needingSync = [];
      final c = build();
      expect(await c.syncWithServer(), isTrue);
    });

    test('syncWithServer syncs each pending record', () async {
      progressRepo.needingSync = [_record(id: 'r1', childId: '42')];
      storage.parentAccessToken = 'ptoken';
      final c = build();
      final ok = await c.syncWithServer();
      expect(ok, isTrue);
      expect(reportsApi.activityEvents, 1);
    });

    test('getRecordsNeedingSync delegates', () async {
      progressRepo.needingSync = [_record(id: 'r1')];
      final c = build();
      expect((await c.getRecordsNeedingSync()).single.id, 'r1');
    });
  });
}
