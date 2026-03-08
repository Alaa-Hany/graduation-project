/// Admin user model — separate from the parent/child User model.
/// Populated from GET /admin/auth/me and POST /admin/auth/login responses.
class AdminUser {
  final int id;
  final String email;
  final String name;
  final bool isActive;
  final List<String> roles;
  final List<String> permissions;
  final String? createdAt;
  final String? updatedAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.isActive,
    required this.roles,
    required this.permissions,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      email: json['email'] as String,
      name: (json['name'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      roles: List<String>.from((json['roles'] as List<dynamic>?) ?? []),
      permissions: List<String>.from((json['permissions'] as List<dynamic>?) ?? []),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'is_active': isActive,
      'roles': roles,
      'permissions': permissions,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Returns true if this admin holds the given dot-notation permission key.
  /// e.g. hasPermission('admin.users.view')
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Returns true if this admin has any of the given roles.
  bool hasRole(String role) => roles.contains(role);

  /// Returns true if this admin is a super_admin.
  bool get isSuperAdmin => roles.contains('super_admin');

  AdminUser copyWith({
    int? id,
    String? email,
    String? name,
    bool? isActive,
    List<String>? roles,
    List<String>? permissions,
    String? createdAt,
    String? updatedAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AdminUser(id: $id, email: $email, roles: $roles, isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
