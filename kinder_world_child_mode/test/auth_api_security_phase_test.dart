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
      jsonEncode(<String, dynamic>{'success': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

AuthApi _api(_RecordingAdapter adapter) => AuthApi(
      NetworkService(
        dio: Dio()..httpClientAdapter = adapter,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      ),
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
}
