import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:kinder_world/features/app_core/language_selection_screen.dart';
import 'package:kinder_world/features/app_core/onboarding_screen.dart';
import 'package:kinder_world/features/auth/user_type_selection_screen.dart';
import 'package:kinder_world/features/parent_mode/auth/parent_pin_screen.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSecureStorage extends SecureStorage {
  _TestSecureStorage({
    this.authToken,
    this.userRole,
    this.parentPinVerified = false,
  });

  final String? authToken;
  final String? userRole;
  bool parentPinVerified;

  @override
  Future<String?> getAuthToken() async => authToken;

  @override
  Future<String?> getUserRole() async => userRole;

  @override
  Future<String?> getChildSession() async => null;

  @override
  Future<bool> isParentPinVerified() async => parentPinVerified;

  @override
  Future<bool> saveParentPinVerified(bool isVerified) async {
    parentPinVerified = isVerified;
    return true;
  }

  @override
  Future<bool> clearParentPinVerification() async {
    parentPinVerified = false;
    return true;
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required super.secureStorage,
    required this.hasPin,
  }) : super(
          networkService: NetworkService(
            secureStorage: secureStorage,
            logger: Logger(),
          ),
          logger: Logger(),
        );

  final bool hasPin;

  @override
  Future<ParentPinStatus> getParentPinStatus() async {
    return ParentPinStatus(
      hasPin: hasPin,
      isLocked: false,
      failedAttempts: 0,
      lockedUntil: null,
    );
  }
}

class _FakeAdminAuthRepository extends AdminAuthRepository {
  _FakeAdminAuthRepository()
      : super(
          network: NetworkService(
            secureStorage: _TestSecureStorage(),
            logger: Logger(),
          ),
          storage: _TestSecureStorage(),
        );

  @override
  Future<void> logout() async {}
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required Map<String, Object> preferences,
  _TestSecureStorage? storage,
  _FakeAuthRepository? authRepository,
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(preferences);
  final sharedPreferences = await SharedPreferences.getInstance();
  final resolvedStorage = storage ?? _TestSecureStorage();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(resolvedStorage),
      loggerProvider.overrideWithValue(Logger()),
      if (authRepository != null)
        authRepositoryProvider.overrideWithValue(authRepository),
      adminAuthRepositoryProvider.overrideWithValue(_FakeAdminAuthRepository()),
      connectivityProvider.overrideWith(
        (ref) => Stream.value(ConnectivityResult.wifi),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const KinderWorldApp(),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('first launch opens language selection', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      preferences: const <String, Object>{},
    );
    await _pumpPastSplash(tester);

    expect(
      container.read(routerProvider).routerDelegate.currentConfiguration.uri.path,
      Routes.language,
    );
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
  });

  testWidgets('saved language without onboarding opens onboarding', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      preferences: const <String, Object>{
        'app_locale': 'ar',
      },
    );
    await _pumpPastSplash(tester);

    expect(
      container.read(routerProvider).routerDelegate.currentConfiguration.uri.path,
      Routes.onboarding,
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('completed onboarding opens user type selection', (
    WidgetTester tester,
  ) async {
    final container = await _pumpApp(
      tester,
      preferences: const <String, Object>{
        'app_locale': 'en',
        'onboarding_completed': true,
      },
    );
    await _pumpPastSplash(tester);

    expect(
      container.read(routerProvider).routerDelegate.currentConfiguration.uri.path,
      Routes.selectUserType,
    );
    expect(find.byType(UserTypeSelectionScreen), findsOneWidget);
  });

  testWidgets('authenticated parent entering parent mode is sent to PIN', (
    WidgetTester tester,
  ) async {
    final storage = _TestSecureStorage(
      authToken: 'parent-token',
      userRole: 'parent',
      parentPinVerified: false,
    );
    final authRepository = _FakeAuthRepository(
      secureStorage: storage,
      hasPin: true,
    );
    final container = await _pumpApp(
      tester,
      preferences: const <String, Object>{
        'app_locale': 'en',
        'onboarding_completed': true,
      },
      storage: storage,
      authRepository: authRepository,
    );
    await _pumpPastSplash(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(UserTypeSelectionScreen)),
    )!;

    await tester.tap(find.text(l10n.parentMode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    expect(find.byType(ParentPinScreen), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.parentPin,
    );
  });
}
