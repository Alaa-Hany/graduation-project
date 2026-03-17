import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';
import 'package:kinder_world/features/app_core/welcome_screen.dart';
import 'package:kinder_world/features/auth/parent_forgot_password_screen.dart';
import 'package:kinder_world/features/auth/user_type_selection_screen.dart';

class _RouteMarker extends StatelessWidget {
  const _RouteMarker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label)),
    );
  }
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/select-user-type',
        builder: (_, __) => const UserTypeSelectionScreen(),
      ),
      GoRoute(
        path: '/parent/login',
        builder: (_, __) => const _RouteMarker('parent-login-route'),
      ),
      GoRoute(
        path: '/parent/forgot-password',
        builder: (_, __) => const ParentForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/child/login',
        builder: (_, __) => const _RouteMarker('child-login-route'),
      ),
    ],
  );
}

Future<GoRouter> _pumpFlowApp(WidgetTester tester, {required String initialLocation}) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = _buildRouter(initialLocation);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
        routerConfig: router,
        locale: const Locale('en'),
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
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  return router;
}

Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tapAt(tester.getCenter(finder.first));
  await tester.pump();
}

void main() {
  testWidgets('welcome route renders primary onboarding actions',
      (WidgetTester tester) async {
    await _pumpFlowApp(tester, initialLocation: '/welcome');

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WelcomeScreen)),
    )!;

    expect(find.text(l10n.getStarted), findsOneWidget);
    expect(find.byType(GradientButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('user type selection route renders parent and child entry panels',
      (WidgetTester tester) async {
    await _pumpFlowApp(tester, initialLocation: '/select-user-type');

    final l10n = AppLocalizations.of(
      tester.element(find.byType(UserTypeSelectionScreen)),
    )!;

    expect(find.text(l10n.parentMode), findsOneWidget);
    expect(find.text(l10n.childMode), findsOneWidget);
    expect(find.text(l10n.parentModeDescription), findsOneWidget);
    expect(find.text(l10n.childModeDescription), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });

  testWidgets('parent forgot password validates domain and reaches sent state',
      (WidgetTester tester) async {
    await _pumpFlowApp(tester, initialLocation: '/parent/forgot-password');

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ParentForgotPasswordScreen)),
    )!;

    await tester.enterText(find.byType(TextFormField), 'parent-at-gmail');
    await _tapVisibleText(tester, l10n.sendResetLink);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.emailValidationInvalid), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'parent@gmail.com');
    await _tapVisibleText(tester, l10n.sendResetLink);
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text(l10n.checkYourInbox), findsOneWidget);
    expect(find.text(l10n.resetLinkSentTo('parent@gmail.com')), findsOneWidget);
  });
}
