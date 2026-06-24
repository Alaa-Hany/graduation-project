import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/utils/children_api_parsing.dart';
import 'package:kinder_world/core/utils/session_token_utils.dart';
import 'package:logger/logger.dart';

class ChildProfilesViewService {
  ChildProfilesViewService({
    required ChildRepository childRepository,
    required NetworkService networkService,
    required SecureStorage secureStorage,
    required Logger logger,
  })  : _childRepository = childRepository,
        _networkService = networkService,
        _secureStorage = secureStorage,
        _logger = logger;

  final ChildRepository _childRepository;
  final NetworkService _networkService;
  final SecureStorage _secureStorage;
  final Logger _logger;

  Future<List<ChildProfile>> loadAllChildren({
    String defaultAvatar = AppConstants.defaultChildAvatar,
    String localParentId = 'local',
    String? localParentEmail,
    FutureOr<void> Function(List<ChildProfile> children)? onRemoteSynced,
  }) async {
    final localChildren = await _childRepository.getAllChildProfiles();
    final childrenById = {
      for (final child in localChildren) child.id: child,
    };

    final token = _secureStorage.hasCachedAuthToken
        ? _secureStorage.cachedAuthToken
        : await _secureStorage.getAuthToken();
    if (token == null || isChildSessionToken(token)) {
      return childrenById.values.toList(growable: false);
    }

    final parentId = _secureStorage.hasCachedUserId
        ? _secureStorage.cachedUserId
        : await _secureStorage.getParentId();
    final parentEmail = _secureStorage.hasCachedUserEmail
        ? _secureStorage.cachedUserEmail
        : await _secureStorage.getParentEmail();

    unawaited(
      _syncChildren(
        initialChildren: childrenById,
        parentId: parentId ?? localParentId,
        parentEmail: parentEmail ?? localParentEmail,
        defaultAvatar: defaultAvatar,
        preserveExistingAgeIfValid: true,
        preserveExistingRealName: true,
      ).then((children) async {
        if (onRemoteSynced != null) {
          await onRemoteSynced(children);
        }
      }).catchError((Object error, StackTrace stackTrace) {
        _logger.w('Error syncing all children for view: $error');
      }),
    );

    return childrenById.values.toList(growable: false);
  }

  Future<List<ChildProfile>> loadParentChildren({
    required String parentId,
    String? parentEmail,
    String defaultAvatar = AppConstants.defaultChildAvatar,
    FutureOr<void> Function(List<ChildProfile> children)? onRemoteSynced,
  }) async {
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await _childRepository.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }

    final localChildren =
        await _childRepository.getChildProfilesForParent(parentId);
    final childrenById = {
      for (final child in localChildren) child.id: child,
    };

    final token = _secureStorage.hasCachedAuthToken
        ? _secureStorage.cachedAuthToken
        : await _secureStorage.getAuthToken();
    if (token == null || isChildSessionToken(token)) {
      return childrenById.values.toList(growable: false);
    }

    unawaited(
      _syncChildren(
        initialChildren: childrenById,
        parentId: parentId,
        parentEmail: parentEmail,
        defaultAvatar: defaultAvatar,
        preserveExistingAgeIfValid: false,
        preserveExistingRealName: false,
      ).then((children) async {
        if (onRemoteSynced != null) {
          await onRemoteSynced(children);
        }
      }).catchError((Object error, StackTrace stackTrace) {
        _logger.w('Error syncing parent children for view: $error');
      }),
    );

    return childrenById.values.toList(growable: false);
  }

  Future<ChildProfile?> ensureLocalChildProfile({
    required String childId,
    required List<String> selectedPictures,
    required String defaultAvatar,
    ChildProfile? childProfile,
    String? fallbackName,
  }) async {
    final existing =
        childProfile ?? await _childRepository.getChildProfile(childId);
    final password = selectedPictures.length == 3
        ? List<String>.from(selectedPictures)
        : const <String>[];
    final resolvedFallback =
        (fallbackName != null && fallbackName.trim().isNotEmpty)
            ? fallbackName.trim()
            : null;
    final isDefaultName = resolvedFallback != null &&
        (resolvedFallback == childId || resolvedFallback == 'Child $childId');

    if (existing != null) {
      var updatedProfile = existing;
      if (existing.avatarPath.isEmpty && existing.avatar.isNotEmpty) {
        updatedProfile = updatedProfile.copyWith(
          avatarPath: existing.avatar,
          updatedAt: DateTime.now(),
        );
      }
      if (password.isNotEmpty &&
          !_samePictures(existing.picturePassword, password)) {
        updatedProfile = updatedProfile.copyWith(
          picturePassword: password,
          updatedAt: DateTime.now(),
        );
      }
      if (resolvedFallback != null &&
          !isDefaultName &&
          existing.name != resolvedFallback) {
        updatedProfile = updatedProfile.copyWith(
          name: resolvedFallback,
          updatedAt: DateTime.now(),
        );
      }
      if (updatedProfile != existing) {
        return await _childRepository.updateChildProfile(updatedProfile);
      }
      return updatedProfile;
    }

    final now = DateTime.now();
    final finalName = _resolveLocalProfileName(
      childId: childId,
      childProfile: childProfile,
      fallbackName: resolvedFallback,
      isDefaultName: isDefaultName,
    );

    final newProfile = ChildProfile(
      id: childId,
      name: finalName,
      age: childProfile?.age ?? 0,
      avatar: childProfile?.avatar ?? defaultAvatar,
      avatarPath: childProfile?.avatarPath.isNotEmpty == true
          ? childProfile!.avatarPath
          : (childProfile?.avatar ?? defaultAvatar),
      interests: childProfile?.interests ?? const [],
      level: childProfile?.level ?? 1,
      xp: childProfile?.xp ?? 0,
      streak: childProfile?.streak ?? 0,
      favorites: childProfile?.favorites ?? const [],
      parentId: childProfile?.parentId ?? 'local',
      parentEmail: childProfile?.parentEmail,
      picturePassword: password,
      createdAt: childProfile?.createdAt ?? now,
      updatedAt: now,
      lastSession: childProfile?.lastSession,
      totalTimeSpent: childProfile?.totalTimeSpent ?? 0,
      activitiesCompleted: childProfile?.activitiesCompleted ?? 0,
      currentMood: childProfile?.currentMood,
      learningStyle: childProfile?.learningStyle,
      specialNeeds: childProfile?.specialNeeds,
      accessibilityNeeds: childProfile?.accessibilityNeeds,
    );

    return await _childRepository.createChildProfile(newProfile);
  }

  List<ChildProfile> dedupeChildren(List<ChildProfile> children) {
    final seen = <String, ChildProfile>{};
    for (final child in children) {
      seen.putIfAbsent(child.id, () => child);
    }
    return seen.values.toList(growable: false);
  }

  Future<List<ChildProfile>> _syncChildren({
    required Map<String, ChildProfile> initialChildren,
    required String parentId,
    required String? parentEmail,
    required String defaultAvatar,
    required bool preserveExistingAgeIfValid,
    required bool preserveExistingRealName,
  }) async {
    final childrenById = Map<String, ChildProfile>.from(initialChildren);
    final response = await _networkService.get<dynamic>('/children');
    final apiChildren = extractChildrenList(response.data);
    final writeOperations = <Future<Object?>>[];

    for (final childData in apiChildren) {
      final childId = parseChildId(childData);
      if (childId == null || childId.isEmpty) continue;
      final existing = childrenById[childId];
      final merged = _mergeChildProfileFromApi(
        childData,
        existing: existing,
        parentId: parentId,
        parentEmail: parentEmail,
        defaultAvatar: defaultAvatar,
        preserveExistingAgeIfValid: preserveExistingAgeIfValid,
        preserveExistingRealName: preserveExistingRealName,
      );
      if (merged == null) continue;
      childrenById[childId] = merged;
      writeOperations.add(
        existing == null
            ? _childRepository.createChildProfile(merged)
            : _childRepository.updateChildProfile(merged),
      );
    }

    if (writeOperations.isNotEmpty) {
      await Future.wait(writeOperations);
    }
    return childrenById.values.toList(growable: false);
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    required String defaultAvatar,
    required bool preserveExistingAgeIfValid,
    required bool preserveExistingRealName,
    ChildProfile? existing,
    String? parentId,
    String? parentEmail,
  }) {
    final childId = parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final resolvedName = preserveExistingRealName
        ? _resolveChildLoginName(
            childId: childId,
            apiName: apiName,
            existingName: existing?.name,
          )
        : (apiName != null && apiName.isNotEmpty)
            ? apiName
            : (existing?.name ?? childId);
    final age = _resolveAgeFromApi(
      data,
      existing,
      preserveExistingAgeIfValid: preserveExistingAgeIfValid,
    );
    final mergedLevel = _mergeProgress(data, 'level', existing?.level ?? 0);
    final level = mergedLevel > 0 ? mergedLevel : 1;
    final avatar =
        existing?.avatar ?? data['avatar']?.toString() ?? defaultAvatar;
    final resolvedAvatarPath = existing?.avatarPath.isNotEmpty == true
        ? existing!.avatarPath
        : (avatar.isNotEmpty ? avatar : defaultAvatar);
    final picturePassword = (existing?.picturePassword.isNotEmpty ?? false)
        ? existing!.picturePassword
        : _parseStringList(data['picture_password']);
    final createdAt =
        existing?.createdAt ?? _parseDate(data['created_at'], now);
    final updatedAt = _parseDate(data['updated_at'], now);
    final lastSession =
        existing?.lastSession ?? _parseNullableDate(data['last_session']);

    return ChildProfile(
      id: childId,
      name: resolvedName,
      age: age,
      avatar: avatar,
      avatarPath: resolvedAvatarPath,
      interests: existing?.interests ?? _parseStringList(data['interests']),
      level: level,
      xp: _mergeProgress(data, 'xp', existing?.xp ?? 0),
      streak: _mergeProgress(data, 'streak', existing?.streak ?? 0),
      favorites: existing?.favorites ?? _parseStringList(data['favorites']),
      parentId: parentId ?? existing?.parentId ?? 'local',
      parentEmail: existing?.parentEmail ??
          parentEmail ??
          data['parent_email']?.toString(),
      picturePassword: picturePassword,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSession: lastSession,
      totalTimeSpent:
          _mergeProgress(data, 'total_time_spent', existing?.totalTimeSpent ?? 0),
      activitiesCompleted: _mergeProgress(
          data, 'activities_completed', existing?.activitiesCompleted ?? 0),
      currentMood: existing?.currentMood ?? data['current_mood']?.toString(),
      learningStyle:
          existing?.learningStyle ?? data['learning_style']?.toString(),
      specialNeeds: existing?.specialNeeds ??
          _parseNullableStringList(data['special_needs']),
      accessibilityNeeds: existing?.accessibilityNeeds ??
          _parseNullableStringList(data['accessibility_needs']),
    );
  }

  String _resolveLocalProfileName({
    required String childId,
    required ChildProfile? childProfile,
    required String? fallbackName,
    required bool isDefaultName,
  }) {
    if (childProfile != null &&
        childProfile.name.isNotEmpty &&
        childProfile.name != childId &&
        childProfile.name.toLowerCase() != 'child') {
      return childProfile.name;
    }
    if (!isDefaultName &&
        fallbackName != null &&
        fallbackName.toLowerCase() != 'child') {
      return fallbackName;
    }
    return childId;
  }

  String _resolveChildLoginName({
    required String childId,
    required String? apiName,
    required String? existingName,
  }) {
    final hasRealName = existingName != null &&
        existingName.isNotEmpty &&
        existingName != childId &&
        existingName.toLowerCase() != 'child';
    if (apiName != null &&
        apiName.isNotEmpty &&
        apiName != childId &&
        apiName.toLowerCase() != 'child') {
      return apiName;
    }
    return hasRealName ? existingName : childId;
  }

  bool _samePictures(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Resolves a progress counter (xp/level/streak/time/activities) in parent
  /// mode. The backend aggregates these from the child's analytics, so the
  /// server is the source of truth — but we never regress below a fresher local
  /// value (e.g. on a shared device where child mode just updated Hive). When
  /// the key is absent (older backend) the local value is kept unchanged.
  int _mergeProgress(Map<String, dynamic> data, String key, int existingValue) {
    if (!data.containsKey(key) || data[key] == null) {
      return existingValue;
    }
    final apiValue = _parseInt(data[key], existingValue);
    return apiValue > existingValue ? apiValue : existingValue;
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
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
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
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
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

  int _resolveAgeFromApi(
    Map<String, dynamic> data,
    ChildProfile? existing, {
    required bool preserveExistingAgeIfValid,
  }) {
    final existingAge = existing?.age ?? 0;
    if (preserveExistingAgeIfValid && existingAge > 0) {
      return existingAge;
    }

    final apiAge = _parseInt(data['age'], 0);
    final birthDate = _parseBirthDate(
      data['birthdate'] ??
          data['birth_date'] ??
          data['date_of_birth'] ??
          data['dob'],
    );
    final computedAge = _ageFromBirthDate(birthDate);

    if (kDebugMode) {
      debugPrint(
        'Child age resolve: apiAge=$apiAge, birthDate=$birthDate, computedAge=$computedAge, existing=$existingAge',
      );
    }

    if (apiAge > 0) return apiAge;
    if (computedAge > 0) return computedAge;
    return preserveExistingAgeIfValid ? 0 : existingAge;
  }
}

final childProfilesViewServiceProvider = Provider<ChildProfilesViewService>((
  ref,
) {
  return ChildProfilesViewService(
    childRepository: ref.watch(childRepositoryProvider),
    networkService: ref.watch(networkServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
    logger: ref.watch(loggerProvider),
  );
});
