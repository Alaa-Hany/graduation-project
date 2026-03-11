import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/app.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getChildSession() async => null;

  @override
  Future<String?> getParentId() async => 'test_parent';
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
      ],
      child: const KinderWorldApp(),
    ));

    // Verify that the app starts without errors.
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Theme is applied correctly', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(_TestSecureStorage()),
        loggerProvider.overrideWithValue(Logger()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KinderWorldApp(),
    ));

    // Verify that MaterialApp has a theme
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, isNotNull);
  });
}
