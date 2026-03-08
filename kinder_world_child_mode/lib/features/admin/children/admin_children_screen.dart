import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_child_record.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/router.dart';

class AdminChildrenScreen extends ConsumerStatefulWidget {
  const AdminChildrenScreen({super.key});

  @override
  ConsumerState<AdminChildrenScreen> createState() => _AdminChildrenScreenState();
}

class _AdminChildrenScreenState extends ConsumerState<AdminChildrenScreen> {
  final _parentIdController = TextEditingController();
  final _ageController = TextEditingController();
  int _page = 1;
  bool? _active;
  bool _loading = true;
  String? _error;
  List<AdminChildRecord> _children = const [];
  Map<String, dynamic> _pagination = const {};

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _parentIdController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(adminManagementRepositoryProvider).fetchChildren(
            parentId: _parentIdController.text.trim(),
            age: _ageController.text.trim(),
            active: _active,
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _children = response.items;
        _pagination = response.pagination;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showEditDialog(AdminChildRecord child) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: child.name);
    final ageController = TextEditingController(text: child.age?.toString() ?? '');
    final avatarController = TextEditingController(text: child.avatar ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.adminChildrenEditTitle ?? 'Edit child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n?.adminChildrenNameField ?? 'Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              decoration: InputDecoration(
                labelText: l10n?.adminChildrenAgeField ?? 'Age',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avatarController,
              decoration: InputDecoration(
                labelText: l10n?.adminChildrenAvatarField ?? 'Avatar',
              ),
            ),
          ],
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
    );
    if (saved != true) return;

    await ref.read(adminManagementRepositoryProvider).updateChild(
          child.id,
          name: nameController.text.trim(),
          age: ageController.text.trim(),
          avatar: avatarController.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.adminChildrenUpdatedMessage ?? 'Child updated successfully')),
    );
    await _loadChildren();
  }

  Future<void> _deactivate(AdminChildRecord child) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n?.adminChildrenDeactivateTitle ?? 'Deactivate child'),
            content: Text(
              l10n?.adminChildrenDeactivateConfirm ?? 'Deactivate this child profile?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n?.adminChildrenDeactivateAction ?? 'Deactivate'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await ref.read(adminManagementRepositoryProvider).deactivateChild(child.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.adminChildrenDeactivatedMessage ?? 'Child deactivated successfully')),
    );
    await _loadChildren();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.children.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.adminChildrenTitle ?? 'Children management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n?.adminChildrenSubtitle ?? 'Inspect and maintain child profiles.'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _parentIdController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminChildrenParentFilter ?? 'Parent ID',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _loadChildren();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  decoration: InputDecoration(
                    labelText: l10n?.adminChildrenAgeFilter ?? 'Age',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _loadChildren();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _active,
                  decoration: InputDecoration(
                    labelText: l10n?.adminChildrenStatusFilter ?? 'Status',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n?.adminUsersStatusAll ?? 'All'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(l10n?.adminUsersStatusActive ?? 'Active'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(l10n?.adminUsersStatusDisabled ?? 'Disabled'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _active = value;
                      _page = 1;
                    });
                    _loadChildren();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loadChildren,
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.retry ?? 'Retry'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(l10n?.adminChildrenNameColumn ?? 'Name')),
                    DataColumn(label: Text(l10n?.adminChildrenParentColumn ?? 'Parent')),
                    DataColumn(label: Text(l10n?.adminChildrenAgeColumn ?? 'Age')),
                    DataColumn(label: Text(l10n?.adminChildrenStatusColumn ?? 'Status')),
                    DataColumn(label: Text(l10n?.adminChildrenActionsColumn ?? 'Actions')),
                  ],
                  rows: _children
                      .map(
                        (child) => DataRow(
                          cells: [
                            DataCell(Text(child.name)),
                            DataCell(Text('${child.parentId}')),
                            DataCell(Text(child.age?.toString() ?? '—')),
                            DataCell(
                              Chip(
                                label: Text(
                                  child.isActive
                                      ? (l10n?.adminUsersStatusActive ?? 'Active')
                                      : (l10n?.adminUsersStatusDisabled ?? 'Disabled'),
                                ),
                              ),
                            ),
                            DataCell(
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => context.go('${Routes.adminChildren}/${child.id}'),
                                    child: Text(l10n?.adminUsersViewAction ?? 'View'),
                                  ),
                                  TextButton(
                                    onPressed: () => _showEditDialog(child),
                                    child: Text(l10n?.edit ?? 'Edit'),
                                  ),
                                  TextButton(
                                    onPressed: child.isActive ? () => _deactivate(child) : null,
                                    child: Text(l10n?.adminChildrenDeactivateAction ?? 'Deactivate'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.adminPaginationSummary(
                      (_pagination['page'] as int?) ?? _page,
                      (_pagination['total_pages'] as int?) ?? 1,
                      (_pagination['total'] as int?) ?? _children.length,
                    ) ??
                    'Page ${(_pagination['page'] as int?) ?? _page}',
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: ((_pagination['has_previous'] as bool?) ?? false)
                        ? () {
                            setState(() => _page -= 1);
                            _loadChildren();
                          }
                        : null,
                    child: Text(l10n?.adminPaginationPrevious ?? 'Previous'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: ((_pagination['has_next'] as bool?) ?? false)
                        ? () {
                            setState(() => _page += 1);
                            _loadChildren();
                          }
                        : null,
                    child: Text(l10n?.adminPaginationNext ?? 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
