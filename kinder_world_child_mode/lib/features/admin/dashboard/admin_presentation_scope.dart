import 'package:kinder_world/router.dart';

const Set<String> adminPresentationMenuRoutes = {
  Routes.adminDashboard,
  Routes.adminUsers,
  Routes.adminChildren,
  Routes.adminSupport,
  Routes.adminAudit,
};

const Set<String> adminPresentationHiddenRoutes = {
  Routes.adminContent,
  Routes.adminReports,
  Routes.adminSubscriptions,
  Routes.adminAdmins,
  Routes.adminSettings,
};

bool isAdminPresentationRoute(String? route) {
  if (route == null || route.isEmpty) {
    return false;
  }
  if (adminPresentationMenuRoutes.contains(route)) {
    return true;
  }
  if (adminPresentationHiddenRoutes.contains(route)) {
    return true;
  }
  return route.startsWith('${Routes.adminUsers}/') ||
      route.startsWith('${Routes.adminChildren}/');
}
