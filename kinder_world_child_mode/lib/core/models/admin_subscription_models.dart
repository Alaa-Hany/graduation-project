class AdminSubscriptionLifecycle {
  const AdminSubscriptionLifecycle({
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
  });

  final String currentPlanId;
  final String? selectedPlanId;
  final String status;
  final String? startedAt;
  final String? expiresAt;
  final String? cancelAt;
  final bool willRenew;
  final String lastPaymentStatus;
  final String provider;
  final bool isActive;

  factory AdminSubscriptionLifecycle.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionLifecycle(
      currentPlanId: json['current_plan_id'] as String? ?? 'FREE',
      selectedPlanId: json['selected_plan_id'] as String?,
      status: json['status'] as String? ?? 'free',
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      cancelAt: json['cancel_at'] as String?,
      willRenew: json['will_renew'] as bool? ?? false,
      lastPaymentStatus:
          json['last_payment_status'] as String? ?? 'not_applicable',
      provider: json['provider'] as String? ?? 'internal',
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class AdminSubscriptionHistorySummary {
  const AdminSubscriptionHistorySummary({
    required this.eventCount,
    required this.billingTransactionCount,
    required this.paymentAttemptCount,
  });

  final int eventCount;
  final int billingTransactionCount;
  final int paymentAttemptCount;

  factory AdminSubscriptionHistorySummary.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionHistorySummary(
      eventCount: json['event_count'] as int? ?? 0,
      billingTransactionCount: json['billing_transaction_count'] as int? ?? 0,
      paymentAttemptCount: json['payment_attempt_count'] as int? ?? 0,
    );
  }
}

class AdminSubscriptionEventRecord {
  const AdminSubscriptionEventRecord({
    required this.id,
    required this.eventType,
    required this.planId,
    required this.status,
    required this.source,
    required this.occurredAt,
    this.previousPlanId,
    this.previousStatus,
    this.paymentStatus,
    this.detailsJson = const {},
  });

  final int id;
  final String eventType;
  final String? previousPlanId;
  final String planId;
  final String? previousStatus;
  final String status;
  final String? paymentStatus;
  final String source;
  final Map<String, dynamic> detailsJson;
  final String? occurredAt;

  factory AdminSubscriptionEventRecord.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionEventRecord(
      id: json['id'] as int? ?? 0,
      eventType: json['event_type'] as String? ?? '',
      previousPlanId: json['previous_plan_id'] as String?,
      planId: json['plan_id'] as String? ?? 'FREE',
      previousStatus: json['previous_status'] as String?,
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String?,
      source: json['source'] as String? ?? 'internal',
      detailsJson: json['details_json'] is Map
          ? Map<String, dynamic>.from(json['details_json'] as Map)
          : const {},
      occurredAt: json['occurred_at'] as String?,
    );
  }
}

class AdminBillingTransactionRecord {
  const AdminBillingTransactionRecord({
    required this.id,
    required this.planId,
    required this.transactionType,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.effectiveAt,
    this.metadataJson = const {},
  });

  final int id;
  final String planId;
  final String transactionType;
  final int amountCents;
  final String currency;
  final String status;
  final String? effectiveAt;
  final Map<String, dynamic> metadataJson;

  factory AdminBillingTransactionRecord.fromJson(Map<String, dynamic> json) {
    return AdminBillingTransactionRecord(
      id: json['id'] as int? ?? 0,
      planId: json['plan_id'] as String? ?? 'FREE',
      transactionType: json['transaction_type'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? '',
      effectiveAt: json['effective_at'] as String?,
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
    );
  }
}

class AdminPaymentAttemptRecord {
  const AdminPaymentAttemptRecord({
    required this.id,
    required this.planId,
    required this.attemptType,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.requestedAt,
    this.providerReference,
    this.failureCode,
    this.failureMessage,
    this.completedAt,
    this.metadataJson = const {},
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
  final String? requestedAt;
  final String? completedAt;
  final Map<String, dynamic> metadataJson;

  factory AdminPaymentAttemptRecord.fromJson(Map<String, dynamic> json) {
    return AdminPaymentAttemptRecord(
      id: json['id'] as int? ?? 0,
      planId: json['plan_id'] as String? ?? 'FREE',
      attemptType: json['attempt_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amountCents: json['amount_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      providerReference: json['provider_reference'] as String?,
      failureCode: json['failure_code'] as String?,
      failureMessage: json['failure_message'] as String?,
      requestedAt: json['requested_at'] as String?,
      completedAt: json['completed_at'] as String?,
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
    );
  }
}

class AdminSubscriptionRecord {
  const AdminSubscriptionRecord({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.plan,
    required this.status,
    required this.isActive,
    required this.childCount,
    required this.paymentMethodCount,
    required this.limits,
    required this.features,
    required this.lifecycle,
    required this.historySummary,
    required this.recentEvents,
    required this.billingHistory,
    required this.paymentAttempts,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final String email;
  final String name;
  final String plan;
  final String status;
  final bool isActive;
  final int childCount;
  final int paymentMethodCount;
  final Map<String, dynamic> limits;
  final Map<String, dynamic> features;
  final AdminSubscriptionLifecycle lifecycle;
  final AdminSubscriptionHistorySummary historySummary;
  final List<AdminSubscriptionEventRecord> recentEvents;
  final List<AdminBillingTransactionRecord> billingHistory;
  final List<AdminPaymentAttemptRecord> paymentAttempts;
  final String? createdAt;
  final String? updatedAt;

  factory AdminSubscriptionRecord.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionRecord(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      plan: json['plan'] as String? ?? 'FREE',
      status: json['status'] as String? ?? 'free',
      isActive: json['is_active'] as bool? ?? true,
      childCount: json['child_count'] as int? ?? 0,
      paymentMethodCount: json['payment_method_count'] as int? ?? 0,
      limits: json['limits'] is Map
          ? Map<String, dynamic>.from(json['limits'] as Map)
          : const {},
      features: json['features'] is Map
          ? Map<String, dynamic>.from(json['features'] as Map)
          : const {},
      lifecycle: AdminSubscriptionLifecycle.fromJson(
        json['lifecycle'] is Map
            ? Map<String, dynamic>.from(json['lifecycle'] as Map)
            : const {},
      ),
      historySummary: AdminSubscriptionHistorySummary.fromJson(
        json['history_summary'] is Map
            ? Map<String, dynamic>.from(json['history_summary'] as Map)
            : const {},
      ),
      recentEvents: (json['recent_events'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AdminSubscriptionEventRecord.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      billingHistory: (json['billing_history'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AdminBillingTransactionRecord.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      paymentAttempts: (json['payment_attempts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) =>
              AdminPaymentAttemptRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AdminSystemSettingEntry {
  const AdminSystemSettingEntry({
    required this.id,
    required this.key,
    required this.valueJson,
    this.updatedBy,
    this.updatedAt,
  });

  final int id;
  final String key;
  final dynamic valueJson;
  final int? updatedBy;
  final String? updatedAt;

  factory AdminSystemSettingEntry.fromJson(Map<String, dynamic> json) {
    return AdminSystemSettingEntry(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      valueJson: json['value_json'],
      updatedBy: json['updated_by'] as int?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AdminSystemSettingsPayload {
  const AdminSystemSettingsPayload({
    required this.settings,
    required this.effective,
  });

  final Map<String, AdminSystemSettingEntry> settings;
  final Map<String, dynamic> effective;

  factory AdminSystemSettingsPayload.fromJson(Map<String, dynamic> json) {
    final settingsMap = <String, AdminSystemSettingEntry>{};
    final rawSettings = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : <String, dynamic>{};
    rawSettings.forEach((key, value) {
      if (value is Map) {
        settingsMap[key] =
            AdminSystemSettingEntry.fromJson(Map<String, dynamic>.from(value));
      }
    });
    return AdminSystemSettingsPayload(
      settings: settingsMap,
      effective: json['effective'] is Map
          ? Map<String, dynamic>.from(json['effective'] as Map)
          : const {},
    );
  }
}
