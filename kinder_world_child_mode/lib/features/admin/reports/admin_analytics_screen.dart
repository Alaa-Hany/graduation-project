import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_analytics_overview.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/management/admin_management_repository.dart';
import 'package:kinder_world/features/admin/shared/admin_permission_placeholder.dart';
import 'package:kinder_world/features/admin/shared/admin_state_widgets.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(currentAdminProvider);
    if (!(admin?.hasPermission('admin.analytics.view') ?? false)) {
      return const AdminPermissionPlaceholder();
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          AdminPageHeader(
            title: l10n.adminAnalyticsTitle,
            subtitle: l10n.adminAnalyticsSubtitle,
            actions: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadAnalytics,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.adminRefreshTooltip),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Range selector ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'week',
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                  label: Text(l10n.adminAnalyticsRangeWeek),
                ),
                ButtonSegment(
                  value: 'month',
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(l10n.adminAnalyticsRangeMonth),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() => _range = s.first);
                _loadAnalytics();
              },
            ),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _loadAnalytics)
          else if (_overview == null && _usage == null)
            AdminEmptyState(
              message: l10n.adminAnalyticsNoData,
              icon: Icons.analytics_outlined,
            )
          else if (_overview != null && _usage != null) ...[
            // ── KPI Grid ──────────────────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _KpiCard(
                    title: l10n.adminAnalyticsTotalUsers,
                    value: '${_overview!.kpis['total_users'] ?? 0}',
                    icon: Icons.people_outline,
                    bgColor: cs.primaryContainer,
                    iconColor: cs.primary,
                  ),
                  _KpiCard(
                    title: l10n.adminAnalyticsActiveChildren,
                    value: '${_overview!.kpis['active_children'] ?? 0}',
                    icon: Icons.child_care_outlined,
                    bgColor: cs.secondaryContainer,
                    iconColor: cs.secondary,
                  ),
                  _KpiCard(
                    title: l10n.adminAnalyticsActivitiesToday,
                    value: '${_overview!.kpis['activities_today'] ?? 0}',
                    icon: Icons.bolt_outlined,
                    bgColor: cs.tertiaryContainer,
                    iconColor: cs.tertiary,
                  ),
                  _KpiCard(
                    title: l10n.adminAnalyticsOpenTickets,
                    value: '${_overview!.kpis['open_tickets'] ?? 0}',
                    icon: Icons.support_agent_outlined,
                    bgColor: cs.errorContainer,
                    iconColor: cs.error,
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),

            // ── Charts + Summary ──────────────────────────────────────
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: _buildUsageCard(context, l10n)),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: _buildSummaryCards(context, l10n)),
                  ],
                );
              }
              return Column(children: [
                _buildUsageCard(context, l10n),
                const SizedBox(height: 16),
                _buildSummaryCards(context, l10n),
              ]);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context, AppLocalizations l10n) {
    final usage = _usage!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.adminAnalyticsUsageTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _UsageChart(points: usage.points),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 8, children: [
              _LegendDot(color: cs.primary, label: l10n.adminAnalyticsNewUsers),
              _LegendDot(
                  color: cs.secondary, label: l10n.adminAnalyticsNewChildren),
              _LegendDot(
                  color: cs.tertiary, label: l10n.adminAnalyticsActivities),
              _LegendDot(color: cs.error, label: l10n.adminAnalyticsTickets),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, AppLocalizations l10n) {
    final overview = _overview!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final planTotal = overview.subscriptionsByPlan.values
        .fold<int>(0, (a, b) => a + (b as int? ?? 0));
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.adminAnalyticsSubscriptionsTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              ...overview.subscriptionsByPlan.entries.map((entry) {
                final count = entry.value as int? ?? 0;
                final fraction =
                    planTotal > 0 ? (count / planTotal).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: theme.textTheme.bodySmall),
                          Text(
                            '$count',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor:
                              cs.primaryContainer.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              _summaryRow(context, l10n.adminAnalyticsPaidSubscriptions,
                  '${overview.paidSubscriptions}', cs.tertiary),
              const SizedBox(height: 8),
              _summaryRow(context, l10n.adminAnalyticsFreeSubscriptions,
                  '${overview.freeSubscriptions}', cs.secondary),
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
              Row(children: [
                Icon(Icons.confirmation_num_outlined,
                    size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.adminAnalyticsRecentTickets,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (overview.recentTickets.isEmpty)
                Text(l10n.adminAnalyticsNoData,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)))
              else
                ...overview.recentTickets.map((ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (_) {
                            final s =
                                ticket['status']?.toString().toLowerCase();
                            final dotColor = s == 'open'
                                ? cs.error
                                : s == 'in_progress'
                                    ? cs.tertiary
                                    : s == 'resolved'
                                        ? cs.secondary
                                        : cs.outline;
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              decoration: BoxDecoration(
                                  color: dotColor, shape: BoxShape.circle),
                            );
                          }),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ticket['subject']?.toString() ?? '-',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                    '${ticket['status'] ?? '-'} · ${ticket['email'] ?? '-'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.55))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _summaryRow(
      BuildContext context, String label, String value, Color valueColor) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 12),
        Text(value,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}

// ─────────────────────────── KPI Card ────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: bgColor.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Legend Dot ──────────────────────────────────────

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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────── Usage Chart ─────────────────────────────────────

class _UsageChart extends StatelessWidget {
  const _UsageChart({required this.points});

  final List<AdminAnalyticsUsagePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = points.fold<int>(
      1,
      (cur, p) => math.max(
          cur,
          math.max(math.max(p.users, p.children),
              math.max(p.activities, p.tickets))),
    );

    return LayoutBuilder(builder: (context, constraints) {
      const pw = 42.0;
      final chartW = math.max(constraints.maxWidth, points.length * pw);
      return SizedBox(
        height: 220,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartW,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((point) {
                return SizedBox(
                  width: pw,
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
                              _buildBar(scheme.primary, point.users, maxVal),
                              const SizedBox(width: 2),
                              _buildBar(
                                  scheme.secondary, point.children, maxVal),
                              const SizedBox(width: 2),
                              _buildBar(
                                  scheme.tertiary, point.activities, maxVal),
                              const SizedBox(width: 2),
                              _buildBar(scheme.error, point.tickets, maxVal),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(point.label,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBar(Color color, int value, int maxVal) {
    final hf =
        (value == 0 || maxVal == 0) ? 0.0 : (value / maxVal).clamp(0.04, 1.0);
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: hf,
          child: Container(
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }
}
