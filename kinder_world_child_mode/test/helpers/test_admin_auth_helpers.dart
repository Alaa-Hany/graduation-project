import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';
import 'package:logger/logger.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

/// No-op SecureStorage — returns null/false for every token read.
class _StubSecureStorage extends SecureStorage {
  @override
  bool get hasCachedAuthToken => false;

  @override
  String? get cachedAuthToken => null;

  @override
  Future<String?> getAuthToken() async => null;

  @override
  Future<String?> getAdminToken() async => null;

  @override
  Future<String?> getAdminRefreshToken() async => null;
}

/// HTTP adapter that always returns an empty 200 without making real calls.
class _NullHttpAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString('{}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
}

/// AdminAuthRepository whose canBootstrap / restoreSession never hit the
/// network.  Pass [stubAdmin] to simulate an already-authenticated session.
class _StubAdminAuthRepository extends AdminAuthRepository {
  _StubAdminAuthRepository({this.stubAdmin})
      : super(
          adminApi: AdminApi(
            NetworkService(
              dio: Dio()..httpClientAdapter = _NullHttpAdapter(),
              secureStorage: _StubSecureStorage(),
              logger: Logger(),
            ),
          ),
          storage: _StubSecureStorage(),
        );

  final AdminUser? stubAdmin;

  @override
  Future<bool> canBootstrap() async => false;

  @override
  Future<AdminUser?> restoreSession() async => stubAdmin;
}

// ---------------------------------------------------------------------------
// Mock notifier
// ---------------------------------------------------------------------------

/// AdminAuthNotifier subclass for tests.
///
/// Extends [AdminAuthNotifier] (not [StateNotifier] directly) so Riverpod's
/// type system is satisfied.  The stub repository makes canBootstrap() and
/// restoreSession() return immediately without any HTTP calls or timers, so
/// tests stay clean.
///
/// Usage:
/// ```dart
/// final container = ProviderContainer(
///   overrides: [
///     ...createMockAdminAuthOverrides(admin: _superAdmin),
///   ],
/// );
/// ```
class MockAdminAuthNotifier extends AdminAuthNotifier {
  MockAdminAuthNotifier({AdminUser? admin})
      : super(
          _StubAdminAuthRepository(stubAdmin: admin),
          AppNavigationController(),
        );
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

List<Override> createMockAdminAuthOverrides({
  AdminUser? admin,
  // `status` is kept for API compatibility but the notifier state is driven
  // by whether [admin] is null (→ unauthenticated) or not (→ authenticated).
  AdminAuthStatus status = AdminAuthStatus.unauthenticated,
}) {
  return [
    adminAuthProvider.overrideWith((ref) {
      final repo = ref.watch(adminAuthRepositoryProvider);
      final navController = ref.watch(appNavigationControllerProvider);
      return AdminAuthNotifier(repo, navController);
    }),
  ];
}
