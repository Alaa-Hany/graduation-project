import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:kinder_world/features/parent_mode/auth/parent_pin_screen.dart';
import 'package:kinder_world/features/parent_mode/child_management/child_management_screen.dart';
import 'package:kinder_world/features/parent_mode/child_management/parent_child_profile_screen.dart';
import 'package:kinder_world/features/parent_mode/controls/parental_controls_screen.dart';
import 'package:kinder_world/features/parent_mode/dashboard/parent_dashboard_screen.dart';
import 'package:kinder_world/features/parent_mode/notifications/parent_notifications_screen.dart';
import 'package:kinder_world/features/parent_mode/reports/reports_screen.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/parent_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/about_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/accessibility_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/change_password_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/contact_us_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/help_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/language_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/legal_pages.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/privacy_settings_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/profile_screen.dart';
import 'package:kinder_world/features/parent_mode/settings/screens/theme_screen.dart';
import 'package:kinder_world/features/parent_mode/subscription/billing_management_screen.dart';
import 'package:kinder_world/features/parent_mode/subscription/subscription_screen.dart';
import 'package:kinder_world/features/system_pages/data_sync_screen.dart';
import 'package:kinder_world/features/system_pages/error_screen.dart';
import 'package:kinder_world/core/subscription/subscription_return.dart';

import 'route_paths.dart';

Widget _buildParentChildProfileRoute(
    BuildContext context, GoRouterState state) {
  final extra = state.extra;
  ChildProfile? child;
  if (extra is ChildProfile) {
    child = extra;
  } else if (extra is Map) {
    try {
      child = ChildProfile.fromJson(Map<String, dynamic>.from(extra));
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

List<RouteBase> buildParentRoutes() {
  return [
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
      builder: (context, state) {
        final payload =
            SubscriptionReturnPayload.fromQuery(state.uri.queryParameters);
        return SubscriptionScreen(returnPayload: payload);
      },
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
  ];
}
