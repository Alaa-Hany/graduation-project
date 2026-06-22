// Unit tests for [ChildSessionController] — session restore/start/end, profile
// management, progress operations, favorites/interests, mood/learning style and
// stats. ChildRepository and SecureStorage are faked.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _FakeSecureStorage extends Fake implements SecureStorage {
  String? role;
  String? childSession;
  int saveChildCalls = 0;
  int clearChildCalls = 0;
  int clearAuthCalls = 0;

  @override
  bool get hasCachedSessionSnapshot => false;

  @override
  Future<String?> getUserRole() async => role;

  @override
  Future<String?> getChildSession() async => childSession;

  @override
  Future<bool> saveChildSession(String childId) async {
    saveChildCalls++;
    childSession = childId;
    return true;
  }

  @override
  Future<bool> clearChildSession() async {
    clearChildCalls++;
    childSession = null;
    return true;
  }

  @override
  Future<bool> clearAuthOnly() async {
    clearAuthCalls++;
    return true;
  }
}

class _FakeChildRepository extends Fake implements ChildRepository {
  final Map<String, ChildProfile> profiles = {};

  @override
  Future<ChildProfile?> getChildProfile(String childId) async =>
      profiles[childId];

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }

  ChildProfile? _mutate(String id, ChildProfile Function(ChildProfile) f) {
    final c = profiles[id];
    if (c == null) return null;
    final u = f(c);
    profiles[id] = u;
    return u;
  }

  @override
  Future<ChildProfile?> addXP(String childId, int xpAmount) async =>
      _mutate(childId, (c) => c.copyWith(xp: c.xp + xpAmount));

  @override
  Future<ChildProfile?> updateStreak(String childId) async =>
      _mutate(childId, (c) => c.copyWith(streak: c.streak + 1));

  @override
  Future<ChildProfile?> completeActivity({
    required String childId,
    required int xpEarned,
    required int timeSpent,
  }) async =>
      _mutate(
          childId,
          (c) => c.copyWith(
              xp: c.xp + xpEarned,
              activitiesCompleted: c.activitiesCompleted + 1));

  @override
  Future<ChildProfile?> addToFavorites(String childId, String activityId) async =>
      _mutate(childId, (c) => c.copyWith(favorites: [...c.favorites, activityId]));

  @override
  Future<ChildProfile?> removeFromFavorites(
          String childId, String activityId) async =>
      _mutate(childId,
          (c) => c.copyWith(favorites: c.favorites.where((f) => f != activityId).toList()));

  @override
  Future<ChildProfile?> updateInterests(
          String childId, List<String> newInterests) async =>
      _mutate(childId, (c) => c.copyWith(interests: newInterests));

  @override
  Future<ChildProfile?> updateMood(String childId, String mood) async =>
      _mutate(childId, (c) => c.copyWith(currentMood: mood));

  @override
  Future<ChildProfile?> updateLearningStyle(
          String childId, String learningStyle) async =>
      _mutate(childId, (c) => c.copyWith(learningStyle: learningStyle));

  @override
  Future<Map<String, dynamic>> getChildStats(String childId) async =>
      profiles.containsKey(childId) ? {'totalXP': profiles[childId]!.xp} : {};
}

ChildProfile _child({String id = 'c1', int xp = 0, int streak = 0}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: id,
    name: 'Kid',
    age: 6,
    avatar: '🦊',
    interests: const [],
    level: 1,
    xp: xp,
    streak: streak,
    favorites: const [],
    parentId: 'p1',
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

void main() {
  late _FakeChildRepository repo;
  late _FakeSecureStorage storage;

  setUp(() {
    repo = _FakeChildRepository();
    storage = _FakeSecureStorage();
  });

  // Build a controller and let the constructor's async restore complete.
  Future<ChildSessionController> build() async {
    final c = ChildSessionController(
      childRepository: repo,
      secureStorage: storage,
      logger: Logger(level: Level.off),
    );
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  // Build a controller with an already-active session for 'c1'.
  Future<ChildSessionController> withSession() async {
    repo.profiles['c1'] = _child();
    final c = await build();
    await c.startChildSession(childId: 'c1');
    return c;
  }

  group('session restore', () {
    test('no active session when role is not child', () async {
      storage.role = 'parent';
      final c = await build();
      expect(c.state.hasActiveSession, isFalse);
      expect(c.state.isLoading, isFalse);
    });

    test('restores active session when role=child and profile exists', () async {
      storage.role = 'child';
      storage.childSession = 'c1';
      repo.profiles['c1'] = _child();

      final c = await build();
      expect(c.state.hasActiveSession, isTrue);
      expect(c.state.childProfile!.id, 'c1');
    });

    test('clears auth when stored child profile is missing', () async {
      storage.role = 'child';
      storage.childSession = 'gone';

      final c = await build();
      expect(c.state.hasActiveSession, isFalse);
      expect(storage.clearAuthCalls, 1);
    });
  });

  group('start/end session', () {
    test('startChildSession with provided profile persists session', () async {
      final c = await build();
      final ok = await c.startChildSession(
          childId: 'c1', childProfile: _child(id: 'c1'));
      expect(ok, isTrue);
      expect(c.state.childId, 'c1');
      expect(storage.saveChildCalls, 1);
    });

    test('startChildSession loads profile from repo when not provided',
        () async {
      repo.profiles['c1'] = _child(xp: 50);
      final c = await build();
      final ok = await c.startChildSession(childId: 'c1');
      expect(ok, isTrue);
      expect(c.state.childProfile!.xp, 50);
    });

    test('startChildSession fails when profile not found', () async {
      final c = await build();
      final ok = await c.startChildSession(childId: 'ghost');
      expect(ok, isFalse);
      expect(c.state.error, isNotNull);
    });

    test('endChildSession clears the session', () async {
      final c = await withSession();
      final ok = await c.endChildSession();
      expect(ok, isTrue);
      expect(c.state.hasActiveSession, isFalse);
      expect(storage.clearChildCalls, 1);
    });
  });

  group('profile management', () {
    test('loadChildProfile success and not-found', () async {
      repo.profiles['c1'] = _child();
      final c = await build();
      expect(await c.loadChildProfile('c1'), isTrue);
      expect(await c.loadChildProfile('ghost'), isFalse);
    });

    test('updateChildProfile updates state', () async {
      final c = await withSession();
      final ok = await c.updateChildProfile(_child(xp: 999));
      expect(ok, isTrue);
      expect(c.state.childProfile!.xp, 999);
    });

    test('refreshProfile is a no-op without active session', () async {
      final c = await build();
      await c.refreshProfile(); // should not throw
      expect(c.state.hasActiveSession, isFalse);
    });

    test('refreshProfile pulls latest from repo', () async {
      final c = await withSession();
      repo.profiles['c1'] = _child(xp: 777);
      await c.refreshProfile();
      expect(c.state.childProfile!.xp, 777);
    });
  });

  group('progress operations require a session', () {
    test('addXP returns false without session, true with', () async {
      final c = await build();
      expect(await c.addXP(10), isFalse);

      final c2 = await withSession();
      expect(await c2.addXP(10), isTrue);
      expect(c2.state.childProfile!.xp, 10);
    });

    test('updateStreak with session', () async {
      final c = await withSession();
      expect(await c.updateStreak(), isTrue);
      expect(c.state.childProfile!.streak, 1);
    });

    test('completeActivity with session', () async {
      final c = await withSession();
      expect(await c.completeActivity(xpEarned: 20, timeSpent: 5), isTrue);
      expect(c.state.childProfile!.activitiesCompleted, 1);
    });
  });

  group('favorites, interests, mood, style', () {
    test('add/remove favorites', () async {
      final c = await withSession();
      expect(await c.addToFavorites('a1'), isTrue);
      expect(c.state.childProfile!.favorites, contains('a1'));
      expect(await c.removeFromFavorites('a1'), isTrue);
      expect(c.state.childProfile!.favorites, isNot(contains('a1')));
    });

    test('favorites fail without session', () async {
      final c = await build();
      expect(await c.addToFavorites('a1'), isFalse);
    });

    test('updateInterests / updateMood / updateLearningStyle', () async {
      final c = await withSession();
      expect(await c.updateInterests(['art']), isTrue);
      expect(c.state.childProfile!.interests, ['art']);
      expect(await c.updateMood('happy'), isTrue);
      expect(c.state.childProfile!.currentMood, 'happy');
      expect(await c.updateLearningStyle('visual'), isTrue);
      expect(c.state.childProfile!.learningStyle, 'visual');
    });
  });

  group('stats and error', () {
    test('getChildStats empty without session, populated with', () async {
      final c = await build();
      expect(await c.getChildStats(), isEmpty);

      final c2 = await withSession();
      final stats = await c2.getChildStats();
      expect(stats['totalXP'], 0);
    });

    test('clearError resets error', () async {
      final c = await build();
      await c.startChildSession(childId: 'ghost'); // sets an error
      expect(c.state.error, isNotNull);
      c.clearError();
      expect(c.state.error, isNull);
    });
  });
}
