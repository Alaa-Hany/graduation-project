import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => null;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.body = const {'success': true}});

  Map<String, dynamic> body;
  int status = 200;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

AuthApi _api(_RecordingAdapter adapter, {RegistrationTokenStore? store}) =>
    AuthApi(
      NetworkService(
        dio: Dio()..httpClientAdapter = adapter,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      ),
      registrationTokenStore: store,
    );

const _registerBody = {
  'success': true,
  'email': 'mona@example.com',
  'verification_required': true,
  'registration_token': 'reg-token-123',
};

Future<void> _register(AuthApi api) => api.register(
      name: 'Mona',
      email: ' Mona@Example.com ',
      password: 'Secret123!',
      confirmPassword: 'Secret123!',
    );

void main() {
  test('deleteAccount sends DELETE /auth/account with the password', () async {
    final adapter = _RecordingAdapter();
    await _api(adapter).deleteAccount(password: 'Secret123!');

    expect(adapter.lastOptions?.method, 'DELETE');
    expect(adapter.lastOptions?.path, '/api/v1/auth/account');
    expect(adapter.lastOptions?.data['password'], 'Secret123!');
    expect(
        (adapter.lastOptions?.data as Map).containsKey('two_factor_code'), isFalse);
  });

  test('deleteAccount includes a trimmed 2FA code when given', () async {
    final adapter = _RecordingAdapter();
    await _api(adapter)
        .deleteAccount(password: 'Secret123!', twoFactorCode: ' 123456 ');

    expect(adapter.lastOptions?.data['two_factor_code'], '123456');
  });

  test('childChangePassword sends the parent token, not the child session',
      () async {
    final adapter = _RecordingAdapter();
    await _api(adapter).childChangePassword(
      childId: '7',
      name: 'Mira',
      currentPicturePassword: const ['apple', 'cat', 'dog'],
      newPicturePassword: const ['tree', 'book', 'fish'],
      parentAccessToken: 'parent.jwt',
    );

    expect(adapter.lastOptions?.path, '/api/v1/auth/child/change-password');
    expect(adapter.lastOptions?.headers['Authorization'], 'Bearer parent.jwt');
  });

  test('verifyEmailOtp sends the registration token from register', () async {
    final adapter = _RecordingAdapter(body: const {
      'success': true,
      'email': 'mona@example.com',
      'verification_required': true,
      'registration_token': 'reg-token-123',
    });
    final api = _api(adapter);
    await api.register(
      name: 'Mona',
      email: ' Mona@Example.com ',
      password: 'Secret123!',
      confirmPassword: 'Secret123!',
    );
    await api.verifyEmailOtp(email: 'mona@example.com', otp: '123456');

    expect(adapter.lastOptions?.path, '/api/v1/auth/verify-email-otp');
    expect(adapter.lastOptions?.data['registration_token'], 'reg-token-123');

    // Used once: a later verify (e.g. after logging in again) goes without it.
    await api.verifyEmailOtp(email: 'mona@example.com', otp: '123456');
    expect(
      (adapter.lastOptions?.data as Map).containsKey('registration_token'),
      isFalse,
    );
  });

  test('registration token survives a reload (new AuthApi, same storage)',
      () async {
    final store = MemoryRegistrationTokenStore(); // stands in for secure storage
    final adapter = _RecordingAdapter(body: Map.of(_registerBody));
    await _register(_api(adapter, store: store));

    // Page reload / app restart: a fresh AuthApi reading the same storage.
    final afterReload = _api(adapter, store: store);
    await afterReload.verifyEmailOtp(email: 'mona@example.com', otp: '123456');

    expect(adapter.lastOptions?.data['registration_token'], 'reg-token-123');
    expect(await store.read('mona@example.com'), isNull);
  });

  test('a wrong code keeps the registration token for the next try', () async {
    final store = MemoryRegistrationTokenStore();
    final adapter = _RecordingAdapter(body: Map.of(_registerBody));
    final api = _api(adapter, store: store);
    await _register(api);

    adapter
      ..status = 400
      ..body = {
        'detail': {'code': 'INVALID_OR_EXPIRED_OTP'},
      };
    await expectLater(
      api.verifyEmailOtp(email: 'mona@example.com', otp: '000000'),
      throwsA(isA<DioException>()),
    );
    expect(await store.read('mona@example.com'), 'reg-token-123');

    adapter
      ..status = 200
      ..body = {'success': true};
    await api.verifyEmailOtp(email: 'mona@example.com', otp: '123456');
    expect(adapter.lastOptions?.data['registration_token'], 'reg-token-123');
  });

  test('the app stores the registration token in secure storage', () {
    final store = SecureRegistrationTokenStore(_TestSecureStorage());
    expect(store, isA<RegistrationTokenStore>());
  });
}
