import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/app.dart';
import 'helpers/test_admin_auth_helpers.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  bool get hasCachedAuthToken => true;

  @override
  String? get cachedAuthToken => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getChildSession() async => null;

  @override
  Future<String?> getParentId() async => 'test_parent';

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<bool> isParentPinVerified() async => false;

  @override
  Future<bool> clearParentPinVerification() async => true;

  @override
  bool get hasCachedSessionSnapshot => true;
}


void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App starts correctly', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(_TestSecureStorage()),
        loggerProvider.overrideWithValue(Logger()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider
            .overrideWith((ref) => Stream.value(ConnectivityResult.wifi)),
        ...createMockAdminAuthOverrides(),
      ],
      child: const KinderWorldApp(),
    ));

    // Verify that the app starts without errors.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Flush pending timers: one pump() drains microtasks, pump(zero) fires
    // any Duration.zero timers (e.g. Riverpod _debugAssertCanDependOn),
    // and pump(seconds:4) drains any overlay auto-dismiss timers.
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Theme is applied correctly', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(_TestSecureStorage()),
        loggerProvider.overrideWithValue(Logger()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider
            .overrideWith((ref) => Stream.value(ConnectivityResult.wifi)),
        ...createMockAdminAuthOverrides(),
      ],
      child: const KinderWorldApp(),
    ));

    // Verify that MaterialApp has a theme
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);

    // Drain any pending timers (e.g. overlay auto-dismiss) before the test ends.
    await tester.pump(const Duration(seconds: 4));
  });
}
