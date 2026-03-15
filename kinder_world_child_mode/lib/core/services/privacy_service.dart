import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

class PrivacyService {
  final NetworkService _networkService;
  final Logger _logger;

  PrivacyService({
    required NetworkService networkService,
    required Logger logger,
  })  : _networkService = networkService,
        _logger = logger;

  Future<PrivacySettings> getPrivacySettings() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/privacy/settings',
      );

      if (response.data == null) {
        return PrivacySettings.defaults();
      }

      return PrivacySettings.fromJson(response.data!);
    } catch (e) {
      _logger.e('Error getting privacy settings: $e');
      return PrivacySettings.defaults();
    }
  }

  Future<PrivacySettings?> updatePrivacySettings(
    PrivacySettings settings,
  ) async {
    try {
      final response = await _networkService.put<Map<String, dynamic>>(
        '/privacy/settings',
        data: settings.toJson(),
      );

      final body = response.data;
      if (body == null) {
        return settings;
      }
      if (body.containsKey('analytics_enabled') ||
          body.containsKey('personalized_recommendations') ||
          body.containsKey('data_collection_opt_out')) {
        return PrivacySettings.fromJson(body);
      }
      final success = body['success'] == true;
      return success ? settings : null;
    } catch (e) {
      _logger.e('Error updating privacy settings: $e');
      return null;
    }
  }
}
