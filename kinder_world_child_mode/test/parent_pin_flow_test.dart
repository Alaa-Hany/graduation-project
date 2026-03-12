import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
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
  })  : storage = secureStorage,
        super(
          networkService: NetworkService(
            secureStorage: secureStorage,
            logger: Logger(),
          ),
          logger: Logger(),
        );

  final SecureStorage storage;
  bool hasPin;
  String currentPin = '2468';

  @override
  Future<ParentPinStatus> getParentPinStatus() async {
    return ParentPinStatus(
      hasPin: hasPin,
      isLocked: false,
      failedAttempts: 0,
      lockedUntil: null,
    );
  }

  @override
  Future<ParentPinActionResult> setParentPin(String pin, String confirmPin) async {
    if (pin != confirmPin) {
      return const ParentPinActionResult(success: false, error: 'PIN mismatch');
    }
    hasPin = true;
    currentPin = pin;
    await clearParentPinVerification();
    await storage.saveParentPinVerified(true);
    return const ParentPinActionResult(
      success: true,
      message: 'Parent PIN created successfully',
    );
  }

  @override
  Future<ParentPinActionResult> verifyParentPin(String enteredPin) async {
    if (enteredPin != currentPin) {
      return const ParentPinActionResult(success: false, error: 'Incorrect PIN');
    }
    await storage.saveParentPinVerified(true);
    return const ParentPinActionResult(
      success: true,
      message: 'Parent PIN verified successfully',
    );
  }

  @override
  Future<ParentPinActionResult> changeParentPin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    if (currentPin != this.currentPin) {
      return const ParentPinActionResult(
        success: false,
        error: 'Current PIN is incorrect',
      );
    }
    this.currentPin = newPin;
    await storage.saveParentPinVerified(true);
    return const ParentPinActionResult(
      success: true,
      message: 'Parent PIN changed successfully',
    );
  }

  @override
  Future<ParentPinActionResult> requestParentPinReset({String? note}) async {
    return const ParentPinActionResult(
      success: true,
      message: 'Support request created for Parent PIN reset',
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
  required _TestSecureStorage storage,
  required _FakeAuthRepository authRepository,
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(const <String, Object>{
    'app_locale': 'en',
    'onboarding_completed': true,
  });
  final sharedPreferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(storage),
      loggerProvider.overrideWithValue(Logger()),
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
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  testWidgets('protected parent route redirects to parent pin screen', (
    WidgetTester tester,
  ) async {
    final storage = _TestSecureStorage(
      authToken: 'parent-token',
      userRole: 'parent',
      parentPinVerified: false,
    );
    final repo = _FakeAuthRepository(
      secureStorage: storage,
      hasPin: true,
    );
    final container = await _pumpApp(
      tester,
      storage: storage,
      authRepository: repo,
    );
    final router = container.read(routerProvider);

    router.go(Routes.parentSettings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ParentPinScreen), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.parentPin,
    );
  });

  testWidgets('auto mode creates pin and continues to protected route', (
    WidgetTester tester,
  ) async {
    final storage = _TestSecureStorage(
      authToken: 'parent-token',
      userRole: 'parent',
      parentPinVerified: false,
    );
    final repo = _FakeAuthRepository(
      secureStorage: storage,
      hasPin: false,
    );
    final container = await _pumpApp(
      tester,
      storage: storage,
      authRepository: repo,
    );
    final router = container.read(routerProvider);

    router.go('${Routes.parentPin}?redirect=${Uri.encodeComponent(Routes.parentSettings)}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final success = await container.read(parentPinProvider.notifier).setPin(
          pin: '1234',
          confirmPin: '1234',
        );
    await tester.pump(const Duration(milliseconds: 500));
    router.go(Routes.parentSettings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(success, isTrue);
    expect(repo.hasPin, isTrue);
  });

  testWidgets('verify mode shows error for incorrect pin', (
    WidgetTester tester,
  ) async {
    final storage = _TestSecureStorage(
      authToken: 'parent-token',
      userRole: 'parent',
      parentPinVerified: false,
    );
    final repo = _FakeAuthRepository(
      secureStorage: storage,
      hasPin: true,
    );
    final container = await _pumpApp(
      tester,
      storage: storage,
      authRepository: repo,
    );
    final router = container.read(routerProvider);
    router.go('${Routes.parentPin}?mode=verify');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final success = await container.read(parentPinProvider.notifier).verifyPin('1111');
    await tester.pump(const Duration(milliseconds: 500));

    final pinState = container.read(parentPinProvider);
    expect(success, isFalse);
    expect(pinState.isVerified, isFalse);
    expect(pinState.error, 'Incorrect PIN');
  });
}
