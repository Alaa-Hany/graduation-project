import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/system_pages/error_screen.dart';

import 'routing/route_guards.dart';
import 'routing/routes_admin.dart';
import 'routing/routes_child.dart';
import 'routing/routes_parent.dart';
import 'routing/routes_public.dart';

export 'routing/route_paths.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  final logger = ref.read(loggerProvider);
  final refreshListenable = RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: resolveInitialLocation(),
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshListenable,
    redirect: (context, state) => appRedirect(
      ref: ref,
      secureStorage: secureStorage,
      logger: logger,
      state: state,
    ),
    routes: [
      ...buildPublicRoutes(),
      ...buildChildRoutes(),
      ...buildParentRoutes(),
      ...buildAdminRoutes(),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      error:
          state.error?.toString() ?? AppLocalizations.of(context)!.pageNotFound,
    ),
  );
});
