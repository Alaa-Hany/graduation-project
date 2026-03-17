import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/providers/subscription_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';

class SubscriptionLifecycle {
  const SubscriptionLifecycle({
    required this.currentPlanId,
    required this.selectedPlanId,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.cancelAt,
    required this.willRenew,
    required this.lastPaymentStatus,
    required this.provider,
    required this.isActive,
    required this.hasPaidAccess,
  });

  final String currentPlanId;
  final String? selectedPlanId;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? cancelAt;
  final bool willRenew;
  final String lastPaymentStatus;
  final String provider;
  final bool isActive;
  final bool hasPaidAccess;

  factory SubscriptionLifecycle.fromJson(Map<String, dynamic> json) {
    return SubscriptionLifecycle(
      currentPlanId: (json['current_plan_id'] ?? json['plan'] ?? 'FREE').toString(),
      selectedPlanId: json['selected_plan_id']?.toString(),
      status: (json['status'] ?? 'free').toString(),
      startedAt: _readDateTime(json['started_at']),
      expiresAt: _readDateTime(json['expires_at']),
      cancelAt: _readDateTime(json['cancel_at']),
      willRenew: _readBool(json['will_renew']) ?? false,
      lastPaymentStatus: (json['last_payment_status'] ?? 'not_applicable').toString(),
      provider: (json['provider'] ?? 'internal').toString(),
      isActive: _readBool(json['is_active']) ?? false,
      hasPaidAccess: _readBool(json['has_paid_access']) ??
          subscriptionPlanTierFromBackend(json['current_plan_id']?.toString()) != PlanTier.free,
    );
  }
}

class SubscriptionHistorySummary {
  const SubscriptionHistorySummary({
    required this.eventCount,
    required this.billingTransactionCount,
    required this.paymentAttemptCount,
  });

  final int eventCount;
  final int billingTransactionCount;
  final int paymentAttemptCount;

  factory SubscriptionHistorySummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistorySummary(
      eventCount: _readInt(json['event_count']) ?? 0,
      billingTransactionCount: _readInt(json['billing_transaction_count']) ?? 0,
      paymentAttemptCount: _readInt(json['payment_attempt_count']) ?? 0,
    );
  }
}

class SubscriptionEventRecord {
  const SubscriptionEventRecord({
    required this.id,
    required this.eventType,
    required this.previousPlanId,
    required this.planId,
    required this.previousStatus,
    required this.status,
    required this.paymentStatus,
    required this.source,
    required this.details,
    required this.occurredAt,
  });

  final int id;
  final String eventType;
  final String? previousPlanId;
  final String planId;
  final String? previousStatus;
  final String status;
  final String? paymentStatus;
  final String source;
  final Map<String, dynamic> details;
  final DateTime? occurredAt;

  factory SubscriptionEventRecord.fromJson(Map<String, dynamic> json) {
    return SubscriptionEventRecord(
      id: _readInt(json['id']) ?? 0,
      eventType: (json['event_type'] ?? '').toString(),
      previousPlanId: json['previous_plan_id']?.toString(),
      planId: (json['plan_id'] ?? 'FREE').toString(),
      previousStatus: json['previous_status']?.toString(),
      status: (json['status'] ?? '').toString(),
      paymentStatus: json['payment_status']?.toString(),
      source: (json['source'] ?? 'internal').toString(),
      details: Map<String, dynamic>.from(json['details_json'] as Map? ?? const {}),
      occurredAt: _readDateTime(json['occurred_at']),
    );
  }
}

class BillingTransactionRecord {
  const BillingTransactionRecord({
    required this.id,
    required this.planId,
    required this.transactionType,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.effectiveAt,
    required this.metadata,
  });

  final int id;
  final String planId;
  final String transactionType;
  final int amountCents;
  final String currency;
  final String status;
  final DateTime? effectiveAt;
  final Map<String, dynamic> metadata;

  factory BillingTransactionRecord.fromJson(Map<String, dynamic> json) {
    return BillingTransactionRecord(
      id: _readInt(json['id']) ?? 0,
      planId: (json['plan_id'] ?? 'FREE').toString(),
      transactionType: (json['transaction_type'] ?? '').toString(),
      amountCents: _readInt(json['amount_cents']) ?? 0,
      currency: (json['currency'] ?? 'USD').toString(),
      status: (json['status'] ?? '').toString(),
      effectiveAt: _readDateTime(json['effective_at']),
      metadata: Map<String, dynamic>.from(json['metadata_json'] as Map? ?? const {}),
    );
  }
}

class PaymentAttemptRecord {
  const PaymentAttemptRecord({
    required this.id,
    required this.planId,
    required this.attemptType,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.providerReference,
    required this.failureCode,
    required this.failureMessage,
    required this.requestedAt,
    required this.completedAt,
    required this.metadata,
  });

  final int id;
  final String planId;
  final String attemptType;
  final String status;
  final int amountCents;
  final String currency;
  final String? providerReference;
  final String? failureCode;
  final String? failureMessage;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  factory PaymentAttemptRecord.fromJson(Map<String, dynamic> json) {
    return PaymentAttemptRecord(
      id: _readInt(json['id']) ?? 0,
      planId: (json['plan_id'] ?? 'FREE').toString(),
      attemptType: (json['attempt_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amountCents: _readInt(json['amount_cents']) ?? 0,
      currency: (json['currency'] ?? 'USD').toString(),
      providerReference: json['provider_reference']?.toString(),
      failureCode: json['failure_code']?.toString(),
      failureMessage: json['failure_message']?.toString(),
      requestedAt: _readDateTime(json['requested_at']),
      completedAt: _readDateTime(json['completed_at']),
      metadata: Map<String, dynamic>.from(json['metadata_json'] as Map? ?? const {}),
    );
  }
}

class SubscriptionHistorySnapshot {
  const SubscriptionHistorySnapshot({
    required this.userId,
    required this.currentPlanId,
    required this.status,
    required this.events,
    required this.billingTransactions,
    required this.paymentAttempts,
  });

  final int userId;
  final String currentPlanId;
  final String status;
  final List<SubscriptionEventRecord> events;
  final List<BillingTransactionRecord> billingTransactions;
  final List<PaymentAttemptRecord> paymentAttempts;

  factory SubscriptionHistorySnapshot.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistorySnapshot(
      userId: _readInt(json['user_id']) ?? 0,
      currentPlanId: (json['current_plan_id'] ?? 'FREE').toString(),
      status: (json['status'] ?? 'free').toString(),
      events: _readModelList(
        json['events'],
        SubscriptionEventRecord.fromJson,
      ),
      billingTransactions: _readModelList(
        json['billing_transactions'],
        BillingTransactionRecord.fromJson,
      ),
      paymentAttempts: _readModelList(
        json['payment_attempts'],
        PaymentAttemptRecord.fromJson,
      ),
    );
  }
}

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.planId,
    required this.currentPlanId,
    required this.limits,
    required this.features,
    required this.lifecycle,
    required this.historySummary,
    required this.recentEvents,
    required this.billingHistory,
    required this.paymentAttempts,
  });

  final String planId;
  final String currentPlanId;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> features;
  final SubscriptionLifecycle lifecycle;
  final SubscriptionHistorySummary historySummary;
  final List<SubscriptionEventRecord> recentEvents;
  final List<BillingTransactionRecord> billingHistory;
  final List<PaymentAttemptRecord> paymentAttempts;

  PlanTier get tier => subscriptionPlanTierFromBackend(currentPlanId);

  PlanInfo get planInfo => planInfoFromSubscriptionSnapshot(
        planId: currentPlanId,
        limits: limits,
        features: features,
      );

  bool get isPremium => tier != PlanTier.free;

  factory SubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    return SubscriptionSnapshot(
      planId: (json['plan'] ?? json['current_plan_id'] ?? 'FREE').toString(),
      currentPlanId: (json['current_plan_id'] ?? json['plan'] ?? 'FREE').toString(),
      limits: Map<String, dynamic>.from(json['limits'] as Map? ?? const {}),
      features: Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
      lifecycle: SubscriptionLifecycle.fromJson(
        Map<String, dynamic>.from(json['lifecycle'] as Map? ?? const {}),
      ),
      historySummary: SubscriptionHistorySummary.fromJson(
        Map<String, dynamic>.from(json['history_summary'] as Map? ?? const {}),
      ),
      recentEvents: _readModelList(
        json['recent_events'],
        SubscriptionEventRecord.fromJson,
      ),
      billingHistory: _readModelList(
        json['billing_history'],
        BillingTransactionRecord.fromJson,
      ),
      paymentAttempts: _readModelList(
        json['payment_attempts'],
        PaymentAttemptRecord.fromJson,
      ),
    );
  }
}

PlanTier subscriptionPlanTierFromBackend(String? rawPlan) {
  final normalized = (rawPlan ?? '').trim().toUpperCase();
  switch (normalized) {
    case 'FAMILY_PLUS':
      return PlanTier.familyPlus;
    case 'PREMIUM':
      return PlanTier.premium;
    case 'FREE':
    default:
      return PlanTier.free;
  }
}

PlanInfo planInfoFromSubscriptionSnapshot({
  required String planId,
  required Map<String, dynamic> limits,
  required Map<String, dynamic> features,
}) {
  final tier = subscriptionPlanTierFromBackend(planId);
  final defaults = PlanInfo.fromTier(tier);

  return PlanInfo(
    tier: tier,
    maxChildren: _readInt(limits['max_children']) ?? defaults.maxChildren,
    hasBasicReports:
        _readBool(features['basic_reports']) ?? defaults.hasBasicReports,
    hasAdvancedReports:
        _readBool(features['advanced_reports']) ?? defaults.hasAdvancedReports,
    hasAiInsights:
        _readBool(features['ai_insights']) ?? defaults.hasAiInsights,
    hasOfflineDownloads: _readBool(features['offline_downloads']) ??
        defaults.hasOfflineDownloads,
    hasSmartControls: tier != PlanTier.free,
    hasExclusiveContent: tier != PlanTier.free,
    hasFamilyDashboard: tier == PlanTier.familyPlus,
  );
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _readDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

List<T> _readModelList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) mapper,
) {
  final raw = value as List<dynamic>? ?? const [];
  return raw
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList();
}

final subscriptionSnapshotProvider =
    FutureProvider<SubscriptionSnapshot>((ref) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final data = await subscriptionService.getSubscription(
    forceRefresh: true,
    allowCachedOnError: false,
  );
  if (data == null || data.isEmpty) {
    throw StateError('Subscription snapshot is unavailable');
  }
  return SubscriptionSnapshot.fromJson(data);
});

final subscriptionHistoryProvider =
    FutureProvider<SubscriptionHistorySnapshot>((ref) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  final data = await subscriptionService.getSubscriptionHistory(
    forceRefresh: true,
    allowCachedOnError: false,
  );
  if (data == null || data.isEmpty) {
    throw StateError('Subscription history is unavailable');
  }
  return SubscriptionHistorySnapshot.fromJson(data);
});

final planInfoProvider = FutureProvider<PlanInfo>((ref) async {
  final snapshot = await ref.watch(subscriptionSnapshotProvider.future);
  return snapshot.planInfo;
});
