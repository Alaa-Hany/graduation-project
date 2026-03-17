import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/faq_item.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

class ContentService {
  final NetworkService _networkService;
  final Logger _logger;

  ContentService({
    required NetworkService networkService,
    required Logger logger,
  })  : _networkService = networkService,
        _logger = logger;

  /// Get FAQ items (returns empty list if no API or error)
  Future<List<FaqItem>> getFaq() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/help-faq',
      );

      final data = response.data;
      final rawItems = data?['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        return [];
      }

      return rawItems
          .map((e) {
            try {
              return FaqItem.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<FaqItem>()
          .toList();
    } catch (e) {
      _logger.w('Error getting FAQ: $e');
      return [];
    }
  }

  /// Get legal content (returns empty string if no API or error)
  /// type can be: 'terms', 'privacy', 'coppa'
  Future<String> getLegal(String type) async {
    try {
      final endpoint = switch (type) {
        'terms' => '/legal/terms',
        'privacy' => '/legal/privacy',
        'coppa' => '/legal/coppa',
        _ => '/legal/terms',
      };
      final response =
          await _networkService.get<Map<String, dynamic>>(endpoint);

      if (response.data == null) {
        return '';
      }

      return response.data!['body'] as String? ??
          response.data!['content'] as String? ??
          '';
    } catch (e) {
      _logger.w('Error getting legal content: $e');
      return '';
    }
  }

  Future<String> getAbout() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/about',
      );
      if (response.data == null) {
        return '';
      }
      return response.data!['body'] as String? ?? '';
    } catch (e) {
      _logger.w('Error getting about content: $e');
      return '';
    }
  }
}

final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(
    networkService: ref.watch(networkServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});
