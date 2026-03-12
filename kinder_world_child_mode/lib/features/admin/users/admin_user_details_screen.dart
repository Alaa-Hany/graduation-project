import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
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
  Map<String, dynamic>? _activity;
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
        _activity = results[1] as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
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

    final summary =
        Map<String, dynamic>.from(_activity?['summary'] as Map? ?? const {});
    final notifications = List<Map<String, dynamic>>.from(
      (_activity?['notifications'] as List<dynamic>? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final tickets = List<Map<String, dynamic>>.from(
      (_activity?['support_tickets'] as List<dynamic>? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminUsersDetailTitle(_user!.email),
            style: Theme.of(context).textTheme.headlineSmall,
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
                  '${l10n.adminUsersChildrenColumn}: ${summary['child_count'] ?? _user!.childCount}',
                  '${l10n.adminUsersNotificationsMetric}: ${summary['notification_count'] ?? 0}',
                  '${l10n.adminUsersSupportMetric}: ${summary['support_ticket_count'] ?? 0}',
                  '${l10n.adminUsersLastUpdatedMetric}: ${summary['last_updated_at'] ?? _user!.updatedAt ?? l10n.notAvailable}',
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
                              entry['title'] as String? ?? l10n.notAvailable,
                            ),
                            subtitle:
                                Text(entry['created_at'] as String? ?? ''),
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
                              entry['subject'] as String? ?? l10n.notAvailable,
                            ),
                            subtitle:
                                Text(entry['created_at'] as String? ?? ''),
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
