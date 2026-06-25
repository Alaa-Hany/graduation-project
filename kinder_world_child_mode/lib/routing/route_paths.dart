class Routes {
  // App core
  static const splash = '/splash';
  static const language = '/language';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';

  // Auth
  static const selectUserType = '/select-user-type';
  static const parentLogin = '/parent/login';
  static const parentRegister = '/parent/register';
  static const parentVerifyEmail = '/parent/verify-email';
  static const parentForgotPassword = '/parent/forgot-password';
  static const parentResetPassword = '/parent/reset-password';
  static const childLogin = '/child/login';
  static const childForgotPassword = '/child/forgot-password';
  static const parentResetChildPassword = '/parent/reset-child-password';

  // Child shell tabs
  static const childHome = '/child/home';
  static const childLearn = '/child/learn';
  static const childPlay = '/child/play';
  static const childAiBuddy = '/child/ai-buddy';
  static const childProfile = '/child/profile';
  static const childAchievements = '/child/achievements';
  static const childStore = '/child/store';
  static const childActivityOfDay = '/child/home/activity-of-day';

  // Parent
  static const parentDashboard = '/parent/dashboard';
  static const parentPin = '/parent/pin';
  static const parentChildManagement = '/parent/child-management';
  static const parentChildProfile = '/parent/child-profile';
  static String parentChildProfileById(String childId) =>
      '$parentChildProfile/${Uri.encodeComponent(childId)}';
  static const parentReports = '/parent/reports';
  static const parentControls = '/parent/controls';
  static const parentSettings = '/parent/settings';
  static const parentSubscription = '/parent/subscription';
  static const parentNotifications = '/parent/notifications';
  static const parentSafetyDashboard = '/parent/safety-dashboard';
  static const parentDataSync = '/parent/data-sync';

  // Parent Settings sub-routes
  static const parentProfile = '/parent/profile';
  static const parentChangePassword = '/parent/change-password';
  static const parentTheme = '/parent/theme';
  static const parentLanguage = '/parent/language';
  static const parentPrivacySettings = '/parent/privacy-settings';
  static const parentHelp = '/parent/help';
  static const parentContactUs = '/parent/contact-us';
  static const parentAbout = '/parent/about';
  static const parentAccessibility = '/parent/accessibility';
  static const parentTerms = '/parent/legal/terms';
  static const parentPrivacyPolicy = '/parent/legal/privacy';
  static const parentCoppa = '/parent/legal/coppa';

  // Admin
  static const adminLogin = '/admin/login';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminChildren = '/admin/children';
  static const adminContent = '/admin/content';
  static const adminReports = '/admin/reports';
  static const adminSupport = '/admin/support';
  static const adminSubscriptions = '/admin/subscriptions';
  static const adminAdmins = '/admin/admins';
  static const adminAudit = '/admin/audit';
  static const adminSettings = '/admin/settings';
  static const adminAccessDenied = '/admin/access-denied';

  // System
  static const noInternet = '/no-internet';
  static const error = '/error';
  static const maintenance = '/maintenance';
  static const help = '/help';
  static const legal = '/legal';
}
