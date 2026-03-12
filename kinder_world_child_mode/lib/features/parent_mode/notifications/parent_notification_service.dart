import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:logger/logger.dart';

class ParentNotificationService {
  ParentNotificationService({
    required NetworkService networkService,
    required ChildRepository childRepository,
    required ProgressRepository progressRepository,
    required SharedPreferences sharedPreferences,
    required Logger logger,
  })  : _networkService = networkService,
        _childRepository = childRepository,
        _progressRepository = progressRepository,
        _sharedPreferences = sharedPreferences,
        _logger = logger;

  static const _readDerivedIdsKey = 'read_derived_notification_ids';

  final NetworkService _networkService;
  final ChildRepository _childRepository;
  final ProgressRepository _progressRepository;
  final SharedPreferences _sharedPreferences;
  final Logger _logger;

  Future<List<ParentNotificationEntry>> loadNotifications({
    required String parentId,
    required AppLocalizations l10n,
  }) async {
    final remote = await _fetchRemoteNotifications();
    final readDerivedIds = _readDerivedIds;
    final screenTimeLimit = await _fetchScreenTimeLimitMinutes();
    final children = await _childRepository.getChildrenForParent(parentId);
    final recordsByChild = <String, List<ProgressRecord>>{};
    for (final child in children) {
      recordsByChild[child.id] =
          await _progressRepository.getProgressForChild(child.id);
    }

    final derived = buildDerivedNotifications(
      children: children,
      recordsByChild: recordsByChild,
      screenTimeLimitMinutes: screenTimeLimit,
      readDerivedIds: readDerivedIds,
      l10n: l10n,
      now: DateTime.now(),
    );

    final combined = [...remote, ...derived]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  Future<void> markAllRead(List<ParentNotificationEntry> entries) async {
    final remoteIds = entries
        .where((entry) => entry.isRemote && entry.remoteId != null)
        .map((entry) => entry.remoteId!)
        .toList();
    if (remoteIds.isNotEmpty) {
      await _networkService.post<Map<String, dynamic>>('/notifications/mark-all-read');
    }
    final derivedIds = entries
        .where((entry) => !entry.isRemote)
        .map((entry) => entry.id)
        .toSet();
    await _saveReadDerivedIds({..._readDerivedIds, ...derivedIds});
  }

  Future<void> markRead(ParentNotificationEntry entry) async {
    if (entry.isRemote && entry.remoteId != null) {
      await _networkService.post<Map<String, dynamic>>(
        '/notifications/${entry.remoteId}/read',
      );
      return;
    }
    await _saveReadDerivedIds({..._readDerivedIds, entry.id});
  }

  Future<List<ParentNotificationEntry>> _fetchRemoteNotifications() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/notifications',
      );
      final data = response.data ?? const <String, dynamic>{};
      final rawItems = data['notifications'] as List<dynamic>? ?? const [];
      return rawItems
          .whereType<Map>()
          .map(
            (item) => ParentNotificationEntry.fromBackend(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      _logger.e('Error loading remote notifications: $e');
      return const [];
    }
  }

  Future<int> _fetchScreenTimeLimitMinutes() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/parental-controls/settings',
      );
      final data = response.data ?? const <String, dynamic>{};
      final settings = Map<String, dynamic>.from(
        data['settings'] as Map? ?? const {},
      );
      final enabled = settings['daily_limit_enabled'] != false;
      final hours = (settings['hours_per_day'] as num?)?.toInt() ?? 2;
      if (!enabled) return 1 << 30;
      return hours * 60;
    } catch (_) {
      return 120;
    }
  }

  Set<String> get _readDerivedIds {
    return _sharedPreferences.getStringList(_readDerivedIdsKey)?.toSet() ??
        <String>{};
  }

  Future<void> _saveReadDerivedIds(Set<String> ids) async {
    await _sharedPreferences.setStringList(_readDerivedIdsKey, ids.toList());
  }

  static List<ParentNotificationEntry> buildDerivedNotifications({
    required List<ChildProfile> children,
    required Map<String, List<ProgressRecord>> recordsByChild,
    required int screenTimeLimitMinutes,
    required Set<String> readDerivedIds,
    required AppLocalizations l10n,
    required DateTime now,
  }) {
    final items = <ParentNotificationEntry>[];

    for (final child in children) {
      final records = List<ProgressRecord>.from(
        recordsByChild[child.id] ?? const <ProgressRecord>[],
      )..sort((a, b) => b.date.compareTo(a.date));
      final latestRecord = records.isNotEmpty ? records.first : null;
      final latestSessionAt = latestRecord?.date ?? child.lastSession;

      final latestLesson = records.cast<ProgressRecord?>().firstWhere(
            (record) =>
                record != null &&
                record.activityId.startsWith('lesson_') &&
                record.completionStatus == CompletionStatus.completed,
            orElse: () => null,
          );
      if (latestLesson != null &&
          now.difference(latestLesson.date).inDays <= 7) {
        items.add(
          _derivedEntry(
            id: 'lesson-${child.id}-${latestLesson.id}',
            type: 'LESSON_COMPLETED',
            title: l10n.lesson,
            body: l10n.notificationLessonCompleted(
              child.name,
              latestLesson.notes?.trim().isNotEmpty == true
                  ? latestLesson.notes!.trim()
                  : latestLesson.activityId.replaceFirst('lesson_', ''),
            ),
            createdAt: latestLesson.date,
            childId: child.id,
            readDerivedIds: readDerivedIds,
          ),
        );
      }

      if (child.streak > 0 &&
          _isStreakMilestone(child.streak) &&
          latestSessionAt != null &&
          now.difference(latestSessionAt).inDays <= 1) {
        items.add(
          _derivedEntry(
            id: 'streak-${child.id}-${child.streak}',
            type: 'STREAK_REACHED',
            title: l10n.streak,
            body: l10n.notificationStreakReached(child.name, child.streak),
            createdAt: latestSessionAt,
            childId: child.id,
            readDerivedIds: readDerivedIds,
          ),
        );
      }

      if (latestSessionAt != null) {
        final inactiveDays = now.difference(latestSessionAt).inDays;
        if (inactiveDays >= 3) {
          items.add(
            _derivedEntry(
              id: 'inactive-${child.id}-${latestSessionAt.toIso8601String()}',
              type: 'INACTIVITY_REMINDER',
              title: l10n.notifications,
              body: l10n.notificationInactive(child.name, inactiveDays),
              createdAt: latestSessionAt.add(const Duration(hours: 1)),
              childId: child.id,
              readDerivedIds: readDerivedIds,
            ),
          );
        }
      }

      final todaysMinutes = records
          .where(
            (record) =>
                record.date.year == now.year &&
                record.date.month == now.month &&
                record.date.day == now.day,
          )
          .fold<int>(0, (sum, record) => sum + record.duration);
      if (todaysMinutes > screenTimeLimitMinutes) {
        items.add(
          _derivedEntry(
            id: 'screen-${child.id}-${now.year}-${now.month}-${now.day}',
            type: 'SCREEN_TIME_LIMIT',
            title: l10n.notifications,
            body: l10n.notificationScreenTime(
              child.name,
              (screenTimeLimitMinutes / 60).ceil(),
            ),
            createdAt: now,
            childId: child.id,
            readDerivedIds: readDerivedIds,
          ),
        );
      }
    }

    return items;
  }

  static ParentNotificationEntry _derivedEntry({
    required String id,
    required String type,
    required String title,
    required String body,
    required DateTime createdAt,
    required String childId,
    required Set<String> readDerivedIds,
  }) {
    return ParentNotificationEntry(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: readDerivedIds.contains(id),
      isRemote: false,
      childId: childId,
    );
  }

  static bool _isStreakMilestone(int value) {
    return const {1, 3, 7, 14, 30, 100}.contains(value);
  }
}

final parentNotificationServiceProvider = Provider<ParentNotificationService>((ref) {
  final networkService = ref.watch(networkServiceProvider);
  final childRepository = ref.watch(childRepositoryProvider);
  final progressRepository = ref.watch(progressRepositoryProvider);
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  final logger = ref.watch(loggerProvider);

  return ParentNotificationService(
    networkService: networkService,
    childRepository: childRepository,
    progressRepository: progressRepository,
    sharedPreferences: sharedPreferences,
    logger: logger,
  );
});
