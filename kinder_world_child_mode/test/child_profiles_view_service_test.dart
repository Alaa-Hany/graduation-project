// Unit tests for [ChildProfilesViewService] — loading local children, the
// remote-sync merge path, ensureLocalChildProfile branches, and dedupe. The
// repository, network service and secure storage are faked.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/services/child_profiles_view_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _FakeNetworkService extends Fake implements NetworkService {
  Object? childrenData;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: childrenData as T,
    );
  }
}

class _FakeSecureStorage extends Fake implements SecureStorage {
  String? token;
  String? userId;
  String? userEmail;

  @override
  bool get hasCachedAuthToken => true;
  @override
  String? get cachedAuthToken => token;
  @override
  bool get hasCachedUserId => true;
  @override
  String? get cachedUserId => userId;
  @override
  bool get hasCachedUserEmail => true;
  @override
  String? get cachedUserEmail => userEmail;
}

class _FakeChildRepository extends Fake implements ChildRepository {
  final Map<String, ChildProfile> profiles = {};
  int createCalls = 0;
  int updateCalls = 0;
  int linkCalls = 0;

  @override
  Future<List<ChildProfile>> getAllChildProfiles() async =>
      profiles.values.toList();

  @override
  Future<List<ChildProfile>> getChildProfilesForParent(String parentId) async =>
      profiles.values.where((c) => c.parentId == parentId).toList();

  @override
  Future<ChildProfile?> getChildProfile(String childId) async =>
      profiles[childId];

  @override
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async {
    createCalls++;
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async {
    updateCalls++;
    profiles[profile.id] = profile;
    return profile;
  }

  @override
  Future<void> linkChildrenToParent({
    required String parentId,
    required String parentEmail,
  }) async {
    linkCalls++;
  }
}

ChildProfile _child({
  String id = 'c1',
  String name = 'Kid',
  String avatar = '🦊',
  String avatarPath = '🦊',
  List<String> picturePassword = const ['a', 'b', 'c'],
  String parentId = 'p1',
}) {
  final now = DateTime(2025, 1, 1);
  return ChildProfile(
    id: id,
    name: name,
    age: 6,
    avatar: avatar,
    avatarPath: avatarPath,
    interests: const [],
    level: 1,
    xp: 0,
    streak: 0,
    favorites: const [],
    parentId: parentId,
    picturePassword: picturePassword,
    createdAt: now,
    updatedAt: now,
    totalTimeSpent: 0,
    activitiesCompleted: 0,
  );
}

void main() {
  late _FakeNetworkService net;
  late _FakeSecureStorage storage;
  late _FakeChildRepository repo;
  late ChildProfilesViewService service;

  setUp(() {
    net = _FakeNetworkService();
    storage = _FakeSecureStorage();
    repo = _FakeChildRepository();
    service = ChildProfilesViewService(
      childRepository: repo,
      networkService: net,
      secureStorage: storage,
      logger: Logger(level: Level.off),
    );
  });

  group('dedupeChildren', () {
    test('keeps first occurrence per id', () {
      final result = service.dedupeChildren([
        _child(id: 'a', name: 'First'),
        _child(id: 'a', name: 'Second'),
        _child(id: 'b'),
      ]);
      expect(result.length, 2);
      expect(result.firstWhere((c) => c.id == 'a').name, 'First');
    });
  });

  group('loadAllChildren', () {
    test('returns local children without syncing when token is null', () async {
      repo.profiles['c1'] = _child();
      storage.token = null;

      final result = await service.loadAllChildren();
      expect(result.map((c) => c.id), ['c1']);
    });

    test('does not sync for a child-session token', () async {
      repo.profiles['c1'] = _child();
      storage.token = 'child_session_abc'; // legacy child marker

      var synced = false;
      await service.loadAllChildren(onRemoteSynced: (_) => synced = true);
      await Future<void>.delayed(Duration.zero);
      expect(synced, isFalse);
    });

    test('syncs and merges remote children for a parent token', () async {
      storage.token = 'parent-jwt-token';
      storage.userId = 'p1';
      net.childrenData = {
        'children': [
          {'id': 'remote1', 'name': 'Remote Kid', 'age': 7},
        ],
      };

      final completer = Completer<List<ChildProfile>>();
      await service.loadAllChildren(
        onRemoteSynced: (children) => completer.complete(children),
      );

      final merged = await completer.future;
      expect(merged.map((c) => c.id), contains('remote1'));
      expect(repo.createCalls, 1);
      final remote = merged.firstWhere((c) => c.id == 'remote1');
      expect(remote.name, 'Remote Kid');
      expect(remote.age, 7);
    });
  });

  group('loadParentChildren', () {
    test('links by email then returns local children', () async {
      repo.profiles['c1'] = _child(parentId: 'p1');
      storage.token = null;

      final result = await service.loadParentChildren(
        parentId: 'p1',
        parentEmail: 'mom@x.com',
      );
      expect(repo.linkCalls, 1);
      expect(result.map((c) => c.id), ['c1']);
    });
  });

  group('ensureLocalChildProfile', () {
    test('creates a new profile when none exists', () async {
      final created = await service.ensureLocalChildProfile(
        childId: 'newkid',
        selectedPictures: const ['x', 'y', 'z'],
        defaultAvatar: '🐯',
        fallbackName: 'Sara',
      );
      expect(created, isNotNull);
      expect(created!.id, 'newkid');
      expect(created.name, 'Sara');
      expect(created.picturePassword, ['x', 'y', 'z']);
      expect(repo.createCalls, 1);
    });

    test('backfills avatarPath from avatar on existing profile', () async {
      repo.profiles['c1'] = _child(avatar: '🦊', avatarPath: '');
      final updated = await service.ensureLocalChildProfile(
        childId: 'c1',
        selectedPictures: const [],
        defaultAvatar: '🐯',
      );
      expect(updated!.avatarPath, '🦊');
      expect(repo.updateCalls, 1);
    });

    test('updates picture password when changed', () async {
      repo.profiles['c1'] = _child(picturePassword: const ['a', 'b', 'c']);
      final updated = await service.ensureLocalChildProfile(
        childId: 'c1',
        selectedPictures: const ['d', 'e', 'f'],
        defaultAvatar: '🐯',
      );
      expect(updated!.picturePassword, ['d', 'e', 'f']);
    });

    test('returns existing unchanged when nothing differs', () async {
      repo.profiles['c1'] = _child(picturePassword: const ['a', 'b', 'c']);
      final result = await service.ensureLocalChildProfile(
        childId: 'c1',
        selectedPictures: const ['a', 'b', 'c'],
        defaultAvatar: '🐯',
      );
      expect(result, isNotNull);
      expect(repo.updateCalls, 0);
    });
  });
}
