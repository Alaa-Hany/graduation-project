import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/subscription/subscription_return.dart';

void main() {
  group('SubscriptionReturnPayload', () {
    test('parses checkout success with session id', () {
      final payload = SubscriptionReturnPayload.fromQuery({
        'flow': 'checkout',
        'result': 'success',
        'session_id': 'cs_test_123',
      });

      expect(payload, isNotNull);
      expect(payload!.flow, 'checkout');
      expect(payload.result, 'success');
      expect(payload.sessionId, 'cs_test_123');
    });

    test('normalizes canceled status', () {
      final payload = SubscriptionReturnPayload.fromQuery({
        'status': 'canceled',
      });

      expect(payload, isNotNull);
      expect(payload!.result, 'canceled');
      expect(payload.flow, 'portal');
    });
  });
}
