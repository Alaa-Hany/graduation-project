class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.timestamp,
    this.admin,
    this.beforeJson,
    this.afterJson,
    this.ipAddress,
    this.userAgent,
  });

  final int id;
  final String action;
  final String entityType;
  final String entityId;
  final String? timestamp;
  final Map<String, dynamic>? admin;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;
  final String? ipAddress;
  final String? userAgent;

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    return AdminAuditLog(
      id: json['id'] as int,
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      timestamp: json['timestamp'] as String?,
      admin: parseMap(json['admin']),
      beforeJson: parseMap(json['before_json']),
      afterJson: parseMap(json['after_json']),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
    );
  }
}
