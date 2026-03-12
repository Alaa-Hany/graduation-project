import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:kinder_world/features/parent_mode/reports/report_service.dart';

ChildProfile _child({
  int activitiesCompleted = 2,
  int totalTimeSpent = 25,
  String? currentMood = 'happy',
}) {
  return ChildProfile(
    id: 'child-1',
    name: 'Dana',
    age: 7,
    avatar: 'assets/images/avatars/av1.png',
    interests: const ['math'],
    level: 2,
    xp: 250,
    streak: 6,
    favorites: const [],
    parentId: 'parent-1',
    parentEmail: 'parent@example.com',
    picturePassword: const ['cat', 'dog', 'apple'],
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
    totalTimeSpent: totalTimeSpent,
    activitiesCompleted: activitiesCompleted,
    currentMood: currentMood,
    avatarPath: 'assets/images/avatars/av1.png',
  );
}

ProgressRecord _record({
  required String id,
  required String activityId,
  required DateTime date,
  required int score,
  required int duration,
  required int xpEarned,
  String completionStatus = CompletionStatus.completed,
  String? moodAfter,
  String? notes,
}) {
  return ProgressRecord(
    id: id,
    childId: 'child-1',
    activityId: activityId,
    date: date,
    score: score,
    duration: duration,
    xpEarned: xpEarned,
    notes: notes,
    completionStatus: completionStatus,
    moodAfter: moodAfter,
    syncStatus: SyncStatus.pending,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('buildReportFromRecords aggregates real progress metrics', () {
    final now = DateTime.now();
    final report = ParentReportService.buildReportFromRecords(
      child: _child(),
      period: ReportPeriod.week,
      allRecords: [
        _record(
          id: '1',
          activityId: 'lesson_math_1',
          date: now.subtract(const Duration(days: 1)),
          score: 95,
          duration: 15,
          xpEarned: 50,
          moodAfter: 'happy',
          notes: 'Counting Numbers',
        ),
        _record(
          id: '2',
          activityId: 'lesson_science_1',
          date: now.subtract(const Duration(days: 2)),
          score: 85,
          duration: 12,
          xpEarned: 40,
          moodAfter: 'excited',
        ),
        _record(
          id: '3',
          activityId: 'activity_of_the_day',
          date: now.subtract(const Duration(days: 3)),
          score: 100,
          duration: 5,
          xpEarned: 50,
          moodAfter: 'happy',
        ),
      ],
    );

    expect(report.usesRecordedSessions, isTrue);
    expect(report.totalActivitiesCompleted, 3);
    expect(report.totalLessonsCompleted, 2);
    expect(report.totalScreenTimeMinutes, 32);
    expect(report.averageScore.round(), 93);
    expect(report.topContentType, 'lessons');
    expect(report.moodCounts['happy'], 2);
    expect(report.recentSessions.first.title, 'Counting Numbers');
  });

  test('buildReportFromRecords falls back to child profile totals when no records exist', () {
    final report = ParentReportService.buildReportFromRecords(
      child: _child(activitiesCompleted: 4, totalTimeSpent: 90, currentMood: 'calm'),
      period: ReportPeriod.month,
      allRecords: const [],
    );

    expect(report.usesRecordedSessions, isFalse);
    expect(report.totalActivitiesCompleted, 4);
    expect(report.totalScreenTimeMinutes, 90);
    expect(report.totalLessonsCompleted, 0);
    expect(report.currentMood, 'calm');
    expect(report.recentSessions, isEmpty);
  });
}
