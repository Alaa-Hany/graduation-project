class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Kinder World';
  static const String appVersion = '1.0.0';
  
  // API
  // Override at build time:
  //   flutter run  --dart-define=API_BASE_URL=http://<HOST>:8000
  //   flutter build apk --dart-define=API_BASE_URL=http://<HOST>:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const Duration apiTimeout = Duration(seconds: 60);
  
  // Storage
  static const String hiveBoxName = 'kinder_world_box';
  static const String secureStorageKey = 'kinder_world_secure';
  
  // Performance Targets
  static const Duration startupTime = Duration(seconds: 3);
  static const Duration contentLoadTime = Duration(seconds: 2);
  static const Duration aiResponseTime = Duration(milliseconds: 1500);
  static const int maxMemoryUsage = 200; // MB
  
  // Child-Friendly UI
  static const double minTouchTarget = 48.0;
  static const double iconSize = 32.0;
  static const double largeIconSize = 48.0;
  static const double fontSize = 18.0;
  static const double largeFontSize = 24.0;
  
  // Screen Time Defaults
  static const int defaultDailyLimit = 120; // minutes
  static const int breakInterval = 30; // minutes
  static const int breakDuration = 5; // minutes
  
  // Content
  static const int maxContentAge = 12;
  static const int minContentAge = 5;
  
  // Avatar defaults
  static const String defaultChildAvatar = 'assets/images/avatars/av1.png';
  
  // Subscription
  static const int freeTrialDays = 14;
  static const int maxChildProfiles = 1;
}
