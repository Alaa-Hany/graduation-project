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
