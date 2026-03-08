import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_rbac_models.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

class AdminAdminManagementScreen extends ConsumerStatefulWidget {
  const AdminAdminManagementScreen({super.key});

  @override
  ConsumerState<AdminAdminManagementScreen> createState() =>
      _AdminAdminManagementScreenState();
}

class _AdminAdminManagementScreenState
    extends ConsumerState<AdminAdminManagementScreen> {
  bool _loadingUsers = true;
  bool _loadingRoles = true;
  String? _usersError;
  String? _rolesError;

  List<AdminUser> _adminUsers = const [];
  Map<String, dynamic> _adminPagination = const {};
  AdminUser? _selectedAdmin;
  String _search = '';
  String _status = 'all';
  int _page = 1;

  List<AdminRoleRecord> _roles = const [];
  AdminRoleRecord? _selectedRole;
  AdminPermissionsPayload? _permissionsPayload;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadRoles();
  }

  Future<void> _loadUsers({int? selectId}) async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchAdminUsers(
                search: _search,
                status: _status,
                page: _page,
              );
      AdminUser? selected = _selectedAdmin;
      final targetId = selectId ?? _selectedAdmin?.id;
      if (targetId != null) {
        for (final item in response.items) {
          if (item.id == targetId) {
            selected = item;
            break;
          }
        }
      }
      selected ??= response.items.isNotEmpty ? response.items.first : null;
      if (selected != null) {
        selected = await ref
            .read(adminManagementRepositoryProvider)
            .fetchAdminUserDetail(selected.id);
      }
      if (!mounted) return;
      setState(() {
        _adminUsers = response.items;
        _adminPagination = response.pagination;
        _selectedAdmin = selected;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadRoles({int? selectId}) async {
    setState(() {
      _loadingRoles = true;
      _rolesError = null;
    });
    try {
      final repository = ref.read(adminManagementRepositoryProvider);
      final roles = await repository.fetchRoles();
      final permissions = await repository.fetchPermissions();
      AdminRoleRecord? selected = _selectedRole;
      final targetId = selectId ?? _selectedRole?.id;
      if (targetId != null) {
        for (final item in roles) {
          if (item.id == targetId) {
            selected = item;
            break;
          }
        }
      }
      selected ??= roles.isNotEmpty ? roles.first : null;
      if (selected != null) {
        selected = await repository.fetchRoleDetail(selected.id);
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissionsPayload = permissions;
        _selectedRole = selected;
        _loadingRoles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rolesError = e.toString();
        _loadingRoles = false;
      });
    }
  }

  Future<void> _showCreateAdminDialog() async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final selectedRoleIds = <int>{};
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n?.adminAdminsCreateTitle ?? 'Create admin'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n?.adminAdminsNameField ?? 'Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: l10n?.adminAdminsEmailField ?? 'Email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText:
                              l10n?.adminAdminsPasswordField ?? 'Password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.adminAdminsInitialRolesLabel ?? 'Initial roles',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ..._roles.map(
                        (role) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedRoleIds.contains(role.id),
                          title: Text(role.name),
                          subtitle: role.description.isEmpty
                              ? null
                              : Text(role.description),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value ?? false) {
                                selectedRoleIds.add(role.id);
                              } else {
                                selectedRoleIds.remove(role.id);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n?.adminAdminsCreateAction ?? 'Create admin'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    final created =
        await ref.read(adminManagementRepositoryProvider).createAdminUser(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
              name: nameController.text.trim(),
              roleIds: selectedRoleIds.toList(),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsCreatedMessage ??
              'Admin account created successfully',
        ),
      ),
    );
    await _loadUsers(selectId: created.id);
    await _loadRoles();
  }

  Future<void> _showEditAdminDialog(AdminUser adminUser) async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController(text: adminUser.email);
    final nameController = TextEditingController(text: adminUser.name);
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminAdminsEditTitle ?? 'Edit admin'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsNameField ?? 'Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsEmailField ?? 'Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsPasswordField ?? 'Password',
                      helperText: l10n?.adminAdminsPasswordHelper ??
                          'Leave blank to keep the current password',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n?.save ?? 'Save'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final updated =
        await ref.read(adminManagementRepositoryProvider).updateAdminUser(
              adminUser.id,
              email: emailController.text.trim(),
              name: nameController.text.trim(),
              password: passwordController.text.trim(),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsUpdatedMessage ??
              'Admin account updated successfully',
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
  }

  Future<void> _setAdminEnabled(AdminUser adminUser, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              enabled
                  ? (l10n?.adminAdminsEnableTitle ?? 'Enable admin')
                  : (l10n?.adminAdminsDisableTitle ?? 'Disable admin'),
            ),
            content: Text(
              enabled
                  ? (l10n?.adminAdminsEnableConfirm ??
                      'Enable this admin account?')
                  : (l10n?.adminAdminsDisableConfirm ??
                      'Disable this admin account?'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  enabled
                      ? (l10n?.adminAdminsEnableAction ?? 'Enable')
                      : (l10n?.adminAdminsDisableAction ?? 'Disable'),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final updated = await ref
        .read(adminManagementRepositoryProvider)
        .setAdminUserEnabled(adminUser.id, enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? (l10n?.adminAdminsEnabledMessage ??
                  'Admin account enabled successfully')
              : (l10n?.adminAdminsDisabledMessage ??
                  'Admin account disabled successfully'),
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
  }

  Future<void> _showAssignRoleDialog(AdminUser adminUser) async {
    final l10n = AppLocalizations.of(context);
    final availableRoles =
        _roles.where((role) => !adminUser.roles.contains(role.name)).toList();
    if (availableRoles.isEmpty) return;
    int selectedRoleId = availableRoles.first.id;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n?.adminAdminsAssignRoleTitle ?? 'Assign role'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedRoleId,
                items: availableRoles
                    .map(
                      (role) => DropdownMenuItem<int>(
                        value: role.id,
                        child: Text(role.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(
                    () => selectedRoleId = value ?? selectedRoleId),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n?.cancel ?? 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    l10n?.adminAdminsAssignRoleAction ?? 'Assign role',
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    final updated = await ref
        .read(adminManagementRepositoryProvider)
        .assignAdminRole(adminUser.id, selectedRoleId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsRoleAssignedMessage ?? 'Role assigned successfully',
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
    await _loadRoles();
  }

  Future<void> _removeRole(AdminUser adminUser, AdminRoleRecord role) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminAdminsRemoveRoleTitle ?? 'Remove role'),
            content: Text(
              l10n?.adminAdminsRemoveRoleConfirm(role.name) ??
                  'Remove ${role.name} from this admin?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n?.adminAdminsRemoveRoleAction ?? 'Remove role',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final updated = await ref
        .read(adminManagementRepositoryProvider)
        .removeAdminRole(adminUser.id, role.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsRoleRemovedMessage ?? 'Role removed successfully',
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
    await _loadRoles();
  }

  Future<void> _showCreateRoleDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminAdminsCreateRoleTitle ?? 'Create role'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsRoleNameField ?? 'Role name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsRoleDescriptionField ??
                          'Description',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n?.adminAdminsCreateRoleAction ?? 'Create role',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final created =
        await ref.read(adminManagementRepositoryProvider).createRole(
              name: nameController.text.trim(),
              description: descriptionController.text.trim(),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsRoleCreatedMessage ?? 'Role created successfully',
        ),
      ),
    );
    await _loadRoles(selectId: created.id);
  }

  Future<void> _showEditRoleDialog(AdminRoleRecord role) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: role.name);
    final descriptionController = TextEditingController(text: role.description);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminAdminsEditRoleTitle ?? 'Edit role'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsRoleNameField ?? 'Role name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsRoleDescriptionField ??
                          'Description',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n?.save ?? 'Save'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final updated =
        await ref.read(adminManagementRepositoryProvider).updateRole(
              role.id,
              name: nameController.text.trim(),
              description: descriptionController.text.trim(),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsRoleUpdatedMessage ?? 'Role updated successfully',
        ),
      ),
    );
    await _loadRoles(selectId: updated.id);
  }

  Future<void> _saveRolePermissions(
    AdminRoleRecord role,
    Set<int> permissionIds,
  ) async {
    final l10n = AppLocalizations.of(context);
    final updated = await ref
        .read(adminManagementRepositoryProvider)
        .updateRolePermissions(role.id, permissionIds.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.adminAdminsPermissionsUpdatedMessage ??
              'Role permissions updated successfully',
        ),
      ),
    );
    await _loadRoles(selectId: updated.id);
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = ref.watch(currentAdminProvider);
    if (!(currentAdmin?.hasPermission('admin.admins.manage') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.adminAdminsTitle ?? 'Admin management',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.adminAdminsSubtitle ??
                  'Manage admin accounts, role assignments, and permission maps.',
            ),
            const SizedBox(height: 20),
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: l10n?.adminAdminsUsersTab ?? 'Admin users'),
                Tab(text: l10n?.adminAdminsRolesTab ?? 'Roles & permissions'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUsersTab(context, l10n, currentAdmin),
                  _buildRolesTab(context, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(
    BuildContext context,
    AppLocalizations? l10n,
    AdminUser? currentAdmin,
  ) {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return Center(child: Text(_usersError!));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    initialValue: _search,
                    decoration: InputDecoration(
                      labelText:
                          l10n?.adminAdminsSearchLabel ?? 'Search admins',
                    ),
                    onFieldSubmitted: (value) {
                      setState(() {
                        _search = value.trim();
                        _page = 1;
                      });
                      _loadUsers();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: l10n?.adminAdminsStatusFilter ?? 'Status',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(l10n?.adminUsersStatusAll ?? 'All'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(l10n?.adminUsersStatusActive ?? 'Active'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child:
                            Text(l10n?.adminUsersStatusDisabled ?? 'Disabled'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? 'all';
                        _page = 1;
                      });
                      _loadUsers();
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showCreateAdminDialog,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(l10n?.adminAdminsCreateAction ?? 'Create admin'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.retry ?? 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._adminUsers.map(
              (adminUser) => Card(
                color: _selectedAdmin?.id == adminUser.id
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.35)
                    : null,
                child: ListTile(
                  onTap: () => _loadUsers(selectId: adminUser.id),
                  title: Text(adminUser.email),
                  subtitle: Text(
                    '${adminUser.name.isEmpty ? '—' : adminUser.name}\n${adminUser.roles.join(', ')}',
                  ),
                  isThreeLine: true,
                  trailing: _StatusChip(
                    active: adminUser.isActive,
                    activeLabel: l10n?.adminUsersStatusActive ?? 'Active',
                    disabledLabel: l10n?.adminUsersStatusDisabled ?? 'Disabled',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.adminPaginationSummary(
                        (_adminPagination['page'] as int?) ?? _page,
                        (_adminPagination['total_pages'] as int?) ?? 1,
                        (_adminPagination['total'] as int?) ??
                            _adminUsers.length,
                      ) ??
                      '',
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed:
                          ((_adminPagination['has_previous'] as bool?) ?? false)
                              ? () {
                                  setState(() => _page -= 1);
                                  _loadUsers();
                                }
                              : null,
                      child: Text(l10n?.adminPaginationPrevious ?? 'Previous'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          ((_adminPagination['has_next'] as bool?) ?? false)
                              ? () {
                                  setState(() => _page += 1);
                                  _loadUsers();
                                }
                              : null,
                      child: Text(l10n?.adminPaginationNext ?? 'Next'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        final detail = _buildAdminDetail(context, l10n, currentAdmin);
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              children: [list, const SizedBox(height: 16), detail],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: SingleChildScrollView(child: list)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: SingleChildScrollView(child: detail)),
          ],
        );
      },
    );
  }

  Widget _buildAdminDetail(
    BuildContext context,
    AppLocalizations? l10n,
    AdminUser? currentAdmin,
  ) {
    final adminUser = _selectedAdmin;
    if (adminUser == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.adminAdminsNoSelection ??
                'Select an admin account to view details',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    adminUser.email,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusChip(
                  active: adminUser.isActive,
                  activeLabel: l10n?.adminUsersStatusActive ?? 'Active',
                  disabledLabel: l10n?.adminUsersStatusDisabled ?? 'Disabled',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n?.adminAdminsNameField ?? 'Name'}: ${adminUser.name.isEmpty ? '—' : adminUser.name}',
            ),
            Text('${l10n?.adminAdminsIdLabel ?? 'ID'}: ${adminUser.id}'),
            const SizedBox(height: 16),
            Text(
              l10n?.adminAdminsRolesSection ?? 'Assigned roles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: adminUser.roles.map((roleName) {
                final role = _roles.cast<AdminRoleRecord?>().firstWhere(
                      (item) => item?.name == roleName,
                      orElse: () => null,
                    );
                return InputChip(
                  label: Text(roleName),
                  onDeleted:
                      role == null ? null : () => _removeRole(adminUser, role),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _showAssignRoleDialog(adminUser),
                  child: Text(
                    l10n?.adminAdminsAssignRoleAction ?? 'Assign role',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _showEditAdminDialog(adminUser),
                  child: Text(l10n?.adminAdminsEditAction ?? 'Edit admin'),
                ),
                OutlinedButton(
                  onPressed: adminUser.isActive
                      ? () => _setAdminEnabled(adminUser, false)
                      : () => _setAdminEnabled(adminUser, true),
                  child: Text(
                    adminUser.isActive
                        ? (l10n?.adminAdminsDisableAction ?? 'Disable')
                        : (l10n?.adminAdminsEnableAction ?? 'Enable'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.adminAdminsPermissionsSection ?? 'Effective permissions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: adminUser.permissions
                  .map((permission) => Chip(label: Text(permission)))
                  .toList(),
            ),
            if (currentAdmin?.id == adminUser.id) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.adminAdminsCurrentAdminHint ??
                    'Your own admin account is protected from self-disable and self-role removal.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolesTab(BuildContext context, AppLocalizations? l10n) {
    if (_loadingRoles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rolesError != null) {
      return Center(child: Text(_rolesError!));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _showCreateRoleDialog,
                  icon: const Icon(Icons.add),
                  label:
                      Text(l10n?.adminAdminsCreateRoleAction ?? 'Create role'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadRoles,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.retry ?? 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._roles.map(
              (role) => Card(
                color: _selectedRole?.id == role.id
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.35)
                    : null,
                child: ListTile(
                  onTap: () => _loadRoles(selectId: role.id),
                  title: Text(role.name),
                  subtitle: Text(
                    '${role.description.isEmpty ? '—' : role.description}\n${role.permissionCount} permissions • ${role.adminCount} admins',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        );
        final detail = _buildRoleDetail(context, l10n);
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              children: [list, const SizedBox(height: 16), detail],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: SingleChildScrollView(child: list)),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: SingleChildScrollView(child: detail)),
          ],
        );
      },
    );
  }

  Widget _buildRoleDetail(BuildContext context, AppLocalizations? l10n) {
    final role = _selectedRole;
    final permissionsPayload = _permissionsPayload;
    if (role == null || permissionsPayload == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.adminAdminsNoRoleSelection ??
                'Select a role to edit permissions',
          ),
        ),
      );
    }
    final selectedPermissionIds =
        role.permissions.map((permission) => permission.id).toSet();
    return StatefulBuilder(
      builder: (context, setRoleState) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      role.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _showEditRoleDialog(role),
                    child: Text(l10n?.adminAdminsEditRoleAction ?? 'Edit role'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(role.description.isEmpty ? '—' : role.description),
              const SizedBox(height: 16),
              Text(
                l10n?.adminAdminsPermissionsSection ?? 'Permissions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...permissionsPayload.groups.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...entry.value.map(
                      (permission) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedPermissionIds.contains(permission.id),
                        title: Text(permission.name),
                        subtitle: permission.description.isEmpty
                            ? null
                            : Text(permission.description),
                        onChanged: (value) {
                          setRoleState(() {
                            if (value ?? false) {
                              selectedPermissionIds.add(permission.id);
                            } else {
                              selectedPermissionIds.remove(permission.id);
                            }
                          });
                        },
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () =>
                    _saveRolePermissions(role, selectedPermissionIds),
                child: Text(
                  l10n?.adminAdminsSavePermissionsAction ?? 'Save permissions',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.active,
    required this.activeLabel,
    required this.disabledLabel,
  });

  final bool active;
  final String activeLabel;
  final String disabledLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? activeLabel : disabledLabel,
        style: TextStyle(
          color: active ? scheme.primary : scheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
