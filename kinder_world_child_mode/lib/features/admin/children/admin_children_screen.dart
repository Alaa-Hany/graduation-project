import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_child_record.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_confirm_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_form_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';
import 'package:kinder_world/router.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class AdminChildrenScreen extends ConsumerStatefulWidget {
  const AdminChildrenScreen({super.key});

  @override
  ConsumerState<AdminChildrenScreen> createState() =>
      _AdminChildrenScreenState();
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
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchChildren(
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
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: child.name);
    final ageController =
        TextEditingController(text: child.age?.toString() ?? '');
    final avatarController = TextEditingController(text: child.avatar ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: l10n.adminChildrenEditTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenNameField,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenAgeField,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avatarController,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenAvatarField,
              ),
            ),
          ],
        ),
        onSubmit: () => Navigator.pop(context, true),
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
      SnackBar(content: Text(l10n.adminChildrenUpdatedMessage)),
    );
    await _loadChildren();
  }

  Future<void> _deactivate(AdminChildRecord child) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminChildrenDeactivateTitle,
      message: l10n.adminChildrenDeactivateConfirm,
      confirmLabel: l10n.adminChildrenDeactivateAction,
    );
    if (!confirmed) return;

    await ref.read(adminManagementRepositoryProvider).deactivateChild(child.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminChildrenDeactivatedMessage)),
    );
    await _loadChildren();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.adminChildrenTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.adminChildrenSubtitle),
          const SizedBox(height: 24),
          AdminFilterBar(
            children: [
              Expanded(
                child: TextField(
                  controller: _parentIdController,
                  decoration: InputDecoration(
                    labelText: l10n.adminChildrenParentFilter,
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
                    labelText: l10n.adminChildrenAgeFilter,
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
                    labelText: l10n.adminChildrenStatusFilter,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.adminUsersStatusAll),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(l10n.adminUsersStatusActive),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(l10n.adminUsersStatusDisabled),
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
                label: Text(l10n.retry),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _loadChildren)
          else
            AdminDataTableCard(
              columns: [
                DataColumn(label: Text(l10n.adminChildrenNameColumn)),
                DataColumn(label: Text(l10n.adminChildrenParentColumn)),
                DataColumn(label: Text(l10n.adminChildrenAgeColumn)),
                DataColumn(label: Text(l10n.adminChildrenStatusColumn)),
                DataColumn(label: Text(l10n.adminChildrenActionsColumn)),
              ],
              rows: _children
                  .map(
                    (child) => DataRow(
                      cells: [
                        DataCell(Text(child.name)),
                        DataCell(Text('${child.parentId}')),
                        DataCell(Text(child.age?.toString() ?? '-')),
                        DataCell(
                          Chip(
                            label: Text(
                              child.isActive
                                  ? (l10n.adminUsersStatusActive)
                                  : (l10n.adminUsersStatusDisabled),
                            ),
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => context
                                    .go('${Routes.adminChildren}/${child.id}'),
                                child: Text(l10n.adminUsersViewAction),
                              ),
                              TextButton(
                                onPressed: () => _showEditDialog(child),
                                child: Text(l10n.edit),
                              ),
                              TextButton(
                                onPressed: child.isActive
                                    ? () => _deactivate(child)
                                    : null,
                                child: Text(l10n.adminChildrenDeactivateAction),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          AdminPaginationBar(
            summary: l10n.adminPaginationSummary(
              (_pagination['page'] as int?) ?? _page,
              (_pagination['total_pages'] as int?) ?? 1,
              (_pagination['total'] as int?) ?? _children.length,
            ),
            hasPrevious: (_pagination['has_previous'] as bool?) ?? false,
            hasNext: (_pagination['has_next'] as bool?) ?? false,
            previousLabel: l10n.adminPaginationPrevious,
            nextLabel: l10n.adminPaginationNext,
            onPrevious: () {
              setState(() => _page -= 1);
              _loadChildren();
            },
            onNext: () {
              setState(() => _page += 1);
              _loadChildren();
            },
          ),
        ],
      ),
    );
  }
}
