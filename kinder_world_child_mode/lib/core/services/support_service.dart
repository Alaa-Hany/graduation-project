import 'package:dio/dio.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

class SupportService {
  SupportService({
    required NetworkService networkService,
    required Logger logger,
  })  : _networkService = networkService,
        _logger = logger;

  final NetworkService _networkService;
  final Logger _logger;

  Future<SupportTicketRecord> sendContactMessage({
    required String subject,
    required String message,
    required String category,
  }) async {
    try {
      final response = await _networkService.post<Map<String, dynamic>>(
        '/support/contact',
        data: {
          'subject': subject.trim(),
          'message': message.trim(),
          'category': category,
        },
      );
      final body = Map<String, dynamic>.from(response.data ?? const {});
      return SupportTicketRecord.fromJson(
        Map<String, dynamic>.from(body['item'] as Map),
      );
    } on DioException catch (e) {
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
      final response = await _networkService.get<List<dynamic>>(
        '/support/faq',
      );

      if (response.data == null) {
        return [];
      }

      return (response.data as List)
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
}
