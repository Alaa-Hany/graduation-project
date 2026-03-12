import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLaunchController {
  AppLaunchController(this._prefs);

  static const String _localeKey = 'app_locale';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  final SharedPreferences _prefs;

  bool get hasSavedLocale {
    final code = _prefs.getString(_localeKey);
    return code != null && code.isNotEmpty;
  }

  bool get hasCompletedOnboarding =>
      _prefs.getBool(_onboardingCompletedKey) ?? false;

  Future<void> ensureLocaleSaved(String languageCode) {
    return _prefs.setString(_localeKey, languageCode);
  }

  Future<void> completeOnboarding() {
    return _prefs.setBool(_onboardingCompletedKey, true);
  }
}

final appLaunchProvider = Provider<AppLaunchController>((ref) {
  return AppLaunchController(ref.watch(sharedPreferencesProvider));
});
