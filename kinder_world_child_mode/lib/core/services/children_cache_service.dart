import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/api/children_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/cache_provider.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/utils/children_api_parsing.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';

const _childrenCacheScope = 'children_list';
const _childrenStaleAfter = Duration(minutes: 5);

class ChildrenCacheResult {
  const ChildrenCacheResult({
    required this.children,
    required this.snapshot,
  });

  final List<ChildProfile> children;
  final CacheSnapshot snapshot;
}

class ChildrenCacheService {
  ChildrenCacheService({
    required ChildRepository childRepository,
    required ChildrenApi childrenApi,
    required SecureStorage secureStorage,
    required AppCacheStore cacheStore,
    required Logger logger,
  })  : _childRepository = childRepository,
        _childrenApi = childrenApi,
        _secureStorage = secureStorage,
        _cacheStore = cacheStore,
        _logger = logger;

  final ChildRepository _childRepository;
  final ChildrenApi _childrenApi;
  final SecureStorage _secureStorage;
  final AppCacheStore _cacheStore;
  final Logger _logger;

  Future<ChildrenCacheResult> loadChildrenForParent(
    String parentId, {
    String? parentEmail,
    bool forceRefresh = false,
  }) async {
    if (parentId.isEmpty) {
      return const ChildrenCacheResult(
        children: [],
        snapshot: CacheSnapshot(
          hasData: false,
          freshness: CacheFreshness.missing,
          syncState: CacheSyncState.neverSynced,
        ),
      );
    }

    if (parentEmail != null && parentEmail.isNotEmpty) {
      await _childRepository.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }

    final localChildren =
        await _childRepository.getChildProfilesForParent(parentId);
    final localById = {
      for (final child in localChildren) child.id: child,
    };
    final token = _secureStorage.hasCachedAuthToken
        ? _secureStorage.cachedAuthToken
        : await _secureStorage.getAuthToken();
    final snapshot = _cacheStore.snapshot(
      scope: _childrenCacheScope,
      key: parentId,
      staleAfter: _childrenStaleAfter,
    );

    final shouldFetchRemote =
        forceRefresh || snapshot.isStale || localById.isEmpty;
    final isAuthMissing =
        token == null || token.isEmpty || token.startsWith('child_session_');
    if (isAuthMissing) {
      final isServerBacked = snapshot.syncState != CacheSyncState.neverSynced;
      if (!isServerBacked) {
        return ChildrenCacheResult(
          children: const [],
          snapshot: snapshot,
        );
      }
      return ChildrenCacheResult(
        children: localById.values.toList(growable: false),
        snapshot: snapshot,
      );
    }
    if (!shouldFetchRemote) {
      return ChildrenCacheResult(
        children: localById.values.toList(growable: false),
        snapshot: snapshot,
      );
    }

    try {
      final apiChildren = await _childrenApi.fetchChildren();
      final writeOperations = <Future<Object?>>[];
      for (final childData in apiChildren) {
        final childId = parseChildId(childData);
        if (childId == null || childId.isEmpty) continue;
        final existing = localById[childId];
        final merged = _mergeChildProfileFromApi(
          childData,
          existing: existing,
          parentId: parentId,
          parentEmail: parentEmail,
        );
        if (merged == null) continue;
        localById[childId] = merged;
        writeOperations.add(
          existing == null
              ? _childRepository.createChildProfile(merged)
              : _childRepository.updateChildProfile(merged),
        );
      }
      if (writeOperations.isNotEmpty) {
        await Future.wait(writeOperations);
      }

      await _cacheStore.markFetched(
        scope: _childrenCacheScope,
        key: parentId,
      );

      final refreshedSnapshot = _cacheStore.snapshot(
        scope: _childrenCacheScope,
        key: parentId,
        staleAfter: _childrenStaleAfter,
      );
      return ChildrenCacheResult(
        children: localById.values.toList(growable: false),
        snapshot: CacheSnapshot(
          hasData: true,
          freshness: CacheFreshness.freshServerBacked,
          syncState: refreshedSnapshot.syncState,
          lastFetchedAt: refreshedSnapshot.lastFetchedAt,
          lastSyncedAt: refreshedSnapshot.lastSyncedAt,
          lastMutationAt: refreshedSnapshot.lastMutationAt,
        ),
      );
    } catch (e) {
      _logger
          .w('Children remote refresh failed, serving cached local data: $e');
      await _cacheStore.markSyncFailed(
        scope: _childrenCacheScope,
        key: parentId,
      );
      final staleSnapshot = _cacheStore.snapshot(
        scope: _childrenCacheScope,
        key: parentId,
        staleAfter: _childrenStaleAfter,
      );
      final isServerBacked = staleSnapshot.syncState != CacheSyncState.neverSynced;
      return ChildrenCacheResult(
        children: isServerBacked
            ? localById.values.toList(growable: false)
            : const [],
        snapshot: staleSnapshot,
      );
    }
  }

  Future<void> markChildrenMutated(String parentId) async {
    if (parentId.isEmpty) return;
    await _cacheStore.markMutation(
      scope: _childrenCacheScope,
      key: parentId,
    );
  }

  Future<void> invalidateChildrenCache(String parentId) async {
    if (parentId.isEmpty) return;
    await _cacheStore.invalidate(
      scope: _childrenCacheScope,
      key: parentId,
      removePayload: false,
    );
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return fallback;
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }

  List<String>? _parseNullableStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return null;
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  int _ageFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) age -= 1;
    return age.clamp(0, 120);
  }

  int _resolveAgeFromApi(Map<String, dynamic> data, ChildProfile? existing) {
    final apiAge = _parseInt(data['age'], 0);
    final birthDate = _parseBirthDate(
      data['birthdate'] ??
          data['birth_date'] ??
          data['date_of_birth'] ??
          data['dob'],
    );
    final computedAge = _ageFromBirthDate(birthDate);

    if (apiAge > 0) return apiAge;
    if (computedAge > 0) return computedAge;
    return existing?.age ?? 0;
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    ChildProfile? existing,
    String? parentId,
    String? parentEmail,
  }) {
    final childId = parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final resolvedName = (apiName != null && apiName.isNotEmpty)
        ? apiName
        : (existing?.name ?? childId);
    final age = _resolveAgeFromApi(data, existing);
    final existingLevel = existing?.level ?? 0;
    final level =
        existingLevel > 0 ? existingLevel : _parseInt(data['level'], 1);
    final avatar = existing?.avatar ??
        data['avatar']?.toString() ??
        AppConstants.defaultChildAvatar;
    final resolvedAvatarPath = existing?.avatarPath.isNotEmpty == true
        ? existing!.avatarPath
        : (avatar.isNotEmpty ? avatar : AppConstants.defaultChildAvatar);
    final picturePassword = (existing?.picturePassword.isNotEmpty ?? false)
        ? existing!.picturePassword
        : _parseStringList(data['picture_password']);
    final createdAt =
        existing?.createdAt ?? _parseDate(data['created_at'], now);
    final updatedAt = _parseDate(data['updated_at'], now);
    final lastSession =
        existing?.lastSession ?? _parseNullableDate(data['last_session']);

    final resolvedParentId = parentId ?? existing?.parentId;
    if (resolvedParentId == null || resolvedParentId.isEmpty) {
      return null;
    }

    return ChildProfile(
      id: childId,
      name: resolvedName,
      age: age,
      avatar: avatar,
      avatarPath: resolvedAvatarPath,
      interests: existing?.interests ?? _parseStringList(data['interests']),
      level: level,
      xp: existing?.xp ?? _parseInt(data['xp'], 0),
      streak: existing?.streak ?? _parseInt(data['streak'], 0),
      favorites: existing?.favorites ?? _parseStringList(data['favorites']),
      parentId: resolvedParentId,
      parentEmail: existing?.parentEmail ??
          parentEmail ??
          data['parent_email']?.toString(),
      picturePassword: picturePassword,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSession: lastSession,
      totalTimeSpent:
          existing?.totalTimeSpent ?? _parseInt(data['total_time_spent'], 0),
      activitiesCompleted: existing?.activitiesCompleted ??
          _parseInt(data['activities_completed'], 0),
      currentMood: existing?.currentMood ?? data['current_mood']?.toString(),
      learningStyle:
          existing?.learningStyle ?? data['learning_style']?.toString(),
      specialNeeds: existing?.specialNeeds ??
          _parseNullableStringList(data['special_needs']),
      accessibilityNeeds: existing?.accessibilityNeeds ??
          _parseNullableStringList(data['accessibility_needs']),
    );
  }
}

final childrenCacheServiceProvider = Provider<ChildrenCacheService>((ref) {
  final childRepository = ref.watch(childRepositoryProvider);
  final childrenApi = ref.watch(childrenApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final cacheStore = ref.watch(appCacheStoreProvider);
  final logger = ref.watch(loggerProvider);

  return ChildrenCacheService(
    childRepository: childRepository,
    childrenApi: childrenApi,
    secureStorage: secureStorage,
    cacheStore: cacheStore,
    logger: logger,
  );
});
