import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/privacy_provider.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/services/privacy_service.dart';
import 'package:kinder_world/core/services/support_service.dart';
import 'package:kinder_world/core/providers/support_controller.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_entry.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notification_service.dart';
import 'package:logger/logger.dart';

class SafetyControlsSummary {
  const SafetyControlsSummary({
    required this.dailyLimitEnabled,
    required this.hoursPerDay,
    required this.breakRemindersEnabled,
    required this.ageAppropriateOnly,
    required this.requireApproval,
    required this.sleepMode,
    required this.bedtime,
    required this.wakeTime,
    required this.emergencyLock,
  });

  final bool dailyLimitEnabled;
  final int hoursPerDay;
  final bool breakRemindersEnabled;
  final bool ageAppropriateOnly;
  final bool requireApproval;
  final bool sleepMode;
  final String bedtime;
  final String wakeTime;
  final bool emergencyLock;

  bool get hasActiveProtection =>
      dailyLimitEnabled ||
      ageAppropriateOnly ||
      requireApproval ||
      sleepMode ||
      emergencyLock;

  factory SafetyControlsSummary.fromJson(Map<String, dynamic> json) {
    return SafetyControlsSummary(
      dailyLimitEnabled: json['daily_limit_enabled'] != false,
      hoursPerDay: (json['hours_per_day'] as num?)?.toInt() ?? 2,
      breakRemindersEnabled: json['break_reminders_enabled'] == true,
      ageAppropriateOnly: json['age_appropriate_only'] != false,
      requireApproval: json['require_approval'] == true,
      sleepMode: json['sleep_mode'] == true,
      bedtime: json['bedtime']?.toString() ?? '8:00 PM',
      wakeTime: json['wake_time']?.toString() ?? '7:00 AM',
      emergencyLock: json['emergency_lock'] == true,
    );
  }

  factory SafetyControlsSummary.defaults() {
    return const SafetyControlsSummary(
      dailyLimitEnabled: true,
      hoursPerDay: 2,
      breakRemindersEnabled: true,
      ageAppropriateOnly: true,
      requireApproval: false,
      sleepMode: true,
      bedtime: '8:00 PM',
      wakeTime: '7:00 AM',
      emergencyLock: false,
    );
  }
}

class SafetyLastActivity {
  const SafetyLastActivity({
    required this.childName,
    required this.title,
    required this.timestamp,
  });

  final String childName;
  final String title;
  final DateTime timestamp;
}

class SafetyDashboardSnapshot {
  const SafetyDashboardSnapshot({
    required this.children,
    required this.controls,
    required this.privacySettings,
    required this.notifications,
    required this.supportTickets,
    required this.hasParentPin,
    required this.weeklyScreenTimeMinutes,
    required this.todayScreenTimeMinutes,
    required this.lastActivity,
  });

  final List<ChildProfile> children;
  final SafetyControlsSummary controls;
  final PrivacySettings privacySettings;
  final List<ParentNotificationEntry> notifications;
  final List<SupportTicketRecord> supportTickets;
  final bool hasParentPin;
  final int weeklyScreenTimeMinutes;
  final int todayScreenTimeMinutes;
  final SafetyLastActivity? lastActivity;

  int get unreadAlertsCount =>
      notifications.where((item) => !item.isRead).length;

  int get openSupportTicketsCount => supportTickets.where((ticket) {
        return ticket.status == 'open' || ticket.status == 'in_progress';
      }).length;

  int get privacyGuardsEnabledCount {
    var count = 0;
    if (!privacySettings.analyticsEnabled) count++;
    if (!privacySettings.personalizedRecommendations) count++;
    if (privacySettings.dataCollectionOptOut) count++;
    return count;
  }

  List<ParentNotificationEntry> get highlightedAlerts {
    final unread = notifications.where((item) => !item.isRead).toList();
    final prioritized = unread.where((item) {
      return item.type == 'SCREEN_TIME_LIMIT' ||
          item.type == 'INACTIVITY_REMINDER' ||
          item.type == 'SUPPORT_TICKET_UPDATE';
    }).toList();
    if (prioritized.isNotEmpty) return prioritized.take(3).toList();
    return unread.take(3).toList();
  }

  static SafetyDashboardSnapshot build({
    required List<ChildProfile> children,
    required SafetyControlsSummary controls,
    required PrivacySettings privacySettings,
    required List<ParentNotificationEntry> notifications,
    required List<SupportTicketRecord> supportTickets,
    required bool hasParentPin,
    required List<ProgressRecord> records,
    required DateTime now,
  }) {
    final weeklyMinutes = records
        .where((record) => now.difference(record.date).inDays < 7)
        .fold<int>(0, (sum, record) => sum + record.duration);
    final todayMinutes = records.where((record) {
      return record.date.year == now.year &&
          record.date.month == now.month &&
          record.date.day == now.day;
    }).fold<int>(0, (sum, record) => sum + record.duration);

    final sortedRecords = List<ProgressRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    SafetyLastActivity? lastActivity;
    if (sortedRecords.isNotEmpty) {
      final latest = sortedRecords.first;
      final child = children.cast<ChildProfile?>().firstWhere(
            (item) => item?.id == latest.childId,
            orElse: () => null,
          );
      lastActivity = SafetyLastActivity(
        childName: child?.name ?? latest.childId,
        title: _activityTitle(latest),
        timestamp: latest.date,
      );
    } else {
      final lastSessionChild = children
          .where((child) => child.lastSession != null)
          .toList()
        ..sort((a, b) => b.lastSession!.compareTo(a.lastSession!));
      if (lastSessionChild.isNotEmpty) {
        final child = lastSessionChild.first;
        lastActivity = SafetyLastActivity(
          childName: child.name,
          title: child.currentMood ?? child.learningStyle ?? child.name,
          timestamp: child.lastSession!,
        );
      }
    }

    final fallbackWeeklyMinutes = children.fold<int>(
      0,
      (sum, child) => sum + child.totalTimeSpent,
    );

    return SafetyDashboardSnapshot(
      children: children,
      controls: controls,
      privacySettings: privacySettings,
      notifications: notifications,
      supportTickets: supportTickets,
      hasParentPin: hasParentPin,
      weeklyScreenTimeMinutes:
          weeklyMinutes > 0 ? weeklyMinutes : fallbackWeeklyMinutes,
      todayScreenTimeMinutes: todayMinutes,
      lastActivity: lastActivity,
    );
  }

  static String _activityTitle(ProgressRecord record) {
    final notes = record.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }
    return record.activityId.replaceAll('_', ' ');
  }
}

class SafetyDashboardService {
  SafetyDashboardService({
    required ChildRepository childRepository,
    required ProgressRepository progressRepository,
    required ParentNotificationService parentNotificationService,
    required PrivacyService privacyService,
    required SupportService supportService,
    required AuthRepository authRepository,
    required Logger logger,
    required Ref ref,
  })  : _childRepository = childRepository,
        _progressRepository = progressRepository,
        _parentNotificationService = parentNotificationService,
        _privacyService = privacyService,
        _supportService = supportService,
        _authRepository = authRepository,
        _logger = logger,
        _ref = ref;

  final ChildRepository _childRepository;
  final ProgressRepository _progressRepository;
  final ParentNotificationService _parentNotificationService;
  final PrivacyService _privacyService;
  final SupportService _supportService;
  final AuthRepository _authRepository;
  final Logger _logger;
  final Ref _ref;

  Future<SafetyDashboardSnapshot> load({
    required String parentId,
    required AppLocalizations l10n,
  }) async {
    final children = await _loadChildren(parentId);
    final records = <ProgressRecord>[];
    for (final child in children) {
      records.addAll(await _progressRepository.getProgressForChild(child.id));
    }

    final controlsFuture = _loadControls();
    final privacyFuture = _privacyService.getPrivacySettings();
    final notificationsFuture = _parentNotificationService.loadNotifications(
      parentId: parentId,
      l10n: l10n,
    );
    final supportFuture = _loadSupportTickets();
    final pinFuture = _loadHasPin();

    final results = await Future.wait<dynamic>([
      controlsFuture,
      privacyFuture,
      notificationsFuture,
      supportFuture,
      pinFuture,
    ]);

    return SafetyDashboardSnapshot.build(
      children: children,
      controls: results[0] as SafetyControlsSummary,
      privacySettings: results[1] as PrivacySettings,
      notifications: results[2] as List<ParentNotificationEntry>,
      supportTickets: results[3] as List<SupportTicketRecord>,
      hasParentPin: results[4] as bool,
      records: records,
      now: DateTime.now(),
    );
  }

  Future<List<ChildProfile>> _loadChildren(String parentId) async {
    final parentEmail = await _ref.read(secureStorageProvider).getParentEmail();
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await _childRepository.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }

    final localChildren =
        await _childRepository.getChildProfilesForParent(parentId);
    final childrenById = {for (final child in localChildren) child.id: child};

    final token = await _ref.read(secureStorageProvider).getAuthToken();
    if (token == null || token.startsWith('child_session_')) {
      return childrenById.values.toList();
    }

    try {
      final response =
          await _ref.read(networkServiceProvider).get<dynamic>('/children');
      final rawChildren = _extractChildrenList(response.data);
      for (final data in rawChildren) {
        final child = _mergeChildProfile(
          data,
          parentId: parentId,
          parentEmail: parentEmail,
          existing: childrenById[data['id']?.toString() ?? ''],
        );
        if (child == null) continue;
        childrenById[child.id] = child;
        if (await _childRepository.getChildProfile(child.id) == null) {
          await _childRepository.createChildProfile(child);
        } else {
          await _childRepository.updateChildProfile(child);
        }
      }
    } catch (e) {
      _logger.w('Safety dashboard child sync failed: $e');
    }

    return childrenById.values.toList();
  }

  List<Map<String, dynamic>> _extractChildrenList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final listData =
          data['children'] ?? data['data'] ?? data['results'] ?? data['items'];
      if (listData is List) {
        return listData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  ChildProfile? _mergeChildProfile(
    Map<String, dynamic> data, {
    required String parentId,
    required String? parentEmail,
    required ChildProfile? existing,
  }) {
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final now = DateTime.now();
    final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(data['updated_at']?.toString() ?? '');
    final lastSession =
        DateTime.tryParse(data['last_session']?.toString() ?? '');
    final picturePassword = data['picture_password'] is List
        ? List<String>.from(data['picture_password'] as List)
        : (existing?.picturePassword ?? const <String>[]);

    return ChildProfile(
      id: id,
      name: data['name']?.toString() ?? existing?.name ?? id,
      age: (data['age'] as num?)?.toInt() ?? existing?.age ?? 0,
      avatar: existing?.avatar ?? data['avatar']?.toString() ?? 'avatar_1',
      avatarPath: existing?.avatarPath ?? data['avatar']?.toString() ?? '',
      interests: existing?.interests ?? const [],
      level: existing?.level ?? ((data['level'] as num?)?.toInt() ?? 1),
      xp: existing?.xp ?? ((data['xp'] as num?)?.toInt() ?? 0),
      streak: existing?.streak ?? ((data['streak'] as num?)?.toInt() ?? 0),
      favorites: existing?.favorites ?? const [],
      parentId: parentId,
      parentEmail: existing?.parentEmail ?? parentEmail,
      picturePassword: picturePassword,
      createdAt: existing?.createdAt ?? createdAt ?? now,
      updatedAt: updatedAt ?? existing?.updatedAt ?? now,
      lastSession: lastSession ?? existing?.lastSession,
      totalTimeSpent: existing?.totalTimeSpent ??
          ((data['total_time_spent'] as num?)?.toInt() ?? 0),
      activitiesCompleted: existing?.activitiesCompleted ??
          ((data['activities_completed'] as num?)?.toInt() ?? 0),
      currentMood: existing?.currentMood ?? data['current_mood']?.toString(),
      learningStyle:
          existing?.learningStyle ?? data['learning_style']?.toString(),
      specialNeeds: existing?.specialNeeds,
      accessibilityNeeds: existing?.accessibilityNeeds,
    );
  }

  Future<SafetyControlsSummary> _loadControls() async {
    try {
      final response = await _ref
          .read(networkServiceProvider)
          .get<Map<String, dynamic>>('/parental-controls/settings');
      final body = response.data ?? const <String, dynamic>{};
      final settings = Map<String, dynamic>.from(
        body['settings'] as Map? ?? const {},
      );
      return SafetyControlsSummary.fromJson(settings);
    } catch (e) {
      _logger.w('Safety dashboard controls fallback used: $e');
      return SafetyControlsSummary.defaults();
    }
  }

  Future<List<SupportTicketRecord>> _loadSupportTickets() async {
    try {
      return await _supportService.fetchTickets();
    } catch (e) {
      _logger.w('Safety dashboard support tickets unavailable: $e');
      return const [];
    }
  }

  Future<bool> _loadHasPin() async {
    try {
      final status = await _authRepository.getParentPinStatus();
      return status.hasPin;
    } catch (e) {
      _logger.w('Safety dashboard PIN status unavailable: $e');
      return false;
    }
  }
}

final safetyDashboardServiceProvider = Provider<SafetyDashboardService>((ref) {
  return SafetyDashboardService(
    childRepository: ref.watch(childRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    parentNotificationService: ref.watch(parentNotificationServiceProvider),
    privacyService: ref.watch(privacyServiceProvider),
    supportService: ref.watch(supportServiceProvider),
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerProvider),
    ref: ref,
  );
});
