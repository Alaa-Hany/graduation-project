import 'package:kinder_world/core/network/network_service.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

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

  /// Analytics writes carry an Idempotency-Key so the backend stores a record
  /// once even if the request is retried (network retry, or the record being
  /// re-synced later). Callers pass a key derived from the local record id so
  /// it stays the same across app restarts; otherwise a random one is used,
  /// which still covers automatic network retries of the same call.
  Options _ingestOptions(String? parentAccessToken, String? idempotencyKey) {
    final key = (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        ? idempotencyKey.trim()
        : _uuid.v4();
    return Options(
      headers: {
        if (parentAccessToken != null && parentAccessToken.isNotEmpty)
          'Authorization': 'Bearer $parentAccessToken',
        NetworkService.idempotencyKeyHeader: key,
      },
    );
  }

  static const _uuid = Uuid();

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

  Future<Map<String, dynamic>> getDevelopmentReport({
    required int childId,
    int days = 30,
    String language = 'ar',
    String? parentAccessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/reports/development',
      queryParameters: {
        'child_id': childId,
        'days': days,
        'language': language,
      },
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> ingestActivityEvent(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
    String? idempotencyKey,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/analytics/events',
      data: payload,
      options: _ingestOptions(parentAccessToken, idempotencyKey),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> ingestSessionLog(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
    String? idempotencyKey,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/analytics/sessions',
      data: payload,
      options: _ingestOptions(parentAccessToken, idempotencyKey),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  /// Pushes the child's local-first gamification snapshot (coins, badges,
  /// achievements, reward-store purchases) so it survives a fresh device / web
  /// storage reset. `payload` is `{child_id, updated_at, data}`.
  Future<Map<String, dynamic>> syncGamificationState(
    Map<String, dynamic> payload, {
    String? parentAccessToken,
  }) async {
    final response = await _network.put<Map<String, dynamic>>(
      '/analytics/gamification',
      data: payload,
      options: _authorizedOptions(parentAccessToken),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
