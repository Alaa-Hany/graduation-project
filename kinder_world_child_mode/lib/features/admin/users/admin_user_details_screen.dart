import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_parent_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminManagementRepositoryProvider);
      final user = await repo.fetchUserDetail(widget.userId);
      final activity = await repo.fetchUserActivity(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _activity = activity;
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _user == null) {
      return Center(child: Text(_error ?? 'Failed to load user'));
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
                  '${l10n.adminUsersNameField}: ${_user!.name.isEmpty ? 'â€”' : _user!.name}',
                  '${l10n.adminUsersEmailField}: ${_user!.email}',
                  '${l10n.adminUsersPlanColumn}: ${_user!.plan}',
                  '${l10n.adminUsersStatusColumn}: ${_user!.isActive ? (l10n.adminUsersStatusActive) : (l10n.adminUsersStatusDisabled)}',
                ],
              ),
              _InfoCard(
                title: l10n.adminUsersActivityCard,
                lines: [
                  '${l10n.adminUsersChildrenColumn}: ${summary['child_count'] ?? _user!.childCount}',
                  '${l10n.adminUsersNotificationsMetric}: ${summary['notification_count'] ?? 0}',
                  '${l10n.adminUsersSupportMetric}: ${summary['support_ticket_count'] ?? 0}',
                  '${l10n.adminUsersLastUpdatedMetric}: ${summary['last_updated_at'] ?? _user!.updatedAt ?? 'â€”'}',
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersChildrenSection,
            child: Column(
              children: _user!.children
                  .map(
                    (child) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.child_care_outlined),
                      title: Text(child['name'] as String? ?? 'â€”'),
                      subtitle: Text(
                          '${AppLocalizations.of(context)!.labelId} ${child['id']}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersNotificationsSection,
            child: Column(
              children: notifications
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry['title'] as String? ?? 'â€”'),
                      subtitle: Text(entry['created_at'] as String? ?? ''),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: l10n.adminUsersSupportSection,
            child: Column(
              children: tickets
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry['subject'] as String? ?? 'â€”'),
                      subtitle: Text(entry['created_at'] as String? ?? ''),
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
              ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  )),
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
