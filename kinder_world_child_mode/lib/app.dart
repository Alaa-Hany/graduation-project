import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kinder_world/core/localization/app_localizations.dart'
    as custom_localizations;
import 'package:kinder_world/core/theme/app_theme.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/providers/connectivity_provider.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/router.dart';
import 'package:logger/logger.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';

// Providers
final secureStorageProvider = Provider<SecureStorage>((ref) {
  throw UnimplementedError('secureStorageProvider must be overridden');
});

final loggerProvider = Provider<Logger>((ref) {
  throw UnimplementedError('loggerProvider must be overridden');
});

final networkServiceProvider = Provider<NetworkService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final logger = ref.watch(loggerProvider);
  return NetworkService(
    secureStorage: secureStorage,
    logger: logger,
  );
});

class KinderWorldApp extends ConsumerStatefulWidget {
  const KinderWorldApp({super.key});

  @override
  ConsumerState<KinderWorldApp> createState() => _KinderWorldAppState();
}

class _KinderWorldAppState extends ConsumerState<KinderWorldApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(localeProvider.notifier).loadSavedLocale();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeSettings = ref.watch(themeControllerProvider);
    final palette = ref.watch(themePaletteProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          custom_localizations.AppLocalizations.of(context)?.appTitle ??
          'Kinder World',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(palette: palette),
      darkTheme: AppTheme.darkTheme(palette: palette),
      themeMode: themeSettings.mode,
      localizationsDelegates: const [
        custom_localizations.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      locale: locale,
      routerConfig: ref.watch(routerProvider),

      // Builder for app-level configurations
      builder: (context, child) {
        // Force text direction based on locale
        final isRTL = locale.languageCode == 'ar';

        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: _ConnectivityGuard(child: child!),
        );
      },
    );
  }
}

class _ConnectivityGuard extends ConsumerStatefulWidget {
  const _ConnectivityGuard({required this.child});

  final Widget child;

  @override
  ConsumerState<_ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends ConsumerState<_ConnectivityGuard> {
  String? _lastLocation;
  bool _isOffline = false;
  late final ProviderSubscription<AsyncValue<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<ConnectivityResult>>(
      connectivityProvider,
      (previous, next) {
      final result = next.asData?.value;
      if (result == null) return;

      final router = GoRouter.of(context);
      final location = router.routerDelegate.currentConfiguration.uri.toString();
      final onNoInternet = location == Routes.noInternet;
      final isOffline = result == ConnectivityResult.none;

      if (isOffline && !_isOffline) {
        _isOffline = true;
        if (!onNoInternet) {
          _lastLocation = location;
          router.go(Routes.noInternet);
        }
        return;
      }

      if (!isOffline && _isOffline) {
        _isOffline = false;
        if (onNoInternet) {
          router.go(_lastLocation ?? Routes.welcome);
        }
      }
      },
    );
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
