import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/privacy_settings.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/features/parent_mode/safety/safety_dashboard_service.dart';
import 'package:kinder_world/router.dart';

class SafetyDashboardScreen extends ConsumerStatefulWidget {
  const SafetyDashboardScreen({
    super.key,
    this.initialSnapshot,
  });

  final SafetyDashboardSnapshot? initialSnapshot;

  @override
  ConsumerState<SafetyDashboardScreen> createState() =>
      _SafetyDashboardScreenState();
}

class _SafetyDashboardScreenState extends ConsumerState<SafetyDashboardScreen> {
  Future<SafetyDashboardSnapshot>? _snapshotFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _snapshotFuture ??= widget.initialSnapshot != null
        ? Future<SafetyDashboardSnapshot>.value(widget.initialSnapshot!)
        : _loadSnapshot();
  }

  Future<SafetyDashboardSnapshot> _loadSnapshot() async {
    final l10n = AppLocalizations.of(context)!;
    final parentId = await ref.read(secureStorageProvider).getParentId();
    if (parentId == null || parentId.isEmpty) {
      return SafetyDashboardSnapshot.build(
        children: const [],
        controls: SafetyControlsSummary.defaults(),
        privacySettings: const PrivacySettings(
          analyticsEnabled: true,
          personalizedRecommendations: true,
          dataCollectionOptOut: false,
        ),
        notifications: const [],
        supportTickets: const [],
        hasParentPin: false,
        records: const [],
        now: DateTime.now(),
      );
    }
    return ref.read(safetyDashboardServiceProvider).load(
          parentId: parentId,
          l10n: l10n,
        );
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final parent = context.parentTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.onSurface),
          onPressed: () => context.appBack(fallback: Routes.parentDashboard),
        ),
        title: Text(
          l10n.safetyDashboard,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<SafetyDashboardSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data;
            if (data == null) {
              return ParentEmptyState(
                icon: Icons.security_update_warning_rounded,
                title: l10n.error,
                subtitle: l10n.tryAgain,
                action: FilledButton(
                  onPressed: _refresh,
                  child: Text(l10n.retryAction),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ParentCard(
                    backgroundColor: colors.primary.withValues(alpha: 0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.safetyDashboard,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.safetyDashboardSubtitle,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ParentStatusBadge(
                              status: data.unreadAlertsCount > 0
                                  ? ParentBadgeStatus.alert
                                  : ParentBadgeStatus.active,
                              label: data.unreadAlertsCount > 0
                                  ? '${data.unreadAlertsCount} ${l10n.notifications}'
                                  : l10n.noActiveAlerts,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 52) / 2,
                        child: ParentStatCard(
                          value: '${data.todayScreenTimeMinutes}',
                          label: l10n.screenTime,
                          icon: Icons.timer_outlined,
                          color: context.rewardColor,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 52) / 2,
                        child: ParentStatCard(
                          value: '${data.unreadAlertsCount}',
                          label: l10n.notifications,
                          icon: Icons.notification_important_outlined,
                          color: context.warningColor,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 52) / 2,
                        child: ParentStatCard(
                          value: '${data.children.length}',
                          label: l10n.childProfiles,
                          icon: Icons.child_care_outlined,
                          color: parent.primary,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 52) / 2,
                        child: ParentStatCard(
                          value: '${data.openSupportTicketsCount}',
                          label: l10n.support,
                          icon: Icons.support_agent_rounded,
                          color: context.infoColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatusSection(data: data),
                  const SizedBox(height: 16),
                  _ActivitySection(data: data),
                  const SizedBox(height: 16),
                  _AlertsSection(data: data),
                  const SizedBox(height: 16),
                  _SupportSection(data: data),
                  const SizedBox(height: 16),
                  _QuickActionsSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.data});

  final SafetyDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.overview,
            subtitle: l10n.securitySection,
          ),
          const SizedBox(height: 16),
          _StatusRow(
            icon: Icons.shield_outlined,
            title: l10n.parentalControls,
            subtitle:
                '${data.controls.hoursPerDay}h/day • ${data.controls.sleepMode ? data.controls.bedtime : l10n.inactiveLabel}',
            status: data.controls.hasActiveProtection
                ? ParentBadgeStatus.active
                : ParentBadgeStatus.inactive,
          ),
          _StatusRow(
            icon: Icons.privacy_tip_outlined,
            title: l10n.privacySettings,
            subtitle:
                '${l10n.analyticsTitle}: ${data.privacySettings.analyticsEnabled ? l10n.activeLabel : l10n.inactiveLabel} • ${l10n.dataSharing}: ${data.privacySettings.dataCollectionOptOut ? l10n.activeLabel : l10n.inactiveLabel}',
            status: data.privacyGuardsEnabledCount > 0
                ? ParentBadgeStatus.active
                : ParentBadgeStatus.inactive,
          ),
          _StatusRow(
            icon: Icons.pin_outlined,
            title: l10n.manageParentPin,
            subtitle: l10n.manageParentPinSubtitle,
            status: data.hasParentPin
                ? ParentBadgeStatus.active
                : ParentBadgeStatus.inactive,
          ),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.data});

  final SafetyDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lastActivity = data.lastActivity;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.screenTime,
            subtitle: l10n.recentActivities,
          ),
          const SizedBox(height: 16),
          _MetricTile(
            title: l10n.screenTimeReport,
            value: _formatMinutes(data.weeklyScreenTimeMinutes),
            subtitle: '${data.todayScreenTimeMinutes} min',
            icon: Icons.timer_rounded,
            color: context.rewardColor,
          ),
          const SizedBox(height: 12),
          _MetricTile(
            title: l10n.recentActivities,
            value: lastActivity != null
                ? lastActivity.childName
                : l10n.notAvailable,
            subtitle: lastActivity != null
                ? '${lastActivity.title} • ${_timeAgo(context, lastActivity.timestamp)}'
                : l10n.noRecordedActivityYet,
            icon: Icons.history_rounded,
            color: context.parentTheme.reward,
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.data});

  final SafetyDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final alerts = data.highlightedAlerts;

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.notifications,
            subtitle: l10n.notificationsSubtitle,
            actionLabel: l10n.viewAll,
            onAction: () => context.push(Routes.parentNotifications),
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            Text(
              l10n.noActiveAlerts,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          else
            ...alerts.map((alert) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MetricTile(
                  title: alert.title,
                  value: alert.type.replaceAll('_', ' '),
                  subtitle: alert.body,
                  icon: _alertIcon(alert.type),
                  color: context.warningColor,
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'SCREEN_TIME_LIMIT':
        return Icons.timer_off_rounded;
      case 'INACTIVITY_REMINDER':
        return Icons.do_not_disturb_on_total_silence_rounded;
      case 'SUPPORT_TICKET_UPDATE':
        return Icons.support_agent_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.data});

  final SafetyDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final latestTicket =
        data.supportTickets.isNotEmpty ? data.supportTickets.first : null;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.support,
            subtitle: l10n.supportTicketHistorySubtitle,
          ),
          const SizedBox(height: 16),
          _MetricTile(
            title: l10n.supportTicketHistoryTitle,
            value: '${data.openSupportTicketsCount}',
            subtitle: latestTicket == null
                ? l10n.supportTicketNoHistory
                : '${latestTicket.subject} • ${_supportStatusLabel(context, latestTicket.status)}',
            icon: Icons.support_agent_rounded,
            color: context.infoColor,
          ),
        ],
      ),
    );
  }

  String _supportStatusLabel(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'open':
        return l10n.supportStatusOpen;
      case 'in_progress':
        return l10n.supportStatusInProgress;
      case 'resolved':
        return l10n.supportStatusResolved;
      case 'closed':
        return l10n.supportStatusClosed;
      default:
        return status;
    }
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.quickActions,
            subtitle: l10n.safety,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                label: l10n.parentalControls,
                icon: Icons.shield_outlined,
                onTap: () => context.push(Routes.parentControls),
              ),
              _ActionButton(
                label: l10n.privacySettings,
                icon: Icons.privacy_tip_outlined,
                onTap: () => context.push(Routes.parentPrivacySettings),
              ),
              _ActionButton(
                label: l10n.notifications,
                icon: Icons.notifications_outlined,
                onTap: () => context.push(Routes.parentNotifications),
              ),
              _ActionButton(
                label: l10n.manageParentPin,
                icon: Icons.pin_outlined,
                onTap: () => context.push(
                  '${Routes.parentPin}?mode=change&redirect=${Uri.encodeComponent(Routes.parentSafetyDashboard)}',
                ),
              ),
              _ActionButton(
                label: l10n.contactUs,
                icon: Icons.support_agent_rounded,
                onTap: () => context.push(Routes.parentContactUs),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ParentBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          ParentStatusBadge(status: status),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

String _formatMinutes(int totalMinutes) {
  if (totalMinutes < 60) {
    return '${totalMinutes}m';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

String _timeAgo(BuildContext context, DateTime timestamp) {
  final l10n = AppLocalizations.of(context)!;
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return '${diff.inMinutes} ${l10n.minutesAgo}';
  if (diff.inDays < 1) return '${diff.inHours} ${l10n.hoursAgo}';
  return '${diff.inDays} ${l10n.daysAgo}';
}
