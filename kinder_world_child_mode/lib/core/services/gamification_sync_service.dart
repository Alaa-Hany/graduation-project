import 'package:hive/hive.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/gamification_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/child_mode/learn/coloring_progress_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs the child's full local-first state with the backend so it survives a
/// fresh device / web storage reset. Covers the gamification box (coins, badges,
/// achievements, reward-store purchases) plus the extras that live outside it:
/// avatar customization, favorites, mood history and coloring progress.
///
/// The whole thing is sent as one opaque snapshot (the backend's
/// `gamification_state` JSON column is content-agnostic). Push is fire-and-forget;
/// restore is driven by the login flow.
class ClientStateSyncService {
  ClientStateSyncService({
    required GamificationRepository gamificationRepository,
    required ChildRepository childRepository,
    required Box moodBox,
    required SharedPreferences sharedPreferences,
    required ReportsApi reportsApi,
    required SecureStorage secureStorage,
    required Logger logger,
  })  : _gamRepo = gamificationRepository,
        _childRepo = childRepository,
        _moodBox = moodBox,
        _prefs = sharedPreferences,
        _reportsApi = reportsApi,
        _secureStorage = secureStorage,
        _logger = logger;

  final GamificationRepository _gamRepo;
  final ChildRepository _childRepo;
  final Box _moodBox;
  final SharedPreferences _prefs;
  final ReportsApi _reportsApi;
  final SecureStorage _secureStorage;
  final Logger _logger;

  // Reserved snapshot keys for the non-gamification extras.
  static const _kAvatar = '__avatar';
  static const _kFavorites = '__favorites';
  static const _kMood = '__mood';
  static const _kColoring = '__coloring';

  String _avatarPrefKey(String childId) => 'child_avatar_customization_$childId';
  String _moodKey(String childId) => 'entries_$childId';

  /// Uploads the current full snapshot for [childId]. Never throws — the app
  /// stays usable offline and re-syncs on the next change or login.
  Future<void> push(String childId) async {
    if (childId.isEmpty) return;
    final childIdInt = int.tryParse(childId);
    if (childIdInt == null) return; // server child ids are ints
    try {
      final token = await _resolveToken();
      if (token == null) return;

      final snapshot = await _gamRepo.exportSnapshot(childId);
      final data = Map<String, dynamic>.from(snapshot['data'] as Map);

      // ── Extras (live outside the gamification box) ──
      final avatar = _prefs.getString(_avatarPrefKey(childId));
      if (avatar != null) data[_kAvatar] = avatar;

      final profile = await _childRepo.getChildProfile(childId);
      if (profile != null) data[_kFavorites] = profile.favorites;

      final mood = _moodBox.get(_moodKey(childId));
      if (mood != null) data[_kMood] = mood;

      final coloring = <String, dynamic>{};
      final coloringPrefix = ColoringProgressStorage.childPrefix(childId);
      for (final key in _prefs.getKeys()) {
        if (key.startsWith(coloringPrefix)) {
          coloring[key] = _prefs.getString(key);
        }
      }
      if (coloring.isNotEmpty) data[_kColoring] = coloring;

      await _reportsApi.syncGamificationState(
        {
          'child_id': childIdInt,
          'updated_at': snapshot['updated_at'],
          'data': data,
        },
        parentAccessToken: token,
      );
    } catch (e) {
      _logger.w('Client state snapshot push failed: $e');
    }
  }

  /// Applies a server snapshot (from the login endpoint) into local storage.
  /// Gamification is handled by [GamificationRepository.importSnapshot] (which
  /// owns the last-write-wins decision); the extras are applied only when that
  /// decision says the server copy is the one to keep.
  Future<void> restore(String childId, dynamic serverState) async {
    try {
      final applied = await _gamRepo.importSnapshot(childId, serverState);
      if (!applied) return; // local copy is at least as fresh — keep everything
      if (serverState is! Map) return;
      final data = serverState['data'];
      if (data is! Map) return;

      final avatar = data[_kAvatar];
      if (avatar is String) {
        await _prefs.setString(_avatarPrefKey(childId), avatar);
      }

      final favorites = data[_kFavorites];
      if (favorites is List) {
        final profile = await _childRepo.getChildProfile(childId);
        if (profile != null) {
          await _childRepo.updateChildProfile(
            profile.copyWith(
              favorites: favorites.map((e) => e.toString()).toList(),
            ),
          );
        }
      }

      final mood = data[_kMood];
      if (mood != null) {
        await _moodBox.put(_moodKey(childId), mood);
      }

      final coloring = data[_kColoring];
      if (coloring is Map) {
        for (final entry in coloring.entries) {
          final value = entry.value;
          if (value is String) {
            await _prefs.setString(entry.key.toString(), value);
          }
        }
      }
      _logger.i('Restored full client state for child $childId');
    } catch (e) {
      _logger.w('Client state restore failed: $e');
    }
  }

  Future<String?> _resolveToken() async {
    final parentToken = await _secureStorage.getParentAccessToken();
    if (parentToken != null && parentToken.isNotEmpty) return parentToken;
    final authToken = await _secureStorage.getAuthToken();
    if (authToken != null && authToken.isNotEmpty) return authToken;
    return null;
  }
}
