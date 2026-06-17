import 'package:dio/dio.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';

class AdminAuthResult {
  final bool success;
  final String? error;
  final AdminUser? admin;
  final String? accessToken;
  final String? refreshToken;
  final bool requiresTwoFactor;
  final String? twoFactorMethod;

  const AdminAuthResult({
    required this.success,
    this.error,
    this.admin,
    this.accessToken,
    this.refreshToken,
    this.requiresTwoFactor = false,
    this.twoFactorMethod,
  });

  factory AdminAuthResult.ok({
    AdminUser? admin,
    String? accessToken,
    String? refreshToken,
  }) {
    return AdminAuthResult(
      success: true,
      admin: admin,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AdminAuthResult.fail(
    String error, {
    bool requiresTwoFactor = false,
    String? twoFactorMethod,
  }) {
    return AdminAuthResult(
      success: false,
      error: error,
      requiresTwoFactor: requiresTwoFactor,
      twoFactorMethod: twoFactorMethod,
    );
  }
}

class AdminAuthRepository {
  final AdminApi _adminApi;
  final SecureStorage _storage;

  AdminAuthRepository({
    required AdminApi adminApi,
    required SecureStorage storage,
  })  : _adminApi = adminApi,
        _storage = storage;

  Future<bool> canBootstrap() async {
    try {
      final body = await _adminApi.bootstrapStatus();
      return body['can_bootstrap'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<AdminAuthResult> bootstrap({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final body = await _adminApi.bootstrap(
        email: email,
        password: password,
        name: name,
      );
      final accessToken = body['access_token'] as String;
      final refreshToken = body['refresh_token'] as String;
      final adminJson = Map<String, dynamic>.from(body['admin'] as Map);
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
      return AdminAuthResult.fail(AdminAuthUiMessages.unexpectedError(e));
    }
  }

  Future<AdminAuthResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    try {
      final body = await _adminApi.login(
        email: email,
        password: password,
        twoFactorCode: twoFactorCode,
      );
      final accessToken = body['access_token'] as String;
      final refreshToken = body['refresh_token'] as String;
      final adminJson = Map<String, dynamic>.from(body['admin'] as Map);
      final admin = AdminUser.fromJson(adminJson);

      await _persistSession(admin, accessToken, refreshToken);

      return AdminAuthResult.ok(
        admin: admin,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      return AdminAuthResult.fail(
        _extractError(e),
        requiresTwoFactor: _isTwoFactorRequired(e),
        twoFactorMethod: _extractTwoFactorMethod(e),
      );
    } catch (e) {
      return AdminAuthResult.fail(AdminAuthUiMessages.unexpectedError(e));
    }
  }

  Future<AdminAuthResult> refreshToken() async {
    try {
      final storedRefresh = await _storage.getAdminRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        return AdminAuthResult.fail(
          AdminAuthUiMessages.noRefreshTokenStored,
        );
      }

      final body = await _adminApi.refresh(refreshToken: storedRefresh);
      final newAccessToken = body['access_token'] as String;

      await _storage.saveAdminToken(newAccessToken);

      return AdminAuthResult.ok(accessToken: newAccessToken);
    } on DioException catch (e) {
      return AdminAuthResult.fail(_extractError(e));
    } catch (e) {
      return AdminAuthResult.fail(AdminAuthUiMessages.unexpectedError(e));
    }
  }

  Future<void> logout() async {
    try {
      final token = await _storage.getAdminToken();
      if (token != null && token.isNotEmpty) {
        await _adminApi.logout(accessToken: token);
      }
    } catch (_) {
      // Best-effort API call; local session is always cleared.
    } finally {
      await _storage.clearAdminSession();
    }
  }

  Future<AdminAuthResult> getMe() async {
    try {
      final token = await _storage.getAdminToken();
      if (token == null || token.isEmpty) {
        return AdminAuthResult.fail(AdminAuthUiMessages.notAuthenticated);
      }

      final body = await _adminApi.me(accessToken: token);
      final adminJson = Map<String, dynamic>.from(body['admin'] as Map);
      final admin = AdminUser.fromJson(adminJson);

      await _storage.saveAdminName(admin.name);
      await _storage.saveAdminEmail(admin.email);
      await _storage.saveAdminRoles(admin.roles);
      await _storage.saveAdminPermissions(admin.permissions);

      return AdminAuthResult.ok(admin: admin);
    } on DioException catch (e) {
      return AdminAuthResult.fail(_extractError(e));
    } catch (e) {
      return AdminAuthResult.fail(AdminAuthUiMessages.unexpectedError(e));
    }
  }

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
    if (_isTwoFactorRequired(e)) {
      return _extractDetailMessage(e) ??
          AdminAuthUiMessages.twoFactorCodeRequired;
    }
    if (_extractDetailCode(e) == 'ADMIN_INVALID_TWO_FACTOR_CODE') {
      return _extractDetailMessage(e) ??
          AdminAuthUiMessages.invalidTwoFactorCode;
    }
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map) {
        return detail['message'] as String? ??
            AdminAuthUiMessages.requestFailed;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final message = first['msg']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
        return detail.map((item) => item.toString()).join(', ');
      }
      if (data['message'] != null) {
        final message = data['message'].toString().trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    switch (e.response?.statusCode) {
      case 401:
        return AdminAuthUiMessages.invalidEmailOrPassword;
      case 403:
        return AdminAuthUiMessages.adminAccountDisabled;
      case 404:
        return AdminAuthUiMessages.adminAccountNotFound;
      default:
        return e.message ?? AdminAuthUiMessages.networkError;
    }
  }

  String? _extractDetailMessage(DioException e) {
    final detail = _extractDetailMap(e);
    final message = detail?['message'];
    if (message == null) {
      return null;
    }
    final normalizedMessage = message.toString().trim();
    return normalizedMessage.isEmpty ? null : normalizedMessage;
  }

  Map<String, dynamic>? _extractDetailMap(DioException e) {
    final data = e.response?.data;
    if (data is! Map) {
      return null;
    }
    final detail = data['detail'];
    if (detail is Map) {
      return Map<String, dynamic>.from(detail);
    }
    final error = data['error'];
    if (error is Map) {
      return Map<String, dynamic>.from(error);
    }
    return null;
  }

  String? _extractDetailCode(DioException e) {
    final detail = _extractDetailMap(e);
    final code = detail?['code'];
    if (code == null) {
      return null;
    }
    final normalizedCode = code.toString().trim();
    return normalizedCode.isEmpty ? null : normalizedCode;
  }

  String? _extractTwoFactorMethod(DioException e) {
    final detail = _extractDetailMap(e);
    final method = detail?['two_factor_method'];
    if (method == null) {
      return null;
    }
    final normalizedMethod = method.toString().trim();
    return normalizedMethod.isEmpty ? null : normalizedMethod;
  }

  bool _isTwoFactorRequired(DioException e) {
    return _extractDetailCode(e) == 'ADMIN_TWO_FACTOR_REQUIRED';
  }
}
