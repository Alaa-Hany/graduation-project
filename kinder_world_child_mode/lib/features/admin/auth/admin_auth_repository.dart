import 'package:dio/dio.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';

/// Result wrapper for admin auth operations.
class AdminAuthResult {
  final bool success;
  final String? error;
  final AdminUser? admin;
  final String? accessToken;
  final String? refreshToken;

  const AdminAuthResult({
    required this.success,
    this.error,
    this.admin,
    this.accessToken,
    this.refreshToken,
  });

  factory AdminAuthResult.ok(
      {AdminUser? admin, String? accessToken, String? refreshToken}) {
    return AdminAuthResult(
      success: true,
      admin: admin,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AdminAuthResult.fail(String error) {
    return AdminAuthResult(success: false, error: error);
  }
}

/// Repository for all admin authentication API calls.
/// Uses a dedicated Dio instance that injects the admin token (not the
/// parent/child token) so the two auth flows never interfere.
class AdminAuthRepository {
  final NetworkService _network;
  final SecureStorage _storage;

  AdminAuthRepository({
    required NetworkService network,
    required SecureStorage storage,
  })  : _network = network,
        _storage = storage;

  // ─────────────────────────── Login ───────────────────────────────────────

  /// POST /admin/auth/login
  /// Persists tokens + admin profile to secure storage on success.
  Future<AdminAuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _network.post(
        '/admin/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
        // Override Authorization header — do NOT send parent/child token here
        options: Options(headers: {'Authorization': null}),
      );

      final body = response.data as Map<String, dynamic>;
      final accessToken = body['access_token'] as String;
      final refreshToken = body['refresh_token'] as String;
      final adminJson = body['admin'] as Map<String, dynamic>;
      final admin = AdminUser.fromJson(adminJson);

      await _persistSession(admin, accessToken, refreshToken);

      return AdminAuthResult.ok(
        admin: admin,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      return AdminAuthResult.fail(_extractError(e));
    } catch (e) {
      return AdminAuthResult.fail('Unexpected error: $e');
    }
  }

  // ─────────────────────────── Refresh ─────────────────────────────────────

  /// POST /admin/auth/refresh
  /// Exchanges the stored refresh token for a new access token.
  Future<AdminAuthResult> refreshToken() async {
    try {
      final storedRefresh = await _storage.getAdminRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        return AdminAuthResult.fail('No refresh token stored');
      }

      final response = await _network.post(
        '/admin/auth/refresh',
        data: {'refresh_token': storedRefresh},
        options: Options(headers: {'Authorization': null}),
      );

      final body = response.data as Map<String, dynamic>;
      final newAccessToken = body['access_token'] as String;

      await _storage.saveAdminToken(newAccessToken);

      return AdminAuthResult.ok(accessToken: newAccessToken);
    } on DioException catch (e) {
      return AdminAuthResult.fail(_extractError(e));
    } catch (e) {
      return AdminAuthResult.fail('Unexpected error: $e');
    }
  }

  // ─────────────────────────── Logout ──────────────────────────────────────

  /// POST /admin/auth/logout
  /// Clears local session regardless of API result.
  Future<void> logout() async {
    try {
      final token = await _storage.getAdminToken();
      if (token != null && token.isNotEmpty) {
        await _network.post(
          '/admin/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (_) {
      // Best-effort — always clear local session
    } finally {
      await _storage.clearAdminSession();
    }
  }

  // ─────────────────────────── Me ──────────────────────────────────────────

  /// GET /admin/auth/me
  /// Fetches the current admin profile and refreshes local storage.
  Future<AdminAuthResult> getMe() async {
    try {
      final token = await _storage.getAdminToken();
      if (token == null || token.isEmpty) {
        return AdminAuthResult.fail('Not authenticated');
      }

      final response = await _network.get(
        '/admin/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      final adminJson = body['admin'] as Map<String, dynamic>;
      final admin = AdminUser.fromJson(adminJson);

      // Refresh cached profile data
      await _storage.saveAdminName(admin.name);
      await _storage.saveAdminEmail(admin.email);
      await _storage.saveAdminRoles(admin.roles);
      await _storage.saveAdminPermissions(admin.permissions);

      return AdminAuthResult.ok(admin: admin);
    } on DioException catch (e) {
      return AdminAuthResult.fail(_extractError(e));
    } catch (e) {
      return AdminAuthResult.fail('Unexpected error: $e');
    }
  }

  // ─────────────────────────── Session restore ─────────────────────────────

  /// Restore admin session from secure storage (used on app start).
  /// Returns null if no valid session is stored.
  Future<AdminUser?> restoreSession() async {
    try {
      final token = await _storage.getAdminToken();
      if (token == null || token.isEmpty) return null;
      final meResult = await getMe();
      if (meResult.success && meResult.admin != null) {
        return meResult.admin;
      }

      final refreshResult = await refreshToken();
      if (refreshResult.success) {
        final refreshedMe = await getMe();
        if (refreshedMe.success && refreshedMe.admin != null) {
          return refreshedMe.admin;
        }
      }

      await _storage.clearAdminSession();
      return null;
    } catch (_) {
      await _storage.clearAdminSession();
      return null;
    }
  }

  // ─────────────────────────── Helpers ─────────────────────────────────────

  Future<void> _persistSession(
    AdminUser admin,
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.saveAdminToken(accessToken);
    await _storage.saveAdminRefreshToken(refreshToken);
    await _storage.saveAdminId(admin.id.toString());
    await _storage.saveAdminEmail(admin.email);
    await _storage.saveAdminName(admin.name);
    await _storage.saveAdminRoles(admin.roles);
    await _storage.saveAdminPermissions(admin.permissions);
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map) {
        return detail['message'] as String? ?? 'Request failed';
      }
    }
    switch (e.response?.statusCode) {
      case 401:
        return 'Invalid email or password';
      case 403:
        return 'Admin account is disabled';
      case 404:
        return 'Admin account not found';
      default:
        return e.message ?? 'Network error';
    }
  }
}
