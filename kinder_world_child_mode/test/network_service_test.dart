import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  _TestSecureStorage(this.token);

  final String? token;

  @override
  bool get hasCachedAuthToken => true;

  @override
  String? get cachedAuthToken => token;

  @override
  Future<String?> getAuthToken() async => token;
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
      jsonEncode(<String, dynamic>{'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('network service injects general auth token when no override exists',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent.jwt.token'),
      logger: Logger(),
    );

    await network.get('/demo');

    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer parent.jwt.token',
    );
  });

  test('network service keeps explicit authorization header intact', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent.jwt.token'),
      logger: Logger(),
    );

    await network.get(
      '/admin/auth/me',
      options: Options(headers: {'Authorization': 'Bearer admin.jwt.token'}),
    );

    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer admin.jwt.token',
    );
  });

  test('network service removes authorization when explicitly disabled',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent.jwt.token'),
      logger: Logger(),
    );

    await network.post(
      '/admin/auth/login',
      options: Options(headers: {'Authorization': null}),
    );

    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });

  test('network service never sends child session markers as bearer tokens',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('child_session_42'),
      logger: Logger(),
    );

    await network.get('/anything');

    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });
}
