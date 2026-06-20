import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'support/test_harness.dart';

void main() {
  test('test harness can override plan info for provider tests', () async {
    final harness = await TestHarness.create(
      initializeHive: false,
      planInfoState: AsyncData(PlanInfo.fromTier(PlanTier.premium)),
    );
    final container = harness.createContainer();
    addTearDown(container.dispose);

    final plan = container.read(planInfoStateProvider).requireValue;

    expect(plan.tier, PlanTier.premium);
    expect(plan.hasAiInsights, isTrue);
  });

  test('planInfoFromSubscriptionSnapshot maps backend premium payload', () {
    final plan = planInfoFromSubscriptionSnapshot(
      planId: 'PREMIUM',
      limits: const {'max_children': 3},
      features: const {
        'basic_reports': true,
        'advanced_reports': true,
        'ai_insights': true,
        'offline_downloads': true,
      },
    );

    expect(plan.tier, PlanTier.premium);
    expect(plan.maxChildren, 3);
    expect(plan.hasAdvancedReports, isTrue);
    expect(plan.hasAiInsights, isTrue);
    expect(plan.hasOfflineDownloads, isTrue);
    expect(plan.hasSmartControls, isTrue);
  });

  test('planInfoFromSubscriptionSnapshot maps backend free payload', () {
    final plan = planInfoFromSubscriptionSnapshot(
      planId: 'FREE',
      limits: const {'max_children': 1},
      features: const {
        'basic_reports': true,
        'advanced_reports': false,
        'ai_insights': false,
        'offline_downloads': false,
      },
    );

    expect(plan.tier, PlanTier.free);
    expect(plan.maxChildren, 1);
    expect(plan.hasAdvancedReports, isFalse);
    expect(plan.hasAiInsights, isFalse);
    expect(plan.hasOfflineDownloads, isFalse);
    expect(plan.hasSmartControls, isFalse);
  });

  test('SubscriptionSnapshot parses lifecycle and recent history', () {
    final snapshot = SubscriptionSnapshot.fromJson({
      'plan': 'PREMIUM',
      'current_plan_id': 'PREMIUM',
      'limits': {'max_children': 3},
      'features': {
        'basic_reports': true,
        'advanced_reports': true,
        'ai_insights': true,
        'offline_downloads': true,
      },
      'lifecycle': {
        'current_plan_id': 'PREMIUM',
        'status': 'active',
        'started_at': '2026-03-17T10:00:00Z',
        'expires_at': null,
        'will_renew': false,
        'last_payment_status': 'succeeded',
        'provider': 'internal',
        'is_active': true,
        'has_paid_access': true,
      },
      'history_summary': {
        'event_count': 2,
        'billing_transaction_count': 1,
        'payment_attempt_count': 1,
      },
      'recent_events': [
        {
          'id': 1,
          'event_type': 'purchase',
          'plan_id': 'PREMIUM',
          'status': 'active',
          'source': 'parent_select',
          'occurred_at': '2026-03-17T10:00:00Z',
        },
      ],
      'billing_history': [
        {
          'id': 1,
          'plan_id': 'PREMIUM',
          'transaction_type': 'purchase',
          'amount_cents': 1000,
          'currency': 'USD',
          'status': 'succeeded',
          'effective_at': '2026-03-17T10:00:00Z',
        },
      ],
      'payment_attempts': [
        {
          'id': 1,
          'plan_id': 'PREMIUM',
          'attempt_type': 'checkout',
          'status': 'succeeded',
          'amount_cents': 1000,
          'currency': 'USD',
          'requested_at': '2026-03-17T10:00:00Z',
        },
      ],
    });

    expect(snapshot.lifecycle.status, 'active');
    expect(snapshot.lifecycle.willRenew, isFalse);
    expect(snapshot.lifecycle.hasPaidAccess, isTrue);
    expect(snapshot.historySummary.eventCount, 2);
    expect(snapshot.recentEvents.single.eventType, 'purchase');
    expect(snapshot.billingHistory.single.transactionType, 'purchase');
    expect(snapshot.paymentAttempts.single.attemptType, 'checkout');
    expect(snapshot.planInfo.isRecurringSubscription, isTrue);
  });

  test('SubscriptionHistorySnapshot parses full history payload', () {
    final history = SubscriptionHistorySnapshot.fromJson({
      'user_id': 7,
      'current_plan_id': 'FAMILY_PLUS',
      'status': 'active',
      'events': [
        {
          'id': 9,
          'event_type': 'purchase',
          'plan_id': 'FAMILY_PLUS',
          'status': 'active',
          'source': 'parent_activate',
          'occurred_at': '2026-03-17T10:00:00Z',
        },
      ],
      'billing_transactions': [
        {
          'id': 4,
          'plan_id': 'FAMILY_PLUS',
          'transaction_type': 'purchase',
          'amount_cents': 2000,
          'currency': 'USD',
          'status': 'succeeded',
          'effective_at': '2026-03-17T10:00:00Z',
        },
        {
          'id': 5,
          'plan_id': 'FAMILY_PLUS',
          'transaction_type': 'refund',
          'amount_cents': -2000,
          'currency': 'USD',
          'status': 'refunded',
          'effective_at': '2026-03-18T10:00:00Z',
        },
      ],
      'payment_attempts': [
        {
          'id': 6,
          'plan_id': 'FAMILY_PLUS',
          'attempt_type': 'checkout',
          'status': 'succeeded',
          'amount_cents': 2000,
          'currency': 'USD',
          'requested_at': '2026-03-17T10:00:00Z',
        },
      ],
    });

    expect(history.userId, 7);
    expect(history.currentPlanId, 'FAMILY_PLUS');
    expect(history.events.single.eventType, 'purchase');
    expect(history.billingTransactions.first.amountCents, 2000);
    expect(history.billingTransactions.first.transactionType, 'purchase');
    expect(history.billingTransactions.last.transactionType, 'refund');
    expect(history.billingTransactions.last.amountCents, -2000);
    expect(history.paymentAttempts.single.attemptType, 'checkout');
  });
}
