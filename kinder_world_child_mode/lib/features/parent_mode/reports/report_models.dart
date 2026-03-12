import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';

enum ReportPeriod { week, month, year }

extension ReportPeriodRange on ReportPeriod {
  int get days {
    switch (this) {
      case ReportPeriod.week:
        return 7;
      case ReportPeriod.month:
        return 30;
      case ReportPeriod.year:
        return 365;
    }
  }
}

class ReportDailyPoint {
  const ReportDailyPoint({
    required this.date,
    required this.activitiesCompleted,
    required this.lessonsCompleted,
    required this.screenTimeMinutes,
  });

  final DateTime date;
  final int activitiesCompleted;
  final int lessonsCompleted;
  final int screenTimeMinutes;
}

class ReportAchievement {
  const ReportAchievement({
    required this.titleKey,
    required this.detail,
    required this.achieved,
  });

  final String titleKey;
  final String detail;
  final bool achieved;
}

class ReportRecentSession {
  const ReportRecentSession({
    required this.title,
    required this.contentType,
    required this.score,
    required this.durationMinutes,
    required this.completedAt,
    required this.completionStatus,
  });

  final String title;
  final String contentType;
  final int score;
  final int durationMinutes;
  final DateTime completedAt;
  final String completionStatus;
}

class ChildReportData {
  const ChildReportData({
    required this.child,
    required this.period,
    required this.filteredRecords,
    required this.dailyPoints,
    required this.totalActivitiesCompleted,
    required this.totalSessions,
    required this.totalLessonsCompleted,
    required this.totalScreenTimeMinutes,
    required this.averageScore,
    required this.completionRate,
    required this.topContentType,
    required this.moodCounts,
    required this.currentMood,
    required this.achievements,
    required this.recentSessions,
    required this.usesRecordedSessions,
  });

  final ChildProfile child;
  final ReportPeriod period;
  final List<ProgressRecord> filteredRecords;
  final List<ReportDailyPoint> dailyPoints;
  final int totalActivitiesCompleted;
  final int totalSessions;
  final int totalLessonsCompleted;
  final int totalScreenTimeMinutes;
  final double averageScore;
  final double completionRate;
  final String? topContentType;
  final Map<String, int> moodCounts;
  final String? currentMood;
  final List<ReportAchievement> achievements;
  final List<ReportRecentSession> recentSessions;
  final bool usesRecordedSessions;
}
