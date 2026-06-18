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
  test('content service fetches FAQ items from /content/help-faq response',
      () async {
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

    expect(adapter.lastOptions?.path, '/api/v1/content/help-faq');
    expect(items, hasLength(1));
    expect(items.first.question, 'How do I add a child profile?');
  });

  test('content service resolves legal content from /legal/privacy body',
      () async {
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

    expect(adapter.lastOptions?.path, '/api/v1/legal/privacy');
    expect(body, 'Privacy body from backend');
  });

  test('content service resolves legal payload content fallback', () async {
    final adapter = _QueuedAdapter([
      const _QueuedResponse(
        200,
        {
          'content': 'COPPA fallback content',
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

    final payload = await service.getLegalPayload('coppa');

    expect(adapter.lastOptions?.path, '/api/v1/legal/coppa');
    expect(payload.resolvedBody, 'COPPA fallback content');
  });

  test('content service resolves localized legal item body fallback', () async {
    final adapter = _QueuedAdapter([
      const _QueuedResponse(
        200,
        {
          'item': {
            'id': 4,
            'slug': 'privacy-policy',
            'content_type': 'legal',
            'title_en': 'Privacy Policy',
            'title_ar': 'سياسة الخصوصية',
            'body_en': 'Privacy body from item',
            'body_ar': 'محتوى الخصوصية من العنصر',
          },
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

    final payload = await service.getLegalPayload('privacy');

    expect(adapter.lastOptions?.path, '/api/v1/legal/privacy');
    expect(payload.resolvedBody, 'Privacy body from item');
    expect(
      payload.resolvedBodyForLanguageCode('ar'),
      'محتوى الخصوصية من العنصر',
    );
  });

  test('content service fetches about body from /content/about', () async {
    final adapter = _QueuedAdapter([
      const _QueuedResponse(
        200,
        {
          'body': 'About Kinder World',
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

    final body = await service.getAbout();

    expect(adapter.lastOptions?.path, '/api/v1/content/about');
    expect(body, 'About Kinder World');
  });
}
