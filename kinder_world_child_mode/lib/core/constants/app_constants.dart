import 'package:flutter/foundation.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;

  static const double pagePadding = 20.0;
  static const double sectionGap = 24.0;
  static const double cardGap = 12.0;
  static const double cardPadding = 18.0;
}

class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  static const double card = 16.0;
  static const double button = 14.0;
  static const double input = 12.0;
  static const double icon = 10.0;
  static const double chip = 8.0;
  static const double badge = 6.0;
}

class AppConstants {
  AppConstants._();

  static const String appName = 'Kinder World';
  static const String appVersion = '1.0.0';

  // Override at build time:
  // flutter run --dart-define=API_BASE_URL=http://<HOST>:8000
  // flutter build apk --dart-define=API_BASE_URL=http://<HOST>:8000
  // Optional environment routing:
  // --dart-define=APP_ENV=development|staging|production
  // --dart-define=DEV_API_BASE_URL=http://127.0.0.1:8000
  // --dart-define=STAGING_API_BASE_URL=https://staging.example.com
  // --dart-define=PROD_API_BASE_URL=https://api.example.com
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const String _developmentBaseUrlOverride = String.fromEnvironment(
    'DEV_API_BASE_URL',
    defaultValue: '',
  );
  static const String _stagingBaseUrl = String.fromEnvironment(
    'STAGING_API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionBaseUrl = String.fromEnvironment(
    'PROD_API_BASE_URL',
    defaultValue: '',
  );

  static final String baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }

    switch (_appEnv) {
      case 'production':
      case 'prod':
        return _requiredBaseUrl(
          value: _productionBaseUrl,
          defineName: 'PROD_API_BASE_URL',
        );
      case 'staging':
        return _requiredBaseUrl(
          value: _stagingBaseUrl,
          defineName: 'STAGING_API_BASE_URL',
        );
      case 'test':
      case 'development':
      case 'dev':
      default:
        return _developmentBaseUrl;
    }
  }

  static String get _developmentBaseUrl {
    if (_developmentBaseUrlOverride.isNotEmpty) {
      return _developmentBaseUrlOverride;
    }

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return 'http://$host:8000';
    }

    return 'http://192.168.42.128:8000';
  }

  static String _requiredBaseUrl({
    required String value,
    required String defineName,
  }) {
    if (value.isNotEmpty) {
      return value;
    }
    throw StateError(
      'Missing API base URL. Provide --dart-define=$defineName=<URL> or '
      '--dart-define=API_BASE_URL=<URL>.',
    );
  }

  static const Duration apiTimeout = Duration(seconds: 60);

  static const String hiveBoxName = 'kinder_world_box';
  static const String secureStorageKey = 'kinder_world_secure';

  static const Duration startupTime = Duration(seconds: 3);
  static const Duration contentLoadTime = Duration(seconds: 2);
  static const Duration aiResponseTime = Duration(milliseconds: 1500);
  static const int maxMemoryUsage = 200;

  static const double minTouchTarget = 48.0;
  static const double iconSize = 32.0;
  static const double largeIconSize = 48.0;
  static const double fontSize = 18.0;
  static const double largeFontSize = 24.0;

  static const int defaultDailyLimit = 120;
  static const int breakInterval = 30;
  static const int breakDuration = 5;

  static const int maxContentAge = 12;
  static const int minContentAge = 5;

  static const String defaultChildAvatar = 'assets/images/avatars/av1.png';

  static const int freeTrialDays = 14;
  static const int maxChildProfiles = 1;
}
