import 'package:go_router/go_router.dart';

import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/app_core/language_selection_screen.dart';
import 'package:kinder_world/features/app_core/onboarding_screen.dart';
import 'package:kinder_world/features/app_core/splash_screen.dart';
import 'package:kinder_world/features/app_core/welcome_screen.dart';
import 'package:kinder_world/features/auth/child_forgot_password_screen.dart';
import 'package:kinder_world/features/auth/child_login_screen.dart';
import 'package:kinder_world/features/auth/parent_forgot_password_screen.dart';
import 'package:kinder_world/features/auth/parent_login_screen.dart';
import 'package:kinder_world/features/auth/parent_register_screen.dart';
import 'package:kinder_world/features/auth/parent_verify_email_screen.dart';
import 'package:kinder_world/features/auth/user_type_selection_screen.dart';
import 'package:kinder_world/features/child_mode/profile/achievements_screen.dart';
import 'package:kinder_world/features/child_mode/store/reward_store_screen.dart';
import 'package:kinder_world/features/system_pages/error_screen.dart';
import 'package:kinder_world/features/system_pages/help_support_screen.dart';
import 'package:kinder_world/features/system_pages/legal_screen.dart';
import 'package:kinder_world/features/system_pages/maintenance_screen.dart';
import 'package:kinder_world/features/system_pages/no_internet_screen.dart';

import 'route_paths.dart';

List<RouteBase> buildPublicRoutes() {
  return [
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
      path: Routes.parentVerifyEmail,
      builder: (context, state) {
        final extra = state.extra;
        final email =
            extra is Map<String, dynamic> ? extra['email']?.toString() : null;
        return ParentVerifyEmailScreen(initialEmail: email);
      },
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
  ];
}
