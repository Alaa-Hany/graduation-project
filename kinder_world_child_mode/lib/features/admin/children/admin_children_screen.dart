import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_child_record.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_confirm_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_filter_bar.dart';
import 'package:kinder_world/features/admin/shared/admin_form_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/features/admin/shared/admin_table_widgets.dart';

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

  Future<void> _edit(AdminChildRecord child) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: child.name);
    final ageCtrl = TextEditingController(text: child.age?.toString() ?? '');
    final avatarCtrl = TextEditingController(text: child.avatar ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminFormDialog(
        title: l10n.adminChildrenEditTitle,
        submitLabel: l10n.save,
        onSubmit: () => Navigator.of(ctx).pop(true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenNameField,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenAgeField,
                prefixIcon: const Icon(Icons.cake_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: avatarCtrl,
              decoration: InputDecoration(
                labelText: l10n.adminChildrenAvatarField,
                prefixIcon: const Icon(Icons.image_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated =
          await ref.read(adminManagementRepositoryProvider).updateChild(
                child.id,
                name: nameCtrl.text.trim(),
                age: ageCtrl.text.trim(),
                avatar: avatarCtrl.text.trim(),
              );
      if (!mounted) return;
      setState(() {
        final idx = _children.indexWhere((c) => c.id == updated.id);
        if (idx != -1) {
          _children = List.of(_children)..[idx] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminChildrenUpdatedMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deactivate(AdminChildRecord child) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: l10n.adminChildrenDeactivateTitle,
      message: l10n.adminChildrenDeactivateConfirm,
      confirmLabel: l10n.adminChildrenDeactivateAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      final updated = await ref
          .read(adminManagementRepositoryProvider)
          .deactivateChild(child.id);
      if (!mounted) return;
      setState(() {
        final idx = _children.indexWhere((c) => c.id == updated.id);
        if (idx != -1) {
          _children = List.of(_children)..[idx] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminChildrenDeactivatedMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canWrite =
        ref.watch(adminAuthProvider.notifier).hasPermission('children:write');

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.primary),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // ── Header ────────────────────────────────────────────────────────
          AdminPageHeader(
            title: l10n.adminChildrenTitle,
            subtitle: l10n.adminChildrenSubtitle,
            actions: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadChildren,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.adminRefreshTooltip),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filter Bar ────────────────────────────────────────────────────
          AdminFilterBar(
            trailing: FilledButton.icon(
              onPressed: () {
                setState(() => _page = 1);
                _loadChildren();
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(l10n.adminAuditApplyFilters),
            ),
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _parentIdController,
                  decoration: InputDecoration(
                    labelText: l10n.adminChildrenParentFilter,
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 18),
                    border: outlineBorder,
                    enabledBorder: outlineBorder,
                    focusedBorder: focusedBorder,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    setState(() => _page = 1);
                    _loadChildren();
                  },
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.adminChildrenAgeFilter,
                    prefixIcon: const Icon(Icons.cake_outlined, size: 18),
                    border: outlineBorder,
                    enabledBorder: outlineBorder,
                    focusedBorder: focusedBorder,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    setState(() => _page = 1);
                    _loadChildren();
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _active,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.adminChildrenStatusFilter,
                    prefixIcon: const Icon(Icons.toggle_on_outlined, size: 18),
                    border: outlineBorder,
                    enabledBorder: outlineBorder,
                    focusedBorder: focusedBorder,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                  onChanged: (v) {
                    setState(() {
                      _active = v;
                      _page = 1;
                    });
                    _loadChildren();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Content ───────────────────────────────────────────────────────
          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _loadChildren)
          else if (_children.isEmpty)
            AdminEmptyState(
              message: l10n.adminChildrenNoChildren,
              icon: Icons.child_care_outlined,
            )
          else
            AdminDataTableCard(
              mobileBreakpoint: 860,
              mobileBuilder: (context) => Column(
                children: _children
                    .map(
                      (child) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      child.name.isNotEmpty
                                          ? child.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          child.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          child.parent?['name'] as String? ??
                                              '#${child.parentId}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _ChildStatusChip(
                                    isActive: child.isActive,
                                    activeLabel: l10n.adminUsersStatusActive,
                                    inactiveLabel: l10n.adminUsersStatusDisabled,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      '${l10n.adminChildrenAgeColumn}: ${child.age?.toString() ?? '—'}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    label: Text('#${child.id}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if (canWrite) ...[
                                const Divider(height: 20),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _edit(child),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: Text(l10n.edit),
                                    ),
                                    TextButton.icon(
                                      onPressed: child.isActive
                                          ? () => _deactivate(child)
                                          : null,
                                      icon: const Icon(Icons.block_outlined, size: 16),
                                      label:
                                          Text(l10n.adminChildrenDeactivateAction),
                                      style: TextButton.styleFrom(
                                        foregroundColor: child.isActive
                                            ? colorScheme.error
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    l10n.adminChildrenNameColumn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l10n.adminChildrenParentColumn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l10n.adminChildrenAgeColumn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l10n.adminChildrenStatusColumn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l10n.adminChildrenActionsColumn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              rows: _children
                  .map(
                    (child) => DataRow(
                      cells: [
                        // Name cell with avatar initial
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  child.name.isNotEmpty
                                      ? child.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                child.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        // Parent cell
                        DataCell(
                          Text(
                            child.parent?['name'] as String? ??
                                '#${child.parentId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        // Age cell
                        DataCell(
                          Text(
                            child.age?.toString() ?? '—',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        // Status chip
                        DataCell(
                          _ChildStatusChip(
                            isActive: child.isActive,
                            activeLabel: l10n.adminUsersStatusActive,
                            inactiveLabel: l10n.adminUsersStatusDisabled,
                          ),
                        ),
                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: l10n.edit,
                                color: colorScheme.primary,
                                onPressed: canWrite ? () => _edit(child) : null,
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.block_outlined, size: 18),
                                tooltip: l10n.adminChildrenDeactivateAction,
                                color: child.isActive
                                    ? colorScheme.error
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                onPressed: canWrite && child.isActive
                                    ? () => _deactivate(child)
                                    : null,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),

          // ── Pagination ────────────────────────────────────────────────────
          if (!_loading && _error == null && _children.isNotEmpty) ...[
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
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Status Chip ─────────────────────────────────────

class _ChildStatusChip extends StatelessWidget {
  const _ChildStatusChip({
    required this.isActive,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? activeLabel : inactiveLabel,
        style: TextStyle(
          color: isActive ? scheme.primary : scheme.error,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
