import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale('en'));

  static const String _localeKey = 'app_locale';

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null || code.isEmpty) return;
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    if (state.languageCode == locale.languageCode) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> setLanguageCode(String languageCode) async {
    await setLocale(Locale(languageCode));
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});
