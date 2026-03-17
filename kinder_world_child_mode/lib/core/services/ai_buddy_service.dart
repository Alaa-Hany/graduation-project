import 'package:dio/dio.dart';
import 'package:kinder_world/core/api/ai_buddy_api.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class AiBuddyUnavailableException implements Exception {
  const AiBuddyUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiBuddyService {
  const AiBuddyService({
    required AiBuddyApi api,
    required SecureStorage secureStorage,
    required Logger logger,
  })  : _api = api,
        _secureStorage = secureStorage,
        _logger = logger;

  final AiBuddyApi _api;
  final SecureStorage _secureStorage;
  final Logger _logger;

  Future<AiBuddyConversation> getOrStartCurrentSession({
    required int childId,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      final current = await _api.getCurrentSession(
        childId: childId,
        accessToken: token,
      );
      final conversation = AiBuddyConversation.fromJson(current);
      if (conversation.session != null) {
        return conversation;
      }
      final started = await _api.startSession(
        childId: childId,
        accessToken: token,
      );
      return AiBuddyConversation.fromJson(started);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<AiBuddyConversation> startSession({
    required int childId,
    bool forceNew = false,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      final response = await _api.startSession(
        childId: childId,
        accessToken: token,
        forceNew: forceNew,
      );
      return AiBuddyConversation.fromJson(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<AiBuddyConversation> getSession({
    required int sessionId,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      final response = await _api.getSession(
        sessionId: sessionId,
        accessToken: token,
      );
      return AiBuddyConversation.fromJson(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<AiBuddySendResult> sendMessage({
    required int sessionId,
    required int childId,
    required String content,
    String? clientMessageId,
    String? quickAction,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      final response = await _api.sendMessage(
        sessionId: sessionId,
        childId: childId,
        content: content,
        accessToken: token,
        clientMessageId: clientMessageId,
        quickAction: quickAction,
      );
      return AiBuddySendResult.fromJson(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<AiBuddyVisibilitySummary> getChildVisibilitySummary({
    required int childId,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      final response = await _api.getChildVisibilitySummary(
        childId: childId,
        accessToken: token,
      );
      return AiBuddyVisibilitySummary.fromJson(response);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> deleteChildHistory({
    required int childId,
  }) async {
    final token = await _requireParentAccessToken();
    try {
      return await _api.deleteChildHistory(
        childId: childId,
        accessToken: token,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<String> _requireParentAccessToken() async {
    final token = await _secureStorage.getParentAccessToken();
    if (token == null || token.isEmpty) {
      throw const AiBuddyUnavailableException(
        'Parent authentication is required to use AI Buddy in child mode.',
      );
    }
    return token;
  }

  Exception _mapDioError(DioException error) {
    final data = error.response?.data;
    _logger.e('AI Buddy request failed: ${error.response?.statusCode} ${error.message}');
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        final code = detail['code']?.toString();
        final message = detail['message']?.toString();
        if (code == 'AI_BUDDY_DISABLED') {
          return AiBuddyUnavailableException(message ?? 'AI Buddy is currently unavailable.');
        }
        if (message != null && message.isNotEmpty) {
          return Exception(message);
        }
      }
      if (detail is String && detail.isNotEmpty) {
        return Exception(detail);
      }
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return Exception(error.message!.trim());
    }
    return Exception('AI Buddy request failed.');
  }
}
