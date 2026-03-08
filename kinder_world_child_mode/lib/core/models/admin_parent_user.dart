class AdminParentUser {
  const AdminParentUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.plan,
    required this.childCount,
    required this.createdAt,
    required this.updatedAt,
    this.children = const [],
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String plan;
  final int childCount;
  final String? createdAt;
  final String? updatedAt;
  final List<Map<String, dynamic>> children;

  factory AdminParentUser.fromJson(Map<String, dynamic> json) {
    final rawChildren = (json['children'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return AdminParentUser(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'parent',
      isActive: json['is_active'] as bool? ?? true,
      plan: json['plan'] as String? ?? 'FREE',
      childCount: json['child_count'] as int? ?? rawChildren.length,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      children: rawChildren,
    );
  }
}
