import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/auth_api.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/services/device_identity_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      jsonEncode(<String, dynamic>{
        'success': true,
        'child_id': 7,
        'session_token': 'token',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('childLogin sends persistent device id', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = AuthApi(
      NetworkService(
        dio: dio,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      ),
      deviceIdentityService: DeviceIdentityService(sharedPreferences: prefs),
    );

    await api.childLogin(
      childId: '7',
      name: 'Mira',
      picturePassword: const ['apple', 'cat', 'dog'],
    );

    expect(adapter.lastOptions?.data['device_id'], isA<String>());
    expect(
        (adapter.lastOptions?.data['device_id'] as String).isNotEmpty, isTrue);
  });

  test('validateChildSession sends same persistent device id', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final service = DeviceIdentityService(sharedPreferences: prefs);
    final expectedDeviceId = await service.getDeviceId();
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = AuthApi(
      NetworkService(
        dio: dio,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      ),
      deviceIdentityService: service,
    );

    await api.validateChildSession(sessionToken: 'child-session-token');

    expect(adapter.lastOptions?.data['device_id'], expectedDeviceId);
  });

  test('childRegister sends parent authorization header to secured children endpoint',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = AuthApi(
      NetworkService(
        dio: dio,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      ),
    );

    await api.childRegister(
      name: 'Mira',
      picturePassword: const ['apple', 'cat', 'dog'],
      parentAccessToken: 'parent.jwt',
      parentEmail: 'parent@example.com',
      age: 7,
    );

    expect(adapter.lastOptions?.path, '/api/v1/children');
    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer parent.jwt',
    );
    expect(adapter.lastOptions?.data['parent_email'], 'parent@example.com');
  });
}
