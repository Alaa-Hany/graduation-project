import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/dashboard/admin_home_tab.dart';
import 'package:kinder_world/features/app_core/onboarding_screen.dart';
import 'package:kinder_world/features/app_core/welcome_screen.dart';

Future<void> _pumpWithTheme(
  WidgetTester tester, {
  required Widget child,
  required ThemeData theme,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BoxDecoration _findGradientDecoration(
  Iterable<Element> elements,
  Color expectedStartColor,
) {
  for (final element in elements) {
    final widget = element.widget;
    final decoration = switch (widget) {
      Container(:final decoration?) when decoration is BoxDecoration => decoration,
      AnimatedContainer(:final decoration?) when decoration is BoxDecoration => decoration,
      _ => null,
    };
    if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
      final gradient = decoration.gradient! as LinearGradient;
      if (gradient.colors.isNotEmpty && gradient.colors.first == expectedStartColor) {
        return decoration;
      }
    }
  }
  throw TestFailure('No gradient decoration found for $expectedStartColor');
}

void main() {
  testWidgets('welcome screen follows scaffold and text theme colors',
      (WidgetTester tester) async {
    final theme = AppTheme.darkTheme(palette: ThemePalettes.green);

    await _pumpWithTheme(
      tester,
      theme: theme,
      child: const WelcomeScreen(),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WelcomeScreen)),
    )!;

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);

    final titleText = tester.widget<Text>(
      find.text(l10n.welcomeTitle),
    );
    expect(titleText.style?.color, theme.colorScheme.onSurface);
  });

  testWidgets('onboarding screen hero gradient follows active palette',
      (WidgetTester tester) async {
    const palette = ThemePalettes.sunset;
    final theme = AppTheme.lightTheme(palette: palette);

    await _pumpWithTheme(
      tester,
      theme: theme,
      child: const OnboardingScreen(),
    );

    final decoration = _findGradientDecoration(
      find.byType(AnimatedContainer).evaluate(),
      palette.primary,
    );
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first, palette.primary);
  });

  testWidgets('admin home banner and role chips respond to dark theme',
      (WidgetTester tester) async {
    final theme = AppTheme.darkTheme(palette: ThemePalettes.purple);
    const admin = AdminUser(
      id: 1,
      email: 'super@kinderworld.app',
      name: 'Super Admin',
      isActive: true,
      roles: ['super_admin'],
      permissions: ['admin.users.view'],
    );

    await _pumpWithTheme(
      tester,
      theme: theme,
      overrides: [
        currentAdminProvider.overrideWithValue(admin),
      ],
      child: const Scaffold(body: AdminHomeTab()),
    );

    final decoration = _findGradientDecoration(
      find.byType(Container).evaluate(),
      theme.colorScheme.primary,
    );
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first, theme.colorScheme.primary);

    final chip = tester.widget<Chip>(find.byType(Chip).first);
    expect(chip.backgroundColor, theme.colorScheme.onPrimary);
  });

  testWidgets('shared parent and child widgets derive surfaces from theme',
      (WidgetTester tester) async {
    final theme = AppTheme.darkTheme(palette: ThemePalettes.blue);

    await _pumpWithTheme(
      tester,
      theme: theme,
      child: const Scaffold(
        body: Column(
          children: [
            ParentStatCard(
              value: '42',
              label: 'Minutes',
              icon: Icons.timer_outlined,
              color: Colors.orange,
            ),
            SizedBox(height: 12),
            ChildCategoryChip(
              label: 'Learn',
              emoji: '📘',
              color: Colors.teal,
              isSelected: false,
              onTap: _noop,
            ),
          ],
        ),
      ),
    );

    final containers = find.byType(Container).evaluate();
    final parentCard = containers
        .map((element) => element.widget)
        .whereType<Container>()
        .firstWhere((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration &&
          decoration.color == theme.colorScheme.surface;
    });
    expect((parentCard.decoration! as BoxDecoration).color, theme.colorScheme.surface);

    final chipContainer = containers
        .map((element) => element.widget)
        .whereType<Container>()
        .firstWhere((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration &&
          decoration.color == theme.colorScheme.surfaceContainerHighest;
    });
    expect(
      (chipContainer.decoration! as BoxDecoration).color,
      theme.colorScheme.surfaceContainerHighest,
    );
  });
}

void _noop() {}
