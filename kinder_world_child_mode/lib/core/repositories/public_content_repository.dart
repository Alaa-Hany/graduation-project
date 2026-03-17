import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/public_content.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

class PublicContentRepository {
  PublicContentRepository({
    required NetworkService networkService,
    required Logger logger,
  })  : _networkService = networkService,
        _logger = logger;

  final NetworkService _networkService;
  final Logger _logger;

  Future<List<PublicContentCategory>> fetchCategories() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/child/categories',
      );
      final items = response.data?['items'];
      if (items is! List) {
        return const [];
      }
      return items
          .whereType<Map>()
          .map((item) => PublicContentCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      _logger.w('Error fetching child content categories: $e');
      return const [];
    }
  }

  Future<List<PublicContentItem>> fetchItems({
    String? categorySlug,
    String? contentType,
    String? search,
    int? age,
  }) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/child/items',
        queryParameters: {
          if (categorySlug != null && categorySlug.isNotEmpty)
            'category_slug': categorySlug,
          if (contentType != null && contentType.isNotEmpty)
            'content_type': contentType,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (age != null) 'age': age,
        },
      );
      final items = response.data?['items'];
      if (items is! List) {
        return const [];
      }
      return items
          .whereType<Map>()
          .map((item) => PublicContentItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      _logger.w('Error fetching child content items: $e');
      return const [];
    }
  }

  Future<PublicContentItem?> fetchItem(String slug) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/child/items/$slug',
      );
      final item = response.data?['item'];
      if (item is! Map) {
        return null;
      }
      return PublicContentItem.fromJson(Map<String, dynamic>.from(item));
    } catch (e) {
      _logger.w('Error fetching child content item $slug: $e');
      return null;
    }
  }
}

final publicContentRepositoryProvider = Provider<PublicContentRepository>((ref) {
  return PublicContentRepository(
    networkService: ref.watch(networkServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});
