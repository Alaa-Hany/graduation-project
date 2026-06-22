// Unit tests for [DeferredOperationsQueue] and [DeferredOperation] — the
// offline HTTP retry queue. Uses mock SharedPreferences and a fake
// NetworkService.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/offline/deferred_operations_queue.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNetworkService extends Fake implements NetworkService {
  bool connected = true;
  bool failNonOffline = false;
  bool failOffline = false;
  final List<String> calls = [];

  @override
  Future<bool> isConnected() async => connected;

  Response<T> _maybeThrow<T>(String tag, String path) {
    calls.add('$tag $path');
    if (failOffline) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
      );
    }
    if (failNonOffline) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> post<T>(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) async =>
      _maybeThrow<T>('POST', path);

  @override
  Future<Response<T>> put<T>(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) async =>
      _maybeThrow<T>('PUT', path);

  @override
  Future<Response<T>> patch<T>(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) async =>
      _maybeThrow<T>('PATCH', path);

  @override
  Future<Response<T>> delete<T>(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) async =>
      _maybeThrow<T>('DELETE', path);
}

void main() {
  late DeferredOperationsQueue queue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    queue = DeferredOperationsQueue(
      preferences: prefs,
      logger: Logger(level: Level.off),
    );
  });

  group('DeferredOperation', () {
    test('JSON round-trip preserves fields', () {
      final op = DeferredOperation(
        id: 'op1',
        method: 'POST',
        path: '/x',
        createdAt: DateTime(2025, 1, 1),
        data: {'a': 1},
        queryParameters: {'q': '2'},
        attempts: 1,
        lastError: 'boom',
      );
      final back = DeferredOperation.fromJson(op.toJson());
      expect(back.id, 'op1');
      expect(back.method, 'POST');
      expect(back.data, {'a': 1});
      expect(back.attempts, 1);
      expect(back.lastError, 'boom');
    });

    test('copyWith updates attempts and lastError', () {
      final op = DeferredOperation(
        id: 'op1',
        method: 'POST',
        path: '/x',
        createdAt: DateTime(2025, 1, 1),
      );
      final updated = op.copyWith(attempts: 3, lastError: 'err');
      expect(updated.attempts, 3);
      expect(updated.lastError, 'err');
      expect(updated.id, 'op1');
    });

    test('fromJson tolerates missing/!typed fields', () {
      final op = DeferredOperation.fromJson({'path': '/y'});
      expect(op.method, 'POST'); // default
      expect(op.path, '/y');
      expect(op.attempts, 0);
    });
  });

  group('enqueue & read', () {
    test('starts empty', () async {
      expect(await queue.getPendingOperations(), isEmpty);
      expect(await queue.pendingCount(), 0);
    });

    test('enqueue adds operations and upcases method', () async {
      await queue.enqueueHttpOperation(method: 'post', path: '/a', data: {'x': 1});
      await queue.enqueueHttpOperation(method: 'put', path: '/b');
      final pending = await queue.getPendingOperations();
      expect(pending.length, 2);
      expect(pending.first.method, 'POST');
      expect(pending[1].method, 'PUT');
      expect(await queue.pendingCount(), 2);
    });

    test('getPendingOperations returns empty on corrupt payload', () async {
      SharedPreferences.setMockInitialValues({
        'offline.deferred_operations.queue': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final q = DeferredOperationsQueue(
          preferences: prefs, logger: Logger(level: Level.off));
      expect(await q.getPendingOperations(), isEmpty);
    });
  });

  group('processPending', () {
    test('returns 0 when offline', () async {
      await queue.enqueueHttpOperation(method: 'POST', path: '/a');
      final net = _FakeNetworkService()..connected = false;
      expect(await queue.processPending(net), 0);
      expect(await queue.pendingCount(), 1); // untouched
    });

    test('processes all when online and clears queue', () async {
      await queue.enqueueHttpOperation(method: 'POST', path: '/a');
      await queue.enqueueHttpOperation(method: 'DELETE', path: '/b');
      final net = _FakeNetworkService();
      final processed = await queue.processPending(net);
      expect(processed, 2);
      expect(await queue.pendingCount(), 0);
      expect(net.calls, ['POST /a', 'DELETE /b']);
    });

    test('keeps operation with incremented attempts on non-offline error',
        () async {
      await queue.enqueueHttpOperation(method: 'POST', path: '/a');
      final net = _FakeNetworkService()..failNonOffline = true;
      final processed = await queue.processPending(net);
      expect(processed, 0);
      final pending = await queue.getPendingOperations();
      expect(pending.single.attempts, 1);
    });

    test('stops on offline error and preserves remaining', () async {
      await queue.enqueueHttpOperation(method: 'POST', path: '/a');
      await queue.enqueueHttpOperation(method: 'POST', path: '/b');
      final net = _FakeNetworkService()..failOffline = true;
      final processed = await queue.processPending(net);
      expect(processed, 0);
      expect(await queue.pendingCount(), 2); // both retained
    });
  });
}
