import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
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

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _status = 'all';
  int _page = 1;
  bool _loading = true;
  String? _error;
  List<AdminParentUser> _users = const [];
  Map<String, dynamic> _pagination = const {};

  List<DropdownMenuItem<String>> _planItems(AppLocalizations l10n) => [
        DropdownMenuItem(
          value: 'FREE',
          child: Text(l10n.adminPlanFree),
        ),
        DropdownMenuItem(
          value: 'PREMIUM',
          child: Text(l10n.adminPlanPremium),
        ),
        DropdownMenuItem(
          value: 'FAMILY_PLUS',
          child: Text(l10n.adminPlanFamilyPlus),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(adminManagementRepositoryProvider).fetchUsers(
                search: _searchController.text,
                status: _status,
                page: _page,
              );
      if (!mounted) return;
      setState(() {
        _users = response.items;
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

  Future<void> _showEditDialog(AdminParentUser user) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    String plan = user.plan;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AdminFormDialog(
          title: l10n.adminUsersEditTitle,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.adminUsersNameField,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: l10n.adminUsersEmailField,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: plan,
                    items: _planItems(l10n),
                    onChanged: (value) => setState(() => plan = value ?? plan),
                    decoration: InputDecoration(
                      labelText: l10n.adminUsersPlanField,
                    ),
                  ),
                ],
              );
            },
          ),
          onSubmit: () => Navigator.pop(context, true),
        );
      },
    );

    if (saved != true) return;

    await ref.read(adminManagementRepositoryProvider).updateUser(
          user.id,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          plan: plan,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminUsersUpdatedMessage)),
    );
    await _loadUsers();
  }

  Future<void> _toggleEnabled(AdminParentUser user, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: enabled ? l10n.adminUsersEnableTitle : l10n.adminUsersDisableTitle,
      message: enabled
          ? l10n.adminUsersEnableConfirm
          : l10n.adminUsersDisableConfirm,
      confirmLabel:
          enabled ? l10n.adminUsersEnableAction : l10n.adminUsersDisableAction,
    );
    if (!confirmed) return;

    await ref
        .read(adminManagementRepositoryProvider)
        .setUserEnabled(user.id, enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? l10n.adminUsersEnabledMessage
              : l10n.adminUsersDisabledMessage,
        ),
      ),
    );
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.users.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ─────────────────────────────────────────
              AdminPageHeader(
                title: l10n.adminUsersTitle,
                subtitle: l10n.adminUsersSubtitle,
                actions: [
                  FilledButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Filters ─────────────────────────────────────────────
              AdminFilterBar(
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 260,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.adminUsersSearchLabel,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _loadUsers();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: l10n.adminUsersStatusFilter,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                ],
              ),
              const SizedBox(height: 20),

              // ── Content ─────────────────────────────────────────────
              if (_loading)
                const AdminLoadingState()
              else if (_error != null)
                AdminErrorState(message: _error!, onRetry: _loadUsers)
              else if (_users.isEmpty)
                AdminEmptyState(message: l10n.adminUsersSubtitle)
              else if (compact)
                Column(
                  children: _users.map((user) {
                    return Card(
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
                                    (user.name.isNotEmpty
                                            ? user.name[0]
                                            : user.email[0])
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name.isEmpty ? '-' : user.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        user.email,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                _StatusChip(
                                  isActive: user.isActive,
                                  activeLabel: l10n.adminUsersStatusActive,
                                  inactiveLabel: l10n.adminUsersStatusDisabled,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _PlanChip(plan: user.plan),
                                Chip(
                                  avatar:
                                      const Icon(Icons.child_care, size: 14),
                                  label: Text('${user.childCount}'),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () => context
                                      .go('${Routes.adminUsers}/${user.id}'),
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 16),
                                  label: Text(l10n.adminUsersViewAction),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showEditDialog(user),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 16),
                                  label: Text(l10n.edit),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _toggleEnabled(user, !user.isActive),
                                  icon: Icon(
                                    user.isActive
                                        ? Icons.block_outlined
                                        : Icons.check_circle_outline,
                                    size: 16,
                                    color: user.isActive
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                  label: Text(
                                    user.isActive
                                        ? l10n.adminUsersDisableAction
                                        : l10n.adminUsersEnableAction,
                                    style: TextStyle(
                                      color: user.isActive
                                          ? colorScheme.error
                                          : colorScheme.primary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                AdminDataTableCard(
                  columns: [
                    DataColumn(label: Text(l10n.adminUsersNameColumn)),
                    DataColumn(label: Text(l10n.adminUsersEmailColumn)),
                    DataColumn(label: Text(l10n.adminUsersPlanColumn)),
                    DataColumn(label: Text(l10n.adminUsersChildrenColumn)),
                    DataColumn(label: Text(l10n.adminUsersStatusColumn)),
                    DataColumn(label: Text(l10n.adminUsersActionsColumn)),
                  ],
                  rows: _users.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  (user.name.isNotEmpty
                                          ? user.name[0]
                                          : user.email[0])
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(user.name.isEmpty ? '-' : user.name),
                            ],
                          ),
                        ),
                        DataCell(Text(user.email)),
                        DataCell(_PlanChip(plan: user.plan)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.child_care,
                                  size: 14,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text('${user.childCount}'),
                            ],
                          ),
                        ),
                        DataCell(
                          _StatusChip(
                            isActive: user.isActive,
                            activeLabel: l10n.adminUsersStatusActive,
                            inactiveLabel: l10n.adminUsersStatusDisabled,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.adminUsersViewAction,
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 18),
                                onPressed: () => context
                                    .go('${Routes.adminUsers}/${user.id}'),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                tooltip: l10n.edit,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showEditDialog(user),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                tooltip: user.isActive
                                    ? l10n.adminUsersDisableAction
                                    : l10n.adminUsersEnableAction,
                                icon: Icon(
                                  user.isActive
                                      ? Icons.block_outlined
                                      : Icons.check_circle_outline,
                                  size: 18,
                                  color: user.isActive
                                      ? colorScheme.error
                                      : colorScheme.primary,
                                ),
                                onPressed: () =>
                                    _toggleEnabled(user, !user.isActive),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              AdminPaginationBar(
                summary: l10n.adminPaginationSummary(
                  (_pagination['page'] as int?) ?? _page,
                  (_pagination['total_pages'] as int?) ?? 1,
                  (_pagination['total'] as int?) ?? _users.length,
                ),
                hasPrevious: (_pagination['has_previous'] as bool?) ?? false,
                hasNext: (_pagination['has_next'] as bool?) ?? false,
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
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.isActive,
    required this.activeLabel,
    required this.inactiveLabel,
  });

  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? activeLabel : inactiveLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalized = plan.trim().toUpperCase();
    final foreground = switch (normalized) {
      'PREMIUM' => const Color(0xFF8A5A00),
      'FAMILY_PLUS' => const Color(0xFF0B7285),
      _ => colorScheme.onSurfaceVariant,
    };
    final background = switch (normalized) {
      'PREMIUM' => const Color(0xFFFFF3CD),
      'FAMILY_PLUS' => const Color(0xFFD9F2F7),
      _ => colorScheme.surfaceContainerHighest,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
