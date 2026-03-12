import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_rbac_models.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_form_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

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
  bool _adminDetailLoading = false;
  bool _roleDetailLoading = false;
  String? _usersError;
  String? _rolesError;
  String? _adminDetailError;
  String? _roleDetailError;

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
      _adminDetailError = null;
    });
    try {
      final repository = ref.read(adminManagementRepositoryProvider);
      final response = await repository.fetchAdminUsers(
        search: _search,
        status: _status,
        page: _page,
      );
      AdminUser? selected;
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
      if (!mounted) return;
      setState(() {
        _adminUsers = response.items;
        _adminPagination = response.pagination;
        _selectedAdmin = selected;
        _loadingUsers = false;
        _adminDetailLoading = false;
      });
      if (selected != null) {
        await _selectAdmin(selected.id, quiet: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _loadingUsers = false;
        _adminDetailLoading = false;
      });
    }
  }

  Future<void> _loadRoles({int? selectId}) async {
    setState(() {
      _loadingRoles = true;
      _rolesError = null;
      _roleDetailError = null;
    });
    try {
      final repository = ref.read(adminManagementRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.fetchRoles(),
        repository.fetchPermissions(),
      ]);
      final roles = results[0] as List<AdminRoleRecord>;
      final permissions = results[1] as AdminPermissionsPayload;
      AdminRoleRecord? selected;
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
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissionsPayload = permissions;
        _selectedRole = selected;
        _loadingRoles = false;
        _roleDetailLoading = false;
      });
      if (selected != null) {
        await _selectRole(selected.id, quiet: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rolesError = e.toString();
        _loadingRoles = false;
        _roleDetailLoading = false;
      });
    }
  }

  Future<void> _selectAdmin(int adminUserId, {bool quiet = false}) async {
    final placeholder = _adminUsers.cast<AdminUser?>().firstWhere(
          (item) => item?.id == adminUserId,
          orElse: () => _selectedAdmin,
        );
    setState(() {
      _selectedAdmin = placeholder;
      _adminDetailLoading = true;
      _adminDetailError = null;
      if (!quiet) {
        _usersError = null;
      }
    });
    try {
      final admin = await ref
          .read(adminManagementRepositoryProvider)
          .fetchAdminUserDetail(adminUserId);
      if (!mounted) return;
      setState(() {
        _selectedAdmin = admin;
        _adminDetailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adminDetailError = e.toString();
        _adminDetailLoading = false;
      });
    }
  }

  Future<void> _selectRole(int roleId, {bool quiet = false}) async {
    final placeholder = _roles.cast<AdminRoleRecord?>().firstWhere(
          (item) => item?.id == roleId,
          orElse: () => _selectedRole,
        );
    setState(() {
      _selectedRole = placeholder;
      _roleDetailLoading = true;
      _roleDetailError = null;
      if (!quiet) {
        _rolesError = null;
      }
    });
    try {
      final role = await ref
          .read(adminManagementRepositoryProvider)
          .fetchRoleDetail(roleId);
      if (!mounted) return;
      setState(() {
        _selectedRole = role;
        _roleDetailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roleDetailError = e.toString();
        _roleDetailLoading = false;
      });
    }
  }

  Future<void> _showCreateAdminDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final selectedRoleIds = <int>{};
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
                vertical: 24,
              ),
              title: Text(l10n.adminAdminsCreateTitle),
              content: SizedBox(
                width: adminResponsiveDialogWidth(
                  context,
                  preferredWidth: 520,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.adminAdminsNameField,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: l10n.adminAdminsEmailField,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.adminAdminsPasswordField,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.adminAdminsInitialRolesLabel,
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
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.adminAdminsCreateAction),
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
          l10n.adminAdminsCreatedMessage,
        ),
      ),
    );
    await _loadUsers(selectId: created.id);
    await _loadRoles();
  }

  Future<void> _showEditAdminDialog(AdminUser adminUser) async {
    final l10n = AppLocalizations.of(context)!;
    final emailController = TextEditingController(text: adminUser.email);
    final nameController = TextEditingController(text: adminUser.name);
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
              vertical: 24,
            ),
            title: Text(l10n.adminAdminsEditTitle),
            content: SizedBox(
              width: adminResponsiveDialogWidth(
                context,
                preferredWidth: 440,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsNameField,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsEmailField,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsPasswordField,
                        helperText: l10n.adminAdminsPasswordHelper,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
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
          l10n.adminAdminsUpdatedMessage,
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
  }

  Future<void> _setAdminEnabled(AdminUser adminUser, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              enabled
                  ? l10n.adminAdminsEnableTitle
                  : l10n.adminAdminsDisableTitle,
            ),
            content: Text(
              enabled
                  ? l10n.adminAdminsEnableConfirm
                  : l10n.adminAdminsDisableConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  enabled
                      ? l10n.adminAdminsEnableAction
                      : l10n.adminAdminsDisableAction,
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
              ? l10n.adminAdminsEnabledMessage
              : l10n.adminAdminsDisabledMessage,
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
  }

  Future<void> _showAssignRoleDialog(AdminUser adminUser) async {
    final l10n = AppLocalizations.of(context)!;
    final availableRoles =
        _roles.where((role) => !adminUser.roles.contains(role.name)).toList();
    if (availableRoles.isEmpty) return;
    int selectedRoleId = availableRoles.first.id;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(l10n.adminAdminsAssignRoleTitle),
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
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    l10n.adminAdminsAssignRoleAction,
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
          l10n.adminAdminsRoleAssignedMessage,
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
    await _loadRoles();
  }

  Future<void> _removeRole(AdminUser adminUser, AdminRoleRecord role) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.adminAdminsRemoveRoleTitle),
            content: Text(
              l10n.adminAdminsRemoveRoleConfirm(role.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.adminAdminsRemoveRoleAction,
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
          l10n.adminAdminsRoleRemovedMessage,
        ),
      ),
    );
    await _loadUsers(selectId: updated.id);
    await _loadRoles();
  }

  Future<void> _showCreateRoleDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
              vertical: 24,
            ),
            title: Text(l10n.adminAdminsCreateRoleTitle),
            content: SizedBox(
              width: adminResponsiveDialogWidth(
                context,
                preferredWidth: 440,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsRoleNameField,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsRoleDescriptionField,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.adminAdminsCreateRoleAction,
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
          l10n.adminAdminsRoleCreatedMessage,
        ),
      ),
    );
    await _loadRoles(selectId: created.id);
  }

  Future<void> _showEditRoleDialog(AdminRoleRecord role) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: role.name);
    final descriptionController = TextEditingController(text: role.description);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 40,
              vertical: 24,
            ),
            title: Text(l10n.adminAdminsEditRoleTitle),
            content: SizedBox(
              width: adminResponsiveDialogWidth(
                context,
                preferredWidth: 440,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsRoleNameField,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.adminAdminsRoleDescriptionField,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
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
          l10n.adminAdminsRoleUpdatedMessage,
        ),
      ),
    );
    await _loadRoles(selectId: updated.id);
  }

  Future<void> _saveRolePermissions(
    AdminRoleRecord role,
    Set<int> permissionIds,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final updated = await ref
        .read(adminManagementRepositoryProvider)
        .updateRolePermissions(role.id, permissionIds.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.adminAdminsPermissionsUpdatedMessage,
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
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminPageHeader(
              title: l10n.adminAdminsTitle,
              subtitle: l10n.adminAdminsSubtitle,
              actions: [
                OutlinedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: l10n.adminAdminsUsersTab),
                Tab(text: l10n.adminAdminsRolesTab),
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
    AppLocalizations l10n,
    AdminUser? currentAdmin,
  ) {
    if (_loadingUsers) {
      return const AdminLoadingState();
    }
    if (_usersError != null) {
      return AdminErrorState(message: _usersError!, onRetry: _loadUsers);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final compact = constraints.maxWidth < 720;
        final fieldWidth = compact ? constraints.maxWidth : 260.0;
        final dropdownWidth = compact ? constraints.maxWidth : 200.0;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: TextFormField(
                    initialValue: _search,
                    decoration: InputDecoration(
                      labelText: l10n.adminAdminsSearchLabel,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                  width: dropdownWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.adminAdminsStatusFilter,
                      prefixIcon:
                          const Icon(Icons.filter_list_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(l10n.adminUsersStatusAll),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(l10n.adminUsersStatusActive),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text(l10n.adminUsersStatusDisabled),
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
                  label: Text(l10n.adminAdminsCreateAction),
                ),
                OutlinedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
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
                  onTap: () => _selectAdmin(adminUser.id),
                  title: Text(adminUser.email),
                  subtitle: Text(
                    '${adminUser.name.isEmpty ? '—' : adminUser.name}\n${adminUser.roles.join(', ')}',
                  ),
                  isThreeLine: true,
                  trailing: _StatusChip(
                    active: adminUser.isActive,
                    activeLabel: l10n.adminUsersStatusActive,
                    disabledLabel: l10n.adminUsersStatusDisabled,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AdminPaginationBar(
              summary: l10n.adminPaginationSummary(
                (_adminPagination['page'] as int?) ?? _page,
                (_adminPagination['total_pages'] as int?) ?? 1,
                (_adminPagination['total'] as int?) ?? _adminUsers.length,
              ),
              hasPrevious: (_adminPagination['has_previous'] as bool?) ?? false,
              hasNext: (_adminPagination['has_next'] as bool?) ?? false,
              previousLabel: l10n.adminPaginationPrevious,
              nextLabel: l10n.adminPaginationNext,
              onPrevious: () {
                setState(() => _page -= 1);
                _loadUsers();
              },
              onNext: () {
                setState(() => _page += 1);
                _loadUsers();
              },
            ),
          ],
        );
        final detail = _buildAdminDetail(context, l10n, currentAdmin);
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
    AppLocalizations l10n,
    AdminUser? currentAdmin,
  ) {
    final adminUser = _selectedAdmin;
    if (adminUser == null) {
      return AdminEmptyState(
        message: l10n.adminAdminsNoSelection,
        icon: Icons.manage_accounts_outlined,
      );
    }
    if (_adminDetailLoading) {
      return const Card(
        child: AdminLoadingState(padding: EdgeInsets.all(24)),
      );
    }
    if (_adminDetailError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AdminErrorState(
            message: _adminDetailError!,
            onRetry: () => _selectAdmin(adminUser.id),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _StatusChip(
                  active: adminUser.isActive,
                  activeLabel: l10n.adminUsersStatusActive,
                  disabledLabel: l10n.adminUsersStatusDisabled,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.adminAdminsNameField}: ${adminUser.name.isEmpty ? l10n.notAvailable : adminUser.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${l10n.adminAdminsIdLabel}: ${adminUser.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adminAdminsRolesSection,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                FilledButton.icon(
                  onPressed: () => _showAssignRoleDialog(adminUser),
                  icon: const Icon(Icons.add_moderator_outlined, size: 18),
                  label: Text(l10n.adminAdminsAssignRoleAction),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showEditAdminDialog(adminUser),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.adminAdminsEditAction),
                ),
                OutlinedButton.icon(
                  onPressed: adminUser.isActive
                      ? () => _setAdminEnabled(adminUser, false)
                      : () => _setAdminEnabled(adminUser, true),
                  icon: Icon(
                    adminUser.isActive
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    adminUser.isActive
                        ? l10n.adminAdminsDisableAction
                        : l10n.adminAdminsEnableAction,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adminAdminsPermissionsSection,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: adminUser.permissions
                  .map((permission) => Chip(
                        label: Text(permission),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            if (currentAdmin?.id == adminUser.id) ...[
              const SizedBox(height: 16),
              Text(
                l10n.adminAdminsCurrentAdminHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolesTab(BuildContext context, AppLocalizations l10n) {
    if (_loadingRoles) {
      return const AdminLoadingState();
    }
    if (_rolesError != null) {
      return AdminErrorState(message: _rolesError!, onRetry: _loadRoles);
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
                  label: Text(l10n.adminAdminsCreateRoleAction),
                ),
                OutlinedButton.icon(
                  onPressed: _loadRoles,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
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
                  onTap: () => _selectRole(role.id),
                  title: Text(role.name),
                  subtitle: Text(
                    '${role.description.isEmpty ? '—' : role.description}\n${l10n.adminRoleStats(role.permissionCount, role.adminCount)}',
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _buildRoleDetail(BuildContext context, AppLocalizations l10n) {
    final role = _selectedRole;
    final permissionsPayload = _permissionsPayload;
    if (role == null || permissionsPayload == null) {
      return AdminEmptyState(
        message: l10n.adminAdminsNoRoleSelection,
        icon: Icons.security_outlined,
      );
    }
    if (_roleDetailLoading) {
      return const Card(
        child: AdminLoadingState(padding: EdgeInsets.all(24)),
      );
    }
    if (_roleDetailError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AdminErrorState(
            message: _roleDetailError!,
            onRetry: () => _selectRole(role.id),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showEditRoleDialog(role),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.adminAdminsEditRoleAction),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                role.description.isEmpty ? '—' : role.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.adminAdminsPermissionsSection,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ...permissionsPayload.groups.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.key.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                      ),
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
              FilledButton.icon(
                onPressed: () =>
                    _saveRolePermissions(role, selectedPermissionIds),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(l10n.adminAdminsSavePermissionsAction),
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
