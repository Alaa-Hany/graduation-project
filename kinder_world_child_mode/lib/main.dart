import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/storage/hive_boxes.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/routing/route_guards.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture the route the web page was loaded at *before* any MaterialApp or
  // go_router runs and rewrites the URL. With the hash URL strategy the app
  // route lives in the fragment (e.g. `https://app/#/parent/dashboard`). The
  // router uses this (via resolveInitialLocation) as its initial location so a
  // refresh resumes the saved parent/child mode where the user was, and so deep
  // links (e.g. a password-reset `?token=...`) survive the bootstrap splash.
  if (kIsWeb) {
    final base = Uri.base;
    final raw = base.fragment.isNotEmpty ? base.fragment : base.path;
    final parsed = Uri.parse(raw);
    webEntryRoutePath = parsed.path;
    // Preserve the query string (e.g. the password-reset `?token=...`) so the
    // router can honour the full deep link, not just its path.
    webEntryLocation =
        parsed.hasQuery ? '${parsed.path}?${parsed.query}' : parsed.path;
  }

  // Initialize logger and global error handlers synchronously so they are
  // active before any async init runs.
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

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.e(
      'event=app.flutter_error error=${details.exceptionAsString()} '
      'library=${details.library ?? "unknown"}',
    );
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Child-friendly error screen instead of red debug screen
    return const Material(
      color: Color(0xFFF0F4FF),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌟', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'Oops! Something went wrong.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B6AF0),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please ask a parent for help.',
              style: TextStyle(fontSize: 14, color: Color(0xFF8892A4)),
            ),
          ],
        ),
      ),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.e('event=app.platform_error error=$error stack=$stack');
    // Return true to mark it handled and keep app alive where possible.
    return true;
  };

  // Render a splash frame immediately, then run heavy init (Hive boxes, secure
  // storage preload, shared prefs) in the background. See [AppBootstrap].
  runApp(AppBootstrap(logger: logger));
}

/// Boots the app behind an instant splash.
///
/// `main()` no longer blocks on Hive/secure-storage/shared-prefs init before
/// the first frame. Instead this widget paints [_BootstrapSplash] right away
/// and performs the async init in the background, swapping in the real app
/// (which itself starts at the animated splash route) once everything is ready.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, required this.logger});

  final Logger logger;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<_BootstrapResult> _bootstrap = _initialize();

  Future<_BootstrapResult> _initialize() async {
    // Initialize Hive for local storage.
    await Hive.initFlutter();

    // Open the box required by the parent auth flow first; defer the rest.
    // Boxes store JSON maps (Freezed models don't work with Hive TypeAdapters),
    // so they are opened untyped and (de)serialized in repositories.
    await Hive.openBox<dynamic>(startupHiveBox);

    // Run the remaining init concurrently while the splash is visible.
    final secureStorage = SecureStorage();
    final sharedPreferencesFuture = SharedPreferences.getInstance();
    await Future.wait<void>(<Future<void>>[
      secureStorage.preloadSessionState(),
      openChildModeBoxes(),
    ]);
    final sharedPreferences = await sharedPreferencesFuture;

    // One-time purge of content cached by older builds (which could replay
    // stale/mojibake content from local storage). Must run before any cache
    // reads so the app refetches fresh data from the server.
    await AppCacheStore.migrate(sharedPreferences);

    return _BootstrapResult(
      secureStorage: secureStorage,
      sharedPreferences: sharedPreferences,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return const _BootstrapSplash();
        }
        final result = snapshot.requireData;
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider
                .overrideWithValue(result.sharedPreferences),
            secureStorageProvider.overrideWithValue(result.secureStorage),
            loggerProvider.overrideWithValue(widget.logger),
          ],
          child: const KinderWorldApp(),
        );
      },
    );
  }
}

class _BootstrapResult {
  const _BootstrapResult({
    required this.secureStorage,
    required this.sharedPreferences,
  });

  final SecureStorage secureStorage;
  final SharedPreferences sharedPreferences;
}

/// Minimal, provider-free first frame: centered app logo on the brand
/// background. Shown only while [AppBootstrap] finishes async init.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFF0F4FF),
        body: Center(
          child: Image(
            image: AssetImage('assets/icons/kinderworld-logo.png'),
            width: 160,
            height: 160,
          ),
        ),
      ),
    );
  }
}
