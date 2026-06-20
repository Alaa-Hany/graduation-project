import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kinder_world/core/providers/shared_preferences_provider.dart';
import 'package:kinder_world/core/storage/hive_boxes.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/app.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  late final Future<_BootstrapResult> _bootstrap = _initial