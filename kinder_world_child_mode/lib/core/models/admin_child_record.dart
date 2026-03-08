class AdminChildRecord {
  const AdminChildRecord({
    required this.id,
    required this.parentId,
    required this.name,
    required this.age,
    required this.isActive,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.parent,
  });

  final int id;
  final int parentId;
  final String name;
  final int? age;
  final bool isActive;
  final String? avatar;
  final String? createdAt;
  final String? updatedAt;
  final String? dateOfBirth;
  final Map<String, dynamic>? parent;

  factory AdminChildRecord.fromJson(Map<String, dynamic> json) {
    return AdminChildRecord(
      id: json['id'] as int,
      parentId: json['parent_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      age: json['age'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      avatar: json['avatar'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      parent: json['parent'] is Map
          ? Map<String, dynamic>.from(json['parent'] as Map)
          : null,
    );
  }
}
