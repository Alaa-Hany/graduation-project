import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/models/user.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/repositories/auth_repository.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _MemorySecureStorage extends SecureStorage {
  String? authToken;
  String? refreshToken;
  String? parentAccessToken;
  String? parentRefreshToken;
  String? userId;
  String? userEmail;
  String? userRole;
  String? childSession;
  bool parentPinVerified = false;

  @override
  Future<String?> getAuthToken() async => authToken;

  @override
  Future<bool> saveAuthToken(String token) async {
    authToken = token;
    return true;
  }

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> saveRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }

  @override
  Future<String?> getParentAccessToken() async => parentAccessToken;

  @override
  Future<bool> saveParentAccessToken(String token) async {
    parentAccessToken = token;
    return true;
  }

  @override
  Future<String?> getParentRefreshToken() async => parentRefreshToken;

  @override
  Future<bool> saveParentRefreshToken(String token) async {
    parentRefreshToken = token;
    return true;
  }

  @override
  Future<bool> deleteRefreshToken() async {
    refreshToken = null;
    return true;
  }

  @override
  Future<bool> saveUserId(String value) async {
    userId = value;
    return true;
  }

  @override
  Future<String?> getUserId() async => userId;

  @override
  Future<bool> saveUserEmail(String value) async {
    userEmail = value;
    return true;
  }

  @override
  Future<String?> getUserEmail() async => userEmail;

  @override
  Future<bool> deleteUserEmail() async {
    userEmail = null;
    return true;
  }

  @override
  Future<bool> saveUserRole(String value) async {
    userRole = value;
    return true;
  }

  @override
  Future<String?> getUserRole() async => userRole;

  @override
  Future<bool> saveChildSession(String childId) async {
    childSession = childId;
    return true;
  }

  @override
  Future<String?> getChildSession() async => childSession;

  @override
  Future<bool> clearChildSession() async {
    childSession = null;
    return true;
  }

  @override
  Future<bool> saveParentPinVerified(bool isVerified) async {
    parentPinVerified = isVerified;
    return true;
  }

  @override
  Future<bool> isParentPinVerified() async => parentPinVerified;

  @override
  Future<bool> clearParentPinVerification() async {
    parentPinVerified = false;
    return true;
  }

  @override
  Future<bool> clearAuthOnly() async {
    authToken = null;
    refreshToken = null;
    parentAccessToken = null;
    parentRefreshToken = null;
    userId = null;
    userEmail = null;
    userRole = null;
    childSession = null;
    parentPinVerified = false;
    return true;
  }

  @override
  Future<bool> isAuthenticated() async =>
      authToken != null && authToken!.isNotEmpty;
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(this.storage)
      : super(
          NetworkService(
            secureStorage: storage,
            logger: Logger(),
          ),
        );

  final SecureStorage storage;
  AuthSessionPayload? loginPayload;
  PendingVerificationPayload? registerPayload;
  ChildLoginPayload? childLoginPayload;
  Map<String, dynamic>? refreshPayload;
  Map<String, dynamic>? childSessionValidationPayload;
  Map<String, dynamic>? logoutPayload;
  Map<String, dynamic>? childRegisterPayload;
  Map<String, dynamic>? parentPinStatusPayload;
  Object? loginError;
  int childSessionValidationCalls = 0;
  Object? logoutError;
  int logoutCalls = 0;
  String? lastChildRegisterAuthorization;
  String? lastLoginTwoFactorCode;
  int parentPinStatusCalls = 0;

  @override
  Future<AuthSessionPayload> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    lastLoginTwoFactorCode = twoFactorCode;
    if (loginError != null) {
      throw loginError!;
    }
    return loginPayload!;
  }

  @override
  Future<PendingVerificationPayload> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return registerPayload ??
        PendingVerificationPayload(
          success: true,
          email: email,
          verificationRequired: true,
          raw: const <String, dynamic>{},
        );
  }

  @override
  Future<ChildLoginPayload> childLogin({
    required String childId,
    required String name,
    required List<String> picturePassword,
  }) async {
    return childLoginPayload!;
  }

  @override
  Future<Map<String, dynamic>> refresh({
    required String refreshToken,
  }) async {
    return refreshPayload ?? const {};
  }

  @override
  Future<Map<String, dynamic>> validateChildSession({
    required String sessionToken,
  }) async {
    childSessionValidationCalls += 1;
    return childSessionValidationPayload ?? const {};
  }

  @override
  Future<Map<String, dynamic>> logout() async {
    logoutCalls += 1;
    if (logoutError != null) {
      throw logoutError!;
    }
    return logoutPayload ?? const {'success': true};
  }

  @override
  Future<Map<String, dynamic>> childRegister({
    required String name,
    required List<String> picturePassword,
    required String parentAccessToken,
    String? parentEmail,
    required int age,
    String? avatar,
  }) async {
    lastChildRegisterAuthorization = parentAccessToken;
    return childRegisterPayload ??
        const {
          'child': {'id': 7, 'name': 'Kid'}
        };
  }

  @override
  Future<Map<String, dynamic>> parentPinStatus() async {
    parentPinStatusCalls += 1;
    return parentPinStatusPayload ??
        const {
          'has_pin': true,
          'is_locked': false,
          'failed_attempts': 0,
        };
  }
}

String _jwtWithExp(DateTime dateTime) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"exp":${dateTime.millisecondsSinceEpoch ~/ 1000}}'),
  );
  return '$header.$payload.signature';
}

String _childSessionJwt() {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"token_type":"child_session","exp":4102444800}'),
  );
  return '$header.$payload.signature';
}

Map<String, dynamic> _parentAuthRaw({
  required String accessToken,
  required String refreshToken,
}) {
  return {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user': {
      'id': 'parent-1',
      'email': 'parent@example.com',
      'role': UserRoles.parent,
      'name': 'Parent User',
      'created_at': '2025-01-01T00:00:00.000Z',
      'updated_at': '2025-01-01T00:00:00.000Z',
      'is_active': true,
    },
  };
}

void main() {
  late _MemorySecureStorage storage;
  late _FakeAuthApi authApi;
  late AuthRepository repository;

  setUp(() {
    storage = _MemorySecureStorage();
    authApi = _FakeAuthApi(storage);
    repository = AuthRepository(
      secureStorage: storage,
      authApi: authApi,
      logger: Logger(),
    );
  });

  test('loginParent persists parent auth and clears stale child session state',
      () async {
    storage.childSession = 'child-7';
    storage.parentPinVerified = true;
    authApi.loginPayload = AuthSessionPayload(
      accessToken: 'parent.jwt',
      refreshToken: 'refresh.jwt',
      user: Map<String, dynamic>.from(
        _parentAuthRaw(
          accessToken: 'parent.jwt',
          refreshToken: 'refresh.jwt',
        )['user'] as Map<String, dynamic>,
      ),
      raw: _parentAuthRaw(
        accessToken: 'parent.jwt',
        refreshToken: 'refresh.jwt',
      ),
    );

    final user = await repository.loginParent(
      email: 'Parent@Example.com',
      password: 'Password123!',
    );

    expect(user, isNotNull);
    expect(storage.authToken, 'parent.jwt');
    expect(storage.refreshToken, 'refresh.jwt');
    expect(storage.userRole, UserRoles.parent);
    expect(storage.userEmail, 'parent@example.com');
    expect(storage.childSession, isNull);
    expect(storage.parentPinVerified, isFalse);
  });

  test(
      'loginChild clears parent-only fields and saves backend child session token',
      () async {
    storage.refreshToken = 'refresh.jwt';
    storage.userEmail = 'parent@example.com';
    storage.parentPinVerified = true;
    final sessionToken = _childSessionJwt();
    authApi.childLoginPayload = ChildLoginPayload(
      success: true,
      childId: 'child-7',
      name: 'Mira',
      sessionToken: sessionToken,
      raw: {
        'name': 'Mira',
        'child_id': 'child-7',
        'session_token': sessionToken,
      },
    );

    final user = await repository.loginChild(
      childId: 'child-7',
      childName: 'Mira',
      picturePassword: const ['apple', 'cat', 'dog'],
    );

    expect(user, isNotNull);
    expect(storage.authToken, sessionToken);
    expect(storage.refreshToken, isNull);
    expect(storage.userEmail, isNull);
    expect(storage.userRole, UserRoles.child);
    expect(storage.userId, 'child-7');
    expect(storage.childSession, 'child-7');
    expect(storage.parentPinVerified, isFalse);
  });

  test(
      'validateToken rejects legacy child markers and validates child session JWTs',
      () async {
    storage.authToken = _jwtWithExp(
      DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );
    expect(await repository.validateToken(), isFalse);

    storage.authToken = 'child_session_child-7';
    expect(await repository.validateToken(), isFalse);

    storage.authToken = _childSessionJwt();
    authApi.childSessionValidationPayload = const {
      'success': true,
      'child_id': 'child-7',
      'name': 'Mira',
    };
    expect(await repository.validateToken(), isTrue);
  });

  test('getCurrentUser resolves child identity from backend session validation',
      () async {
    storage.userRole = UserRoles.child;
    storage.authToken = _childSessionJwt();
    storage.childSession = 'child-7';
    authApi.childSessionValidationPayload = const {
      'success': true,
      'child_id': 'child-7',
      'name': 'Mira',
    };

    final user = await repository.getCurrentUser();

    expect(user, isNotNull);
    expect(user!.id, 'child-7');
    expect(user.role, UserRoles.child);
    expect(user.name, 'Mira');
  });

  test(
      'getCurrentUser clears legacy child markers even when childSession is missing',
      () async {
    storage.userRole = UserRoles.child;
    storage.authToken = 'child_session_child-7';

    final user = await repository.getCurrentUser();

    expect(user, isNull);
    expect(storage.authToken, isNull);
    expect(storage.userRole, isNull);
  });

  test(
      'getCurrentUser preserves non-legacy child auth when childSession is missing',
      () async {
    final sessionToken = _childSessionJwt();
    storage.userRole = UserRoles.child;
    storage.authToken = sessionToken;

    final user = await repository.getCurrentUser();

    expect(user, isNull);
    expect(storage.authToken, sessionToken);
    expect(storage.userRole, UserRoles.child);
    expect(authApi.childSessionValidationCalls, 0);
  });

  test('logout notifies backend for parent sessions before clearing local auth',
      () async {
    storage.authToken = 'token';
    storage.refreshToken = 'refresh';
    storage.userId = 'parent-1';
    storage.userEmail = 'parent@example.com';
    storage.userRole = UserRoles.parent;
    authApi.logoutPayload = const {'success': true};

    final success = await repository.logout();

    expect(success, isTrue);
    expect(authApi.logoutCalls, 1);
    expect(storage.authToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test('logout clears local auth even when parent logout API fails', () async {
    storage.authToken = 'token';
    storage.refreshToken = 'refresh';
    storage.userRole = UserRoles.parent;
    authApi.logoutError = DioException(
      requestOptions: RequestOptions(path: '/auth/logout'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/logout'),
        statusCode: 500,
      ),
    );

    final success = await repository.logout();

    expect(success, isTrue);
    expect(authApi.logoutCalls, 1);
    expect(storage.authToken, isNull);
    expect(storage.userRole, isNull);
  });

  test('logout clears auth-only session fields', () async {
    storage.authToken = 'token';
    storage.refreshToken = 'refresh';
    storage.userId = 'parent-1';
    storage.userEmail = 'parent@example.com';
    storage.userRole = UserRoles.parent;
    storage.childSession = 'child-1';
    storage.parentPinVerified = true;
    authApi.logoutPayload = const {'success': true};

    final success = await repository.logout();

    expect(success, isTrue);
    expect(authApi.logoutCalls, 1);
    expect(storage.authToken, isNull);
    expect(storage.refreshToken, isNull);
    expect(storage.userId, isNull);
    expect(storage.userEmail, isNull);
    expect(storage.userRole, isNull);
    expect(storage.childSession, isNull);
    expect(storage.parentPinVerified, isFalse);
  });

  test(
      'registerChild uses current parent auth token for secured child creation',
      () async {
    storage.authToken = 'parent.jwt';
    storage.userRole = UserRoles.parent;
    authApi.childRegisterPayload = const {
      'child': {'id': 7, 'name': 'Mira'}
    };

    final response = await repository.registerChild(
      name: 'Mira',
      picturePassword: const ['apple', 'cat', 'dog'],
      parentEmail: 'parent@example.com',
      age: 7,
    );

    expect(response, isNotNull);
    expect(response!.childId, '7');
    expect(authApi.lastChildRegisterAuthorization, 'parent.jwt');
  });

  test(
      'registerChild falls back to stored parent token when child session is active',
      () async {
    storage.authToken = _childSessionJwt();
    storage.userRole = UserRoles.child;
    storage.parentAccessToken = 'stored.parent.jwt';
    authApi.childRegisterPayload = const {
      'child': {'id': 8, 'name': 'Noor'}
    };

    final response = await repository.registerChild(
      name: 'Noor',
      picturePassword: const ['apple', 'cat', 'dog'],
      parentEmail: 'parent@example.com',
      age: 7,
    );

    expect(response, isNotNull);
    expect(response!.childId, '8');
    expect(authApi.lastChildRegisterAuthorization, 'stored.parent.jwt');
  });

  test('registerChild fails fast when no parent session is available',
      () async {
    expect(
      () => repository.registerChild(
        name: 'Noor',
        picturePassword: const ['apple', 'cat', 'dog'],
        parentEmail: 'parent@example.com',
        age: 7,
      ),
      throwsA(isA<ChildRegisterException>()),
    );
  });

  test('getParentPinStatus skips API call without authenticated parent session',
      () async {
    storage.authToken = null;
    storage.userRole = null;

    final status = await repository.getParentPinStatus();

    expect(status.hasPin, isFalse);
    expect(authApi.parentPinStatusCalls, 0);
  });

  test('getParentPinStatus uses API for authenticated parent sessions',
      () async {
    storage.authToken = 'parent.jwt';
    storage.userRole = UserRoles.parent;
    authApi.parentPinStatusPayload = const {
      'has_pin': true,
      'is_locked': false,
      'failed_attempts': 2,
    };

    final status = await repository.getParentPinStatus();

    expect(status.hasPin, isTrue);
    expect(status.failedAttempts, 2);
    expect(authApi.parentPinStatusCalls, 1);
  });

  test('loginParent surfaces two-factor challenge details from backend',
      () async {
    authApi.loginError = DioException(
      requestOptions: RequestOptions(path: '/auth/login'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/login'),
        statusCode: 401,
        data: const {
          'detail': {
            'code': 'PARENT_TWO_FACTOR_REQUIRED',
            'message': 'Two-factor authentication code is required',
            'two_factor_method': 'totp',
          },
        },
      ),
    );

    expect(
      () => repository.loginParent(
        email: 'parent@example.com',
        password: 'Password123!',
      ),
      throwsA(
        isA<ParentAuthException>()
            .having((e) => e.requiresTwoFactor, 'requiresTwoFactor', isTrue)
            .having((e) => e.twoFactorMethod, 'twoFactorMethod', 'totp')
            .having(
              (e) => e.message,
              'message',
              'Two-factor authentication code is required',
            ),
      ),
    );
  });

  test('loginParent forwards optional two-factor code to auth API', () async {
    authApi.loginPayload = AuthSessionPayload(
      accessToken: 'parent.jwt',
      refreshToken: 'refresh.jwt',
      user: Map<String, dynamic>.from(
        _parentAuthRaw(
          accessToken: 'parent.jwt',
          refreshToken: 'refresh.jwt',
        )['user'] as Map<String, dynamic>,
      ),
      raw: _parentAuthRaw(
        accessToken: 'parent.jwt',
        refreshToken: 'refresh.jwt',
      ),
    );

    final user = await repository.loginParent(
      email: 'parent@example.com',
      password: 'Password123!',
      twoFactorCode: '123456',
    );

    expect(user, isNotNull);
    expect(authApi.lastLoginTwoFactorCode, '123456');
  });
}
