import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/maintenance_mode_provider.dart';
import 'package:kinder_world/core/providers/parent_pin_provider.dart';
import 'package:logger/logger.dart';

import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';

import 'route_paths.dart';

bool isPublicRoute(String path) {
  return path == Routes.splash ||
      path == Routes.language ||
      path == Routes.onboarding ||
      path == Routes.welcome ||
      path == Routes.selectUserType ||
      path == Routes.parentForgotPassword ||
      path == Routes.parentResetPassword ||
      path == Routes.childForgotPassword ||
      path == Routes.error ||
      path == Routes.noInternet ||
      path == Routes.maintenance;
}

bool isAdminRoute(String path) => path.startsWith('/admin/');

String? requiredAdminPermissionForPath(String path) {
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

bool isParentAuthRoute(String path) {
  return path == Routes.parentLogin ||
      path == Routes.parentRegister ||
      path == Routes.parentVerifyEmail;
}

bool isAnyChildRoute(String path) => path.startsWith('/child/');
bool isAnyParentRoute(String path) => path.startsWith('/parent/');
bool isParentPinProtectedRoute(String path) {
  return isAnyParentRoute(path) &&
      path != Routes.parentPin &&
      !isParentAuthRoute(path) &&
      path != Routes.parentForgotPassword;
}

/// Tracks whether the first router redirect of this app launch has run yet.
///
/// Created once per [routerProvider], so it resets on a fresh app launch — and
/// crucially on a web page refresh, since that recreates the whole app. Used to
/// detect when the app's entry URL points straight into a saved parent/child
/// session (e.g. refreshing the page while on `/parent/dashboard`) so we can
/// send the user back to the user-type chooser instead of silently resuming.
class AppLaunchRedirectGuard {
  bool firstRedirectHandled = false;
}

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(this.ref) {
    _adminSubscription = ref.listen<AdminAuthState>(
      adminAuthProvider,
      (_, __) => notifyListeners(),
    );
    _authSubscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
    _parentPinSubscription = ref.listen<ParentPinState>(
      parentPinProvider,
      (_, __) => notifyListeners(),
    );
    _maintenanceSubscription = ref.listen<bool>(
      maintenanceModeProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref ref;
  late final ProviderSubscription<AdminAuthState> _adminSubscription;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<ParentPinState> _parentPinSubscription;
  late final ProviderSubscription<bool> _maintenanceSubscription;

  @override
  void dispose() {
    _adminSubscription.close();
    _authSubscription.close();
    _parentPinSubscription.close();
    _maintenanceSubscription.close();
    super.dispose();
  }
}

Future<String?> appRedirect({
  required Ref ref,
  required SecureStorage secureStorage,
  required Logger logger,
  required GoRouterState state,
  required AppLaunchRedirectGuard launchGuard,
}) async {
  final path = state.uri.path;

  // On the web, a page refresh restores the deep-linked URL and recreates the
  // app. If the entry URL points straight into a saved parent/child session
  // (e.g. `/parent/dashboard` or `/child/home`), resume that mode directly so
  // the user lands back where they were instead of being bounced to the
  // user-type chooser. The normal session-based redirect logic below still
  // applies (e.g. parent routes remain PIN-protected), so this only skips the
  // explicit re-selection step. The launch guard is retained for any future
  // first-redirect needs but no longer forces a chooser detour.
  launchGuard.firstRedirectHandled = true;

  final adminAuthState = ref.read(adminAuthProvider);
  final isMaintenanceMode = ref.read(maintenanceModeProvider);

  if (isMaintenanceMode && !isAdminRoute(path) && path != Routes.maintenance) {
    return Routes.maintenance;
  }

  if (isPublicRoute(path)) return null;

  if (isAdminRoute(path)) {
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
    final requiredPermission = requiredAdminPermissionForPath(path);
    if (requiredPermission != null &&
        !(adminAuthState.admin?.hasPermission(requiredPermission) ?? false)) {
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

  if (kDebugMode) {
    logger.d(
      'Router redirect check -> path: $path | auth: ${authToken != null} | role: $userRole | childSession: $childSession',
    );
  }

  final isAuthenticated = resolvedSession.isAuthenticated;

  if (!isAuthenticated) {
    if (isParentAuthRoute(path) ||
        path == Routes.childLogin ||
        path == Routes.selectUserType ||
        path == Routes.parentForgotPassword ||
        path == Routes.parentResetPassword ||
        path == Routes.childForgotPassword) {
      return null;
    }
    return Routes.welcome;
  }

  if (userRole == null || userRole.isEmpty) {
    if (path != Routes.selectUserType) return Routes.selectUserType;
    return null;
  }

  if (isParentAuthRoute(path)) {
    if (userRole == 'parent') return Routes.parentDashboard;
    if (userRole == 'child') {
      return childSession == null ? Routes.childLogin : Routes.childHome;
    }
  }

  if (userRole == 'parent') {
    if (isAnyChildRoute(path)) return Routes.parentDashboard;
    if (path == Routes.parentPin) return null;
    if (isParentPinProtectedRoute(path) && !resolvedSession.parentPinVerified) {
      final redirectTarget = Uri.encodeComponent(path);
      return '${Routes.parentPin}?redirect=$redirectTarget';
    }
    if (isAnyParentRoute(path)) return null;
    return Routes.parentDashboard;
  }

  if (userRole == 'child') {
    if (childSession == null) {
      if (path != Routes.childLogin) return Routes.childLogin;
      return null;
    }
    if (isAnyParentRoute(path)) return Routes.childHome;
    if (!isAnyChildRoute(path)) return Routes.childHome;
    return null;
  }

  return Routes.selectUserType;
}
