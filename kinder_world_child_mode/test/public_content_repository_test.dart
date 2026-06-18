import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/repositories/public_content_repository.dart';
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
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
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
  group('PublicContentRepository', () {
    late _QueuedAdapter adapter;
    late PublicContentRepository repository;

    setUp(() {
      adapter = _QueuedAdapter(<_QueuedResponse>[]);
      final dio = Dio()..httpClientAdapter = adapter;
      final network = NetworkService(
        dio: dio,
        secureStorage: _TestSecureStorage(),
        logger: Logger(),
      );
      repository = PublicContentRepository(
        networkService: network,
        logger: Logger(),
      );
    });

    test('fetchCategories parses category items', () async {
      adapter._responses.add(
        const _QueuedResponse(
          200,
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'slug': 'educational',
                'title_en': 'Educational',
                'title_ar': 'تعليمي',
                'content_count': 2,
                'quiz_count': 1,
              },
            ],
          },
        ),
      );

      final categories = await repository.fetchCategories();

      expect(adapter.lastOptions?.path, '/api/v1/content/child/categories');
      expect(categories, hasLength(1));
      expect(categories.single.slug, 'educational');
    });

    test('fetchItems parses published child content items', () async {
      adapter._responses.add(
        const _QueuedResponse(
          200,
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'slug': 'counting-fun',
                'content_type': 'lesson',
                'title_en': 'Counting Fun',
                'title_ar': 'العد الممتع',
                'metadata_json': <String, dynamic>{'level': 'beginner'},
                'quizzes': <Map<String, dynamic>>[],
              },
            ],
          },
        ),
      );

      final items = await repository.fetchItems(
        categorySlug: 'educational',
        contentType: 'lesson',
        search: 'counting',
        age: 7,
      );

      expect(adapter.lastOptions?.path, '/api/v1/content/child/items');
      expect(adapter.lastOptions?.queryParameters['category_slug'], 'educational');
      expect(adapter.lastOptions?.queryParameters['content_type'], 'lesson');
      expect(items, hasLength(1));
      expect(items.single.slug, 'counting-fun');
      expect(items.single.metadata['level'], 'beginner');
    });

    test('fetchItem parses single child content payload', () async {
      adapter._responses.add(
        const _QueuedResponse(
          200,
          <String, dynamic>{
            'item': <String, dynamic>{
              'id': 9,
              'slug': 'bedtime-story',
              'content_type': 'story',
              'title_en': 'Bedtime Story',
              'title_ar': 'قصة قبل النوم',
              'quizzes': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'title_en': 'Story Quiz',
                  'title_ar': 'اختبار القصة',
                  'question_count': 2,
                  'questions_json': <Map<String, dynamic>>[],
                },
              ],
            },
          },
        ),
      );

      final item = await repository.fetchItem('bedtime-story');

      expect(adapter.lastOptions?.path, '/api/v1/content/child/items/bedtime-story');
      expect(item?.slug, 'bedtime-story');
      expect(item?.quizzes, hasLength(1));
    });
  });
}
