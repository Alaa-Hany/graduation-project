import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';

void main() {
  test('AdminSubscriptionRecord parses lifecycle and history collections', () {
    final record = AdminSubscriptionRecord.fromJson({
      'id': 12,
      'user_id': 12,
      'email': 'parent@example.com',
      'name': 'Parent',
      'plan': 'PREMIUM',
      'status': 'active',
      'is_active': true,
      'child_count': 2,
      'payment_method_count': 1,
      'limits': {'max_children': 3},
      'features': {'advanced_reports': true},
      'lifecycle': {
        'current_plan_id': 'PREMIUM',
        'status': 'active',
        'started_at': '2026-03-17T10:00:00Z',
        'expires_at': '2026-04-16T10:00:00Z',
        'will_renew': true,
        'last_payment_status': 'succeeded',
        'provider': 'internal',
        'is_active': true,
      },
      'history_summary': {
        'event_count': 3,
        'billing_transaction_count': 2,
        'payment_attempt_count': 2,
      },
      'recent_events': [
        {
          'id': 1,
          'event_type': 'activate',
          'plan_id': 'PREMIUM',
          'status': 'active',
          'source': 'parent_select',
        },
      ],
      'billing_history': [
        {
          'id': 2,
          'plan_id': 'PREMIUM',
          'transaction_type': 'activation',
          'amount_cents': 1000,
          'currency': 'USD',
          'status': 'succeeded',
        },
      ],
      'payment_attempts': [
        {
          'id': 3,
          'plan_id': 'PREMIUM',
          'attempt_type': 'checkout',
          'status': 'succeeded',
          'amount_cents': 1000,
          'currency': 'USD',
          'requested_at': '2026-03-17T10:00:00Z',
        },
      ],
    });

    expect(record.lifecycle.status, 'active');
    expect(record.historySummary.eventCount, 3);
    expect(record.recentEvents.single.eventType, 'activate');
    expect(record.billingHistory.single.transactionType, 'activation');
    expect(record.paymentAttempts.single.attemptType, 'checkout');
  });
}
