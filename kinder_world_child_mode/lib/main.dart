import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _startupHiveBoxes = <String>[
  'child_profiles',
  'activities',
  'progress_records',
  'gamification_data',
  'mood_entries',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Open required Hive boxes as untyped for JSON storage
  // Note: Freezed models don't work directly with Hive TypeAdapters,
  // so we store as JSON maps and serialize/deserialize in repositories
  await Future.wait(_startupHiveBoxes.map(Hive.openBox));

  // Initialize secure storage
  final secureStorage = SecureStorage();
  final sharedPreferencesFuture = SharedPreferences.getInstance();
  await secureStorage.preloadSessionState();
  final sharedPreferences = await sharedPreferencesFuture;

  // Initialize logger
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: kDebugMode,
      printEmojis: kDebugMode,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  // Set error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e('Flutter Error: ${details.exceptionAsString()}');
  };

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(secureStorage),
        loggerProvider.overrideWithValue(logger),
      ],
      child: const KinderWorldApp(),
    ),
  );
}
