import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/router.dart';

final appNavigationControllerProvider =
    Provider<AppNavigationController>((ref) {
  final controller = AppNavigationController();
  ref.onDispose(controller.dispose);
  return controller;
});

class AppNavigationController {
  GoRouter? _router;
  VoidCallback? _listener;
  final List<String> _history = <String>[];
  bool _backHandlingLocked = false;

  List<String> get history => List.unmodifiable(_history);

  void attach(GoRouter router) {
    if (identical(_router, router)) {
      _recordCurrentLocation();
      return;
    }

    detach();
    _router = router;
    _listener = _recordCurrentLocation;
    router.routerDelegate.addListener(_listener!);
    _recordCurrentLocation();
  }

  void detach() {
    final router = _router;
    final listener = _listener;
    if (router != null && listener != null) {
      router.routerDelegate.removeListener(listener);
    }
    _router = null;
    _listener = null;
  }

  void dispose() {
    detach();
  }

  void clearHistory({String? seedLocation}) {
    _history
      ..clear()
      ..addAll(
        seedLocation == null || seedLocation.isEmpty
            ? const []
            : [_normalize(seedLocation)],
      );
  }

  Future<bool> handleBack(
    BuildContext context, {
    String? fallback,
  }) async {
    if (_backHandlingLocked) {
      return true;
    }
    _backHandlingLocked = true;
    try {
    final router = _router ?? GoRouter.maybeOf(context);
    if (router == null) {
      return true;
    }

    final currentLocation = _currentLocationFor(context, router);
    _recordLocation(currentLocation);

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final modalRoute = ModalRoute.of(context);
    final isPopupRoute = modalRoute is PopupRoute;
    if (isPopupRoute && rootNavigator.canPop()) {
      rootNavigator.pop();
      return true;
    }

    final previous = _previousLocation(currentLocation);
    if (_shouldUsePreviousRoute(
      previous: previous,
      current: currentLocation,
      fallback: fallback,
    )) {
      _removeTail(currentLocation);
      router.go(previous!);
      return true;
    }

    final resolvedFallback = _normalize(
      fallback ?? fallbackFor(currentLocation),
    );
    if (resolvedFallback != currentLocation) {
      clearHistory(seedLocation: resolvedFallback);
      router.go(resolvedFallback);
    }
    return true;
    } finally {
      Future<void>.microtask(() {
        _backHandlingLocked = false;
      });
    }
  }

  Future<bool> handleSystemBack(
    BuildContext context, {
    String? fallback,
  }) async {
    return handleBack(context, fallback: fallback);
  }

  String fallbackFor(String location) {
    final normalized = _normalize(location);

    if (normalized == Routes.adminDashboard) {
      return Routes.selectUserType;
    }
    if (_isAdminRoute(normalized)) {
      return Routes.adminDashboard;
    }

    if (normalized == Routes.parentPin) {
      return Routes.parentDashboard;
    }
    if (normalized == Routes.parentDashboard) {
      return Routes.selectUserType;
    }
    if (_isParentRoute(normalized)) {
      return Routes.parentDashboard;
    }

    if (normalized.startsWith('${Routes.childLearn}/subject/') ||
        normalized.startsWith('${Routes.childLearn}/lesson/')) {
      return Routes.childLearn;
    }
    if (normalized.startsWith('${Routes.childPlay}/category/')) {
      return Routes.childPlay;
    }
    if (normalized == Routes.childAchievements ||
        normalized == Routes.childStore) {
      return Routes.childProfile;
    }
    if (normalized == Routes.childLearn ||
        normalized == Routes.childPlay ||
        normalized == Routes.childAiBuddy ||
        normalized == Routes.childProfile ||
        normalized == Routes.childActivityOfDay) {
      return Routes.childHome;
    }
    if (normalized == Routes.childHome) {
      return Routes.selectUserType;
    }

    if (normalized == Routes.adminLogin ||
        normalized == Routes.parentLogin ||
        normalized == Routes.parentRegister ||
        normalized == Routes.parentForgotPassword ||
        normalized == Routes.childLogin ||
        normalized == Routes.childForgotPassword) {
      return Routes.selectUserType;
    }

    if (normalized == Routes.selectUserType) {
      return Routes.welcome;
    }

    if (normalized == Routes.help ||
        normalized == Routes.legal ||
        normalized == Routes.error ||
        normalized == Routes.maintenance ||
        normalized == Routes.noInternet) {
      return Routes.welcome;
    }

    if (normalized == Routes.welcome ||
        normalized == Routes.language ||
        normalized == Routes.onboarding ||
        normalized == Routes.splash) {
      return Routes.welcome;
    }

    return Routes.welcome;
  }

  void _recordCurrentLocation() {
    final router = _router;
    if (router == null) return;
    _recordLocation(router.routerDelegate.currentConfiguration.uri.path);
  }

  void _recordLocation(String location) {
    final normalized = _normalize(location);
    if (_history.isEmpty || _history.last != normalized) {
      _history.add(normalized);
    }
  }

  String? _previousLocation(String currentLocation) {
    if (_history.length < 2) {
      return null;
    }

    for (var index = _history.length - 2; index >= 0; index--) {
      final candidate = _history[index];
      if (candidate != currentLocation) {
        return candidate;
      }
    }
    return null;
  }

  void _removeTail(String location) {
    while (_history.isNotEmpty && _history.last == location) {
      _history.removeLast();
    }
  }

  String _normalize(String location) {
    if (location.isEmpty) {
      return Routes.welcome;
    }
    if (location.length > 1 && location.endsWith('/')) {
      return location.substring(0, location.length - 1);
    }
    return location;
  }

  String _currentLocationFor(BuildContext context, GoRouter router) {
    try {
      return _normalize(GoRouterState.of(context).uri.path);
    } catch (_) {
      return _normalize(router.routeInformationProvider.value.uri.path);
    }
  }

  bool _isAdminRoute(String location) => location.startsWith('/admin/');

  bool _isParentRoute(String location) => location.startsWith('/parent/');

  bool _shouldUsePreviousRoute({
    required String? previous,
    required String current,
    required String? fallback,
  }) {
    if (previous == null || previous == current) {
      return false;
    }

    final currentSection = _sectionFor(current);
    final previousSection = _sectionFor(previous);

    if (_isProtectedSection(current) && !_isSectionRoot(current)) {
      return previousSection == currentSection;
    }

    if (_isSectionRoot(current) &&
        (_isAuthRoute(previous) || _isBootstrapRoute(previous))) {
      return false;
    }

    if (fallback == null || fallback.isEmpty) {
      return true;
    }

    return true;
  }

  String _sectionFor(String location) {
    final normalized = _normalize(location);
    if (_isAdminAuthRoute(normalized)) {
      return 'admin-auth';
    }
    if (_isParentAuthRoute(normalized)) {
      return 'parent-auth';
    }
    if (_isChildAuthRoute(normalized)) {
      return 'child-auth';
    }
    if (normalized.startsWith('/admin/')) {
      return 'admin';
    }
    if (normalized.startsWith('/parent/')) {
      return 'parent';
    }
    if (normalized.startsWith('/child/')) {
      return 'child';
    }
    return 'public';
  }

  bool _isAdminAuthRoute(String location) => location == Routes.adminLogin;

  bool _isParentAuthRoute(String location) =>
      location == Routes.parentLogin ||
      location == Routes.parentRegister ||
      location == Routes.parentForgotPassword;

  bool _isChildAuthRoute(String location) =>
      location == Routes.childLogin ||
      location == Routes.childForgotPassword;

  bool _isAuthRoute(String location) =>
      _isAdminAuthRoute(location) ||
      _isParentAuthRoute(location) ||
      _isChildAuthRoute(location);

  bool _isBootstrapRoute(String location) {
    final normalized = _normalize(location);
    return normalized == Routes.welcome ||
        normalized == Routes.splash ||
        normalized == Routes.language ||
        normalized == Routes.onboarding;
  }

  bool _isProtectedSection(String location) {
    final normalized = _normalize(location);
    return normalized.startsWith('/admin/') ||
        normalized.startsWith('/parent/') ||
        normalized.startsWith('/child/');
  }

  bool _isSectionRoot(String location) {
    final normalized = _normalize(location);
    return normalized == Routes.adminDashboard ||
        normalized == Routes.parentDashboard ||
        normalized == Routes.childHome ||
        normalized == Routes.selectUserType ||
        normalized == Routes.welcome;
  }
}

class AppNavigationBackHandler extends ConsumerWidget {
  const AppNavigationBackHandler({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(appNavigationControllerProvider).handleSystemBack(context);
      },
      child: child,
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.fallback,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.iconSize = 20,
    this.color,
    this.tooltip,
  });

  final String fallback;
  final IconData icon;
  final double iconSize;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: iconSize, color: color),
      tooltip: tooltip,
      onPressed: () => context.appBack(fallback: fallback),
    );
  }
}

extension AppBackNavigationExtension on BuildContext {
  Future<void> appBack({String? fallback}) async {
    final container = ProviderScope.containerOf(this, listen: false);
    await container
        .read(appNavigationControllerProvider)
        .handleBack(this, fallback: fallback);
  }

  void clearAppNavigationHistory({String? seedLocation}) {
    final container = ProviderScope.containerOf(this, listen: false);
    container
        .read(appNavigationControllerProvider)
        .clearHistory(seedLocation: seedLocation);
  }
}
