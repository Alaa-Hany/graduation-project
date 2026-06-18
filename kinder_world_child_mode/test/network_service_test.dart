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

class _CancelableQueuedAdapter implements HttpClientAdapter {
  _CancelableQueuedAdapter(this._responses);

  final List<_QueuedResponse> _responses;
  final Completer<void> firstFetchStarted = Completer<void>();
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
    if (!firstFetchStarted.isCompleted) {
      firstFetchStarted.complete();
    }

    final next = _responses.removeAt(0);
    final responseFuture = Future<ResponseBody>.delayed(
      next.delay,
      () => ResponseBody.fromString(
        jsonEncode(next.payload),
        next.statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    if (cancelFuture == null) {
      return responseFuture;
    }

    return Future.any([
      responseFuture,
      cancelFuture.then<ResponseBody>((_) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'request_cancelled',
        );
      }),
    ]);
  }
}

class _QueuedResponse {
  const _QueuedResponse(
    this.statusCode,
    this.payload, {
    this.delay = Duration.zero,
  });

  final int statusCode;
  final Map<String, dynamic> payload;
  final Duration delay;
}

String _childSessionJwt() {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"token_type":"child_session","exp":4102444800}'),
  );
  return '$header.$payload.signature';
}

void main() {
  test('network service injects general auth token when no override exists',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent_test_token_placeholder'),
      logger: Logger(),
    );

    await network.get('/demo');

    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer parent_test_token_placeholder',
    );
  });

  test('network service keeps explicit authorization header intact', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent_test_token_placeholder'),
      logger: Logger(),
    );

    await network.get(
      '/admin/auth/me',
      options: Options(
        headers: {'Authorization': 'Bearer admin_test_token_placeholder'},
      ),
    );

    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer admin_test_token_placeholder',
    );
  });

  test('network service removes authorization when explicitly disabled',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent_test_token_placeholder'),
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

  test('network service never sends child session JWTs as bearer tokens',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage(_childSessionJwt()),
      logger: Logger(),
    );

    await network.get('/anything');

    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });

  test('cancelAllRequests cancels in-flight requests without closing Dio',
      () async {
    final adapter = _CancelableQueuedAdapter([
      const _QueuedResponse(
        200,
        {'ok': false},
        delay: Duration(seconds: 5),
      ),
      const _QueuedResponse(200, {'ok': true}),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage('parent_test_token_placeholder'),
      logger: Logger(),
    );

    final pendingRequest = network.get<Map<String, dynamic>>('/slow');
    await adapter.firstFetchStarted.future;

    network.cancelAllRequests();

    await expectLater(
      pendingRequest,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );

    final followUpResponse = await network.get<Map<String, dynamic>>('/after');

    expect(followUpResponse.statusCode, 200);
    expect(followUpResponse.data?['ok'], isTrue);
    expect(adapter.lastOptions?.path, '/api/v1/after');
  });
}
