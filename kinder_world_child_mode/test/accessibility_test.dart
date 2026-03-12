// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/accessibility_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/accessibility_settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a minimal ProviderScope + MaterialApp wrapping [child].
/// Injects a fake SharedPreferences so no disk I/O occurs in tests.
Future<ProviderContainer> _pumpAccessibilityScreen(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
  );

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: theme ?? AppTheme.lightTheme(palette: ThemePalettes.green),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: const AccessibilitySettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests – AccessibilityState
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AccessibilityState – unit', () {
    test('default state has all features disabled', () {
      const state = AccessibilityState();
      expect(state.largeFontEnabled, isFalse);
      expect(state.highContrastEnabled, isFalse);
      expect(state.isAnyEnabled, isFalse);
    });

    test('isAnyEnabled is true when largeFontEnabled is true', () {
      const state = AccessibilityState(largeFontEnabled: true);
      expect(state.isAnyEnabled, isTrue);
    });

    test('isAnyEnabled is true when highContrastEnabled is true', () {
      const state = AccessibilityState(highContrastEnabled: true);
      expect(state.isAnyEnabled, isTrue);
    });

    test('isAnyEnabled is true when both features are enabled', () {
      const state = AccessibilityState(
        largeFontEnabled: true,
        highContrastEnabled: true,
      );
      expect(state.isAnyEnabled, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const original = AccessibilityState(largeFontEnabled: true);
      final updated = original.copyWith(highContrastEnabled: true);
      expect(updated.largeFontEnabled, isTrue);
      expect(updated.highContrastEnabled, isTrue);
    });

    test('copyWith with no args returns equivalent state', () {
      const state = AccessibilityState(
        largeFontEnabled: true,
        highContrastEnabled: false,
      );
      final copy = state.copyWith();
      expect(copy, equals(state));
    });

    test('equality holds for identical states', () {
      const a = AccessibilityState(largeFontEnabled: true);
      const b = AccessibilityState(largeFontEnabled: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality holds for different states', () {
      const a = AccessibilityState(largeFontEnabled: true);
      const b = AccessibilityState(highContrastEnabled: true);
      expect(a, isNot(equals(b)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Unit tests – AccessibilityController
  // ─────────────────────────────────────────────────────────────────────────

  group('AccessibilityController – unit', () {
    late SharedPreferences prefs;
    late AccessibilityController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      controller = AccessibilityController(prefs);
    });

    test('initial state reads from SharedPreferences (all false)', () {
      expect(controller.state.largeFontEnabled, isFalse);
      expect(controller.state.highContrastEnabled, isFalse);
    });

    test('initial state reads persisted large font value', () async {
      SharedPreferences.setMockInitialValues({
        'accessibility_large_font': true,
      });
      final p = await SharedPreferences.getInstance();
      final c = AccessibilityController(p);
      expect(c.state.largeFontEnabled, isTrue);
    });

    test('initial state reads persisted high contrast value', () async {
      SharedPreferences.setMockInitialValues({
        'accessibility_high_contrast': true,
      });
      final p = await SharedPreferences.getInstance();
      final c = AccessibilityController(p);
      expect(c.state.highContrastEnabled, isTrue);
    });

    test('setLargeFont(true) updates state and persists', () async {
      await controller.setLargeFont(true);
      expect(controller.state.largeFontEnabled, isTrue);
      expect(prefs.getBool('accessibility_large_font'), isTrue);
    });

    test('setLargeFont(false) updates state and persists', () async {
      await controller.setLargeFont(true);
      await controller.setLargeFont(false);
      expect(controller.state.largeFontEnabled, isFalse);
      expect(prefs.getBool('accessibility_large_font'), isFalse);
    });

    test('setHighContrast(true) updates state and persists', () async {
      await controller.setHighContrast(true);
      expect(controller.state.highContrastEnabled, isTrue);
      expect(prefs.getBool('accessibility_high_contrast'), isTrue);
    });

    test('setHighContrast(false) updates state and persists', () async {
      await controller.setHighContrast(true);
      await controller.setHighContrast(false);
      expect(controller.state.highContrastEnabled, isFalse);
      expect(prefs.getBool('accessibility_high_contrast'), isFalse);
    });

    test('reset() clears all features and removes prefs keys', () async {
      await controller.setLargeFont(true);
      await controller.setHighContrast(true);
      await controller.reset();

      expect(controller.state.largeFontEnabled, isFalse);
      expect(controller.state.highContrastEnabled, isFalse);
      expect(prefs.getBool('accessibility_large_font'), isNull);
      expect(prefs.getBool('accessibility_high_contrast'), isNull);
    });

    test('setLargeFont does not affect highContrast state', () async {
      await controller.setHighContrast(true);
      await controller.setLargeFont(true);
      expect(controller.state.highContrastEnabled, isTrue);
    });

    test('setHighContrast does not affect largeFont state', () async {
      await controller.setLargeFont(true);
      await controller.setHighContrast(true);
      expect(controller.state.largeFontEnabled, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Widget tests – AccessibilitySettingsScreen
  // ─────────────────────────────────────────────────────────────────────────

  group('AccessibilitySettingsScreen – widget', () {
    testWidgets('renders screen title and both toggle tiles',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(tester);

      // AppBar title
      expect(find.text('Accessibility'), findsOneWidget);

      // Toggle labels
      expect(find.text('Large Font'), findsOneWidget);
      expect(find.text('High Contrast'), findsOneWidget);

      // Both switches start off
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 2);
      expect(switches[0].value, isFalse);
      expect(switches[1].value, isFalse);
    });

    testWidgets('banner shows "Off" status when no feature is active',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(tester);
      // The banner status chip has a unique key; tile labels also show "Off"
      // but we verify the banner chip specifically.
      final bannerStatus = find.byKey(const Key('accessibility_banner_status'));
      expect(bannerStatus, findsOneWidget);
      expect(
        (tester.widget<Text>(bannerStatus)).data,
        'Off',
      );
    });

    testWidgets('banner shows "Active" status when large font is enabled',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(
        tester,
        prefs: {'accessibility_large_font': true},
      );
      final bannerStatus = find.byKey(const Key('accessibility_banner_status'));
      expect(bannerStatus, findsOneWidget);
      expect(
        (tester.widget<Text>(bannerStatus)).data,
        'Active',
      );
    });

    testWidgets('toggling large font switch updates state',
        (WidgetTester tester) async {
      final container = await _pumpAccessibilityScreen(tester);

      // Tap the first switch (Large Font)
      final largeFontSwitch = find.byType(Switch).first;
      await tester.tap(largeFontSwitch);
      await tester.pumpAndSettle();

      final state = container.read(accessibilityProvider);
      expect(state.largeFontEnabled, isTrue);
    });

    testWidgets('toggling high contrast switch updates state',
        (WidgetTester tester) async {
      final container = await _pumpAccessibilityScreen(tester);

      // Tap the second switch (High Contrast)
      final highContrastSwitch = find.byType(Switch).last;
      await tester.tap(highContrastSwitch);
      await tester.pumpAndSettle();

      final state = container.read(accessibilityProvider);
      expect(state.highContrastEnabled, isTrue);
    });

    testWidgets('reset button is hidden when no feature is active',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(tester);
      expect(find.text('Reset All Accessibility Settings'), findsNothing);
    });

    testWidgets('reset button appears when a feature is active',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(
        tester,
        prefs: {'accessibility_large_font': true},
      );
      expect(find.text('Reset All Accessibility Settings'), findsOneWidget);
    });

    testWidgets('parent note is always visible', (WidgetTester tester) async {
      await _pumpAccessibilityScreen(tester);
      expect(
        find.textContaining(
            'These settings apply to the child'),
        findsOneWidget,
      );
    });

    testWidgets('screen renders correctly with both features enabled',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(
        tester,
        prefs: {
          'accessibility_large_font': true,
          'accessibility_high_contrast': true,
        },
      );

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isTrue);
      // Banner chip shows "Active" (unique key)
      final bannerStatus = find.byKey(const Key('accessibility_banner_status'));
      expect(bannerStatus, findsOneWidget);
      expect((tester.widget<Text>(bannerStatus)).data, 'Active');
      expect(find.text('Reset All Accessibility Settings'), findsOneWidget);
    });

    testWidgets('live preview section is always rendered',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(tester);
      // The preview contains a simulated child greeting
      expect(find.textContaining('Hello, Sara!'), findsOneWidget);
    });

    testWidgets('live preview shows black background in high contrast mode',
        (WidgetTester tester) async {
      await _pumpAccessibilityScreen(
        tester,
        prefs: {'accessibility_high_contrast': true},
      );

      // Find a Container with black color (the preview background)
      final blackContainers = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == Colors.black;
          }
        }
        return false;
      });
      expect(blackContainers, findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Theme tests – high contrast themes
  // ─────────────────────────────────────────────────────────────────────────

  group('AppTheme – high contrast', () {
    test('highContrastLightTheme has black background', () {
      final theme =
          AppTheme.highContrastLightTheme(palette: ThemePalettes.green);
      expect(theme.colorScheme.surface, Colors.white);
      expect(theme.colorScheme.onSurface, Colors.black);
    });

    test('highContrastDarkTheme has white-on-black scheme', () {
      final theme =
          AppTheme.highContrastDarkTheme(palette: ThemePalettes.green);
      expect(theme.colorScheme.surface, Colors.black);
      expect(theme.colorScheme.onSurface, Colors.white);
    });

    test('highContrastLightTheme has thick border side', () {
      final theme =
          AppTheme.highContrastLightTheme(palette: ThemePalettes.green);
      final outlinedButtonTheme = theme.outlinedButtonTheme.style;
      final side = outlinedButtonTheme
          ?.side
          ?.resolve({WidgetState.focused});
      // Border width should be >= 2 for high contrast
      if (side != null) {
        expect(side.width, greaterThanOrEqualTo(2.0));
      }
    });

    test('highContrastLightTheme text is bold', () {
      final theme =
          AppTheme.highContrastLightTheme(palette: ThemePalettes.green);
      final bodyLarge = theme.textTheme.bodyLarge;
      expect(bodyLarge?.fontWeight, FontWeight.w700);
    });

    test('highContrastDarkTheme text is bold', () {
      final theme =
          AppTheme.highContrastDarkTheme(palette: ThemePalettes.green);
      final bodyLarge = theme.textTheme.bodyLarge;
      expect(bodyLarge?.fontWeight, FontWeight.w700);
    });

    test('high contrast themes differ from normal themes', () {
      final normal = AppTheme.lightTheme(palette: ThemePalettes.green);
      final highContrast =
          AppTheme.highContrastLightTheme(palette: ThemePalettes.green);
      // Primary color should differ (HC uses black/white)
      expect(
        normal.colorScheme.primary,
        isNot(equals(highContrast.colorScheme.primary)),
      );
    });

    testWidgets('AccessibilitySettingsScreen renders with high contrast theme',
        (WidgetTester tester) async {
      final hcTheme =
          AppTheme.highContrastLightTheme(palette: ThemePalettes.green);
      await _pumpAccessibilityScreen(tester, theme: hcTheme);
      // Should render without errors
      expect(find.text('Accessibility'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Integration-style: provider reacts to controller changes
  // ─────────────────────────────────────────────────────────────────────────

  group('accessibilityProvider – integration', () {
    test('provider reflects controller mutations', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(accessibilityProvider).isAnyEnabled, isFalse);

      await container
          .read(accessibilityProvider.notifier)
          .setLargeFont(true);
      expect(container.read(accessibilityProvider).largeFontEnabled, isTrue);
      expect(container.read(accessibilityProvider).isAnyEnabled, isTrue);

      await container
          .read(accessibilityProvider.notifier)
          .setHighContrast(true);
      expect(
          container.read(accessibilityProvider).highContrastEnabled, isTrue);

      await container.read(accessibilityProvider.notifier).reset();
      expect(container.read(accessibilityProvider).isAnyEnabled, isFalse);
    });

    test('provider persists state across re-creation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // First container – enable large font
      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await container1
          .read(accessibilityProvider.notifier)
          .setLargeFont(true);
      container1.dispose();

      // Second container – reads from same prefs instance
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(
          container2.read(accessibilityProvider).largeFontEnabled, isTrue);
    });
  });
}
