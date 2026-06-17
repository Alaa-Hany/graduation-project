import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_management_activity.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_form_dialog.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class AdminUserDetailsScreen extends ConsumerStatefulWidget {
  const AdminUserDetailsScreen({
    super.key,
    required this.userId,
  });

  final int userId;

  @override
  ConsumerState<AdminUserDetailsScreen> createState() =>
      _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState
    extends ConsumerState<AdminUserDetailsScreen> {
  AdminParentUser? _user;
  AdminUserActivityDetails? _activity;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminUserDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminManagementRepositoryProvider);
      final results = await Future.wait<Object?>([
        repo.fetchUserDetail(widget.userId),
        repo.fetchUserActivity(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as AdminParentUser;
        _activity = results[1] as AdminUserActivityDetails;
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

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final user = _user;
    if (user == null) return;
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AdminFormDialog(
            title: l10n.adminUsersResetPasswordTitle,
            submitLabel: l10n.adminUsersResetPasswordAction,
            onSubmit: () => Navigator.of(context).pop(true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adminUsersResetPasswordHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.adminUsersPasswordField,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final temporaryPassword =
        await ref.read(adminManagementRepositoryProvider).resetUserPassword(
              user.id,
              newPassword: passwordController.text.trim(),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.adminUsersResetPasswordSuccess(temporaryPassword),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    final canEdit = admin?.hasPermission('admin.users.edit') ?? false;
    if (!(admin?.hasPermission('admin.users.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    if (_loading) {
      return const AdminLoadingState(padding: EdgeInsets.all(24));
    }
    if (_error != null || _user == null) {
      return AdminErrorState(
        message: _error ?? l10n.unexpectedError,
        onRetry: _load,
      );
    }

    final activity = _activity;
    final summary = activity?.summary;
    final notifications =
        activity?.notifications ?? const <AdminUserNotificationPreview>[];
    final tickets =
        activity?.supportTickets ?? const <AdminUserSupportTicketPreview>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminUsersDetailTitle(_user!.email),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (canEdit)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _resetPassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: Text(l10n.adminUsersResetPasswordAction),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InfoCard(
                title: l10n.adminUsersOverviewCard,
                lines: [
                  '${l10n.adminUsersNameField}: ${_user!.name.isEmpty ? l10n.notAvailable : _user!.name}',
                  '${l10n.adminUsersEmailField}: ${_user!.email}',
                  '${l10n.adminUsersPlanColumn}: ${_user!.plan}',
                  '${l10n.adminUsersStatusColumn}: ${_user!.isActive ? l10n.adminUsersStatusActive : l10n.adminUsersStatusDisabled}',
                ],
              ),
              _InfoCard(
                title: l10n.adminUsersActivityCard,
                lines: [
                  '${l10n.adminUsersChildrenColumn}: ${summary?.childCount ?? _user!.childCount}',
                  '${l10n.adminUsersNotificationsMetric}: ${summary?.notificationCount ?? 0}',
                  '${l10n.adminUsersSupportMetric}: ${summary?.supportTicketCount ?? 0}',
                  '${l10n.adminUsersLastUpdatedMetric}: ${summary?.lastUpdatedAt ?? _user!.updatedAt ?? l10n.notAvailable}',
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersChildrenSection,
            child: _user!.children.isEmpty
                ? AdminEmptyState(
                    message: l10n.adminChildrenNoChildren,
                    icon: Icons.child_care_outlined,
                  )
                : Column(
                    children: _user!.children
                        .map(
                          (child) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.child_care_outlined),
                            title: Text(
                              child['name'] as String? ?? l10n.notAvailable,
                            ),
                            subtitle: Text('${l10n.labelId} ${child['id']}'),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersNotificationsSection,
            child: notifications.isEmpty
                ? AdminEmptyState(
                    message: l10n.adminUsersNotificationsMetric,
                    icon: Icons.notifications_none_rounded,
                  )
                : Column(
                    children: notifications
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.title.isEmpty
                                  ? l10n.notAvailable
                                  : entry.title,
                            ),
                            subtitle: Text(entry.createdAt ?? ''),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersSupportSection,
            child: tickets.isEmpty
                ? AdminEmptyState(
                    message: l10n.adminUsersSupportMetric,
                    icon: Icons.support_agent_outlined,
                  )
                : Column(
                    children: tickets
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.subject.isEmpty
                                  ? l10n.notAvailable
                                  : entry.subject,
                            ),
                            subtitle: Text(entry.createdAt ?? ''),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
