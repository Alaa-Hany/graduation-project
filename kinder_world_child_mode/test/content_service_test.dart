import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/services/content_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _TestSecureStorage extends SecureStorage {
  @override
  bool get hasCachedAuthToken => false;

  @override
  String? get cachedAuthToken => null;

  @override
  Future<String?> getAuthToken() async => null;
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._responses);

  final List<_QueuedResponse> _responses;
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
    final next = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(next.payload),
      next.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.payload);

  final int statusCode;
  final Map<String, dynamic> payload;
}

void main() {
  test('content service fetches FAQ items from /content/help-faq response', () async {
    final adapter = _QueuedAdapter([
      const _QueuedResponse(
        200,
        {
          'items': [
            {
              'id': 'faq-1',
              'question': 'How do I add a child profile?',
              'answer': 'Use parent dashboard.',
            },
          ],
        },
      ),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage(),
      logger: Logger(),
    );
    final service = ContentService(
      networkService: network,
      logger: Logger(),
    );

    final items = await service.getFaq();

    expect(adapter.lastOptions?.path, '/content/help-faq');
    expect(items, hasLength(1));
    expect(items.first.question, 'How do I add a child profile?');
  });

  test('content service resolves legal content from /legal/privacy body', () async {
    final adapter = _QueuedAdapter([
      const _QueuedResponse(
        200,
        {
          'body': 'Privacy body from backend',
        },
      ),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final network = NetworkService(
      dio: dio,
      secureStorage: _TestSecureStorage(),
      logger: Logger(),
    );
    final service = ContentService(
      networkService: network,
      logger: Logger(),
    );

    final body = await service.getLegal('privacy');

    expect(adapter.lastOptions?.path, '/legal/privacy');
    expect(body, 'Privacy body from backend');
  });
}
