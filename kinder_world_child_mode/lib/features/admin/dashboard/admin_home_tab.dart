import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/core/models/admin_audit_log.dart';
import 'package:kinder_world/core/models/admin_subscription_models.dart';
import 'package:kinder_world/core/models/admin_support_ticket.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';
import 'package:kinder_world/router.dart';

/// IMPORTANT:
/// All UI text must use AppLocalizations.
/// Hardcoded strings are NOT allowed.

class AdminHomeTab extends ConsumerStatefulWidget {
  const AdminHomeTab({super.key});

  @override
  ConsumerState<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends ConsumerState<AdminHomeTab> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  _AdminDashboardSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = !refresh;
      _refreshing = refresh;
      _error = null;
    });
    final admin = ref.read(currentAdminProvider);
    final repo = ref.read(adminManagementRepositoryProvider);
    final sectionErrors = <String>[];

    Future<T?> safe<T>(Future<T> Function() loader, String section) async {
      try {
        return await loader();
      } catch (e) {
        sectionErrors.add('$section: $e');
        return null;
      }
    }

    final overviewFuture = _canLoad(admin, 'admin.analytics.view')
        ? safe(() => repo.fetchAnalyticsOverview(), 'overview')
        : Future<AdminAnalyticsOverview?>.value(null);

    final auditFuture = _canLoad(admin, 'admin.audit.view')
        ? safe(() => repo.fetchAuditLogs(page: 1), 'audit')
        : Future<AdminPagedResponse<AdminAuditLog>?>.value(null);

    final openTicketsFuture = _canLoad(admin, 'admin.support.view')
        ? safe(
            () => repo.fetchSupportTickets(status: 'open', page: 1),
            'support_open',
          )
        : Future<AdminPagedResponse<AdminSupportTicket>?>.value(null);

    final inProgressTicketsFuture = _canLoad(admin, 'admin.support.view')
        ? safe(
            () => repo.fetchSupportTickets(status: 'in_progress', page: 1),
            'support_in_progress',
          )
        : Future<AdminPagedResponse<AdminSupportTicket>?>.value(null);

    final subscriptionsFuture = _canLoad(admin, 'admin.subscription.view')
        ? safe(() => repo.fetchSubscriptions(page: 1), 'subscriptions')
        : Future<AdminPagedResponse<AdminSubscriptionRecord>?>.value(null);

    final reviewContentFuture = _canLoad(admin, 'admin.content.view')
        ? safe(
            () => repo.fetchContents(status: 'review', page: 1),
            'content_review',
          )
        : Future<AdminPagedResponse<dynamic>?>.value(null);

    final results = await Future.wait<dynamic>([
      overviewFuture,
      auditFuture,
      openTicketsFuture,
      inProgressTicketsFuture,
      subscriptionsFuture,
      reviewContentFuture,
    ]);

    final overview = results[0] as AdminAnalyticsOverview?;
    final auditResponse = results[1] as AdminPagedResponse<AdminAuditLog>?;
    final openTicketResponse =
        results[2] as AdminPagedResponse<AdminSupportTicket>?;
    final inProgressTicketResponse =
        results[3] as AdminPagedResponse<AdminSupportTicket>?;
    final subscriptionResponse =
        results[4] as AdminPagedResponse<AdminSubscriptionRecord>?;
    final reviewContentResponse = results[5] as AdminPagedResponse<dynamic>?;

    final mergedPending = <int, AdminSupportTicket>{};
    for (final ticket in [
      ...?openTicketResponse?.items,
      ...?inProgressTicketResponse?.items,
    ]) {
      mergedPending[ticket.id] = ticket;
    }
    final pendingTickets = mergedPending.values.toList()
      ..sort((a, b) => _parseDate(b.updatedAt ?? b.createdAt)
          .compareTo(_parseDate(a.updatedAt ?? a.createdAt)));

    final reviewCount = (reviewContentResponse?.pagination['total'] as int?) ??
        reviewContentResponse?.items.length ??
        0;

    final snapshot = _AdminDashboardSnapshot(
      overview: overview,
      auditLogs: auditResponse?.items ?? const [],
      pendingTickets: pendingTickets,
      subscriptions: subscriptionResponse?.items ?? const [],
      reviewContentCount: reviewCount,
      sectionErrors: sectionErrors,
    );

    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
      _refreshing = false;
      if (!snapshot.hasVisibleData && sectionErrors.isNotEmpty) {
        _error = sectionErrors.join('\n');
      }
    });
  }

  bool _canLoad(dynamic admin, String permission) {
    if (admin == null) return false;
    return admin.isSuperAdmin || admin.hasPermission(permission);
  }

  static DateTime _parseDate(String? value) {
    return DateTime.tryParse(value ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overview = _snapshot?.overview;
    final totalUsers = overview?.kpis['total_users'] ?? 0;
    final totalChildren = overview?.kpis['active_children'] ?? 0;
    final openTickets =
        overview?.kpis['open_tickets'] ?? _snapshot?.pendingTickets.length ?? 0;
    final subscriptionTotal = overview == null
        ? _snapshot?.subscriptions.length ?? 0
        : overview.paidSubscriptions + overview.freeSubscriptions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final medium = constraints.maxWidth >= 980;
        final cardWidth = medium
            ? (constraints.maxWidth - 24) / 2
            : compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.adminDashboardWelcome}, ${admin?.name ?? admin?.email ?? l10n.adminRoleSupportAdmin}!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 24 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.adminDashboardSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _refreshing
                              ? null
                              : () => _loadDashboard(refresh: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onPrimary,
                            side: BorderSide(
                                color: colorScheme.onPrimary
                                    .withValues(alpha: 0.5)),
                          ),
                          icon: _refreshing
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l10n.adminRefreshTooltip),
                        ),
                      ],
                    ),
                    if (admin?.roles.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: admin!.roles.map((role) {
                          return Chip(
                            label: Text(
                              role,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: colorScheme.onPrimary,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.adminSidebarOverview,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    width: cardWidth,
                    icon: Icons.people_outline,
                    label: l10n.adminSidebarUsers,
                    value: _loading ? '-' : _formatCompact(totalUsers),
                    color: colorScheme.primaryContainer,
                    iconColor: colorScheme.onPrimaryContainer,
                  ),
                  _StatCard(
                    width: cardWidth,
                    icon: Icons.child_care_outlined,
                    label: l10n.adminSidebarChildren,
                    value: _loading ? '-' : _formatCompact(totalChildren),
                    color: colorScheme.secondaryContainer,
                    iconColor: colorScheme.onSecondaryContainer,
                  ),
                  _StatCard(
                    width: cardWidth,
                    icon: Icons.subscriptions_outlined,
                    label: l10n.adminSidebarSubscriptions,
                    value: _loading ? '-' : _formatCompact(subscriptionTotal),
                    color: colorScheme.tertiaryContainer,
                    iconColor: colorScheme.onTertiaryContainer,
                  ),
                  _StatCard(
                    width: cardWidth,
                    icon: Icons.support_agent_outlined,
                    label: l10n.adminSidebarSupport,
                    value: _loading ? '-' : _formatCompact(openTickets),
                    color: colorScheme.errorContainer,
                    iconColor: colorScheme.onErrorContainer,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_loading)
                const AdminLoadingState(
                    padding: EdgeInsets.symmetric(vertical: 36))
              else if (_error != null)
                AdminErrorState(
                  message: _error!,
                  onRetry: _loadDashboard,
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SectionCard(
                      width: cardWidth,
                      title: l10n.adminAuditTitle,
                      icon: Icons.history_rounded,
                      actionLabel: l10n.adminSidebarAudit,
                      onAction: () => context.go(Routes.adminAudit),
                      child: _AuditFeed(
                        logs: _snapshot?.auditLogs ?? const [],
                        emptyLabel: l10n.adminAuditNoLogs,
                        l10n: l10n,
                      ),
                    ),
                    _SectionCard(
                      width: cardWidth,
                      title: l10n.adminSupportTicketsTitle,
                      icon: Icons.support_agent_outlined,
                      actionLabel: l10n.adminSidebarSupport,
                      onAction: () => context.go(Routes.adminSupport),
                      child: _SupportQueue(
                        tickets: _snapshot?.pendingTickets ?? const [],
                        emptyLabel: l10n.adminSupportNoTickets,
                        l10n: l10n,
                      ),
                    ),
                    _SectionCard(
                      width: cardWidth,
                      title: l10n.adminAnalyticsSubscriptionsTitle,
                      icon: Icons.subscriptions_outlined,
                      actionLabel: l10n.adminSidebarSubscriptions,
                      onAction: () => context.go(Routes.adminSubscriptions),
                      child: _SubscriptionSummary(
                        overview: overview,
                        subscriptions: _snapshot?.subscriptions ?? const [],
                        l10n: l10n,
                      ),
                    ),
                    _SectionCard(
                      width: cardWidth,
                      title: l10n.adminSidebarContent,
                      icon: Icons.edit_note_outlined,
                      actionLabel: l10n.adminSidebarContent,
                      onAction: () => context.go(Routes.adminContent),
                      child: _ContentOpsSummary(
                        reviewCount: _snapshot?.reviewContentCount ?? 0,
                        activityCount: overview?.kpis['activities_today'] ?? 0,
                        l10n: l10n,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (admin?.permissions.isNotEmpty == true) ...[
                Text(
                  l10n.adminDashboardPermissionsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: admin!.permissions.map((perm) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            perm,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatCompact(int value) {
    return NumberFormat.compact().format(value);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 24 : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: compact ? 12 : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboardSnapshot {
  const _AdminDashboardSnapshot({
    required this.overview,
    required this.auditLogs,
    required this.pendingTickets,
    required this.subscriptions,
    required this.reviewContentCount,
    required this.sectionErrors,
  });

  final AdminAnalyticsOverview? overview;
  final List<AdminAuditLog> auditLogs;
  final List<AdminSupportTicket> pendingTickets;
  final List<AdminSubscriptionRecord> subscriptions;
  final int reviewContentCount;
  final List<String> sectionErrors;

  bool get hasVisibleData {
    return overview != null ||
        auditLogs.isNotEmpty ||
        pendingTickets.isNotEmpty ||
        subscriptions.isNotEmpty ||
        reviewContentCount > 0;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final double width;
  final String title;
  final IconData icon;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditFeed extends StatelessWidget {
  const _AuditFeed({
    required this.logs,
    required this.emptyLabel,
    required this.l10n,
  });

  final List<AdminAuditLog> logs;
  final String emptyLabel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (logs.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Column(
      children: logs.take(4).map((log) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.action} - ${log.entityType}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _adminIdentity(log.admin),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (log.timestamp != null)
                      Text(
                        _formatDate(log.timestamp!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _adminIdentity(Map<String, dynamic>? admin) {
    if (admin == null) return '-';
    return admin['email']?.toString() ??
        admin['name']?.toString() ??
        admin['id']?.toString() ??
        '-';
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    return DateFormat('MMM d, h:mm a').format(date);
  }
}

class _SupportQueue extends StatelessWidget {
  const _SupportQueue({
    required this.tickets,
    required this.emptyLabel,
    required this.l10n,
  });

  final List<AdminSupportTicket> tickets;
  final String emptyLabel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (tickets.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    return Column(
      children: tickets.take(4).map((ticket) {
        final isOpen = ticket.status == 'open';
        final statusLabel = isOpen
            ? l10n.adminSupportStatusOpen
            : l10n.adminSupportStatusInProgress;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen
                      ? colorScheme.errorContainer
                      : colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOpen ? colorScheme.error : colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ticket.requester?['email']?.toString() ??
                          ticket.email ??
                          '-',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SubscriptionSummary extends StatelessWidget {
  const _SubscriptionSummary({
    required this.overview,
    required this.subscriptions,
    required this.l10n,
  });

  final AdminAnalyticsOverview? overview;
  final List<AdminSubscriptionRecord> subscriptions;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subscriptionPlanCounts = overview?.subscriptionsByPlan ??
        _buildPlanCountsFromSubscriptions(subscriptions);
    final total =
        subscriptionPlanCounts.values.fold<int>(0, (sum, value) => sum + value);

    if (subscriptionPlanCounts.isEmpty) {
      return Text(
        l10n.adminAnalyticsNoData,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...subscriptionPlanCounts.entries.take(3).map((entry) {
          final progress =
              total == 0 ? 0.0 : (entry.value / total).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.35),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '${l10n.adminAnalyticsPaidSubscriptions}: ${overview?.paidSubscriptions ?? _countPaid(subscriptions)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          '${l10n.adminAnalyticsFreeSubscriptions}: ${overview?.freeSubscriptions ?? _countFree(subscriptions)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Map<String, int> _buildPlanCountsFromSubscriptions(
      List<AdminSubscriptionRecord> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final key = row.plan.isEmpty ? 'unknown' : row.plan;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  int _countPaid(List<AdminSubscriptionRecord> rows) {
    return rows.where((row) => row.plan.toUpperCase() != 'FREE').length;
  }

  int _countFree(List<AdminSubscriptionRecord> rows) {
    return rows.where((row) => row.plan.toUpperCase() == 'FREE').length;
  }
}

class _ContentOpsSummary extends StatelessWidget {
  const _ContentOpsSummary({
    required this.reviewCount,
    required this.activityCount,
    required this.l10n,
  });

  final int reviewCount;
  final int activityCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.adminCmsStatusReview}: $reviewCount',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.adminAnalyticsActivitiesToday}: $activityCount',
          style: theme.textTheme.bodySmall,
        ),
        if (reviewCount == 0) ...[
          const SizedBox(height: 8),
          Text(
            l10n.adminAnalyticsNoData,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}
