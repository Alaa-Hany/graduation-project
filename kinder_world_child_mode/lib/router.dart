import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';

import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_login_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:kinder_world/features/admin/shared/admin_access_denied_screen.dart';

import 'package:kinder_world/features/app_core/splash_screen.dart';
import 'package:kinder_world/features/app_core/language_selection_screen.dart';
import 'package:kinder_world/features/app_core/onboarding_screen.dart';
import 'package:kinder_world/features/app_core/welcome_screen.dart';

import 'package:kinder_world/features/auth/user_type_selection_screen.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/features/auth/parent_login_screen.dart';
import 'package:kinder_world/features/auth/parent_register_screen.dart';
import 'package:kinder_world/features/auth/parent_forgot_password_screen.dart';
import 'package:kinder_world/features/auth/child_login_screen.dart';
import 'package:kinder_world/features/auth/child_forgot_password_screen.dart';

import 'package:kinder_world/features/child_mode/home/child_home_screen.dart';
import 'package:kinder_world/features/child_mode/home/activity_of_the_day_screen.dart';
import 'package:kinder_world/features/child_mode/learn/learn_screen.dart';
import 'package:kinder_world/features/child_mode/learn/subject_screen.dart';
import 'package:kinder_world/features/child_mode/learn/lesson_flow_screen.dart';
import 'package:kinder_world/features/child_mode/play/play_screen.dart';
import 'package:kinder_world/features/child_mode/play/category_screen.dart';
import 'package:kinder_world/features/child_mode/ai_buddy/ai_buddy_screen.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_overview_screen.dart';
import 'package:kinder_world/features/child_mode/profile/achievements_screen.dart';
import 'package:kinder_world/features/child_mode/store/reward_store_screen.dart';

import 'package:kinder_world/features/parent_mode/dashboard/parent_dashboard_screen.dart';
import 'package:kinder_world/features/parent_mode/child_management/child_management_screen.dart';
import 'package:kinder_world/features/parent_mode/child_management/parent_child_profile_screen.dart';
import 'package:kinder_world/features/parent_mode/reports/reports_screen.dart';
import 'package:kinder_world/features/parent_mode/controls/parental_controls_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/parent_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/profile_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/change_password_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/theme_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/language_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/privacy_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/accessibility_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/auth/parent_pin_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/help_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/contact_us_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/about_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/legal_pages.dart';
import 'package:kinder_world/features/parent_mode/subscription/subscription_screen.dart';
import 'package:kinder_world/features/parent_mode/subscription/billing_management_screen.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notifications_screen.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_screen.dart';
import 'package:kinder_world/core/models/child_profile.dart';

import 'package:kinder_world/features/system_pages/no_internet_screen.dart';
import 'package:kinder_world/features/system_pages/help_support_screen.dart';
import 'package:kinder_world/features/system_pages/legal_screen.dart';
import 'package:kinder_world/features/system_pages/data_sync_screen.dart';
import 'package:kinder_world/features/system_pages/error_screen.dart';
import 'package:kinder_world/features/system_pages/maintenance_screen.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

// ========= Route Paths (keep as consts here to avoid scattering strings) =========
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
  static const parentForgotPassword = '/parent/forgot-password';
  static const childLogin = '/child/login';
  static const childForgotPassword = '/child/forgot-password';

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
  static const parentBilling = '/parent/billing';
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

bool _isPublicRoute(String path) {
  return path == Routes.splash ||
      path == Routes.language ||
      path == Routes.onboarding ||
      path == Routes.welcome ||
      path == Routes.selectUserType ||
      path == Routes.parentForgotPassword ||
      path == Routes.childForgotPassword ||
      path == Routes.error ||
      path == Routes.noInternet ||
      path == Routes.maintenance;
}

bool _isAdminRoute(String path) => path.startsWith('/admin/');

String? _requiredAdminPermissionForPath(String path) {
  if (path == Routes.adminUsers || path.startsWith('${Routes.adminUsers}/')) {
    return 'admin.users.view';
  }
  if (path == Routes.adminChildren ||
      path.startsWith('${Routes.adminChildren}/')) {
    return 'admin.children.view';
  }
  if (path == Routes.adminContent) return 'admin.content.view';
  if (path == Routes.adminReports) return 'admin.analytics.view';
  if (path == Routes.adminSupport) return 'admin.support.view';
  if (path == Routes.adminSubscriptions) return 'admin.subscription.view';
  if (path == Routes.adminAdmins) return 'admin.admins.manage';
  if (path == Routes.adminAudit) return 'admin.audit.view';
  if (path == Routes.adminSettings) return 'admin.settings.edit';
  return null;
}

bool _isParentAuthRoute(String path) {
  return path == Routes.parentLogin || path == Routes.parentRegister;
}

bool _isAnyChildRoute(String path) => path.startsWith('/child/');
bool _isAnyParentRoute(String path) => path.startsWith('/parent/');
bool _isParentPinProtectedRoute(String path) {
  return _isAnyParentRoute(path) &&
      path != Routes.parentPin &&
      !_isParentAuthRoute(path) &&
      path != Routes.parentForgotPassword;
}

Widget _buildParentChildProfileRoute(
    BuildContext context, GoRouterState state) {
  final extra = state.extra;
  ChildProfile? child;
  if (extra is ChildProfile) {
    child = extra;
  } else if (extra is Map) {
    try {
      child = ChildProfile.fromJson(
        Map<String, dynamic>.from(extra),
      );
    } catch (_) {
      child = null;
    }
  }

  final childId = state.pathParameters['childId'] ?? child?.id;
  if (childId == null || childId.isEmpty) {
    return ErrorScreen(
      error: AppLocalizations.of(context)!.childProfileNotFound,
    );
  }

  return ParentChildProfileScreen(
    key: ValueKey('parent-child-profile-$childId'),
    childId: childId,
    initialChild: child,
  );
}

class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this.ref) {
    _subscription = ref.listen<AdminAuthState>(
      adminAuthProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref ref;
  late final ProviderSubscription<AdminAuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  final logger = ref.read(loggerProvider);
  final refreshListenable = _RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,

    // Important: keep redirect logic strict + stable to avoid loops.
    redirect: (context, state) async {
      final path = state.uri.path;
      final adminAuthState = ref.read(adminAuthProvider);

      // Always allow public/system routes
      if (_isPublicRoute(path)) return null;

      // ── Admin route guard ──────────────────────────────────────────────
      if (_isAdminRoute(path)) {
        if (adminAuthState.status == AdminAuthStatus.initial ||
            adminAuthState.status == AdminAuthStatus.loading) {
          return null;
        }
        if (path == Routes.adminLogin) {
          return adminAuthState.isAuthenticated ? Routes.adminDashboard : null;
        }
        if (path == Routes.adminAccessDenied) return null;

        if (!adminAuthState.isAuthenticated) {
          return Routes.adminLogin;
        }
        final requiredPermission = _requiredAdminPermissionForPath(path);
        if (requiredPermission != null &&
            !(adminAuthState.admin?.hasPermission(requiredPermission) ??
                false)) {
          return Routes.adminAccessDenied;
        }
        return null;
      }

      late final SecureSessionSnapshot resolvedSession;
      if (secureStorage.hasCachedSessionSnapshot) {
        resolvedSession = secureStorage.cachedSessionSnapshot;
      } else {
        final results = await Future.wait<String?>([
          secureStorage.getAuthToken(),
          secureStorage.getUserRole(),
          secureStorage.getChildSession(),
        ]);
        final parentPinVerified = await secureStorage.isParentPinVerified();
        resolvedSession = SecureSessionSnapshot(
          authToken: results[0],
          userRole: results[1],
          childSession: results[2],
          parentPinVerified: parentPinVerified,
        );
      }
      final authToken = resolvedSession.authToken;
      final userRole = resolvedSession.userRole;
      final childSession = resolvedSession.childSession;

      // Debugging logs to diagnose navigation issues
      if (kDebugMode) {
        logger.d(
          'Router redirect check -> path: $path | auth: ${authToken != null} | role: $userRole | childSession: $childSession',
        );
      }

      final isAuthenticated = resolvedSession.isAuthenticated;

      // If not authenticated -> go to welcome (unless already on auth pages)
      if (!isAuthenticated) {
        // allow reaching parent login/register + child login, and select-user-type
        if (_isParentAuthRoute(path) ||
            path == Routes.childLogin ||
            path == Routes.selectUserType ||
            path == Routes.parentForgotPassword ||
            path == Routes.childForgotPassword) {
          return null;
        }
        return Routes.welcome;
      }

      // Authenticated but role missing -> force select user type
      if (userRole == null || userRole.isEmpty) {
        if (path != Routes.selectUserType) return Routes.selectUserType;
        return null;
      }

      // Prevent authenticated users from staying on login/register screens
      if (_isParentAuthRoute(path)) {
        if (userRole == 'parent') {
          return Routes.parentDashboard;
        }
        if (userRole == 'child') {
          return childSession == null ? Routes.childLogin : Routes.childHome;
        }
      }

      // Role-based protection
      if (userRole == 'parent') {
        // Block child area
        if (_isAnyChildRoute(path)) return Routes.parentDashboard;
        if (path == Routes.parentPin) return null;
        if (_isParentPinProtectedRoute(path)) {
          if (!resolvedSession.parentPinVerified) {
            final redirectTarget = Uri.encodeComponent(path);
            return '${Routes.parentPin}?redirect=$redirectTarget';
          }
        }
        // Parent can access /parent/* freely
        if (_isAnyParentRoute(path)) return null;
        // Unknown route outside parent scope -> go dashboard
        return Routes.parentDashboard;
      }

      if (userRole == 'child') {
        // Child must have a session to enter child shell tabs
        if (childSession == null) {
          // Allow only child login (and public)
          if (path != Routes.childLogin) return Routes.childLogin;
          return null;
        }

        // If child tries to access parent area -> bounce to child home
        if (_isAnyParentRoute(path)) return Routes.childHome;

        // If child is authenticated+session exists, but path is not under /child/*, send to child home
        if (!_isAnyChildRoute(path)) return Routes.childHome;

        // Otherwise allow the child route (including /child/play, /child/learn, etc.)
        return null;
      }

      // Unknown role fallback
      return Routes.selectUserType;
    },

    routes: [
      // App Core Routes
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.language,
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: Routes.selectUserType,
        builder: (context, state) => const UserTypeSelectionScreen(),
      ),
      GoRoute(
        path: Routes.parentLogin,
        builder: (context, state) => const ParentLoginScreen(),
      ),
      GoRoute(
        path: Routes.parentRegister,
        builder: (context, state) => const ParentRegisterScreen(),
      ),
      GoRoute(
        path: Routes.parentForgotPassword,
        builder: (context, state) => const ParentForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.childLogin,
        builder: (context, state) => const ChildLoginScreen(),
      ),
      GoRoute(
        path: Routes.childForgotPassword,
        builder: (context, state) => const ChildForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.childAchievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: Routes.childStore,
        builder: (context, state) => const RewardStoreScreen(),
      ),

      // Child Mode Routes with Bottom Navigation (Shell)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Shell scaffold (bottom nav) must live here
          return ChildHomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.childHome,
                builder: (context, state) => const ChildHomeContent(),
                routes: [
                  GoRoute(
                    path: 'activity-of-day',
                    builder: (context, state) => const ActivityOfTheDayScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.childLearn,
                builder: (context, state) => const LearnScreen(),
                routes: [
                  GoRoute(
                    path: 'subject/:subject',
                    builder: (context, state) {
                      final subject = state.pathParameters['subject']!;
                      return SubjectScreen(subject: subject);
                    },
                  ),
                  GoRoute(
                    path: 'lesson/:lessonId',
                    builder: (context, state) {
                      final lessonId = state.pathParameters['lessonId']!;
                      return LessonFlowScreen(lessonId: lessonId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.childPlay,
                builder: (context, state) => const PlayScreen(),
                routes: [
                  GoRoute(
                    path: 'category/:category',
                    builder: (context, state) {
                      final category = state.pathParameters['category']!;
                      return CategoryScreen(category: category);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.childAiBuddy,
                builder: (context, state) => const AiBuddyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.childProfile,
                builder: (context, state) =>
                    const ChildProfileOverviewScreen(),
              ),
            ],
          ),
        ],
      ),

      // Parent Mode Routes
      GoRoute(
        path: Routes.parentDashboard,
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: Routes.parentPin,
        builder: (context, state) => ParentPinScreen(
          redirectPath: state.uri.queryParameters['redirect'],
          mode: ParentPinFlowMode.values.firstWhere(
            (value) => value.name == state.uri.queryParameters['mode'],
            orElse: () => ParentPinFlowMode.auto,
          ),
        ),
      ),
      GoRoute(
        path: Routes.parentChildManagement,
        builder: (context, state) => const ChildManagementScreen(),
      ),
      GoRoute(
        path: Routes.parentChildProfile,
        builder: _buildParentChildProfileRoute,
      ),
      GoRoute(
        path: '${Routes.parentChildProfile}/:childId',
        builder: _buildParentChildProfileRoute,
      ),
      GoRoute(
        path: Routes.parentReports,
        builder: (context, state) {
          final initialChildId = state.extra as String?;
          return ReportsScreen(initialChildId: initialChildId);
        },
      ),
      GoRoute(
        path: Routes.parentControls,
        builder: (context, state) => const ParentalControlsScreen(),
      ),
      GoRoute(
        path: Routes.parentSettings,
        builder: (context, state) => const ParentSettingsScreen(),
      ),
      GoRoute(
        path: Routes.parentProfile,
        builder: (context, state) => const ParentProfileScreen(),
      ),
      GoRoute(
        path: Routes.parentChangePassword,
        builder: (context, state) => const ParentChangePasswordScreen(),
      ),
      GoRoute(
        path: Routes.parentTheme,
        builder: (context, state) => const ParentThemeScreen(),
      ),
      GoRoute(
        path: Routes.parentLanguage,
        builder: (context, state) => const ParentLanguageScreen(),
      ),
      GoRoute(
        path: Routes.parentPrivacySettings,
        builder: (context, state) => const ParentPrivacySettingsScreen(),
      ),
      GoRoute(
        path: Routes.parentHelp,
        builder: (context, state) => const ParentHelpScreen(),
      ),
      GoRoute(
        path: Routes.parentContactUs,
        builder: (context, state) => const ParentContactUsScreen(),
      ),
      GoRoute(
        path: Routes.parentAbout,
        builder: (context, state) => const ParentAboutScreen(),
      ),
      GoRoute(
        path: Routes.parentAccessibility,
        builder: (context, state) => const AccessibilitySettingsScreen(),
      ),
      GoRoute(
        path: Routes.parentTerms,
        builder: (context, state) => const ParentTermsScreen(),
      ),
      GoRoute(
        path: Routes.parentPrivacyPolicy,
        builder: (context, state) => const ParentPrivacyPolicyScreen(),
      ),
      GoRoute(
        path: Routes.parentCoppa,
        builder: (context, state) => const ParentCoppaScreen(),
      ),
      GoRoute(
        path: Routes.parentSubscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: Routes.parentBilling,
        builder: (context, state) => const BillingManagementScreen(),
      ),
      GoRoute(
        path: Routes.parentNotifications,
        builder: (context, state) => const ParentNotificationsScreen(),
      ),
      GoRoute(
        path: Routes.parentSafetyDashboard,
        builder: (context, state) => const SafetyDashboardScreen(),
      ),
      GoRoute(
        path: Routes.parentDataSync,
        builder: (context, state) => const DataSyncScreen(),
      ),

      // ── Admin Routes ────────────────────────────────────────────────────
      GoRoute(
        path: Routes.adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: Routes.adminDashboard,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminDashboard),
      ),
      GoRoute(
        path: Routes.adminUsers,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminUsers),
      ),
      GoRoute(
        path: '${Routes.adminUsers}/:userId',
        builder: (context, state) => AdminDashboardScreen(
          activePath: '${Routes.adminUsers}/${state.pathParameters['userId']}',
        ),
      ),
      GoRoute(
        path: Routes.adminChildren,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminChildren),
      ),
      GoRoute(
        path: '${Routes.adminChildren}/:childId',
        builder: (context, state) => AdminDashboardScreen(
          activePath:
              '${Routes.adminChildren}/${state.pathParameters['childId']}',
        ),
      ),
      GoRoute(
        path: Routes.adminContent,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminContent),
      ),
      GoRoute(
        path: Routes.adminReports,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminReports),
      ),
      GoRoute(
        path: Routes.adminSupport,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminSupport),
      ),
      GoRoute(
        path: Routes.adminSubscriptions,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminSubscriptions),
      ),
      GoRoute(
        path: Routes.adminAdmins,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminAdmins),
      ),
      GoRoute(
        path: Routes.adminAudit,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminAudit),
      ),
      GoRoute(
        path: Routes.adminSettings,
        builder: (context, state) =>
            const AdminDashboardScreen(activePath: Routes.adminSettings),
      ),
      GoRoute(
        path: Routes.adminAccessDenied,
        builder: (context, state) => const AdminAccessDeniedScreen(),
      ),

      // System Pages
      GoRoute(
        path: Routes.noInternet,
        builder: (context, state) => const NoInternetScreen(),
      ),
      GoRoute(
        path: Routes.error,
        builder: (context, state) => ErrorScreen(
          error: state.extra as String? ??
              AppLocalizations.of(context)!.unexpectedError,
        ),
      ),
      GoRoute(
        path: Routes.maintenance,
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: Routes.help,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: Routes.legal,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'terms';
          return LegalScreen(type: type);
        },
      ),
    ],

    errorBuilder: (context, state) => ErrorScreen(
      error:
          state.error?.toString() ?? AppLocalizations.of(context)!.pageNotFound,
    ),
  );
});
