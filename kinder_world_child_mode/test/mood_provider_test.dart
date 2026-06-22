// Unit tests for [MoodNotifier] and [MoodState] — loading, recording (incl.
// backend sync gating), parent-side reads, and the state getters. The mood
// repository, child repository, reports API and secure storage are faked.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:kinder_world/core/providers/mood_provider.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/mood_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _FakeMoodRepository extends Fake implements MoodRepository {
  final List<MoodEntry> entries = [];
  MoodEntry? todayEntry;
  Map<String, int> counts = {};

  @override
  Future<MoodEntry> addEntry(MoodEntry entry) async {
    entries.add(entry);
    return entry;
  }

  @override
  Future<MoodEntry?> getTodayEntry(String childId) async => todayEntry;

  @override
  Future<List<MoodEntry>> getRecentEntries(String childId, {int limit = 7}) async =>
      entries.take(limit).toList();

  @override
  Future<Map<String, int>> getMoodCounts(String childId, {int days = 7}) async =>
      counts;

  @override
  Future<String?> getMostFrequentMood(String childId, {int days = 7}) async {
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }
}

class _FakeChildRepository extends Fake implements ChildRepository {
  String? lastMood;
  @override
  Future<ChildProfile?> updateMood(String childId, String mood) async {
    lastMood = mood;
    return null;
  }
}

class _FakeReportsApi extends Fake implements ReportsApi {
  int ingestCalls = 0;
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> ingestActivityEvent(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    ingestCalls++;
    lastPayload = payload;
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

MoodEntry _entry(String mood, {String childId = '42', DateTime? at}) {
  final t = at ?? DateTime.now();
  return MoodEntry(
    id: '${childId}_${t.millisecondsSinceEpoch}',
    childId: childId,
    mood: mood,
    timestamp: t,
  );
}

void main() {
  late _FakeMoodRepository moodRepo;
  late _FakeChildRepository childRepo;
  late _FakeReportsApi reportsApi;
  late _FakeSecureStorage storage;

  MoodNotifier build() => MoodNotifier(
        moodRepository: moodRepo,
        childRepository: childRepo,
        reportsApi: reportsApi,
        secureStorage: storage,
        logger: Logger(level: Level.off),
      );

  setUp(() {
    moodRepo = _FakeMoodRepository();
    childRepo = _FakeChildRepository();
    reportsApi = _FakeReportsApi();
    storage = _FakeSecureStorage();
  });

  group('MoodState getters', () {
    test('hasRecordedToday, mostFrequentMood, weekEntryCount', () {
      const state = MoodState(
        todayMood: 'happy',
        weekCounts: {'happy': 3, 'sad': 1},
      );
      expect(state.hasRecordedToday, isTrue);
      expect(state.mostFrequentMood, 'happy');
      expect(state.weekEntryCount, 4);
    });

    test('empty state has no mood and zero count', () {
      const state = MoodState();
      expect(state.hasRecordedToday, isFalse);
      expect(state.mostFrequentMood, isNull);
      expect(state.weekEntryCount, 0);
    });
  });

  group('loadForChild', () {
    test('populates state from repository', () async {
      moodRepo.todayEntry = _entry('calm');
      moodRepo.entries.add(_entry('calm'));
      moodRepo.counts = {'calm': 2};

      final n = build();
      await n.loadForChild('42');

      expect(n.state.todayMood, 'calm');
      expect(n.state.isLoading, isFalse);
      expect(n.state.weekCounts, {'calm': 2});
    });
  });

  group('recordMood', () {
    test('persists entry, updates child mood, and syncs when numeric+parent',
        () async {
      storage.parentAccessToken = 'ptoken';

      final n = build();
      await n.recordMood('42', 'happy');

      expect(moodRepo.entries.length, 1);
      expect(childRepo.lastMood, 'happy');
      expect(reportsApi.ingestCalls, 1);
      expect(reportsApi.lastPayload!['mood_value'], 5); // happy => 5
      expect(n.state.todayMood, 'happy');
      expect(n.state.justSaved, isFalse); // reset after the feedback delay
    });

    test('skips backend sync for non-numeric child id', () async {
      storage.parentAccessToken = 'ptoken';

      final n = build();
      await n.recordMood('child-abc', 'sad');

      expect(reportsApi.ingestCalls, 0);
      expect(n.state.todayMood, 'sad');
    });

    test('skips backend sync when no parent token available', () async {
      // No parent token, and only a child-session auth token.
      storage.authToken = 'child_session_xyz';

      final n = build();
      await n.recordMood('42', 'excited');

      expect(reportsApi.ingestCalls, 0);
    });
  });

  group('parent-side reads', () {
    test('getMoodCountsForPeriod delegates to repo', () async {
      moodRepo.counts = {'happy': 5};
      final n = build();
      expect(await n.getMoodCountsForPeriod('42', 30), {'happy': 5});
    });

    test('getMostFrequentMood delegates to repo', () async {
      moodRepo.counts = {'happy': 2, 'calm': 5};
      final n = build();
      expect(await n.getMostFrequentMood('42'), 'calm');
    });
  });

  test('clearError resets the error', () async {
    final n = build();
    n.state = const MoodState(error: 'boom');
    n.clearError();
    expect(n.state.error, isNull);
  });
}
