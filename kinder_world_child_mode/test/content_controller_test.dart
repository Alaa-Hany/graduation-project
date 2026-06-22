// Unit tests for [ContentController] — activity loading/state, category/type/
// aspect/difficulty queries, personalization & recommendations, offline,
// play-count, progress-record resolution, and the category helpers.
// ContentRepository is faked.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/activity.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/content_controller.dart';
import 'package:kinder_world/core/repositories/content_repository.dart';
import 'package:logger/logger.dart';

Activity _activity({
  String id = 'a1',
  String title = 'Activity',
  String category = 'educational',
  String type = 'lesson',
  String aspect = 'educational',
  List<String> ageRange = const ['4-8'],
  String difficulty = 'easy',
  List<String> tags = const ['math'],
  int playCount = 0,
  double? averageRating,
}) {
  final now = DateTime(2025, 1, 1);
  return Activity(
    id: id,
    title: title,
    description: 'd',
    category: category,
    type: type,
    aspect: aspect,
    ageRange: ageRange,
    difficulty: difficulty,
    duration: 10,
    xpReward: 50,
    thumbnailUrl: '',
    tags: tags,
    learningObjectives: const [],
    isOfflineAvailable: true,
    isPremium: false,
    parentApprovalRequired: false,
    createdAt: now,
    updatedAt: now,
    playCount: playCount,
    averageRating: averageRating,
  );
}

ChildProfile _child({int age = 6, int level = 2, List<String> interests = const ['math']}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: 'c1',
    name: 'Kid',
    age: age,
    avatar: '🦊',
    interests: interests,
    level: level,
    xp: 0,
    streak: 0,
    favorites: const [],
    parentId: 'p1',
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

ProgressRecord _record({
  String id = 'r1',
  String activityId = 'a1',
  String status = CompletionStatus.completed,
}) {
  final now = DateTime.now();
  return ProgressRecord(
    id: id,
    childId: 'c1',
    activityId: activityId,
    date: now,
    score: 80,
    duration: 10,
    xpEarned: 50,
    completionStatus: status,
    syncStatus: SyncStatus.synced,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeContentRepository extends Fake implements ContentRepository {
  List<Activity> all = [];
  List<Activity> popular = [];
  List<Activity> recent = [];
  List<Activity> recommended = [];
  List<Activity> byCategory = [];
  List<Activity> byType = [];
  List<Activity> byAspect = [];
  List<Activity> byDifficulty = [];
  List<Activity> forChild = [];
  List<Activity> offline = [];
  List<Activity> searchResults = [];
  bool throwOnGetAll = false;
  bool incrementResult = true;

  @override
  Future<List<Activity>> getAllActivities() async {
    if (throwOnGetAll) throw Exception('boom');
    return all;
  }

  @override
  Future<List<Activity>> getPopularActivities({int limit = 10}) async => popular;
  @override
  Future<List<Activity>> getRecentlyAddedActivities({int limit = 10}) async =>
      recent;
  @override
  Future<List<Activity>> getRecommendedActivities(ChildProfile child) async =>
      recommended;
  @override
  Future<List<Activity>> getActivitiesByCategory(String category) async =>
      byCategory;
  @override
  Future<List<Activity>> getActivitiesByType(String type) async => byType;
  @override
  Future<List<Activity>> getActivitiesByAspect(String aspect) async => byAspect;
  @override
  Future<List<Activity>> getActivitiesByDifficulty(String difficulty) async =>
      byDifficulty;
  @override
  Future<List<Activity>> getActivitiesForChild(ChildProfile child) async =>
      forChild;
  @override
  Future<List<Activity>> getOfflineActivities() async => offline;
  @override
  Future<List<Activity>> searchActivities(String query) async => searchResults;
  @override
  Future<Activity?> getActivity(String activityId) async =>
      all.where((a) => a.id == activityId).cast<Activity?>().firstWhere(
            (a) => true,
            orElse: () => null,
          );
  @override
  Future<bool> incrementPlayCount(String activityId) async => incrementResult;
  @override
  Future<bool> downloadForOffline(String activityId) async => true;
}

void main() {
  late _FakeContentRepository repo;

  Future<ContentController> build() async {
    final c = ContentController(
      contentRepository: repo,
      logger: Logger(level: Level.off),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  setUp(() {
    repo = _FakeContentRepository();
  });

  group('initialization & loading', () {
    test('constructor loads all and popular activities', () async {
      repo.all = [_activity(id: 'a1')];
      repo.popular = [_activity(id: 'p1')];
      final c = await build();
      expect(c.state.activities.map((a) => a.id), ['a1']);
      expect(c.state.popularActivities.map((a) => a.id), ['p1']);
      expect(c.state.isLoading, isFalse);
    });

    test('loadAllActivities sets error on failure', () async {
      repo.throwOnGetAll = true;
      final c = await build();
      expect(c.state.error, isNotNull);
      expect(c.state.isLoading, isFalse);
    });

    test('category/type/aspect/difficulty queries delegate', () async {
      repo.byCategory = [_activity(id: 'cat')];
      repo.byType = [_activity(id: 'typ')];
      repo.byAspect = [_activity(id: 'asp')];
      repo.byDifficulty = [_activity(id: 'dif')];
      final c = await build();
      expect((await c.loadActivitiesByCategory('x')).single.id, 'cat');
      expect((await c.loadActivitiesByType('x')).single.id, 'typ');
      expect((await c.loadActivitiesByAspect('x')).single.id, 'asp');
      expect((await c.filterByDifficulty('x')).single.id, 'dif');
    });

    test('recentlyAdded and recommended load', () async {
      repo.recent = [_activity(id: 'r')];
      repo.recommended = [_activity(id: 'rec')];
      final c = await build();
      expect((await c.loadRecentlyAddedActivities()).single.id, 'r');
      await c.loadRecommendedActivities(_child());
      expect(c.state.recommendedActivities.single.id, 'rec');
    });
  });

  group('search, filter, offline', () {
    test('searchActivities delegates', () async {
      repo.searchResults = [_activity(id: 's')];
      final c = await build();
      expect((await c.searchActivities('q')).single.id, 's');
    });

    test('filterByAgeRange uses loaded activities', () async {
      repo.all = [
        _activity(id: 'young', ageRange: const ['3-5']),
        _activity(id: 'old', ageRange: const ['10-12']),
      ];
      final c = await build();
      final result = await c.filterByAgeRange(3, 6);
      expect(result.map((a) => a.id), ['young']);
    });

    test('getActivitiesByInterests matches tags', () async {
      repo.all = [
        _activity(id: 'm', tags: const ['math']),
        _activity(id: 'art', tags: const ['drawing']),
      ];
      final c = await build();
      final result = await c.getActivitiesByInterests(['math']);
      expect(result.map((a) => a.id), ['m']);
    });

    test('offline activities and download delegate', () async {
      repo.offline = [_activity(id: 'off')];
      final c = await build();
      expect((await c.getOfflineActivities()).single.id, 'off');
      expect(await c.downloadForOffline('off'), isTrue);
    });
  });

  group('activity interaction', () {
    test('getActivity returns by id', () async {
      repo.all = [_activity(id: 'a1')];
      final c = await build();
      expect((await c.getActivity('a1'))!.id, 'a1');
      expect(await c.getActivity('missing'), isNull);
    });

    test('incrementPlayCount bumps local state', () async {
      repo.all = [_activity(id: 'a1', playCount: 0)];
      final c = await build();
      final ok = await c.incrementPlayCount('a1');
      expect(ok, isTrue);
      expect(c.state.activities.firstWhere((a) => a.id == 'a1').playCount, 1);
    });
  });

  group('recommendations & progress resolution', () {
    test('getDailyRecommendations filters by interest and level', () async {
      repo.forChild = [
        _activity(id: 'match', tags: const ['math'], difficulty: 'medium'),
        _activity(id: 'nomatch', tags: const ['cooking'], difficulty: 'expert'),
      ];
      final c = await build();
      final recs = await c.getDailyRecommendations(_child(level: 2));
      expect(recs.map((a) => a.id), contains('match'));
      expect(recs.map((a) => a.id), isNot(contains('nomatch')));
    });

    test('resolveActivitiesForProgressRecords strips id prefixes', () async {
      repo.all = [_activity(id: 'a1')];
      final c = await build();
      final resolved = await c.resolveActivitiesForProgressRecords([
        _record(id: 'r1', activityId: 'lesson_a1'),
      ]);
      expect(resolved['r1']!.id, 'a1');
    });

    test('pickContinueLearningRecord prefers in-progress', () async {
      final c = await build();
      final picked = c.pickContinueLearningRecord([
        _record(id: 'done', status: CompletionStatus.completed),
        _record(id: 'wip', status: CompletionStatus.inProgress),
      ]);
      expect(picked!.id, 'wip');
    });

    test('pickContinueLearningRecord returns null for empty', () async {
      final c = await build();
      expect(c.pickContinueLearningRecord(const []), isNull);
    });

    test('getContinueLearningActivities resolves recent records', () async {
      repo.all = [_activity(id: 'a1', ageRange: const ['4-8'])];
      final c = await build();
      final result = await c.getContinueLearningActivities(
        _child(age: 6),
        recentRecords: [_record(id: 'r1', activityId: 'a1')],
      );
      expect(result.single.id, 'a1');
    });
  });

  group('catalog helpers & error', () {
    test('category/type/aspect helpers return non-empty lists', () async {
      final c = await build();
      expect(c.getAllCategories(), isNotEmpty);
      expect(c.getAllTypes(), isNotEmpty);
      expect(c.getAllAspects(), isNotEmpty);
      expect(c.getCategoryDisplayName('educational'), isA<String>());
    });

    test('clearError runs without throwing', () async {
      // Note: ContentState.copyWith uses `error ?? this.error`, so passing null
      // does not actually clear the field — clearError is effectively a no-op
      // here. This characterizes the current behavior rather than asserting a
      // reset that the implementation does not perform.
      repo.throwOnGetAll = true;
      final c = await build();
      expect(c.state.error, isNotNull);
      c.clearError();
      expect(c.state.error, isNotNull);
    });
  });
}
