import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/repositories/progress_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';

/// Progress state
class ProgressState {
  final List<ProgressRecord> recentRecords;
  final Map<String, dynamic> stats;
  final bool isLoading;
  final String? error;

  const ProgressState({
    this.recentRecords = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
  });

  ProgressState copyWith({
    List<ProgressRecord>? recentRecords,
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
  }) {
    return ProgressState(
      recentRecords: recentRecords ?? this.recentRecords,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Progress controller manages learning progress, XP, levels, and streaks
class ProgressController extends StateNotifier<ProgressState> {
  final ProgressRepository _progressRepository;
  final ChildRepository _childRepository;
  final Logger _logger;

  ProgressController({
    required ProgressRepository progressRepository,
    required ChildRepository childRepository,
    required Logger logger,
  })  : _progressRepository = progressRepository,
        _childRepository = childRepository,
        _logger = logger,
        super(const ProgressState()) {
    _initialize();
  }

  /// Initialize progress controller
  Future<void> _initialize() async {
    _logger.d('Initializing progress controller');
  }

  // ==================== PROGRESS RECORDS ====================

  /// Record activity completion
  Future<ProgressRecord?> recordActivityCompletion({
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
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Create progress record
      final record = await _progressRepository.createProgressRecord(
        childId: childId,
        activityId: activityId,
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
      );
      
      if (record != null) {
        // Update child stats
        await _childRepository.completeActivity(
          childId: childId,
          xpEarned: xpEarned,
          timeSpent: duration,
        );
        
        // Update streak
        await _childRepository.updateStreak(childId);
        
        _logger.d('Activity completion recorded: ${record.id}');
        
        // Refresh recent records
        await loadRecentRecords(childId);
        
        state = state.copyWith(isLoading: false);
        return record;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to record activity completion',
        );
        return null;
      }
    } catch (e, _) {
      _logger.e('Error recording activity completion: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to record activity completion',
      );
      return null;
    }
  }

  /// Load recent progress records
  Future<void> loadRecentRecords(String childId) async {
    try {
      final records = await _progressRepository.getProgressForChild(childId);
      
      state = state.copyWith(
        recentRecords: records.take(20).toList(),
      );
      
      _logger.d('Loaded ${records.length} progress records for child: $childId');
    } catch (e, _) {
      _logger.e('Error loading recent records for child: $childId, $e');
    }
  }

  /// Load today's progress
  Future<List<ProgressRecord>> loadTodayProgress(String childId) async {
    try {
      final records = await _progressRepository.getTodayProgress(childId);
      _logger.d('Loaded ${records.length} records for today');
      return records;
    } catch (e, _) {
      _logger.e('Error loading today\'s progress for child: $childId, $e');
      return [];
    }
  }

  // ==================== STATISTICS ====================

  /// Get weekly summary
  Future<Map<String, dynamic>> getWeeklySummary(String childId) async {
    try {
      final summary = await _progressRepository.getWeeklySummary(childId);
      _logger.d('Generated weekly summary for child: $childId');
      return summary;
    } catch (e, _) {
      _logger.e('Error getting weekly summary for child: $childId, $e');
      return {};
    }
  }

  /// Get monthly summary
  Future<Map<String, dynamic>> getMonthlySummary(String childId) async {
    try {
      final summary = await _progressRepository.getMonthlySummary(childId);
      _logger.d('Generated monthly summary for child: $childId');
      return summary;
    } catch (e, _) {
      _logger.e('Error getting monthly summary for child: $childId, $e');
      return {};
    }
  }

  // ==================== ANALYTICS ====================

  /// Get performance trends
  Future<Map<String, dynamic>> getPerformanceTrends(String childId) async {
    try {
      final trends = await _progressRepository.getPerformanceTrends(childId);
      _logger.d('Generated performance trends for child: $childId');
      return trends;
    } catch (e, _) {
      _logger.e('Error getting performance trends for child: $childId, $e');
      return {};
    }
  }

  /// Get mood analysis
  Future<Map<String, dynamic>> getMoodAnalysis(String childId) async {
    try {
      final analysis = await _progressRepository.getMoodAnalysis(childId);
      _logger.d('Generated mood analysis for child: $childId');
      return analysis;
    } catch (e, _) {
      _logger.e('Error getting mood analysis for child: $childId, $e');
      return {};
    }
  }

  // ==================== STREAK MANAGEMENT ====================

  /// Calculate streak from progress records
  Future<int> calculateStreak(String childId) async {
    try {
      final records = await _progressRepository.getProgressForChild(childId);
      return await _progressRepository.calculateStreakDays(records);
    } catch (e, _) {
      _logger.e('Error calculating streak for child: $childId, $e');
      return 0;
    }
  }

  // ==================== GOALS & ACHIEVEMENTS ====================

  /// Get achievement progress
  Future<Map<String, dynamic>> getAchievementProgress(String childId) async {
    try {
      final stats = await _progressRepository.getChildStats(childId);
      final streak = await calculateStreak(childId);
      
      return {
        'totalXP': stats['totalXP'] ?? 0,
        'totalActivities': stats['totalActivities'] ?? 0,
        'currentLevel': stats['currentLevel'] ?? 1,
        'currentStreak': streak,
        'completionRate': stats['completionRate'] ?? 0,
        
        // Achievement progress
        'xpAchievements': _calculateXPAchievements(stats['totalXP'] ?? 0),
        'activityAchievements': _calculateActivityAchievements(stats['totalActivities'] ?? 0),
        'streakAchievements': _calculateStreakAchievements(streak),
      };
    } catch (e, _) {
      _logger.e('Error getting achievement progress for child: $childId, $e');
      return {};
    }
  }

  List<Map<String, dynamic>> _calculateXPAchievements(int totalXP) {
    final achievements = [
      {'name': 'First Steps', 'xp': 100, 'achieved': totalXP >= 100},
      {'name': 'Rising Star', 'xp': 500, 'achieved': totalXP >= 500},
      {'name': 'Knowledge Seeker', 'xp': 1000, 'achieved': totalXP >= 1000},
      {'name': 'Learning Champion', 'xp': 5000, 'achieved': totalXP >= 5000},
      {'name': 'Master Learner', 'xp': 10000, 'achieved': totalXP >= 10000},
    ];
    
    return achievements;
  }

  List<Map<String, dynamic>> _calculateActivityAchievements(int totalActivities) {
    final achievements = [
      {'name': 'Getting Started', 'count': 1, 'achieved': totalActivities >= 1},
      {'name': 'Active Learner', 'count': 10, 'achieved': totalActivities >= 10},
      {'name': 'Dedicated Student', 'count': 50, 'achieved': totalActivities >= 50},
      {'name': 'Learning Enthusiast', 'count': 100, 'achieved': totalActivities >= 100},
      {'name': 'Knowledge Master', 'count': 500, 'achieved': totalActivities >= 500},
    ];
    
    return achievements;
  }

  List<Map<String, dynamic>> _calculateStreakAchievements(int streak) {
    final achievements = [
      {'name': 'First Day', 'days': 1, 'achieved': streak >= 1},
      {'name': 'Week Warrior', 'days': 7, 'achieved': streak >= 7},
      {'name': 'Two Week Wonder', 'days': 14, 'achieved': streak >= 14},
      {'name': 'Monthly Master', 'days': 30, 'achieved': streak >= 30},
      {'name': 'Streak Legend', 'days': 100, 'achieved': streak >= 100},
    ];
    
    return achievements;
  }

  // ==================== PARENT REPORTING ====================

  /// Generate parent report data
  Future<Map<String, dynamic>> generateParentReport(String childId) async {
    try {
      final stats = await _progressRepository.getChildStats(childId);
      final weeklySummary = await getWeeklySummary(childId);
      final monthlySummary = await getMonthlySummary(childId);
      final performanceTrends = await getPerformanceTrends(childId);
      final moodAnalysis = await getMoodAnalysis(childId);
      
      return {
        'stats': stats,
        'weeklySummary': weeklySummary,
        'monthlySummary': monthlySummary,
        'performanceTrends': performanceTrends,
        'moodAnalysis': moodAnalysis,
        'generatedAt': DateTime.now(),
      };
    } catch (e, _) {
      _logger.e('Error generating parent report for child: $childId, $e');
      return {};
    }
  }

  // ==================== ERROR HANDLING ====================

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  // ==================== SYNC OPERATIONS ====================

  /// Sync progress with server
  Future<bool> syncWithServer() async {
    try {
      final success = await _progressRepository.syncWithServer();
      
      if (success) {
        _logger.d('Progress synced with server');
      }
      
      return success;
    } catch (e, _) {
      _logger.e('Error syncing progress with server: $e');
      return false;
    }
  }

  /// Get records needing sync
  Future<List<ProgressRecord>> getRecordsNeedingSync() async {
    try {
      return await _progressRepository.getRecordsNeedingSync();
    } catch (e, _) {
      _logger.e('Error getting records needing sync: $e');
      return [];
    }
  }
}

// Provider
final progressControllerProvider = StateNotifierProvider.autoDispose<ProgressController, ProgressState>((ref) {
  final progressRepository = ref.watch(progressRepositoryProvider);
  final childRepository = ref.watch(childRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  return ProgressController(
    progressRepository: progressRepository,
    childRepository: childRepository,
    logger: logger,
  );
});

// Repository provider
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final progressBox = Hive.box('progress_records');
  final logger = ref.watch(loggerProvider);
  
  return ProgressRepository(
    progressBox: progressBox,
    logger: logger,
  );
});

// Helper providers
final recentProgressProvider = Provider<List<ProgressRecord>>((ref) {
  return ref.watch(progressControllerProvider).recentRecords;
});

final progressStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(progressControllerProvider).stats;
});

// Async providers
final weeklySummaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, childId) async {
  final controller = ref.watch(progressControllerProvider.notifier);
  return await controller.getWeeklySummary(childId);
});

final monthlySummaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, childId) async {
  final controller = ref.watch(progressControllerProvider.notifier);
  return await controller.getMonthlySummary(childId);
});

final achievementProgressProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, childId) async {
  final controller = ref.watch(progressControllerProvider.notifier);
  return await controller.getAchievementProgress(childId);
});