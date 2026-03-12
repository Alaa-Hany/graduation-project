import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:logger/logger.dart';

class ParentReportService {
  ParentReportService({
    required this.progressRepository,
    required this.logger,
  });

  final ProgressRepository progressRepository;
  final Logger logger;

  Future<ChildReportData> buildChildReport({
    required ChildProfile child,
    required ReportPeriod period,
  }) async {
    final allRecords = await progressRepository.getProgressForChild(child.id);
    return ParentReportService.buildReportFromRecords(
      child: child,
      period: period,
      allRecords: allRecords,
    );
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
        .where((record) => record.completionStatus == CompletionStatus.completed)
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
      totalActivitiesCompleted:
          completedRecords.isNotEmpty ? completedRecords.length : child.activitiesCompleted,
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
          .where((record) => record.completionStatus == CompletionStatus.completed)
          .length;
      final lessonCount = dayRecords
          .where((record) =>
              record.completionStatus == CompletionStatus.completed &&
              inferContentType(record.activityId) == 'lessons')
          .length;
      final screenTime = dayRecords.fold<int>(
        0,
        (sum, record) => sum + record.duration,
      );
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
  final progressRepository = ref.watch(progressRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  return ParentReportService(
    progressRepository: progressRepository,
    logger: logger,
  );
});
