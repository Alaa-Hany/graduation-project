import 'package:dio/dio.dart';
import 'package:kinder_world/core/network/network_service.dart';

class AiBuddyApi {
  const AiBuddyApi(this._network);

  final NetworkService _network;

  Future<Map<String, dynamic>> startSession({
    required int childId,
    required String accessToken,
    bool forceNew = false,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/ai-buddy/sessions',
      data: {
        'child_id': childId,
        'force_new': forceNew,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> getCurrentSession({
    required int childId,
    required String accessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/ai-buddy/sessions/current',
      queryParameters: {'child_id': childId},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> getSession({
    required int sessionId,
    required String accessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/ai-buddy/sessions/$sessionId',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> sendMessage({
    required int sessionId,
    required int childId,
    required String content,
    required String accessToken,
    String? clientMessageId,
    String? quickAction,
  }) async {
    final response = await _network.post<Map<String, dynamic>>(
      '/ai-buddy/sessions/$sessionId/messages',
      data: {
        'child_id': childId,
        'content': content,
        if (clientMessageId != null) 'client_message_id': clientMessageId,
        if (quickAction != null) 'quick_action': quickAction,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> getChildVisibilitySummary({
    required int childId,
    required String accessToken,
  }) async {
    final response = await _network.get<Map<String, dynamic>>(
      '/ai-buddy/children/$childId/visibility',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  Future<Map<String, dynamic>> deleteChildHistory({
    required int childId,
    required String accessToken,
  }) async {
    final response = await _network.delete<Map<String, dynamic>>(
      '/ai-buddy/children/$childId/history',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
