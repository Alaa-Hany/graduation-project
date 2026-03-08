import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() =>
      _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  bool _loading = true;
  String _range = 'week';
  String? _error;
  AdminAnalyticsOverview? _overview;
  AdminAnalyticsUsage? _usage;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminManagementRepositoryProvider);
      final overview = await repo.fetchAnalyticsOverview();
      final usage = await repo.fetchAnalyticsUsage(_range);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _usage = usage;
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
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.analytics.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.adminAnalyticsTitle ?? 'Analytics overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.adminAnalyticsSubtitle ??
                'Monitor platform growth, activity trends, and support health.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'week',
                    label:
                        Text(l10n?.adminAnalyticsRangeWeek ?? 'Week'),
                  ),
                  ButtonSegment(
                    value: 'month',
                    label:
                        Text(l10n?.adminAnalyticsRangeMonth ?? 'Month'),
                  ),
                ],
                selected: {_range},
                onSelectionChanged: (selection) {
                  setState(() => _range = selection.first);
                  _loadAnalytics();
                },
              ),
              OutlinedButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.retry ?? 'Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          else if (_overview != null && _usage != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  title: l10n?.adminAnalyticsTotalUsers ?? 'Total users',
                  value: '${_overview!.kpis['total_users'] ?? 0}',
                  icon: Icons.people_outline,
                ),
                _KpiCard(
                  title: l10n?.adminAnalyticsActiveChildren ?? 'Active children',
                  value: '${_overview!.kpis['active_children'] ?? 0}',
                  icon: Icons.child_care_outlined,
                ),
                _KpiCard(
                  title: l10n?.adminAnalyticsActivitiesToday ?? 'Activities today',
                  value: '${_overview!.kpis['activities_today'] ?? 0}',
                  icon: Icons.bolt_outlined,
                ),
                _KpiCard(
                  title: l10n?.adminAnalyticsOpenTickets ?? 'Open tickets',
                  value: '${_overview!.kpis['open_tickets'] ?? 0}',
                  icon: Icons.support_agent_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
                        child: _buildUsageCard(context, l10n),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: _buildSummaryCards(context, l10n),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildUsageCard(context, l10n),
                    const SizedBox(height: 16),
                    _buildSummaryCards(context, l10n),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context, AppLocalizations? l10n) {
    final usage = _usage!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.adminAnalyticsUsageTitle ?? 'Usage trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _UsageChart(points: usage.points),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendDot(
                  color: Theme.of(context).colorScheme.primary,
                  label: l10n?.adminAnalyticsNewUsers ?? 'Users',
                ),
                _LegendDot(
                  color: Theme.of(context).colorScheme.secondary,
                  label: l10n?.adminAnalyticsNewChildren ?? 'Children',
                ),
                _LegendDot(
                  color: Theme.of(context).colorScheme.tertiary,
                  label: l10n?.adminAnalyticsActivities ?? 'Activities',
                ),
                _LegendDot(
                  color: Theme.of(context).colorScheme.error,
                  label: l10n?.adminAnalyticsTickets ?? 'Tickets',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, AppLocalizations? l10n) {
    final overview = _overview!;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.adminAnalyticsSubscriptionsTitle ??
                      'Subscriptions summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...overview.subscriptionsByPlan.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                _summaryRow(
                  l10n?.adminAnalyticsPaidSubscriptions ??
                      'Paid subscriptions',
                  '${overview.paidSubscriptions}',
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  l10n?.adminAnalyticsFreeSubscriptions ??
                      'Free subscriptions',
                  '${overview.freeSubscriptions}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.adminAnalyticsRecentTickets ?? 'Recent ticket summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (overview.recentTickets.isEmpty)
                  Text(l10n?.adminAnalyticsNoData ?? 'No data available')
                else
                  ...overview.recentTickets.map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket['subject']?.toString() ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ticket['status'] ?? 'open'} • ${ticket['email'] ?? '—'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.points});

  final List<AdminAnalyticsUsagePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = points.fold<int>(
      1,
      (current, point) => math.max(
        current,
        math.max(
          math.max(point.users, point.children),
          math.max(point.activities, point.tickets),
        ),
      ),
    );

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Bar(color: scheme.primary, value: point.users, maxValue: maxValue),
                        const SizedBox(width: 2),
                        _Bar(color: scheme.secondary, value: point.children, maxValue: maxValue),
                        const SizedBox(width: 2),
                        _Bar(color: scheme.tertiary, value: point.activities, maxValue: maxValue),
                        const SizedBox(width: 2),
                        _Bar(color: scheme.error, value: point.tickets, maxValue: maxValue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    point.label,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.value,
    required this.maxValue,
  });

  final Color color;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final heightFactor = value == 0 || maxValue == 0 ? 0.0 : value / maxValue;
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor == 0 ? 0 : heightFactor.clamp(0.04, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
