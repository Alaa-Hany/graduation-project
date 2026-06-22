// Unit tests for [AdminAuthRepository] — bootstrap/login/refresh/logout/getMe/
// restoreSession flows, including 2FA-required and error mapping. AdminApi and
// SecureStorage are faked.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/admin_api.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_repository.dart';

class _FakeAdminApi extends Fake implements AdminApi {
  Map<String, dynamic> bootstrapStatusBody = {'can_bootstrap': true};
  Map<String, dynamic> authBody = _authBody();
  Map<String, dynamic> refreshBody = {'access_token': 'new-access'};
  Map<String, dynamic> meBody = {'admin': _adminJson()};
  Object? throwError;
  bool bootstrapStatusThrows = false;
  int logoutCalls = 0;

  @override
  Future<Map<String, dynamic>> bootstrapStatus() async {
    if (bootstrapStatusThrows) throw Exception('net');
    return bootstrapStatusBody;
  }

  @override
  Future<Map<String, dynamic>> bootstrap({
    required String email,
    required String password,
    String? name,
  }) async {
    if (throwError != null) throw throwError!;
    return authBody;
  }

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    if (throwError != null) throw throwError!;
    return authBody;
  }

  @override
  Future<Map<String, dynamic>> refresh({required String refreshToken}) async {
    if (throwError != null) throw throwError!;
    return refreshBody;
  }

  @override
  Future<Map<String, dynamic>> me({required String accessToken}) async {
    if (throwError != null) throw throwError!;
    return meBody;
  }

  @override
  Future<Map<String, dynamic>> logout({required String accessToken}) async {
    logoutCalls++;
    return {};
  }
}

class _FakeSecureStorage extends Fake implements SecureStorage {
  String? adminToken;
  String? adminRefreshToken;
  int clearCalls = 0;

  @override
  Future<String?> getAdminToken() async => adminToken;
  @override
  Future<String?> getAdminRefreshToken() async => adminRefreshToken;
  @override
  Future<bool> saveAdminToken(String token) async {
    adminToken = token;
    return true;
  }

  @override
  Future<bool> saveAdminRefreshToken(String token) async {
    adminRefreshToken = token;
    return true;
  }

  @override
  Future<bool> saveAdminId(String id) async => true;
  @override
  Future<bool> saveAdminEmail(String email) async => true;
  @override
  Future<bool> saveAdminName(String name) async => true;
  @override
  Future<bool> saveAdminRoles(List<String> roles) async => true;
  @override
  Future<bool> saveAdminPermissions(List<String> permissions) async => true;
  @override
  Future<bool> clearAdminSession() async {
    clearCalls++;
    adminToken = null;
    adminRefreshToken = null;
    return true;
  }
}

Map<String, dynamic> _adminJson() => {
      'id': 1,
      'email': 'admin@x.com',
      'name': 'Admin',
      'roles': ['superadmin'],
      'permissions': ['all'],
    };

Map<String, dynamic> _authBody() => {
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'admin': _adminJson(),
    };

DioException _dio({int? statusCode, Object? data}) {
  final ro = RequestOptions(path: '/admin/auth');
  return DioException(
    requestOptions: ro,
    response: Response(requestOptions: ro, statusCode: statusCode, data: data),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  late _FakeAdminApi api;
  late _FakeSecureStorage storage;
  late AdminAuthRepository repo;

  setUp(() {
    api = _FakeAdminApi();
    storage = _FakeSecureStorage();
    repo = AdminAuthRepository(adminApi: api, storage: storage);
  });

  group('canBootstrap', () {
    test('true when backend allows', () async {
      expect(await repo.canBootstrap(), isTrue);
    });
    test('false on error', () async {
      api.bootstrapStatusThrows = true;
      expect(await repo.canBootstrap(), isFalse);
    });
  });

  group('bootstrap & login', () {
    test('bootstrap success persists session', () async {
      final result = await repo.bootstrap(email: 'a@x.com', password: 'p');
      expect(result.success, isTrue);
      expect(result.admin!.email, 'admin@x.com');
      expect(storage.adminToken, 'access-1');
      expect(storage.adminRefreshToken, 'refresh-1');
    });

    test('login success returns admin and tokens', () async {
      final result = await repo.login(email: 'a@x.com', password: 'p');
      expect(result.success, isTrue);
      expect(result.accessToken, 'access-1');
    });

    test('login maps 401 to invalid credentials', () async {
      api.throwError = _dio(statusCode: 401);
      final result = await repo.login(email: 'a@x.com', password: 'bad');
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('login surfaces two-factor requirement', () async {
      api.throwError = _dio(
        statusCode: 401,
        data: {
          'detail': {
            'code': 'ADMIN_TWO_FACTOR_REQUIRED',
            'message': 'Enter your 2FA code',
            'two_factor_method': 'totp',
          },
        },
      );
      final result = await repo.login(email: 'a@x.com', password: 'p');
      expect(result.success, isFalse);
      expect(result.requiresTwoFactor, isTrue);
      expect(result.twoFactorMethod, 'totp');
      expect(result.error, 'Enter your 2FA code');
    });
  });

  group('refreshToken', () {
    test('fails when no refresh token stored', () async {
      storage.adminRefreshToken = null;
      final result = await repo.refreshToken();
      expect(result.success, isFalse);
    });

    test('succeeds and saves new access token', () async {
      storage.adminRefreshToken = 'refresh-1';
      final result = await repo.refreshToken();
      expect(result.success, isTrue);
      expect(storage.adminToken, 'new-access');
    });
  });

  group('logout & getMe', () {
    test('logout calls API and clears session', () async {
      storage.adminToken = 'access-1';
      await repo.logout();
      expect(api.logoutCalls, 1);
      expect(storage.clearCalls, 1);
      expect(storage.adminToken, isNull);
    });

    test('getMe fails when not authenticated', () async {
      storage.adminToken = null;
      final result = await repo.getMe();
      expect(result.success, isFalse);
    });

    test('getMe returns admin when authenticated', () async {
      storage.adminToken = 'access-1';
      final result = await repo.getMe();
      expect(result.success, isTrue);
      expect(result.admin!.email, 'admin@x.com');
    });
  });

  group('restoreSession', () {
    test('returns null when no token', () async {
      storage.adminToken = null;
      expect(await repo.restoreSession(), isNull);
    });

    test('returns admin when token valid', () async {
      storage.adminToken = 'access-1';
      final admin = await repo.restoreSession();
      expect(admin, isNotNull);
      expect(admin!.email, 'admin@x.com');
    });
  });

  group('AdminAuthResult factories', () {
    test('ok and fail set fields correctly', () {
      final ok = AdminAuthResult.ok(accessToken: 't');
      expect(ok.success, isTrue);
      expect(ok.accessToken, 't');

      final fail = AdminAuthResult.fail('boom',
          requiresTwoFactor: true, twoFactorMethod: 'sms');
      expect(fail.success, isFalse);
      expect(fail.error, 'boom');
      expect(fail.requiresTwoFactor, isTrue);
      expect(fail.twoFactorMethod, 'sms');
    });
  });
}
