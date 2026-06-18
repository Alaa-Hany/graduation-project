// Tests for LocaleController and ThemeController Riverpod providers.
//
// Covers:
//  - LocaleController: default locale, setLocale, setLanguageCode, hasSavedLocale
//  - ThemeController: default state, setPalette, setMode, persistence
//  - ThemeModeResolutionX: resolvesToDark extension
//  - themePaletteProvider: resolves palette from state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<ProviderContainer> _makeContainer({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// LocaleController tests
// ---------------------------------------------------------------------------

void main() {
  group('LocaleController', () {
    test('defaults to English when no saved locale', () async {
      final container = await _makeContainer();
      final locale = container.read(localeProvider);
      expect(locale.languageCode, 'en');
    });

    test('restores saved locale from SharedPreferences', () async {
      final container = await _makeContainer(
        prefs: {'app_locale': 'ar'},
      );
      final locale = container.read(localeProvider);
      expect(locale.languageCode, 'ar');
    });

    test('setLocale updates state', () async {
      final container = await _makeContainer();
      final ctrl = container.read(localeProvider.notifier);

      await ctrl.setLocale(const Locale('ar'));

      expect(container.read(localeProvider).languageCode, 'ar');
    });

    test('setLanguageCode updates state', () async {
      final container = await _makeContainer();
      final ctrl = container.read(localeProvider.notifier);

      await ctrl.setLanguageCode('ar');

      expect(container.read(localeProvider).languageCode, 'ar');
    });

    test('setLocale persists so future container reads the saved value',
        () async {
      final container = await _makeContainer();
      await container.read(localeProvider.notifier).setLocale(const Locale('ar'));

      // Rebuild a fresh container backed by the same (now-persisted) prefs.
      final prefs = await SharedPreferences.getInstance();
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(localeProvider).languageCode, 'ar');
    });

    test('hasSavedLocale returns false when no locale has been set', () async {
      final container = await _makeContainer();
      final ctrl = container.read(localeProvider.notifier);
      final has = await ctrl.hasSavedLocale();
      expect(has, isFalse);
    });

    test('hasSavedLocale returns true after setLocale', () async {
      final container = await _makeContainer();
      final ctrl = container.read(localeProvider.notifier);
      await ctrl.setLocale(const Locale('en'));
      final has = await ctrl.hasSavedLocale();
      expect(has, isTrue);
    });

    test('setLocale to same language does not throw', () async {
      final container = await _makeContainer(prefs: {'app_locale': 'en'});
      final ctrl = container.read(localeProvider.notifier);
      // Already 'en', setting 'en' should be a no-op on state but still persists
      await expectLater(ctrl.setLocale(const Locale('en')), completes);
    });

    test('supports switching between multiple locales', () async {
      final container = await _makeContainer();
      final ctrl = container.read(localeProvider.notifier);

      await ctrl.setLocale(const Locale('ar'));
      expect(container.read(localeProvider).languageCode, 'ar');

      await ctrl.setLocale(const Locale('en'));
      expect(container.read(localeProvider).languageCode, 'en');
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeController tests
  // ---------------------------------------------------------------------------

  group('ThemeController', () {
    test('defaults to light mode when nothing is persisted', () async {
      final container = await _makeContainer();
      final state = container.read(themeControllerProvider);
      expect(state.mode, ThemeMode.light);
    });

    test('defaults to the default palette id', () async {
      final container = await _makeContainer();
      final state = container.read(themeControllerProvider);
      expect(state.paletteId, ThemePalettes.defaultPaletteId);
    });

    test('setMode to dark updates state', () async {
      final container = await _makeContainer();
      final ctrl = container.read(themeControllerProvider.notifier);

      await ctrl.setMode(ThemeMode.dark);

      expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
    });

    test('setMode to system updates state', () async {
      final container = await _makeContainer();
      await container.read(themeControllerProvider.notifier).setMode(ThemeMode.system);
      expect(container.read(themeControllerProvider).mode, ThemeMode.system);
    });

    test('setPalette updates paletteId in state', () async {
      final container = await _makeContainer();
      // Use the first available palette id (different from default)
      const allPalettes = ThemePalettes.all;
      final target = allPalettes.firstWhere(
        (p) => p.id != ThemePalettes.defaultPaletteId,
        orElse: () => allPalettes.first,
      );

      await container.read(themeControllerProvider.notifier).setPalette(target.id);

      expect(container.read(themeControllerProvider).paletteId, target.id);
    });

    test('setPalette persists and survives container rebuild', () async {
      final container = await _makeContainer();
      const allPalettes = ThemePalettes.all;
      final target = allPalettes.firstWhere(
        (p) => p.id != ThemePalettes.defaultPaletteId,
        orElse: () => allPalettes.first,
      );

      await container.read(themeControllerProvider.notifier).setPalette(target.id);

      final prefs = await SharedPreferences.getInstance();
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(themeControllerProvider).paletteId, target.id);
    });

    test('setMode persists and survives container rebuild', () async {
      final container = await _makeContainer();
      await container.read(themeControllerProvider.notifier).setMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(themeControllerProvider).mode, ThemeMode.dark);
    });

    test('restores persisted mode on startup', () async {
      // Set dark mode = index 2
      final container = await _makeContainer(prefs: {'theme_mode': 2});
      expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
    });

    test('restores persisted palette on startup', () async {
      const allPalettes = ThemePalettes.all;
      final target = allPalettes.firstWhere(
        (p) => p.id != ThemePalettes.defaultPaletteId,
        orElse: () => allPalettes.first,
      );
      final container =
          await _makeContainer(prefs: {'theme_palette_id': target.id});
      expect(container.read(themeControllerProvider).paletteId, target.id);
    });

    test('copyWith updates only the changed fields', () {
      const original = ThemeState(
        paletteId: 'default',
        mode: ThemeMode.light,
      );
      final updated = original.copyWith(mode: ThemeMode.dark);
      expect(updated.mode, ThemeMode.dark);
      expect(updated.paletteId, 'default');
    });

    test('copyWith with no args returns equivalent state', () {
      const original = ThemeState(
        paletteId: 'default',
        mode: ThemeMode.light,
      );
      final copy = original.copyWith();
      expect(copy.paletteId, original.paletteId);
      expect(copy.mode, original.mode);
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeModeResolutionX extension tests
  // ---------------------------------------------------------------------------

  group('ThemeModeResolutionX.resolvesToDark', () {
    test('ThemeMode.dark always resolves to dark', () {
      expect(ThemeMode.dark.resolvesToDark(Brightness.light), isTrue);
      expect(ThemeMode.dark.resolvesToDark(Brightness.dark), isTrue);
    });

    test('ThemeMode.light never resolves to dark', () {
      expect(ThemeMode.light.resolvesToDark(Brightness.light), isFalse);
      expect(ThemeMode.light.resolvesToDark(Brightness.dark), isFalse);
    });

    test('ThemeMode.system follows platform brightness', () {
      expect(ThemeMode.system.resolvesToDark(Brightness.dark), isTrue);
      expect(ThemeMode.system.resolvesToDark(Brightness.light), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // themePaletteProvider
  // ---------------------------------------------------------------------------

  group('themePaletteProvider', () {
    test('returns default palette when no customisation', () async {
      final container = await _makeContainer();
      final palette = container.read(themePaletteProvider);
      expect(palette.id, ThemePalettes.defaultPaletteId);
    });

    test('returns correct palette after setPalette', () async {
      final container = await _makeContainer();
      const allPalettes = ThemePalettes.all;
      final target = allPalettes.firstWhere(
        (p) => p.id != ThemePalettes.defaultPaletteId,
        orElse: () => allPalettes.first,
      );

      await container.read(themeControllerProvider.notifier).setPalette(target.id);
      final palette = container.read(themePaletteProvider);
      expect(palette.id, target.id);
    });
  });
}
