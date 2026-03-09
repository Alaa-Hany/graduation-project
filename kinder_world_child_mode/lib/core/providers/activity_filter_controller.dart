// ─────────────────────────────────────────────────────────────────────────────
// DEAD CODE — not imported anywhere in the app (confirmed via project-wide search).
// Safe to delete once the activity-filter feature is implemented or abandoned.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/models/activity.dart';
class ActivityFilterState {
  final String selectedAspect;
  final String? selectedCategory;
  final String? selectedDifficulty;

  const ActivityFilterState({
    this.selectedAspect = ActivityAspects.educational,
    this.selectedCategory,
    this.selectedDifficulty,
  });

  static const _unset = Object();

  ActivityFilterState copyWith({
    String? selectedAspect,
    Object? selectedCategory = _unset,
    Object? selectedDifficulty = _unset,
  }) {
    return ActivityFilterState(
      selectedAspect: selectedAspect ?? this.selectedAspect,
      selectedCategory: selectedCategory == _unset
          ? this.selectedCategory
          : selectedCategory as String?,
      selectedDifficulty: selectedDifficulty == _unset
          ? this.selectedDifficulty
          : selectedDifficulty as String?,
    );
  }

  bool get hasActiveFilters => selectedCategory != null || selectedDifficulty != null;
}

class ActivityFilterController extends StateNotifier<ActivityFilterState> {
  ActivityFilterController() : super(const ActivityFilterState());

  void selectAspect(String aspect) {
    state = state.copyWith(selectedAspect: aspect);
  }

  void selectCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectDifficulty(String? difficulty) {
    state = state.copyWith(selectedDifficulty: difficulty);
  }

  void clearFilters() {
    state = const ActivityFilterState();
  }
}

final activityFilterControllerProvider =
    StateNotifierProvider<ActivityFilterController, ActivityFilterState>(
        (ref) => ActivityFilterController());
