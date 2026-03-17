import 'package:kinder_world/core/network/network_service.dart';
import 'package:dio/dio.dart';

class ReportsApi {
  const ReportsApi(this._network);

  final NetworkService _network;

  Options? _authorizedOptions(String? parentAccessToken) {
    if (parentAccessToken == null || parentAccessToken.isEmpty) {
      return null;
    }
    return Options(
      headers: {'Authorization': 'Bearer $parentAccessToken'},
    );
  }

  Future<Map<String, dynamic>> getBasicReports({
    int? childId,
    int days = 7,
    String? parentAccessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/reports/basic',
      queryParameters: {
        'days': days,
        if (childId != null) 'child_id': childId,
      },
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> getAdvancedReports({
    int? childId,
    int days = 30,
    String? parentAccessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/reports/advanced',
      queryParameters: {
        'days': days,
        if (childId != null) 'child_id': childId,
      },
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> ingestActivityEvent(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/analytics/events',
      data: payload,
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> ingestSessionLog(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/analytics/sessions',
      data: payload,
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
