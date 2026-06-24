import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/api/reports_api.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/cache_provider.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/utils/session_token_utils.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:logger/logger.dart';

typedef FetchBasicReports = Future<Map<String, dynamic>> Function({
  int? childId,
  int days,
  String? parentAccessToken,
});
typedef FetchAdvancedReports = Future<Map<String, dynamic>> Function({
  int? childId,
  int days,
  String? parentAccessToken,
});
typedef LoadProgressRecords = Future<List<ProgressRecord>> Function(
    String childId);

const _reportCacheScope = 'parent_reports';
const _reportCacheStaleAfter = Duration(minutes: 15);

class ParentReportService {
  ParentReportService({
    required this.secureStorage,
    required this.reportsApi,
    required this.cacheStore,
    required this.logger,
    this.progressRepository,
    FetchBasicReports? fetchBasicReports,
    FetchAdvancedReports? fetchAdvancedReports,
    LoadProgressRecords? loadProgressRecords,
  })  : _fetchBasicReports = fetchBasicReports ?? reportsApi.getBasicReports,
        _fetchAdvancedReports =
            fetchAdvancedReports ?? reportsApi.getAdvancedReports,
        _loadProgressRecords =
            loadProgressRecords ?? progressRepository!.getProgressForChild,
        assert(
          progressRepository != null || loadProgressRecords != null,
          'progressRepository or loadProgressRecords must be provided',
        );

  final SecureStorage secureStorage;
  final ReportsApi reportsApi;
  final ProgressRepository? progressRepository;
  final AppCacheStore cacheStore;
  final Logger logger;
  final FetchBasicReports _fetchBasicReports;
  final FetchAdvancedReports _fetchAdvancedReports;
  final LoadProgressRecords _loadProgressRecords;

  Future<ChildReportData> buildChildReport({
    required ChildProfile child,
    required ReportPeriod period,
    bool includeAdvancedReports = true,
  }) async {
    final result = await loadChildReport(
      child: child,
      period: period,
      includeAdvancedReports: includeAdvancedReports,
    );
    return result.report;
  }

  Future<ChildReportLoadResult> loadChildReport({
    required ChildProfile child,
    required ReportPeriod period,
    bool forceRefresh = false,
    bool includeAdvancedReports = true,
  }) async {
    final childId = int.tryParse(child.id);
    final parentAccessToken = await _resolveParentAccessToken();
    final cacheKey = _reportCacheKey(child.id, period);
    final cacheSnapshot = cacheStore.snapshot(
      scope: _reportCacheScope,
      key: cacheKey,
      staleAfter: _reportCacheStaleAfter,
    );

    if ((parentAccessToken == null || parentAccessToken.isEmpty) &&
        !forceRefresh) {
      return _buildFallbackResult(
        child: child,
        period: period,
        cacheSnapshot: cacheSnapshot,
      );
    }

    try {
      final basicPayload = await _fetchBasicReports(
        childId: childId,
        days: period.days,
        parentAccessToken: parentAccessToken,
      );

      Map<String, dynamic> advancedPayload = const {};
      if (includeAdvancedReports) {
        try {
          advancedPayload = await _fetchAdvancedReports(
            childId: childId,
            days: period.days,
            parentAccessToken: parentAccessToken,
          );
        } catch (e) {
          logger.w('Advanced reports unavailable for child ${child.id}: $e');
        }
      }

      final report = ParentReportService.buildReportFromBackend(
        child: child,
        period: period,
        basicPayload: basicPayload,
        advancedPayload: advancedPayload,
      );

      // Child-mode sessions are recorded locally and only push to the backend
      // when a parent access token is available; a pure child login has none,
      // so the server can legitimately have nothing recorded while the device
      // holds the child's real progress. When the server reports no recorded
      // activity but local records exist, show the on-device progress instead
      // of an empty report (this is what made progress "disappear" for parents
      // after a logout/login).
      if (!report.usesRecordedSessions) {
        final localRecords = await _loadProgressRecords(child.id);
        if (localRecords.isNotEmpty) {
          return ChildReportLoadResult(
            report: ParentReportService.buildReportFromRecords(
              child: child,
              period: period,
              allRecords: localRecords,
            ),
            source: ChildReportSource.localDevice,
            cacheSnapshot: cacheSnapshot.hasData ? cacheSnapshot : null,
            hasPendingLocalChanges:
                localRecords.any((record) => record.needsSync),
          );
        }
      }

      await cacheStore.storeMap(
        scope: _reportCacheScope,
        key: cacheKey,
        payload: _serializeReport(report),
      );
      final storedSnapshot = cacheStore.snapshot(
        scope: _reportCacheScope,
        key: cacheKey,
        staleAfter: _reportCacheStaleAfter,
      );
      return ChildReportLoadResult(
        report: report,
        source: ChildReportSource.liveServer,
        cacheSnapshot: CacheSnapshot(
          hasData: true,
          freshness: CacheFreshness.freshServerBacked,
          syncState: storedSnapshot.syncState,
          lastFetchedAt: storedSnapshot.lastFetchedAt,
          lastSyncedAt: storedSnapshot.lastSyncedAt,
          lastMutationAt: storedSnapshot.lastMutationAt,
        ),
      );
    } catch (e) {
      logger.w(
        'Report refresh unavailable for child ${child.id}, using local fallback: $e',
      );
      return _buildFallbackResult(
        child: child,
        period: period,
        cacheSnapshot: cacheSnapshot,
      );
    }
  }

  Future<String?> _resolveParentAccessToken() async {
    final storedParentToken = await secureStorage.getParentAccessToken();
    if (storedParentToken != null && storedParentToken.isNotEmpty) {
      return storedParentToken;
    }
    final authToken = await secureStorage.getAuthToken();
    if (authToken != null &&
        authToken.isNotEmpty &&
        !isChildSessionToken(authToken)) {
      return authToken;
    }
    return null;
  }

  Future<ChildReportLoadResult> _buildFallbackResult({
    required ChildProfile child,
    required ReportPeriod period,
    required CacheSnapshot cacheSnapshot,
  }) async {
    final localRecords = await _loadProgressRecords(child.id);
    if (localRecords.isNotEmpty) {
      final report = ParentReportService.buildReportFromRecords(
        child: child,
        period: period,
        allRecords: localRecords,
      );
      return ChildReportLoadResult(
        report: report,
        source: ChildReportSource.localDevice,
        cacheSnapshot: cacheSnapshot.hasData ? cacheSnapshot : null,
        hasPendingLocalChanges: localRecords.any((record) => record.needsSync),
      );
    }

    final cachedPayload = cacheStore.readMap(
      scope: _reportCacheScope,
      key: _reportCacheKey(child.id, period),
    );
    if (cachedPayload != null && cachedPayload.isNotEmpty) {
      return ChildReportLoadResult(
        report: ParentReportService.buildReportFromCache(
          child: child,
          period: period,
          payload: cachedPayload,
        ),
        source: ChildReportSource.cachedSnapshot,
        cacheSnapshot: cacheSnapshot,
      );
    }

    return ChildReportLoadResult(
      report: ParentReportService.buildReportFromRecords(
        child: child,
        period: period,
        allRecords: const <ProgressRecord>[],
      ),
      source: ChildReportSource.profileFallback,
    );
  }

  static String _reportCacheKey(String childId, ReportPeriod period) {
    return '$childId:${period.index}';
  }

  static ChildReportData buildReportFromBackend({
    required ChildProfile child,
    required ReportPeriod period,
    required Map<String, dynamic> basicPayload,
    required Map<String, dynamic> advancedPayload,
  }) {
    final basicSummary =
        Map<String, dynamic>.from(basicPayload['summary'] as Map? ?? const {});
    final advancedReports = Map<String, dynamic>.from(
      advancedPayload['reports'] as Map? ?? const {},
    );

    final dailySource = (advancedReports['daily_overview'] as List?) ??
        (basicPayload['reports'] as List?) ??
        const [];
    final recentSource = (advancedReports['recent_sessions'] as List?) ??
        (basicPayload['recent_sessions'] as List?) ??
        const [];
    final achievementSource = Map<String, dynamic>.from(
      advancedReports['achievements'] as Map? ?? const {},
    );
    final moodCountsSource = Map<String, dynamic>.from(
      advancedReports['mood_counts'] as Map? ?? const {},
    );

    final dailyPoints = dailySource
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ReportDailyPoint(
            date: DateTime.tryParse(item['date']?.toString() ?? '') ??
                DateTime.now(),
            activitiesCompleted: _readInt(item['activities_completed']),
            lessonsCompleted: _readInt(item['lessons_completed']),
            screenTimeMinutes: _readInt(item['screen_time_minutes']),
          ),
        )
        .toList(growable: false);

    final recentSessions = recentSource
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ReportRecentSession(
            title: item['title']?.toString() ?? 'Activity',
            contentType: item['content_type']?.toString() ?? 'other',
            score: _readInt(item['score']),
            durationMinutes: _readInt(item['duration_minutes']),
            completedAt:
                DateTime.tryParse(item['completed_at']?.toString() ?? '') ??
                    DateTime.now(),
            completionStatus: item['completion_status']?.toString() ??
                CompletionStatus.completed,
          ),
        )
        .toList(growable: false);

    final achievements =
        (achievementSource['recent_unlocks'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (item) => ReportAchievement(
                titleKey: item['achievement_key']?.toString() ?? 'achievement',
                detail: item['activity_name']?.toString() ??
                    item['occurred_at']?.toString() ??
                    '',
                achieved: true,
              ),
            )
            .toList(growable: false);

    final moodCounts = {
      for (final entry in moodCountsSource.entries)
        entry.key: entry.value is int
            ? entry.value as int
            : int.tryParse('${entry.value}') ?? 0,
    };
    final currentMood = moodCounts.entries.isEmpty
        ? null
        : (moodCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return ChildReportData(
      child: child,
      period: period,
      filteredRecords: const <ProgressRecord>[],
      dailyPoints: dailyPoints,
      totalActivitiesCompleted: _readIntByDays(
        basicSummary,
        'activities_completed',
        period.days,
      ),
      totalSessions: recentSessions.length,
      totalLessonsCompleted: _readIntByDays(
        basicSummary,
        'lessons_completed',
        period.days,
      ),
      totalScreenTimeMinutes: _readIntByDays(
        basicSummary,
        'screen_time_minutes',
        period.days,
      ),
      averageScore: _readDouble(
            advancedReports['account_summary'] is Map
                ? Map<String, dynamic>.from(
                    advancedReports['account_summary'] as Map)['average_score']
                : null,
          ) ??
          _readDouble(basicSummary['average_score']) ??
          0.0,
      completionRate: _readDouble(
            advancedReports['account_summary'] is Map
                ? Map<String, dynamic>.from(advancedReports['account_summary']
                    as Map)['completion_rate']
                : null,
          ) ??
          _readDouble(basicSummary['completion_rate']) ??
          0.0,
      topContentType: advancedReports['top_content_type']?.toString(),
      moodCounts: moodCounts,
      currentMood: currentMood,
      achievements: achievements,
      recentSessions: recentSessions,
      usesRecordedSessions: (basicPayload['data_availability'] as Map?) != null
          ? ((basicPayload['data_availability'] as Map)['screen_time'] ==
                  true ||
              (basicPayload['data_availability'] as Map)['activities'] == true)
          : false,
    );
  }

  static int _readIntByDays(
    Map<String, dynamic> source,
    String prefix,
    int days,
  ) {
    final key = '${prefix}_${days}d';
    final value = source[key];
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static ChildReportData buildReportFromCache({
    required ChildProfile child,
    required ReportPeriod period,
    required Map<String, dynamic> payload,
  }) {
    final dailyPoints = (payload['daily_points'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ReportDailyPoint(
            date: DateTime.tryParse(item['date']?.toString() ?? '') ??
                DateTime.now(),
            activitiesCompleted: _readInt(item['activities_completed']),
            lessonsCompleted: _readInt(item['lessons_completed']),
            screenTimeMinutes: _readInt(item['screen_time_minutes']),
          ),
        )
        .toList(growable: false);

    final recentSessions = (payload['recent_sessions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ReportRecentSession(
            title: item['title']?.toString() ?? 'Activity',
            contentType: item['content_type']?.toString() ?? 'other',
            score: _readInt(item['score']),
            durationMinutes: _readInt(item['duration_minutes']),
            completedAt:
                DateTime.tryParse(item['completed_at']?.toString() ?? '') ??
                    DateTime.now(),
            completionStatus: item['completion_status']?.toString() ??
                CompletionStatus.completed,
          ),
        )
        .toList(growable: false);

    final achievements = (payload['achievements'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ReportAchievement(
            titleKey: item['title_key']?.toString() ?? 'achievement',
            detail: item['detail']?.toString() ?? '',
            achieved: item['achieved'] == true,
          ),
        )
        .toList(growable: false);

    final moodCounts = <String, int>{
      for (final entry in Map<String, dynamic>.from(
              payload['mood_counts'] as Map? ?? const {})
          .entries)
        entry.key: _readInt(entry.value),
    };

    return ChildReportData(
      child: child,
      period: period,
      filteredRecords: const <ProgressRecord>[],
      dailyPoints: dailyPoints,
      totalActivitiesCompleted: _readInt(payload['total_activities_completed']),
      totalSessions: _readInt(payload['total_sessions']),
      totalLessonsCompleted: _readInt(payload['total_lessons_completed']),
      totalScreenTimeMinutes: _readInt(payload['total_screen_time_minutes']),
      averageScore: _readDouble(payload['average_score']) ?? 0.0,
      completionRate: _readDouble(payload['completion_rate']) ?? 0.0,
      topContentType: payload['top_content_type']?.toString(),
      moodCounts: moodCounts,
      currentMood: payload['current_mood']?.toString(),
      achievements: achievements,
      recentSessions: recentSessions,
      usesRecordedSessions: payload['uses_recorded_sessions'] == true,
    );
  }

  static Map<String, dynamic> _serializeReport(ChildReportData report) {
    return <String, dynamic>{
      'total_activities_completed': report.totalActivitiesCompleted,
      'total_sessions': report.totalSessions,
      'total_lessons_completed': report.totalLessonsCompleted,
      'total_screen_time_minutes': report.totalScreenTimeMinutes,
      'average_score': report.averageScore,
      'completion_rate': report.completionRate,
      'top_content_type': report.topContentType,
      'current_mood': report.currentMood,
      'uses_recorded_sessions': report.usesRecordedSessions,
      'mood_counts': report.moodCounts,
      'daily_points': report.dailyPoints
          .map(
            (point) => <String, dynamic>{
              'date': point.date.toIso8601String(),
              'activities_completed': point.activitiesCompleted,
              'lessons_completed': point.lessonsCompleted,
              'screen_time_minutes': point.screenTimeMinutes,
            },
          )
          .toList(growable: false),
      'achievements': report.achievements
          .map(
            (achievement) => <String, dynamic>{
              'title_key': achievement.titleKey,
              'detail': achievement.detail,
              'achieved': achievement.achieved,
            },
          )
          .toList(growable: false),
      'recent_sessions': report.recentSessions
          .map(
            (session) => <String, dynamic>{
              'title': session.title,
              'content_type': session.contentType,
              'score': session.score,
              'duration_minutes': session.durationMinutes,
              'completed_at': session.completedAt.toIso8601String(),
              'completion_status': session.completionStatus,
            },
          )
          .toList(growable: false),
    };
  }

  static ChildReportData buildReportFromRecords({
    required ChildProfile child,
    required ReportPeriod period,
    required List<ProgressRecord> allRecords,
  }) {
    final now = DateTime.now();
    final rangeStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: period.days - 1));

    final filteredRecords = allRecords
        .where((record) => !record.date.isBefore(rangeStart))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final completedRecords = filteredRecords
        .where(
            (record) => record.completionStatus == CompletionStatus.completed)
        .toList();

    final totalLessonsCompleted = completedRecords
        .where((record) => inferContentType(record.activityId) == 'lessons')
        .length;
    final totalScreenTimeMinutes = filteredRecords.fold<int>(
      0,
      (sum, record) => sum + record.duration,
    );
    final averageScore = completedRecords.isEmpty
        ? 0.0
        : (completedRecords.fold<int>(0, (sum, record) => sum + record.score) /
                completedRecords.length)
            .toDouble();
    final completionRate = filteredRecords.isEmpty
        ? 0.0
        : (completedRecords.length / filteredRecords.length).toDouble();

    final contentUsage = <String, int>{};
    final moodCounts = <String, int>{};
    for (final record in filteredRecords) {
      final type = inferContentType(record.activityId);
      contentUsage[type] = (contentUsage[type] ?? 0) + 1;
      final mood = record.moodAfter ?? record.moodBefore;
      if (mood != null && mood.isNotEmpty) {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }

    final topContentType = contentUsage.entries.isEmpty
        ? null
        : (contentUsage.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    final achievements = _buildAchievements(
      child: child,
      completedActivities: completedRecords.length,
      lessonsCompleted: totalLessonsCompleted,
      averageScore: averageScore,
    );

    final recentSessions = filteredRecords.take(5).map((record) {
      return ReportRecentSession(
        title: _titleForRecord(record),
        contentType: inferContentType(record.activityId),
        score: record.score,
        durationMinutes: record.duration,
        completedAt: record.date,
        completionStatus: record.completionStatus,
      );
    }).toList();

    return ChildReportData(
      child: child,
      period: period,
      filteredRecords: filteredRecords,
      dailyPoints: _buildDailyPoints(
        rangeStart: rangeStart,
        days: period.days,
        records: filteredRecords,
      ),
      totalActivitiesCompleted: completedRecords.isNotEmpty
          ? completedRecords.length
          : child.activitiesCompleted,
      totalSessions: filteredRecords.length,
      totalLessonsCompleted: totalLessonsCompleted,
      totalScreenTimeMinutes: filteredRecords.isNotEmpty
          ? totalScreenTimeMinutes
          : child.totalTimeSpent,
      averageScore: averageScore,
      completionRate: completionRate,
      topContentType: topContentType,
      moodCounts: moodCounts,
      currentMood: child.currentMood,
      achievements: achievements,
      recentSessions: recentSessions,
      usesRecordedSessions: filteredRecords.isNotEmpty,
    );
  }

  static List<ReportDailyPoint> _buildDailyPoints({
    required DateTime rangeStart,
    required int days,
    required List<ProgressRecord> records,
  }) {
    final points = <ReportDailyPoint>[];
    for (var offset = 0; offset < days; offset++) {
      final day = rangeStart.add(Duration(days: offset));
      final dayRecords = records.where((record) {
        return record.date.year == day.year &&
            record.date.month == day.month &&
            record.date.day == day.day;
      }).toList();
      final completedCount = dayRecords
          .where(
              (record) => record.completionStatus == CompletionStatus.completed)
          .length;
      final lessonCount = dayRecords
          .where((record) =>
              record.completionStatus == CompletionStatus.completed &&
              inferContentType(record.activityId) == 'lessons')
          .length;
      final screenTime =
          dayRecords.fold<int>(0, (sum, record) => sum + record.duration);
      points.add(
        ReportDailyPoint(
          date: day,
          activitiesCompleted: completedCount,
          lessonsCompleted: lessonCount,
          screenTimeMinutes: screenTime,
        ),
      );
    }
    return points;
  }

  static List<ReportAchievement> _buildAchievements({
    required ChildProfile child,
    required int completedActivities,
    required int lessonsCompleted,
    required double averageScore,
  }) {
    return [
      ReportAchievement(
        titleKey: 'streak',
        detail: '${child.streak}',
        achieved: child.streak >= 5,
      ),
      ReportAchievement(
        titleKey: 'lessons',
        detail: '$lessonsCompleted',
        achieved: lessonsCompleted >= 3,
      ),
      ReportAchievement(
        titleKey: 'activities',
        detail: '$completedActivities',
        achieved: completedActivities >= 5,
      ),
      ReportAchievement(
        titleKey: 'score',
        detail: averageScore.toStringAsFixed(0),
        achieved: averageScore >= 85,
      ),
    ];
  }

  static String _titleForRecord(ProgressRecord record) {
    if (record.notes != null && record.notes!.trim().isNotEmpty) {
      return record.notes!.trim();
    }
    final contentType = inferContentType(record.activityId);
    switch (contentType) {
      case 'lessons':
        return 'Lesson ${record.activityId.replaceFirst('lesson_', '')}';
      case 'activity_of_day':
        return 'Activity of the Day';
      case 'games':
      case 'stories':
      case 'music':
      case 'videos':
        return record.activityId.replaceAll('_', ' ');
      default:
        return record.activityId.replaceAll('_', ' ');
    }
  }

  static String inferContentType(String activityId) {
    if (activityId.startsWith('lesson_')) return 'lessons';
    if (activityId == 'activity_of_the_day') return 'activity_of_day';
    if (activityId.startsWith('game_')) return 'games';
    if (activityId.startsWith('story_')) return 'stories';
    if (activityId.startsWith('music_')) return 'music';
    if (activityId.startsWith('video_')) return 'videos';
    return 'other';
  }
}

final parentReportServiceProvider = Provider<ParentReportService>((ref) {
  return ParentReportService(
    secureStorage: ref.watch(secureStorageProvider),
    reportsApi: ref.watch(reportsApiProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    cacheStore: ref.watch(appCacheStoreProvider),
    logger: ref.watch(loggerProvider),
  );
});
