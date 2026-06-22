// Unit tests for [ChildRepository] — CRUD, parent linking, progress
// (XP/streak/activity), favorites/interests, mood/learning style, and stats.
// Backed by an in-memory fake Hive Box.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:logger/logger.dart';

class _FakeBox extends Fake implements Box {
  final Map<dynamic, dynamic> _store = {};

  @override
  Iterable get keys => _store.keys;

  @override
  int get length => _store.length;

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

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

ChildProfile _child({
  String id = 'c1',
  String parentId = 'p1',
  String? parentEmail,
  int xp = 0,
  int level = 1,
  int streak = 0,
  DateTime? lastSession,
  List<String> favorites = const [],
  List<String> interests = const [],
  int totalTimeSpent = 0,
  int activitiesCompleted = 0,
}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: id,
    name: 'Test',
    age: 6,
    avatar: '🦊',
    interests: interests,
    level: level,
    xp: xp,
    streak: streak,
    favorites: favorites,
    parentId: parentId,
    parentEmail: parentEmail,
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    lastSession: lastSession,
    totalTimeSpent: totalTimeSpent,
    activitiesCompleted: activitiesCompleted,
  );
}

void main() {
  late _FakeBox box;
  late ChildRepository repo;

  setUp(() {
    box = _FakeBox();
    repo = ChildRepository(childBox: box, logger: Logger(level: Level.off));
  });

  void seed(ChildProfile c) => box._store[c.id] = c.toJson();

  group('CRUD', () {
    test('create and read back a profile', () async {
      final created = await repo.createChildProfile(_child());
      expect(created, isNotNull);
      expect(await repo.getChildProfile('c1'), isNotNull);
    });

    test('getChildProfile returns null for unknown id', () async {
      expect(await repo.getChildProfile('ghost'), isNull);
    });

    test('update persists changes', () async {
      await repo.createChildProfile(_child());
      final updated =
          await repo.updateChildProfile(_child(streak: 9));
      expect(updated!.streak, 9);
      expect((await repo.getChildProfile('c1'))!.streak, 9);
    });

    test('delete removes the profile', () async {
      await repo.createChildProfile(_child());
      expect(await repo.deleteChildProfile('c1'), isTrue);
      expect(await repo.getChildProfile('c1'), isNull);
    });
  });

  group('parent queries and linking', () {
    test('getChildrenForParent filters by parentId', () async {
      seed(_child(id: 'a', parentId: 'p1'));
      seed(_child(id: 'b', parentId: 'p2'));
      final kids = await repo.getChildrenForParent('p1');
      expect(kids.map((c) => c.id), ['a']);
    });

    test('linkChildrenToParent reassigns matching email', () async {
      seed(_child(id: 'a', parentId: 'local', parentEmail: 'mom@x.com'));
      await repo.linkChildrenToParent(
          parentId: 'p9', parentEmail: 'mom@x.com');
      final kids = await repo.getChildrenForParent('p9');
      expect(kids.map((c) => c.id), ['a']);
    });

    test('linkChildrenToParent ignores empty args', () async {
      seed(_child(id: 'a', parentEmail: 'mom@x.com'));
      await repo.linkChildrenToParent(parentId: '', parentEmail: '');
      // unchanged
      expect((await repo.getChildProfile('a'))!.parentId, 'p1');
    });
  });

  group('progress operations', () {
    test('addXP increases xp and levels up past threshold', () async {
      await repo.createChildProfile(_child(xp: 950, level: 1));
      final updated = await repo.addXP('c1', 100); // 1050 -> level 2
      expect(updated!.xp, 1050);
      expect(updated.level, 2);
    });

    test('addXP returns null for unknown child', () async {
      expect(await repo.addXP('ghost', 10), isNull);
    });

    test('updateStreak starts at 1 with no prior session', () async {
      await repo.createChildProfile(_child(streak: 0, lastSession: null));
      final updated = await repo.updateStreak('c1');
      expect(updated!.streak, 1);
    });

    test('updateStreak increments on consecutive day', () async {
      await repo.createChildProfile(_child(
          streak: 3,
          lastSession: DateTime.now().subtract(const Duration(days: 1))));
      final updated = await repo.updateStreak('c1');
      expect(updated!.streak, 4);
    });

    test('updateStreak resets after a gap', () async {
      await repo.createChildProfile(_child(
          streak: 8,
          lastSession: DateTime.now().subtract(const Duration(days: 4))));
      final updated = await repo.updateStreak('c1');
      expect(updated!.streak, 1);
    });

    test('completeActivity adds xp, time, count and may level up', () async {
      await repo.createChildProfile(
          _child(xp: 950, totalTimeSpent: 5, activitiesCompleted: 2));
      final updated = await repo.completeActivity(
          childId: 'c1', xpEarned: 100, timeSpent: 7);
      expect(updated!.xp, 1050);
      expect(updated.totalTimeSpent, 12);
      expect(updated.activitiesCompleted, 3);
      expect(updated.level, 2);
    });
  });

  group('favorites & interests', () {
    test('add then remove favorite', () async {
      await repo.createChildProfile(_child());
      final added = await repo.addToFavorites('c1', 'act-1');
      expect(added!.favorites, contains('act-1'));

      // Adding again is a no-op (no duplicate)
      final again = await repo.addToFavorites('c1', 'act-1');
      expect(again!.favorites.where((f) => f == 'act-1').length, 1);

      final removed = await repo.removeFromFavorites('c1', 'act-1');
      expect(removed!.favorites, isNot(contains('act-1')));
    });

    test('updateInterests replaces interest list', () async {
      await repo.createChildProfile(_child(interests: ['old']));
      final updated = await repo.updateInterests('c1', ['art', 'music']);
      expect(updated!.interests, ['art', 'music']);
    });
  });

  group('mood & learning style', () {
    test('updateMood sets currentMood', () async {
      await repo.createChildProfile(_child());
      final updated = await repo.updateMood('c1', 'happy');
      expect(updated!.currentMood, 'happy');
    });

    test('updateLearningStyle sets style', () async {
      await repo.createChildProfile(_child());
      final updated = await repo.updateLearningStyle('c1', 'visual');
      expect(updated!.learningStyle, 'visual');
    });
  });

  group('stats & helpers', () {
    test('getChildStats returns empty for unknown child', () async {
      expect(await repo.getChildStats('ghost'), isEmpty);
    });

    test('getChildStats computes averages', () async {
      await repo.createChildProfile(_child(
          xp: 500,
          level: 1,
          totalTimeSpent: 30,
          activitiesCompleted: 3,
          favorites: ['a'],
          interests: ['x', 'y']));
      final stats = await repo.getChildStats('c1');
      expect(stats['totalXP'], 500);
      expect(stats['averageTimePerActivity'], 10);
      expect(stats['favoriteCount'], 1);
      expect(stats['interestCount'], 2);
    });

    test('childExists and getTotalChildrenCount reflect the box', () async {
      seed(_child(id: 'a'));
      seed(_child(id: 'b'));
      expect(await repo.childExists('a'), isTrue);
      expect(await repo.childExists('missing'), isFalse);
      expect(await repo.getTotalChildrenCount(), 2);
    });

    test('getAllChildProfiles returns every profile', () async {
      seed(_child(id: 'a'));
      seed(_child(id: 'b', parentId: 'p2'));
      final all = await repo.getAllChildProfiles();
      expect(all.map((c) => c.id).toSet(), {'a', 'b'});
    });
  });
}
