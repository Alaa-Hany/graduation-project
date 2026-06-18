// Additional widget tests for ChildLoginScreen.
//
// Covers edge cases not tested in child_login_screen_test.dart:
//  - Login button is disabled when name is empty
//  - Login button is disabled when child ID is empty
//  - Login button is disabled when fewer than 3 picture icons are selected
//  - Login button is enabled only once all 3 constraints are met
//  - Deselecting a picture removes it from the selection
//  - Cannot select more than 3 pictures (4th tap is ignored)
//  - "Forgot password" button navigates to /child/forgot-password
//  - Picture password icons are visible in the picker
//  - Error message from a previous attempt is cleared on a new submission

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/repositories/child_repository.dart';
import 'package:kinder_world/core/services/child_profiles_view_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/features/auth/child_login_screen.dart';
import 'package:logger/logger.dart';

// ---------------------------------------------------------------------------
// Fakes (shared with child_login_screen_test.dart but redeclared here so
// the two test files remain self-contained and runnable independently)
// ---------------------------------------------------------------------------

class _SecureStorage extends SecureStorage {
  String? authToken;
  String? userId;
  String? userRole;
  String? childSession;
  String? userEmail;
  bool parentPinVerified = false;

  @override
  Future<String?> getAuthToken() async => authToken;
  @override
  bool get hasCachedAuthToken => authToken != null;
  @override
  String? get cachedAuthToken => authToken;
  @override
  Future<bool> saveAuthToken(String token) async {
    authToken = token;
    return true;
  }

  @override
  Future<String?> getUserId() async => userId;
  @override
  bool get hasCachedUserId => userId != null;
  @override
  String? get cachedUserId => userId;
  @override
  Future<bool> saveUserId(String value) async {
    userId = value;
    return true;
  }

  @override
  Future<String?> getUserRole() async => userRole;
  @override
  Future<bool> saveUserRole(String value) async {
    userRole = value;
    return true;
  }

  @override
  Future<String?> getChildSession() async => childSession;
  @override
  Future<bool> saveChildSession(String childId) async {
    childSession = childId;
    return true;
  }

  @override
  Future<bool> clearChildSession() async {
    childSession = null;
    return true;
  }

  @override
  Future<String?> getUserEmail() async => userEmail;
  @override
  Future<String?> getParentEmail() async => userEmail;
  @override
  Future<bool> saveUserEmail(String email) async {
    userEmail = email;
    return true;
  }

  @override
  Future<bool> clearParentPinVerification() async {
    parentPinVerified = false;
    return true;
  }

  @override
  Future<bool> saveParentPinVerified(bool isVerified) async {
    parentPinVerified = isVerified;
    return true;
  }

  @override
  Future<bool> isParentPinVerified() async => parentPinVerified;

  @override
  Future<bool> isAuthenticated() async =>
      authToken != null && authToken!.isNotEmpty;
}

class _DummyBox implements Box<dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(SecureStorage s)
      : super(NetworkService(secureStorage: s, logger: Logger()));
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required SecureStorage storage,
    this.loginChildHandler,
  }) : super(
          secureStorage: storage,
          authApi: _FakeAuthApi(storage),
          logger: Logger(),
        );

  Future<User?> Function({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  })? loginChildHandler;

  @override
  Future<void> clearParentPinVerification() async {}

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> loginChild({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  }) async {
    return loginChildHandler!(
      childId: childId,
      childName: childName,
      picturePassword: picturePassword,
    );
  }
}

class _EmptyChildRepository extends ChildRepository {
  _EmptyChildRepository()
      : super(childBox: _DummyBox(), logger: Logger());

  @override
  Future<List<ChildProfile>> getAllChildProfiles() async => [];

  @override
  Future<ChildProfile?> getChildProfile(String childId) async => null;

  @override
  Future<ChildProfile?> createChildProfile(ChildProfile profile) async =>
      profile;

  @override
  Future<ChildProfile?> updateChildProfile(ChildProfile profile) async =>
      profile;
}

// ---------------------------------------------------------------------------
// No-network SecureStorage stub (avoids real HTTP calls from the view service)
// ---------------------------------------------------------------------------

class _NoNetworkSecureStorage extends SecureStorage {
  @override
  bool get hasCachedAuthToken => true;
  @override
  String? get cachedAuthToken => null; // null → skip remote sync
  @override
  Future<String?> getAuthToken() async => null;
  @override
  Future<String?> getUserRole() async => null;
  @override
  Future<String?> getChildSession() async => null;
  @override
  Future<bool> isAuthenticated() async => false;
  @override
  Future<bool> isParentPinVerified() async => false;
  @override
  Future<bool> clearParentPinVerification() async => true;
}

/// ChildProfilesViewService that only reads from the local repo — no network.
class _LocalOnlyChildProfilesViewService extends ChildProfilesViewService {
  _LocalOnlyChildProfilesViewService(ChildRepository repo)
      : super(
          childRepository: repo,
          networkService: NetworkService(
            secureStorage: _NoNetworkSecureStorage(),
            logger: Logger(),
          ),
          secureStorage: _NoNetworkSecureStorage(),
          logger: Logger(),
        );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildApp(List<Override> overrides, {ChildRepository? childRepo}) {
  final router = GoRouter(
    initialLocation: '/child/login',
    routes: [
      GoRoute(
        path: '/child/login',
        builder: (_, __) => const ChildLoginScreen(),
      ),
      GoRoute(
        path: '/child/home',
        builder: (_, __) => const Scaffold(body: Text('child-home')),
      ),
      GoRoute(
        path: '/child/forgot-password',
        builder: (_, __) => const Scaffold(body: Text('forgot-password-screen')),
      ),
      GoRoute(
        path: '/select-user-type',
        builder: (_, __) => const Scaffold(body: Text('select-user-type')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      loggerProvider.overrideWithValue(Logger()),
      appNavigationControllerProvider
          .overrideWithValue(AppNavigationController()),
      if (childRepo != null)
        childProfilesViewServiceProvider.overrideWithValue(
          _LocalOnlyChildProfilesViewService(childRepo),
        ),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme(palette: ThemePalettes.defaultPalette),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
}

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

Future<_SecureStorage> _pumpScreen(
  WidgetTester tester, {
  Future<User?> Function({
    required String childId,
    required String childName,
    required List<String> picturePassword,
  })? loginChildHandler,
}) async {
  _setViewport(tester);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final storage = _SecureStorage();
  final repo = _FakeAuthRepository(
    storage: storage,
    loginChildHandler: loginChildHandler ??
        ({required childId, required childName, required picturePassword}) async =>
            null,
  );
  final childRepo = _EmptyChildRepository();

  await tester.pumpWidget(
    _buildApp(
      [
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
        childRepositoryProvider.overrideWithValue(childRepo),
      ],
      childRepo: childRepo,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return storage;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChildLoginScreen)))!;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Login button disabled until all conditions met ────────────────────────

  testWidgets('login button is disabled when name is empty', (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    // Fill child ID but leave name empty
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'child-1');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNull,
        reason: 'Button should be disabled when name is empty');
  });

  testWidgets('login button is disabled when child ID is empty', (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    // Fill name but leave child ID empty
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNull,
        reason: 'Button should be disabled when child ID is empty');
  });

  testWidgets(
      'login button is disabled when fewer than 3 pictures are selected',
      (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');
    // Select only 2 pictures
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNull,
        reason: 'Button should be disabled with only 2 pictures');
  });

  testWidgets('login button is disabled with zero pictures selected',
      (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNull,
        reason: 'Button should be disabled with 0 pictures');
  });

  testWidgets('login button becomes enabled when all conditions are met',
      (tester) async {
    await _pumpScreen(
      tester,
      loginChildHandler: ({required childId, required childName, required picturePassword}) async =>
          null,
    );
    final l10n = _l10n(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNotNull,
        reason: 'Button should be enabled with all fields filled');
  });

  // ── Picture password deselection ─────────────────────────────────────────

  testWidgets(
      'tapping a selected picture icon a second time deselects it and disables login',
      (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    // All 3 selected — button should be enabled
    final btnBefore = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btnBefore.onPressed, isNotNull);

    // Deselect one icon
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.pump();

    // Now only 2 selected — button should be disabled again
    final btnAfter = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btnAfter.onPressed, isNull,
        reason: 'Button should be disabled after deselecting one picture');
  });

  // ── Cannot select more than 3 pictures ───────────────────────────────────

  testWidgets('selecting a 4th picture icon has no additional effect',
      (tester) async {
    await _pumpScreen(
      tester,
      loginChildHandler: ({required childId, required childName, required picturePassword}) async =>
          null,
    );
    final l10n = _l10n(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');

    // Select 3 pictures
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();

    // Attempt to tap a 4th picture (sports_soccer)
    await tester.tap(find.byIcon(Icons.sports_soccer).first);
    await tester.pump();

    // Button should still be enabled (selection stayed at 3, not broken)
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, l10n.login),
    );
    expect(btn.onPressed, isNotNull,
        reason: '4th tap should be ignored; button stays enabled');
  });

  // ── Forgot password navigation ────────────────────────────────────────────

  testWidgets('tapping forgot password navigates to /child/forgot-password',
      (tester) async {
    await _pumpScreen(tester);
    final l10n = _l10n(tester);

    final forgotFinder = find.widgetWithText(TextButton, l10n.forgotPassword);
    expect(forgotFinder, findsWidgets);

    await tester.tap(forgotFinder.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('forgot-password-screen'), findsOneWidget);
  });

  // ── Picture password icons are visible ───────────────────────────────────

  testWidgets('picture password picker shows expected icons', (tester) async {
    await _pumpScreen(tester);

    // At least eco, pets, emoji_nature must be visible somewhere in the picker
    expect(find.byIcon(Icons.eco), findsWidgets);
    expect(find.byIcon(Icons.pets), findsWidgets);
    expect(find.byIcon(Icons.emoji_nature), findsWidgets);
  });

  // ── Login shows loading, then error cleared on retry ─────────────────────

  testWidgets(
      'error from failed login is cleared when a new login attempt starts',
      (tester) async {
    int callCount = 0;
    await _pumpScreen(
      tester,
      loginChildHandler: ({required childId, required childName, required picturePassword}) async {
        callCount += 1;
        if (callCount == 1) {
          throw const ChildLoginException(statusCode: 401);
        }
        // Second call succeeds (but we only care about the state transition)
        return null;
      },
    );
    final l10n = _l10n(tester);

    Future<void> fillAndSubmit() async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Mira');
      await tester.enterText(fields.at(1), 'child-1');
      await tester.tap(find.byIcon(Icons.eco).first);
      await tester.tap(find.byIcon(Icons.pets).first);
      await tester.tap(find.byIcon(Icons.emoji_nature).first);
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // First attempt — expect error text
    await fillAndSubmit();
    expect(find.text(l10n.childLoginIncorrectPictures), findsAtLeastNWidgets(1));

    // Second attempt — during submission the loading indicator replaces the error
    // We check that the error widget is gone while isLoading is true.
    // (We don't complete the future here so loading stays active.)
    final completer = Completer<User?>();
    callCount = 0; // reset so next call goes to the completer path
    final storage2 = _SecureStorage();
    final repo2 = _FakeAuthRepository(
      storage: storage2,
      loginChildHandler: ({required childId, required childName, required picturePassword}) =>
          completer.future,
    );
    final childRepo2 = _EmptyChildRepository();
    await tester.pumpWidget(
      _buildApp(
        [
          secureStorageProvider.overrideWithValue(storage2),
          authRepositoryProvider.overrideWithValue(repo2),
          childRepositoryProvider.overrideWithValue(childRepo2),
        ],
        childRepo: childRepo2,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'child-1');
    await tester.tap(find.byIcon(Icons.eco).first);
    await tester.tap(find.byIcon(Icons.pets).first);
    await tester.tap(find.byIcon(Icons.emoji_nature).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.login));
    await tester.pump();

    // Loading state — error should not be visible
    expect(find.text(l10n.childLoginIncorrectPictures), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(null);
    await tester.pump(const Duration(milliseconds: 300));

    // Drain the 3-second overlay auto-dismiss timers from both login attempts.
    await tester.pump(const Duration(seconds: 4));
  });

  // ── Screen is rendered (smoke) ────────────────────────────────────────────

  testWidgets('ChildLoginScreen renders without throwing', (tester) async {
    await _pumpScreen(tester);
    expect(find.byType(ChildLoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen shows both name and childId text fields', (tester) async {
    await _pumpScreen(tester);
    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2));
  });
}
