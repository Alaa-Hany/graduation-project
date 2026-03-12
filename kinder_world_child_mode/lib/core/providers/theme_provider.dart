import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final String paletteId;
  final ThemeMode mode;

  const ThemeState({
    required this.paletteId,
    required this.mode,
  });

  ThemeState copyWith({
    String? paletteId,
    ThemeMode? mode,
  }) {
    return ThemeState(
      paletteId: paletteId ?? this.paletteId,
      mode: mode ?? this.mode,
    );
  }
}

extension ThemeModeResolutionX on ThemeMode {
  bool resolvesToDark(Brightness platformBrightness) {
    switch (this) {
      case ThemeMode.system:
        return platformBrightness == Brightness.dark;
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
    }
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  static const _paletteKey = 'theme_palette_id';
  static const _modeKey = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeController(this._prefs)
      : super(
          ThemeState(
            paletteId:
                _prefs.getString(_paletteKey) ?? ThemePalettes.defaultPaletteId,
            mode: ThemeMode.values[
                (_prefs.getInt(_modeKey) ?? ThemeMode.light.index)
                    .clamp(0, ThemeMode.values.length - 1)
                    .toInt()],
          ),
        );

  Future<void> setPalette(String paletteId) async {
    await _prefs.setString(_paletteKey, paletteId);
    state = state.copyWith(paletteId: paletteId);
  }

  Future<void> setMode(ThemeMode mode) async {
    await _prefs.setInt(_modeKey, mode.index);
    state = state.copyWith(mode: mode);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController(ref.watch(sharedPreferencesProvider));
});

final themePaletteProvider = Provider<ThemePalette>((ref) {
  final state = ref.watch(themeControllerProvider);
  return ThemePalettes.byId(state.paletteId);
});
