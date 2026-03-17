import 'package:dio/dio.dart';
import 'package:kinder_world/core/offline/deferred_operations_queue.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

class SupportService {
  SupportService({
    required NetworkService networkService,
    required DeferredOperationsQueue deferredQueue,
    required Logger logger,
  })  : _networkService = networkService,
        _deferredQueue = deferredQueue,
        _logger = logger;

  final NetworkService _networkService;
  final DeferredOperationsQueue _deferredQueue;
  final Logger _logger;

  Future<SupportTicketRecord> sendContactMessage({
    required String subject,
    required String message,
    required String category,
  }) async {
    final payload = {
      'subject': subject.trim(),
      'message': message.trim(),
      'category': category,
    };
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/support/contact',
        data: payload,
      );
      final body = Map<String, dynamic>.from(response.data ?? const {});
      return SupportTicketRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map),
      );
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        await _deferredQueue.enqueueHttpOperation(
          method: 'POST',
          path: '/support/contact',
          data: payload,
        );
        final pendingId = -DateTime.now().millisecondsSinceEpoch;
        return SupportTicketRecord(
          id: pendingId,
          subject: subject.trim(),
          message: message.trim(),
          category: category,
          status: 'queued_offline',
          replyCount: 0,
          createdAt: DateTime.now().toIso8601String(),
          preview: message.trim(),
        );
      }
      _logger.e('Error sending contact message: $e');
      throw Exception(_extractError(e));
    }
  }

  Future<List<SupportTicketRecord>> fetchTickets() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/support/tickets',
      );
      final body = Map<String, dynamic>.from(response.data ?? const {});
      return (body['items'] as List<dynamic>? ?? const [])
          .map((item) => SupportTicketRecord.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } on DioException catch (e) {
      _logger.e('Error loading support tickets: $e');
      throw Exception(_extractError(e));
    }
  }

  Future<SupportTicketRecord> fetchTicketDetail(int ticketId) async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/support/tickets/$ticketId',
      );
      final body = Map<String, dynamic>.from(response.data ?? const {});
      return SupportTicketRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map),
      );
    } on DioException catch (e) {
      _logger.e('Error loading support ticket detail: $e');
      throw Exception(_extractError(e));
    }
  }

  Future<SupportTicketRecord> replyToTicket({
    required int ticketId,
    required String message,
  }) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/support/tickets/$ticketId/reply',
        data: {'message': message.trim()},
      );
      final body = Map<String, dynamic>.from(response.data ?? const {});
      return SupportTicketRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map),
      );
    } on DioException catch (e) {
      _logger.e('Error replying to support ticket: $e');
      throw Exception(_extractError(e));
    }
  }

  Future<List<Map<String, dynamic>>> getFaq() async {
    try {
      final response = await _networkService.get<Map<String, dynamic>>(
        '/content/help-faq',
      );

      final rawItems = response.data?['items'];
      if (rawItems is! List) {
        return [];
      }

      return rawItems
          .map<Map<String, dynamic>>(
            (e) => e is Map<String, dynamic> ? e : {},
          )
          .toList();
    } catch (e) {
      _logger.e('Error getting FAQ: $e');
      return [];
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map<String, dynamic>) {
        final message = detail['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    }
    return e.message ?? 'Support request failed';
  }

  bool _isOfflineError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
}
