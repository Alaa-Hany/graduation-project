class AiBuddyProviderStatus {
  const AiBuddyProviderStatus({
    required this.configured,
    required this.mode,
    required this.status,
    required this.reason,
  });

  final bool configured;
  final String mode;
  final String status;
  final String? reason;

  factory AiBuddyProviderStatus.fromJson(Map<String, dynamic> json) {
    return AiBuddyProviderStatus(
      configured: json['configured'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'internal_fallback',
      status: json['status'] as String? ?? 'fallback',
      reason: json['reason'] as String?,
    );
  }
}

class AiBuddyMessage {
  const AiBuddyMessage({
    required this.id,
    required this.sessionId,
    required this.childId,
    required this.role,
    required this.content,
    required this.intent,
    required this.responseSource,
    required this.status,
    required this.clientMessageId,
    required this.safetyStatus,
    required this.metadataJson,
    required this.retentionExpiresAt,
    required this.archivedAt,
    required this.createdAt,
  });

  final int id;
  final int sessionId;
  final int childId;
  final String role;
  final String content;
  final String? intent;
  final String responseSource;
  final String status;
  final String? clientMessageId;
  final String safetyStatus;
  final Map<String, dynamic> metadataJson;
  final DateTime? retentionExpiresAt;
  final DateTime? archivedAt;
  final DateTime? createdAt;

  bool get isUser => role == 'child' || role == 'user';

  factory AiBuddyMessage.fromJson(Map<String, dynamic> json) {
    return AiBuddyMessage(
      id: json['id'] as int? ?? 0,
      sessionId: json['session_id'] as int? ?? 0,
      childId: json['child_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      intent: json['intent'] as String?,
      responseSource: json['response_source'] as String? ?? 'internal_fallback',
      status: json['status'] as String? ?? 'completed',
      clientMessageId: json['client_message_id'] as String?,
      safetyStatus: json['safety_status'] as String? ?? 'allowed',
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
      retentionExpiresAt: _readDateTime(json['retention_expires_at']),
      archivedAt: _readDateTime(json['archived_at']),
      createdAt: _readDateTime(json['created_at']),
    );
  }
}

class AiBuddySession {
  const AiBuddySession({
    required this.id,
    required this.childId,
    required this.parentUserId,
    required this.status,
    required this.title,
    required this.providerMode,
    required this.providerStatus,
    required this.unavailableReason,
    required this.visibilityMode,
    required this.parentSummary,
    required this.startedAt,
    required this.lastMessageAt,
    required this.endedAt,
    required this.retentionExpiresAt,
    required this.metadataJson,
    required this.messagesCount,
  });

  final int id;
  final int childId;
  final int parentUserId;
  final String status;
  final String? title;
  final String providerMode;
  final String providerStatus;
  final String? unavailableReason;
  final String visibilityMode;
  final String? parentSummary;
  final DateTime? startedAt;
  final DateTime? lastMessageAt;
  final DateTime? endedAt;
  final DateTime? retentionExpiresAt;
  final Map<String, dynamic> metadataJson;
  final int messagesCount;

  factory AiBuddySession.fromJson(Map<String, dynamic> json) {
    return AiBuddySession(
      id: json['id'] as int? ?? 0,
      childId: json['child_id'] as int? ?? 0,
      parentUserId: json['parent_user_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      title: json['title'] as String?,
      providerMode: json['provider_mode'] as String? ?? 'internal_fallback',
      providerStatus: json['provider_status'] as String? ?? 'fallback',
      unavailableReason: json['unavailable_reason'] as String?,
      visibilityMode: json['visibility_mode'] as String? ?? 'summary_and_metrics',
      parentSummary: json['parent_summary'] as String?,
      startedAt: _readDateTime(json['started_at']),
      lastMessageAt: _readDateTime(json['last_message_at']),
      endedAt: _readDateTime(json['ended_at']),
      retentionExpiresAt: _readDateTime(json['retention_expires_at']),
      metadataJson: json['metadata_json'] is Map
          ? Map<String, dynamic>.from(json['metadata_json'] as Map)
          : const {},
      messagesCount: json['messages_count'] as int? ?? 0,
    );
  }
}

class AiBuddyRetentionPolicy {
  const AiBuddyRetentionPolicy({
    required this.messagesRetainedDays,
    required this.autoArchive,
    required this.deleteSupported,
  });

  final int messagesRetainedDays;
  final bool autoArchive;
  final bool deleteSupported;

  factory AiBuddyRetentionPolicy.fromJson(Map<String, dynamic> json) {
    return AiBuddyRetentionPolicy(
      messagesRetainedDays: json['messages_retained_days'] as int? ?? 30,
      autoArchive: json['auto_archive'] as bool? ?? true,
      deleteSupported: json['delete_supported'] as bool? ?? true,
    );
  }
}

class AiBuddyUsageMetrics {
  const AiBuddyUsageMetrics({
    required this.sessionsCount,
    required this.messagesCount,
    required this.childMessagesCount,
    required this.assistantMessagesCount,
    required this.lastSessionAt,
    required this.allowedCount,
    required this.refusalCount,
    required this.safeRedirectCount,
  });

  final int sessionsCount;
  final int messagesCount;
  final int childMessagesCount;
  final int assistantMessagesCount;
  final DateTime? lastSessionAt;
  final int allowedCount;
  final int refusalCount;
  final int safeRedirectCount;

  factory AiBuddyUsageMetrics.fromJson(Map<String, dynamic> json) {
    return AiBuddyUsageMetrics(
      sessionsCount: json['sessions_count'] as int? ?? 0,
      messagesCount: json['messages_count'] as int? ?? 0,
      childMessagesCount: json['child_messages_count'] as int? ?? 0,
      assistantMessagesCount: json['assistant_messages_count'] as int? ?? 0,
      lastSessionAt: _readDateTime(json['last_session_at']),
      allowedCount: json['allowed_count'] as int? ?? 0,
      refusalCount: json['refusal_count'] as int? ?? 0,
      safeRedirectCount: json['safe_redirect_count'] as int? ?? 0,
    );
  }
}

class AiBuddyVisibilityFlag {
  const AiBuddyVisibilityFlag({
    required this.messageId,
    required this.occurredAt,
    required this.classification,
    required this.topic,
    required this.reason,
    required this.action,
  });

  final int messageId;
  final DateTime? occurredAt;
  final String classification;
  final String? topic;
  final String? reason;
  final String? action;

  factory AiBuddyVisibilityFlag.fromJson(Map<String, dynamic> json) {
    return AiBuddyVisibilityFlag(
      messageId: json['message_id'] as int? ?? 0,
      occurredAt: _readDateTime(json['occurred_at']),
      classification: json['classification'] as String? ?? 'allowed',
      topic: json['topic'] as String?,
      reason: json['reason'] as String?,
      action: json['action'] as String?,
    );
  }
}

class AiBuddyVisibilitySession {
  const AiBuddyVisibilitySession({
    required this.id,
    required this.status,
    required this.providerStatus,
    required this.providerMode,
    required this.lastMessageAt,
    required this.parentSummary,
  });

  final int id;
  final String status;
  final String providerStatus;
  final String? providerMode;
  final DateTime? lastMessageAt;
  final String? parentSummary;

  factory AiBuddyVisibilitySession.fromJson(Map<String, dynamic> json) {
    return AiBuddyVisibilitySession(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      providerStatus: json['provider_status'] as String? ?? 'fallback',
      providerMode: json['provider_mode'] as String?,
      lastMessageAt: _readDateTime(json['last_message_at']),
      parentSummary: json['parent_summary'] as String?,
    );
  }
}

class AiBuddyVisibilitySummary {
  const AiBuddyVisibilitySummary({
    required this.childId,
    required this.childName,
    required this.visibilityMode,
    required this.transcriptAccess,
    required this.parentSummary,
    required this.provider,
    required this.retentionPolicy,
    required this.usageMetrics,
    required this.currentSession,
    required this.recentFlags,
  });

  final int childId;
  final String childName;
  final String visibilityMode;
  final bool transcriptAccess;
  final String parentSummary;
  final AiBuddyProviderStatus provider;
  final AiBuddyRetentionPolicy retentionPolicy;
  final AiBuddyUsageMetrics usageMetrics;
  final AiBuddyVisibilitySession? currentSession;
  final List<AiBuddyVisibilityFlag> recentFlags;

  factory AiBuddyVisibilitySummary.fromJson(Map<String, dynamic> json) {
    return AiBuddyVisibilitySummary(
      childId: json['child_id'] as int? ?? 0,
      childName: json['child_name'] as String? ?? '',
      visibilityMode: json['visibility_mode'] as String? ?? 'summary_and_metrics',
      transcriptAccess: json['transcript_access'] as bool? ?? false,
      parentSummary: json['parent_summary'] as String? ?? '',
      provider: AiBuddyProviderStatus.fromJson(
        Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
      ),
      retentionPolicy: AiBuddyRetentionPolicy.fromJson(
        Map<String, dynamic>.from(json['retention_policy'] as Map? ?? const {}),
      ),
      usageMetrics: AiBuddyUsageMetrics.fromJson(
        Map<String, dynamic>.from(json['usage_metrics'] as Map? ?? const {}),
      ),
      currentSession: json['current_session'] is Map
          ? AiBuddyVisibilitySession.fromJson(
              Map<String, dynamic>.from(json['current_session'] as Map),
            )
          : null,
      recentFlags: (json['recent_flags'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AiBuddyVisibilityFlag.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class AiBuddyConversation {
  const AiBuddyConversation({
    required this.session,
    required this.messages,
    required this.provider,
  });

  final AiBuddySession? session;
  final List<AiBuddyMessage> messages;
  final AiBuddyProviderStatus provider;

  bool get hasSession => session != null;

  factory AiBuddyConversation.fromJson(Map<String, dynamic> json) {
    return AiBuddyConversation(
      session: json['session'] is Map
          ? AiBuddySession.fromJson(Map<String, dynamic>.from(json['session'] as Map))
          : null,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AiBuddyMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      provider: AiBuddyProviderStatus.fromJson(
        Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
      ),
    );
  }
}

class AiBuddySendResult {
  const AiBuddySendResult({
    required this.session,
    required this.userMessage,
    required this.assistantMessage,
    required this.provider,
  });

  final AiBuddySession session;
  final AiBuddyMessage userMessage;
  final AiBuddyMessage assistantMessage;
  final AiBuddyProviderStatus provider;

  factory AiBuddySendResult.fromJson(Map<String, dynamic> json) {
    return AiBuddySendResult(
      session: AiBuddySession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map? ?? const {}),
      ),
      userMessage: AiBuddyMessage.fromJson(
        Map<String, dynamic>.from(json['user_message'] as Map? ?? const {}),
      ),
      assistantMessage: AiBuddyMessage.fromJson(
        Map<String, dynamic>.from(json['assistant_message'] as Map? ?? const {}),
      ),
      provider: AiBuddyProviderStatus.fromJson(
        Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
      ),
    );
  }
}

DateTime? _readDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
