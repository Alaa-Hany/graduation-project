import 'package:kinder_world/core/models/admin_user.dart';

class AdminPermissionRecord {
  const AdminPermissionRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.group,
  });

  final int id;
  final String name;
  final String description;
  final String group;

  factory AdminPermissionRecord.fromJson(Map<String, dynamic> json) {
    return AdminPermissionRecord(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      group: (json['group'] as String?) ?? 'general',
    );
  }
}

class AdminRoleRecord {
  const AdminRoleRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.permissionCount,
    required this.adminCount,
    required this.permissionNames,
    required this.permissions,
  });

  final int id;
  final String name;
  final String description;
  final int permissionCount;
  final int adminCount;
  final List<String> permissionNames;
  final List<AdminPermissionRecord> permissions;

  factory AdminRoleRecord.fromJson(Map<String, dynamic> json) {
    return AdminRoleRecord(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      permissionCount: (json['permission_count'] as num?)?.toInt() ?? 0,
      adminCount: (json['admin_count'] as num?)?.toInt() ?? 0,
      permissionNames: List<String>.from(
        (json['permission_names'] as List<dynamic>?) ?? const [],
      ),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((item) => AdminPermissionRecord.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}

class AdminPermissionsPayload {
  const AdminPermissionsPayload({
    required this.items,
    required this.groups,
  });

  final List<AdminPermissionRecord> items;
  final Map<String, List<AdminPermissionRecord>> groups;

  factory AdminPermissionsPayload.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map((item) => AdminPermissionRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    final rawGroups =
        Map<String, dynamic>.from(json['groups'] as Map? ?? const {});
    return AdminPermissionsPayload(
      items: items,
      groups: {
        for (final entry in rawGroups.entries)
          entry.key: (entry.value as List<dynamic>? ?? const [])
              .map((item) => AdminPermissionRecord.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList(),
      },
    );
  }
}

class ManagedAdminUser {
  const ManagedAdminUser({
    required this.admin,
  });

  final AdminUser admin;

  factory ManagedAdminUser.fromJson(Map<String, dynamic> json) {
    return ManagedAdminUser(admin: AdminUser.fromJson(json));
  }
}
