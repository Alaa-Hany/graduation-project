import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AccessibilityState {
  final bool largeFontEnabled;
  final bool highContrastEnabled;

  const AccessibilityState({
    this.largeFontEnabled = false,
    this.highContrastEnabled = false,
  });

  AccessibilityState copyWith({
    bool? largeFontEnabled,
    bool? highContrastEnabled,
  }) {
    return AccessibilityState(
      largeFontEnabled: largeFontEnabled ?? this.largeFontEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
    );
  }

  /// True if at least one accessibility feature is active.
  bool get isAnyEnabled => largeFontEnabled || highContrastEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilityState &&
          other.largeFontEnabled == largeFontEnabled &&
          other.highContrastEnabled == highContrastEnabled;

  @override
  int get hashCode => Object.hash(largeFontEnabled, highContrastEnabled);
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class AccessibilityController extends StateNotifier<AccessibilityState> {
  static const _largeFontKey = 'accessibility_large_font';
  static const _highContrastKey = 'accessibility_high_contrast';

  final SharedPreferences _prefs;

  AccessibilityController(this._prefs)
      : super(
          AccessibilityState(
            largeFontEnabled: _prefs.getBool(_largeFontKey) ?? false,
            highContrastEnabled: _prefs.getBool(_highContrastKey) ?? false,
          ),
        );

  Future<void> setLargeFont(bool value) async {
    await _prefs.setBool(_largeFontKey, value);
    state = state.copyWith(largeFontEnabled: value);
  }

  Future<void> setHighContrast(bool value) async {
    await _prefs.setBool(_highContrastKey, value);
    state = state.copyWith(highContrastEnabled: value);
  }

  Future<void> reset() async {
    await _prefs.remove(_largeFontKey);
    await _prefs.remove(_highContrastKey);
    state = const AccessibilityState();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final accessibilityProvider =
    StateNotifierProvider<AccessibilityController, AccessibilityState>((ref) {
  return AccessibilityController(ref.watch(sharedPreferencesProvider));
});
