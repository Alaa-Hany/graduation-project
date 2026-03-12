import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Repository for progress tracking and analytics
class ProgressRepository {
  final Box _progressBox;
  final Logger _logger;
  final _uuid = const Uuid();
  final Map<String, ProgressRecord> _recordCache = <String, ProgressRecord>{};
  final Map<String, List<ProgressRecord>> _recordsByChild =
      <String, List<ProgressRecord>>{};
  bool _didWarmRecords = false;

  ProgressRepository({
    required Box progressBox,
    required Logger logger,
  })  : _progressBox = progressBox,
        _logger = logger;

  ProgressRecord? _decodeRecord(dynamic data) {
    if (data == null) return null;
    final Map<String, dynamic> json = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : Map<String, dynamic>.from(data as Map);
    return ProgressRecord.fromJson(json);
  }

  void _cacheRecord(ProgressRecord record) {
    _recordCache[record.id] = record;
    final records =
        _recordsByChild.putIfAbsent(record.childId, () => <ProgressRecord>[]);
    final index = records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
    records.sort((a, b) => b.date.compareTo(a.date));
  }

  void _removeCachedRecord(String recordId) {
    final removed = _recordCache.remove(recordId);
    if (removed == null) return;
    final records = _recordsByChild[removed.childId];
    if (records == null) return;
    records.removeWhere((item) => item.id == recordId);
    if (records.isEmpty) {
      _recordsByChild.remove(removed.childId);
    }
  }

  Future<void> _warmRecords() async {
    if (_didWarmRecords) return;

    for (final key in _progressBox.keys) {
      final data = _progressBox.get(key);
      if (data == null) continue;
      try {
        final record = _decodeRecord(data);
        if (record == null) continue;
        _cacheRecord(record);
      } catch (e) {
        _logger.e('Error parsing progress record: $key, $e');
      }
    }
    _didWarmRecords = true;
  }

  // ==================== CRUD OPERATIONS ====================

  /// Create progress record
  Future<ProgressRecord?> createProgressRecord({
    required String childId,
    required String activityId,
    required int score,
    required int duration,
    required int xpEarned,
    String? notes,
    String completionStatus = CompletionStatus.completed,
    Map<String, dynamic>? performanceMetrics,
    String? aiFeedback,
    String? moodBefore,
    String? moodAfter,
    bool? difficultyAdjusted,
    bool? helpRequested,
    bool? parentApproved,
  }) async {
    try {
      final now = DateTime.now();
      final record = ProgressRecord(
        id: _uuid.v4(),
        childId: childId,
        activityId: activityId,
        date: now,
        score: score,
        duration: duration,
        xpEarned: xpEarned,
        notes: notes,
        completionStatus: completionStatus,
        performanceMetrics: performanceMetrics,
        aiFeedback: aiFeedback,
        moodBefore: moodBefore,
        moodAfter: moodAfter,
        difficultyAdjusted: difficultyAdjusted,
        helpRequested: helpRequested,
        parentApproved: parentApproved,
        syncStatus: SyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final json = record.toJson();
      await _progressBox.put(record.id, json);
      _cacheRecord(record);
      
      _logger.d('Progress record created: ${record.id}');
      return record;
    } catch (e) {
      _logger.e('Error creating progress record: $e');
      return null;
    }
  }

  /// Get progress record by ID
  Future<ProgressRecord?> getProgressRecord(String recordId) async {
    try {
      final cached = _recordCache[recordId];
      if (cached != null) {
        return cached;
      }

      final data = _progressBox.get(recordId);
      
      if (data == null) {
        _logger.w('Progress record not found: $recordId');
        return null;
      }

      final record = _decodeRecord(data);
      if (record != null) {
        _cacheRecord(record);
      }
      return record;
    } catch (e) {
      _logger.e('Error getting progress record: $recordId, $e');
      return null;
    }
  }

  /// Update progress record
  Future<ProgressRecord?> updateProgressRecord(ProgressRecord record) async {
    try {
      final updated = record.copyWith(
        updatedAt: DateTime.now(),
      );
      
      final json = updated.toJson();
      await _progressBox.put(updated.id, json);
      _cacheRecord(updated);
      
      _logger.d('Progress record updated: ${updated.id}');
      return updated;
    } catch (e) {
      _logger.e('Error updating progress record: $e');
      return null;
    }
  }

  /// Delete progress record
  Future<bool> deleteProgressRecord(String recordId) async {
    try {
      await _progressBox.delete(recordId);
      _removeCachedRecord(recordId);
      _logger.d('Progress record deleted: $recordId');
      return true;
    } catch (e) {
      _logger.e('Error deleting progress record: $recordId, $e');
      return false;
    }
  }

  // ==================== QUERIES ====================

  /// Get all progress records for a child
  Future<List<ProgressRecord>> getProgressForChild(String childId) async {
    try {
      await _warmRecords();
      final records = List<ProgressRecord>.from(
        _recordsByChild[childId] ?? const <ProgressRecord>[],
        growable: false,
      );
      
      _logger.d('Retrieved ${records.length} records for child: $childId');
      return records;
    } catch (e) {
      _logger.e('Error getting progress for child: $childId, $e');
      return [];
    }
  }

  Future<List<ProgressRecord>> getProgressForChildren(
    Iterable<String> childIds,
  ) async {
    try {
      await _warmRecords();
      final records = <ProgressRecord>[];
      for (final childId in childIds) {
        records.addAll(_recordsByChild[childId] ?? const <ProgressRecord>[]);
      }
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (e) {
      _logger.e('Error getting progress for children: $e');
      return [];
    }
  }

  /// Get today's progress for a child
  Future<List<ProgressRecord>> getTodayProgress(String childId) async {
    try {
      final allRecords = await getProgressForChild(childId);
      final today = DateTime.now();
      
      final todayRecords = allRecords.where((record) {
        return record.date.year == today.year &&
               record.date.month == today.month &&
               record.date.day == today.day;
      }).toList();
      
      _logger.d('Found ${todayRecords.length} records for today');
      return todayRecords;
    } catch (e) {
      _logger.e('Error getting today\'s progress: $childId, $e');
      return [];
    }
  }

  /// Get progress for date range
  Future<List<ProgressRecord>> getProgressForDateRange({
    required String childId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final allRecords = await getProgressForChild(childId);
      
      final filtered = allRecords.where((record) {
        return record.date.isAfter(startDate) &&
               record.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
      
      _logger.d('Found ${filtered.length} records for date range');
      return filtered;
    } catch (e) {
      _logger.e('Error getting progress for date range: $e');
      return [];
    }
  }

  // ==================== STATISTICS ====================

  /// Get child statistics
  Future<Map<String, dynamic>> getChildStats(String childId) async {
    try {
      final records = await getProgressForChild(childId);
      
      if (records.isEmpty) {
        return {
          'totalXP': 0,
          'totalActivities': 0,
          'averageScore': 0,
          'totalTimeSpent': 0,
          'completionRate': 0,
        };
      }

      final totalXP = records.fold<int>(0, (sum, record) => sum + record.xpEarned);
      final totalScore = records.fold<int>(0, (sum, record) => sum + record.score);
      final totalTime = records.fold<int>(0, (sum, record) => sum + record.duration);
      
      final completedCount = records
          .where((r) => r.completionStatus == CompletionStatus.completed)
          .length;
      
      final completionRate = completedCount / records.length;

      return {
        'totalXP': totalXP,
        'totalActivities': records.length,
        'averageScore': totalScore / records.length,
        'totalTimeSpent': totalTime,
        'completionRate': completionRate,
        'completedActivities': completedCount,
        'averageDuration': totalTime / records.length,
      };
    } catch (e) {
      _logger.e('Error getting child stats: $childId, $e');
      return {};
    }
  }

  /// Get weekly summary
  Future<Map<String, dynamic>> getWeeklySummary(String childId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weekRecords = await getProgressForDateRange(
        childId: childId,
        startDate: weekStart,
        endDate: weekEnd,
      );

      final dailyStats = <String, Map<String, dynamic>>{};
      
      for (var i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayKey = '${day.year}-${day.month}-${day.day}';
        
        final dayRecords = weekRecords.where((record) {
          return record.date.year == day.year &&
                 record.date.month == day.month &&
                 record.date.day == day.day;
        }).toList();
        
        dailyStats[dayKey] = {
          'date': day,
          'activitiesCompleted': dayRecords.length,
          'xpEarned': dayRecords.fold<int>(0, (sum, r) => sum + r.xpEarned),
          'timeSpent': dayRecords.fold<int>(0, (sum, r) => sum + r.duration),
        };
      }

      return {
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'totalActivities': weekRecords.length,
        'totalXP': weekRecords.fold<int>(0, (sum, r) => sum + r.xpEarned),
        'totalTime': weekRecords.fold<int>(0, (sum, r) => sum + r.duration),
        'dailyStats': dailyStats,
      };
    } catch (e) {
      _logger.e('Error getting weekly summary: $childId, $e');
      return {};
    }
  }

  /// Get monthly summary
  Future<Map<String, dynamic>> getMonthlySummary(String childId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      final monthRecords = await getProgressForDateRange(
        childId: childId,
        startDate: monthStart,
        endDate: monthEnd,
      );

      return {
        'monthStart': monthStart,
        'monthEnd': monthEnd,
        'totalActivities': monthRecords.length,
        'totalXP': monthRecords.fold<int>(0, (sum, r) => sum + r.xpEarned),
        'totalTime': monthRecords.fold<int>(0, (sum, r) => sum + r.duration),
        'averageScore': monthRecords.isEmpty 
            ? 0 
            : monthRecords.fold<int>(0, (sum, r) => sum + r.score) / monthRecords.length,
      };
    } catch (e) {
      _logger.e('Error getting monthly summary: $childId, $e');
      return {};
    }
  }

  // ==================== ANALYTICS ====================

  /// Get performance trends
  Future<Map<String, dynamic>> getPerformanceTrends(String childId) async {
    try {
      final records = await getProgressForChild(childId);
      
      if (records.isEmpty) return {};

      // Last 7 days trend
      final last7Days = records.take(7).toList();
      final avgScoreLast7 = last7Days.fold<int>(0, (sum, r) => sum + r.score) / last7Days.length;
      
      // Previous 7 days
      final previous7Days = records.skip(7).take(7).toList();
      final avgScorePrevious7 = previous7Days.isEmpty 
          ? 0 
          : previous7Days.fold<int>(0, (sum, r) => sum + r.score) / previous7Days.length;
      
      final trend = avgScoreLast7 - avgScorePrevious7;

      return {
        'currentAverageScore': avgScoreLast7,
        'previousAverageScore': avgScorePrevious7,
        'trend': trend > 0 ? 'improving' : trend < 0 ? 'declining' : 'stable',
        'trendValue': trend,
      };
    } catch (e) {
      _logger.e('Error getting performance trends: $childId, $e');
      return {};
    }
  }

  /// Get mood analysis
  Future<Map<String, dynamic>> getMoodAnalysis(String childId) async {
    try {
      final records = await getProgressForChild(childId);
      
      final moodCounts = <String, int>{};
      var moodImprovedCount = 0;
      
      for (var record in records) {
        if (record.moodAfter != null) {
          moodCounts[record.moodAfter!] = (moodCounts[record.moodAfter!] ?? 0) + 1;
        }
        
        if (record.moodImproved) {
          moodImprovedCount++;
        }
      }

      return {
        'moodCounts': moodCounts,
        'moodImprovedCount': moodImprovedCount,
        'moodImprovementRate': records.isEmpty 
            ? 0 
            : moodImprovedCount / records.length,
      };
    } catch (e) {
      _logger.e('Error getting mood analysis: $childId, $e');
      return {};
    }
  }

  // ==================== STREAK CALCULATION ====================

  /// Calculate streak days
  Future<int> calculateStreakDays(List<ProgressRecord> records) async {
    try {
      if (records.isEmpty) return 0;

      // Sort by date descending
      final sorted = [...records];
      sorted.sort((a, b) => b.date.compareTo(a.date));

      var streak = 0;
      var currentDate = DateTime.now();
      
      // Check if there's activity today
      final hasToday = sorted.any((record) {
        return record.date.year == currentDate.year &&
               record.date.month == currentDate.month &&
               record.date.day == currentDate.day;
      });

      if (!hasToday) {
        // Check if there's activity yesterday
        final yesterday = currentDate.subtract(const Duration(days: 1));
        final hasYesterday = sorted.any((record) {
          return record.date.year == yesterday.year &&
                 record.date.month == yesterday.month &&
                 record.date.day == yesterday.day;
        });
        
        if (!hasYesterday) return 0;
        
        currentDate = yesterday;
      }

      // Count consecutive days
      for (var i = 0; i < 365; i++) {
        final checkDate = currentDate.subtract(Duration(days: i));
        
        final hasActivity = sorted.any((record) {
          return record.date.year == checkDate.year &&
                 record.date.month == checkDate.month &&
                 record.date.day == checkDate.day;
        });

        if (hasActivity) {
          streak++;
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      _logger.e('Error calculating streak: $e');
      return 0;
    }
  }

  // ==================== SYNC ====================

  /// Get records needing sync
  Future<List<ProgressRecord>> getRecordsNeedingSync() async {
    try {
      await _warmRecords();
      final allRecords = _recordCache.values
          .where((record) => record.needsSync)
          .toList(growable: false);

      _logger.d('Found ${allRecords.length} records needing sync');
      return allRecords;
    } catch (e) {
      _logger.e('Error getting records needing sync: $e');
      return [];
    }
  }

  /// Sync with server
  Future<bool> syncWithServer() async {
    try {
      final needsSync = await getRecordsNeedingSync();
      
      for (var record in needsSync) {
        // Mark as synced
        final updated = record.copyWith(
          syncStatus: SyncStatus.synced,
          updatedAt: DateTime.now(),
        );
        await updateProgressRecord(updated);
      }
      
      _logger.d('Synced ${needsSync.length} records');
      return true;
    } catch (e) {
      _logger.e('Error syncing with server: $e');
      return false;
    }
  }
}
