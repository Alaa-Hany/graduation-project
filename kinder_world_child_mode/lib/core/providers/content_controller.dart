import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/models/activity.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/repositories/content_repository.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';

/// Content state
class ContentState {
  final List<Activity> activities;
  final List<Activity> recommendedActivities;
  final List<Activity> popularActivities;
  final bool isLoading;
  final String? error;

  const ContentState({
    this.activities = const [],
    this.recommendedActivities = const [],
    this.popularActivities = const [],
    this.isLoading = false,
    this.error,
  });

  ContentState copyWith({
    List<Activity>? activities,
    List<Activity>? recommendedActivities,
    List<Activity>? popularActivities,
    bool? isLoading,
    String? error,
  }) {
    return ContentState(
      activities: activities ?? this.activities,
      recommendedActivities: recommendedActivities ?? this.recommendedActivities,
      popularActivities: popularActivities ?? this.popularActivities,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Content controller manages activities and content discovery
class ContentController extends StateNotifier<ContentState> {
  final ContentRepository _contentRepository;
  final Logger _logger;

  ContentController({
    required ContentRepository contentRepository,
    required Logger logger,
  })  : _contentRepository = contentRepository,
        _logger = logger,
        super(const ContentState()) {
    _initialize();
  }

  /// Initialize content
  Future<void> _initialize() async {
    _logger.d('Initializing content controller');
    await loadAllActivities();
    await loadPopularActivities();
  }

  // ==================== CONTENT LOADING ====================

  /// Load all activities
  Future<void> loadAllActivities() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final activities = await _contentRepository.getAllActivities();
      
      state = state.copyWith(
        activities: activities,
        isLoading: false,
      );
      
      _logger.d('Loaded ${activities.length} activities');
    } catch (e, _) {
      _logger.e('Error loading activities: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load activities',
      );
    }
  }

  /// Load activities by category
  Future<List<Activity>> loadActivitiesByCategory(String category) async {
    try {
      final activities = await _contentRepository.getActivitiesByCategory(category);
      _logger.d('Loaded ${activities.length} activities for category: $category');
      return activities;
    } catch (e, _) {
      _logger.e('Error loading activities by category: $category, $e');
      return [];
    }
  }

  /// Load activities by type
  Future<List<Activity>> loadActivitiesByType(String type) async {
    try {
      final activities = await _contentRepository.getActivitiesByType(type);
      _logger.d('Loaded ${activities.length} activities for type: $type');
      return activities;
    } catch (e, _) {
      _logger.e('Error loading activities by type: $type, $e');
      return [];
    }
  }

  /// Load activities by aspect
  Future<List<Activity>> loadActivitiesByAspect(String aspect) async {
    try {
      final activities = await _contentRepository.getActivitiesByAspect(aspect);
      _logger.d('Loaded ${activities.length} activities for aspect: $aspect');
      return activities;
    } catch (e, _) {
      _logger.e('Error loading activities by aspect: $aspect, $e');
      return [];
    }
  }

  /// Load popular activities
  Future<void> loadPopularActivities() async {
    try {
      final activities = await _contentRepository.getPopularActivities(limit: 10);
      
      state = state.copyWith(popularActivities: activities);
      _logger.d('Loaded ${activities.length} popular activities');
    } catch (e, _) {
      _logger.e('Error loading popular activities: $e');
    }
  }

  /// Load recently added activities
  Future<List<Activity>> loadRecentlyAddedActivities() async {
    try {
      final activities = await _contentRepository.getRecentlyAddedActivities(limit: 10);
      _logger.d('Loaded ${activities.length} recently added activities');
      return activities;
    } catch (e, _) {
      _logger.e('Error loading recently added activities: $e');
      return [];
    }
  }

  // ==================== PERSONALIZATION ====================

  /// Load recommended activities for a child
  Future<void> loadRecommendedActivities(ChildProfile child) async {
    try {
      final activities = await _contentRepository.getRecommendedActivities(child);
      
      state = state.copyWith(recommendedActivities: activities);
      _logger.d('Loaded ${activities.length} recommended activities for ${child.name}');
    } catch (e, _) {
      _logger.e('Error loading recommended activities: $e');
    }
  }

  /// Load activities appropriate for a child
  Future<List<Activity>> loadActivitiesForChild(ChildProfile child) async {
    try {
      final activities = await _contentRepository.getActivitiesForChild(child);
      _logger.d('Loaded ${activities.length} activities for child: ${child.name}');
      return activities;
    } catch (e, _) {
      _logger.e('Error loading activities for child: ${child.name}, $e');
      return [];
    }
  }

  // ==================== SEARCH & FILTER ====================

  /// Search activities
  Future<List<Activity>> searchActivities(String query) async {
    try {
      final activities = await _contentRepository.searchActivities(query);
      _logger.d('Found ${activities.length} activities for query: $query');
      return activities;
    } catch (e, _) {
      _logger.e('Error searching activities: $query, $e');
      return [];
    }
  }

  /// Filter activities by difficulty
  Future<List<Activity>> filterByDifficulty(String difficulty) async {
    try {
      final activities = await _contentRepository.getActivitiesByDifficulty(difficulty);
      _logger.d('Filtered ${activities.length} activities by difficulty: $difficulty');
      return activities;
    } catch (e, _) {
      _logger.e('Error filtering by difficulty: $difficulty, $e');
      return [];
    }
  }

  /// Filter activities by age range
  Future<List<Activity>> filterByAgeRange(int minAge, int maxAge) async {
    try {
      final activities = state.activities.where((activity) {
        // Check if any age in the range is appropriate for the activity
        for (int age = minAge; age <= maxAge; age++) {
          if (activity.isAppropriateForAge(age)) {
            return true;
          }
        }
        return false;
      }).toList();
      
      _logger.d('Filtered ${activities.length} activities for age range: $minAge-$maxAge');
      return activities;
    } catch (e, _) {
      _logger.e('Error filtering by age range: $minAge-$maxAge, $e');
      return [];
    }
  }

  // ==================== OFFLINE SUPPORT ====================

  /// Get offline available activities
  Future<List<Activity>> getOfflineActivities() async {
    try {
      final activities = await _contentRepository.getOfflineActivities();
      _logger.d('Found ${activities.length} offline activities');
      return activities;
    } catch (e, _) {
      _logger.e('Error getting offline activities: $e');
      return [];
    }
  }

  /// Download activity for offline use
  Future<bool> downloadForOffline(String activityId) async {
    try {
      final success = await _contentRepository.downloadForOffline(activityId);
      _logger.d('Download activity for offline: $activityId - $success');
      return success;
    } catch (e, _) {
      _logger.e('Error downloading for offline: $activityId, $e');
      return false;
    }
  }

  // ==================== ACTIVITY INTERACTION ====================

  /// Get activity by ID
  Future<Activity?> getActivity(String activityId) async {
    try {
      final activity = await _contentRepository.getActivity(activityId);
      _logger.d('Retrieved activity: $activityId');
      return activity;
    } catch (e, _) {
      _logger.e('Error getting activity: $activityId, $e');
      return null;
    }
  }

  /// Increment activity play count
  Future<bool> incrementPlayCount(String activityId) async {
    try {
      final success = await _contentRepository.incrementPlayCount(activityId);
      
      if (success) {
        // Update local state
        state = state.copyWith(
          activities: state.activities.map((activity) {
            if (activity.id == activityId) {
              return activity.copyWith(playCount: activity.playCount + 1);
            }
            return activity;
          }).toList(),
        );
      }
      
      return success;
    } catch (e, _) {
      _logger.e('Error incrementing play count: $activityId, $e');
      return false;
    }
  }

  // ==================== CONTENT DISCOVERY ====================

  /// Get activities by interests
  Future<List<Activity>> getActivitiesByInterests(List<String> interests) async {
    try {
      final activities = state.activities.where((activity) {
        return activity.tags.any((tag) => interests.contains(tag));
      }).toList();
      
      _logger.d('Found ${activities.length} activities matching interests: $interests');
      return activities;
    } catch (e, _) {
      _logger.e('Error getting activities by interests: $interests, $e');
      return [];
    }
  }

  /// Get daily recommended activities
  Future<List<Activity>> getDailyRecommendations(ChildProfile child) async {
    try {
      // Get recommended activities
      final recommended = await loadActivitiesForChild(child);
      
      // Filter by child's interests and level
      final filtered = recommended.where((activity) {
        // Check if activity matches child's interests
        final interestMatch = activity.tags.any((tag) => child.interests.contains(tag));
        
        // Check if difficulty is appropriate
        final levelDiff = (activity.difficultyLevel - child.level).abs();
        
        return interestMatch && levelDiff <= 2;
      }).toList();
      
      // Sort by relevance and return top 5
      filtered.sort((a, b) {
        final aInterestMatches = a.tags.where((tag) => child.interests.contains(tag)).length;
        final bInterestMatches = b.tags.where((tag) => child.interests.contains(tag)).length;
        
        if (aInterestMatches != bInterestMatches) {
          return bInterestMatches.compareTo(aInterestMatches);
        }
        
        final aRating = a.averageRating ?? 0.0;
        final bRating = b.averageRating ?? 0.0;
        return bRating.compareTo(aRating);
      });
      
      return filtered.take(5).toList();
    } catch (e, _) {
      _logger.e('Error getting daily recommendations: $e');
      return [];
    }
  }

  /// Get continue learning activities (recently played)
  Future<List<Activity>> getContinueLearningActivities(ChildProfile child) async {
    try {
      // Get child's recent activities (would need progress data)
      // For now, return popular activities
      return state.popularActivities.take(3).toList();
    } catch (e, _) {
      _logger.e('Error getting continue learning activities: $e');
      return [];
    }
  }

  // ==================== CATEGORY MANAGEMENT ====================

  /// Get all categories
  List<String> getAllCategories() {
    return ActivityCategories.all;
  }

  /// Get all types
  List<String> getAllTypes() {
    return ActivityTypes.all;
  }

  /// Get all aspects
  List<String> getAllAspects() {
    return ActivityAspects.all;
  }

  /// Get category display name
  String getCategoryDisplayName(String category) {
    return ActivityCategories.getDisplayName(category);
  }

  /// Get type display name
  String getTypeDisplayName(String type) {
    return ActivityTypes.getDisplayName(type);
  }

  /// Get aspect display name
  String getAspectDisplayName(String aspect) {
    return ActivityAspects.getDisplayName(aspect);
  }

  // ==================== ERROR HANDLING ====================

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  // ==================== SYNC OPERATIONS ====================

  /// Sync content with server
  Future<bool> syncWithServer() async {
    try {
      return await _contentRepository.syncWithServer();
    } catch (e, _) {
      _logger.e('Error syncing content: $e');
      return false;
    }
  }
}

// Provider
final contentControllerProvider = StateNotifierProvider.autoDispose<ContentController, ContentState>((ref) {
  final contentRepository = ref.watch(contentRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  
  return ContentController(
    contentRepository: contentRepository,
    logger: logger,
  );
});

// Repository provider
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final activityBox = Hive.box('activities');
  final logger = ref.watch(loggerProvider);
  
  return ContentRepository(
    activityBox: activityBox,
    logger: logger,
  );
});

// Helper providers
final allActivitiesProvider = Provider<List<Activity>>((ref) {
  return ref.watch(contentControllerProvider).activities;
});

final recommendedActivitiesProvider = Provider<List<Activity>>((ref) {
  return ref.watch(contentControllerProvider).recommendedActivities;
});

final popularActivitiesProvider = Provider<List<Activity>>((ref) {
  return ref.watch(contentControllerProvider).popularActivities;
});

// Async providers for dynamic content
final activitiesByCategoryProvider = FutureProvider.autoDispose.family<List<Activity>, String>((ref, category) async {
  final controller = ref.watch(contentControllerProvider.notifier);
  return await controller.loadActivitiesByCategory(category);
});

final dailyRecommendationsProvider = FutureProvider.autoDispose.family<List<Activity>, ChildProfile>((ref, child) async {
  final controller = ref.watch(contentControllerProvider.notifier);
  return await controller.getDailyRecommendations(child);
});

final offlineActivitiesProvider = FutureProvider.autoDispose<List<Activity>>((ref) async {
  final controller = ref.watch(contentControllerProvider.notifier);
  return await controller.getOfflineActivities();
});