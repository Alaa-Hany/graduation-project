import 'package:go_router/go_router.dart';

import 'package:kinder_world/features/admin/auth/admin_login_screen.dart';
import 'package:kinder_world/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:kinder_world/features/admin/shared/admin_access_denied_screen.dart';

import 'route_paths.dart';

List<RouteBase> buildAdminRoutes() {
  return [
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
  ];
}
