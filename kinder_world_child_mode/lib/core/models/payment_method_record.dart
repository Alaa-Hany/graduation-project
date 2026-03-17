class PaymentMethodRecord {
  const PaymentMethodRecord({
    required this.id,
    required this.label,
    required this.provider,
    required this.providerCustomerId,
    required this.providerMethodId,
    required this.methodType,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
    required this.createdAt,
    required this.metadata,
  });

  final int id;
  final String label;
  final String provider;
  final String? providerCustomerId;
  final String? providerMethodId;
  final String? methodType;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  bool get isProviderBacked => provider != 'internal' && providerMethodId != null;

  String get displayTitle {
    if ((brand ?? '').isNotEmpty && (last4 ?? '').isNotEmpty) {
      return '${brand!.toUpperCase()} •••• $last4';
    }
    if ((label).trim().isNotEmpty) {
      return label;
    }
    if ((providerMethodId ?? '').isNotEmpty) {
      return providerMethodId!;
    }
    return 'Payment method';
  }

  String get expiryLabel {
    if (expMonth == null || expYear == null) {
      return '';
    }
    final month = expMonth!.toString().padLeft(2, '0');
    return '$month/$expYear';
  }

  factory PaymentMethodRecord.fromJson(Map<String, dynamic> json) {
    return PaymentMethodRecord(
      id: _readInt(json['id']) ?? 0,
      label: (json['label'] ?? '').toString(),
      provider: (json['provider'] ?? 'internal').toString(),
      providerCustomerId: json['provider_customer_id']?.toString(),
      providerMethodId: json['provider_method_id']?.toString(),
      methodType: json['method_type']?.toString(),
      brand: json['brand']?.toString(),
      last4: json['last4']?.toString(),
      expMonth: _readInt(json['exp_month']),
      expYear: _readInt(json['exp_year']),
      isDefault: _readBool(json['is_default']) ?? false,
      createdAt: _readDateTime(json['created_at']),
      metadata: Map<String, dynamic>.from(json['metadata_json'] as Map? ?? const {}),
    );
  }
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
