// Unit tests for [SupportService] — contact messages (online/offline/error),
// ticket listing/detail/reply, and FAQ fetching. NetworkService and the
// deferred-operations queue are faked.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/offline/deferred_operations_queue.dart';
import 'package:kinder_world/core/services/support_service.dart';
import 'package:logger/logger.dart';

class _FakeNetworkService extends Fake implements NetworkService {
  Object? nextData;
  DioException? nextError;

  Response<T> _response<T>(String path) => Response<T>(
        requestOptions: RequestOptions(path: path),
        data: nextData as T,
      );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (nextError != null) throw nextError!;
    return _response<T>(path);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (nextError != null) throw nextError!;
    return _response<T>(path);
  }
}

class _FakeQueue extends Fake implements DeferredOperationsQueue {
  int enqueuedCount = 0;
  String? lastPath;

  @override
  Future<void> enqueueHttpOperation({
    required String method,
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    enqueuedCount++;
    lastPath = path;
  }
}

DioException _dio(DioExceptionType type, {Object? responseData}) {
  final ro = RequestOptions(path: '/x');
  return DioException(
    requestOptions: ro,
    type: type,
    response: responseData == null
        ? null
        : Response(requestOptions: ro, data: responseData),
  );
}

Map<String, dynamic> _ticketJson({int id = 1, String status = 'open'}) => {
      'id': id,
      'subject': 'Help',
      'message': 'I need help',
      'category': 'general',
      'status': status,
      'reply_count': 0,
    };

void main() {
  late _FakeNetworkService net;
  late _FakeQueue queue;
  late SupportService service;

  setUp(() {
    net = _FakeNetworkService();
    queue = _FakeQueue();
    service = SupportService(
      networkService: net,
      deferredQueue: queue,
      logger: Logger(level: Level.off),
    );
  });

  group('sendContactMessage', () {
    test('returns parsed ticket on success', () async {
      net.nextData = {'item': _ticketJson(id: 42)};

      final ticket = await service.sendContactMessage(
        subject: ' Help ',
        message: ' please ',
        category: 'general',
      );

      expect(ticket.id, 42);
      expect(queue.enqueuedCount, 0);
    });

    test('queues offline and returns a placeholder when connection fails',
        () async {
      net.nextError = _dio(DioExceptionType.connectionError);

      final ticket = await service.sendContactMessage(
        subject: 'Help',
        message: 'offline please',
        category: 'general',
      );

      expect(ticket.status, 'queued_offline');
      expect(ticket.id, lessThan(0)); // negative placeholder id
      expect(queue.enqueuedCount, 1);
      expect(queue.lastPath, '/support/contact');
    });

    test('rethrows server error detail on non-offline failure', () async {
      net.nextError = _dio(
        DioExceptionType.badResponse,
        responseData: {'detail': 'Subject too long'},
      );

      expect(
        () => service.sendContactMessage(
          subject: 'Help',
          message: 'hi',
          category: 'general',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Subject too long'))),
      );
      expect(queue.enqueuedCount, 0);
    });
  });

  group('tickets', () {
    test('fetchTickets parses a list', () async {
      net.nextData = {
        'items': [_ticketJson(id: 1), _ticketJson(id: 2)],
      };
      final tickets = await service.fetchTickets();
      expect(tickets.map((t) => t.id), [1, 2]);
    });

    test('fetchTickets returns empty list when items missing', () async {
      net.nextData = <String, dynamic>{};
      expect(await service.fetchTickets(), isEmpty);
    });

    test('fetchTicketDetail parses single ticket', () async {
      net.nextData = {'item': _ticketJson(id: 7)};
      final ticket = await service.fetchTicketDetail(7);
      expect(ticket.id, 7);
    });

    test('replyToTicket parses updated ticket', () async {
      net.nextData = {'item': _ticketJson(id: 7, status: 'open')};
      final ticket = await service.replyToTicket(ticketId: 7, message: 'thanks');
      expect(ticket.id, 7);
    });

    test('fetchTickets throws on Dio error', () async {
      net.nextError = _dio(DioExceptionType.badResponse,
          responseData: {'detail': 'boom'});
      expect(() => service.fetchTickets(), throwsA(isA<Exception>()));
    });
  });

  group('FAQ', () {
    test('getFaq returns list of maps', () async {
      net.nextData = {
        'items': [
          {'q': 'a', 'a': 'b'},
        ],
      };
      final faq = await service.getFaq();
      expect(faq.length, 1);
      expect(faq.first['q'], 'a');
    });

    test('getFaq returns empty when items not a list', () async {
      net.nextData = {'items': 'not-a-list'};
      expect(await service.getFaq(), isEmpty);
    });

    test('getFaq returns empty on error', () async {
      net.nextError = _dio(DioExceptionType.connectionError);
      expect(await service.getFaq(), isEmpty);
    });
  });
}
