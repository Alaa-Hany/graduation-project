import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/services/sound_effects_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether app-wide music / sound effects are turned on.
///
/// Persists the child's choice and keeps [SoundEffectsService] in sync so the
/// toggle silences playback immediately. Defaults to on.
class SoundController extends StateNotifier<bool> {
  static const _key = 'sound_enabled';
  final SharedPreferences _prefs;

  SoundController(this._prefs) : super(_prefs.getBool(_key) ?? true) {
    SoundEffectsService.instance.setEnabled(state);
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_key, value);
    SoundEffectsService.instance.setEnabled(value);
    state = value;
  }

  Future<void> toggle() => setEnabled(!state);
}

final soundControllerProvider =
    StateNotifierProvider<SoundController, bool>((ref) {
  return SoundController(ref.watch(sharedPreferencesProvider));
});
