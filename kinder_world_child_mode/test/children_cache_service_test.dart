// Unit tests for [ChildrenCacheService] — the local-first / stale-while-revalidate
// loader for a parent's children. Uses a real AppCacheStore over mock
// SharedPreferences, with faked repository, children API and secure storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/children_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/services/children_cache_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scope = 'children_list';

class _FakeChildrenApi extends Fake implements ChildrenApi {
  List<Map<String, dynamic>> children = [];
  bool throwOnFetch = false;

  @override
  Future<List<Map<String, dynamic>>> fetchChildren() async {
    if (throwOnFetch) throw Exception('network down');
    return children;
  }
}

class _FakeChildRepository extends Fake implements ChildRepository {
  final Map<String, ChildProfile> profiles = {};
  int linkCalls = 0;
  int createCalls = 0;

  @override
  Future<void> linkChildrenToParent({
    required String parentId,
    required String parentEmail,
  }) async {
    linkCalls++;
  }

  @override
  Future<List<ChildProfile>> getChildProfilesForParent(String parentId) async =>
      profiles.values.where((c) => c.parentId == parentId).toList();

  @override
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async {
    createCalls++;
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }
}

class _FakeSecureStorage extends Fake implements SecureStorage {
  String? token;
  @override
  bool get hasCachedAuthToken => token != null;
  @override
  String? get cachedAuthToken => token;
  @override
  Future<String?> getAuthToken() async => token;
}

ChildProfile _child({String id = 'c1', String parentId = 'p1'}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: id,
    name: 'Kid',
    age: 6,
    avatar: '🦊',
    interests: const [],
    level: 1,
    xp: 0,
    streak: 0,
    favorites: const [],
    parentId: parentId,
    picturePassword: const ['a', 'b', 'c'],
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

void main() {
  late _FakeChildrenApi api;
  late _FakeChildRepository repo;
  late _FakeSecureStorage storage;
  late AppCacheStore cacheStore;
  late ChildrenCacheService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cacheStore = AppCacheStore(prefs);
    api = _FakeChildrenApi();
    repo = _FakeChildRepository();
    storage = _FakeSecureStorage();
    service = ChildrenCacheService(
      childRepository: repo,
      childrenApi: api,
      secureStorage: storage,
      cacheStore: cacheStore,
      logger: Logger(level: Level.off),
    );
  });

  test('empty parentId returns a missing snapshot', () async {
    final result = await service.loadChildrenForParent('');
    expect(result.children, isEmpty);
    expect(result.snapshot.freshness, CacheFreshness.missing);
    expect(result.snapshot.syncState, CacheSyncState.neverSynced);
  });

  test('no auth + never synced returns empty', () async {
    storage.token = null;
    final result = await service.loadChildrenForParent('p1');
    expect(result.children, isEmpty);
  });

  test('no auth but server-backed cache returns local children', () async {
    storage.token = null;
    repo.profiles['c1'] = _child();
    // A stored payload makes the cache "server-backed" (synced).
    await cacheStore.storeList(scope: _scope, key: 'p1', payload: [
      {'id': 'c1'},
    ]);

    final result = await service.loadChildrenForParent('p1');
    expect(result.children.map((c) => c.id), ['c1']);
  });

  test('fetches and merges remote children when authed', () async {
    storage.token = 'parent-token';
    api.children = [
      {'id': 'remote1', 'name': 'Remote Kid', 'age': 7},
    ];

    final result = await service.loadChildrenForParent('p1');
    expect(result.children.map((c) => c.id), contains('remote1'));
    expect(repo.createCalls, 1);
    expect(result.snapshot.freshness, CacheFreshness.freshServerBacked);
  });

  test('links children by email before loading', () async {
    storage.token = 'parent-token';
    api.children = const [];
    await service.loadChildrenForParent('p1', parentEmail: 'mom@x.com');
    expect(repo.linkCalls, 1);
  });

  test('serves local data on remote failure (after a prior sync)', () async {
    storage.token = 'parent-token';
    repo.profiles['c1'] = _child();
    await cacheStore.storeList(scope: _scope, key: 'p1', payload: [
      {'id': 'c1'},
    ]);
    api.throwOnFetch = true;

    final result =
        await service.loadChildrenForParent('p1', forceRefresh: true);
    expect(result.children.map((c) => c.id), ['c1']);
    expect(result.snapshot.syncState, CacheSyncState.syncFailed);
  });

  test('markChildrenMutated and invalidateChildrenCache no-op on empty id',
      () async {
    // Should not throw.
    await service.markChildrenMutated('');
    await service.invalidateChildrenCache('');
  });

  test('markChildrenMutated records a mutation', () async {
    // A payload must exist for the snapshot to expose meta fields.
    await cacheStore.storeList(scope: _scope, key: 'p1', payload: [
      {'id': 'c1'},
    ]);
    await service.markChildrenMutated('p1');
    final snap = cacheStore.snapshot(
        scope: _scope, key: 'p1', staleAfter: const Duration(minutes: 5));
    expect(snap.lastMutationAt, isNotNull);
    expect(snap.syncState, CacheSyncState.pendingSync);
  });
}
