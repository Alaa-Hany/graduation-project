import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/app_connection_status.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_guard.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ParentDashboardContent extends StatelessWidget {
  const ParentDashboardContent({
    super.key,
    required this.children,
    required this.recentActivitiesFuture,
  });

  final List<ChildProfile> children;
  final Future<List<ProgressRecord>> recentActivitiesFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlanStatusBanner(),
          const SizedBox(height: 16),
          const AppConnectionStatusBanner.parent(),
          const ParentDashboardSafetyCard(),
          const SizedBox(height: 24),
          ParentDashboardAlertsSection(
            children: children,
            recentActivitiesFuture: recentActivitiesFuture,
          ),
          const SizedBox(height: 24),
          const ParentDashboardQuickActionsSection(),
          const SizedBox(height: 24),
          ParentDashboardChildrenOverviewSection(children: children),
          const SizedBox(height: 24),
          ParentDashboardQuickStatsSection(
            children: children,
            recentActivitiesFuture: recentActivitiesFuture,
          ),
          const SizedBox(height: 24),
          PlanGuard(
            requiredTier: PlanTier.premium,
            featureLabel: l10n.aiInsights,
            child: ParentDashboardAiInsightsSection(children: children),
          ),
          const SizedBox(height: 24),
          ParentDashboardRecentActivitiesSection(
            children: children,
            recentActivitiesFuture: recentActivitiesFuture,
          ),
          const SizedBox(height: 24),
          ParentDashboardWeeklyProgressChartSection(
            children: children,
            recentActivitiesFuture: recentActivitiesFuture,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class ParentDashboardSafetyCard extends StatelessWidget {
  const ParentDashboardSafetyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ParentCard(
      onTap: () => context.go('/parent/safety-dashboard'),
      backgroundColor: colors.primary.withValuesCompat(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValuesCompat(alpha: 0.12),
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
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.safetyDashboardSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class ParentDashboardAlertsSection extends StatelessWidget {
  const ParentDashboardAlertsSection({
    super.key,
    required this.children,
    required this.recentActivitiesFuture,
  });

  final List<ChildProfile> children;
  final Future<List<ProgressRecord>> recentActivitiesFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final parentTheme = context.parentTheme;

    return FutureBuilder<List<ProgressRecord>>(
      future: recentActivitiesFuture,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <ProgressRecord>[];
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        final alerts = <_DashboardAlertItem>[];
        final latestByChild = <String, DateTime>{};
        final todayMinutesByChild = <String, int>{};

        for (final record in records) {
          final existing = latestByChild[record.childId];
          if (existing == null || record.date.isAfter(existing)) {
            latestByChild[record.childId] = record.date;
          }
          if (!record.date.isBefore(todayStart)) {
            todayMinutesByChild[record.childId] =
                (todayMinutesByChild[record.childId] ?? 0) + record.duration;
          }
        }

        for (final child in children) {
          final todayMinutes = todayMinutesByChild[child.id] ?? 0;
          if (todayMinutes > AppConstants.defaultDailyLimit) {
            alerts.add(
              _DashboardAlertItem(
                message: l10n.notificationScreenTime(
                  child.name,
                  (todayMinutes / 60).ceil(),
                ),
                icon: Icons.timer_off_outlined,
                color: parentTheme.warning,
                onTap: () => context.go(Routes.parentControls),
              ),
            );
          }

          final latest = latestByChild[child.id] ?? child.lastSession;
          if (latest == null) {
            // No session data yet (still loading, or genuinely never used) —
            // we have no real timestamp to base an inactivity claim on.
            continue;
          }

          final inactiveDays = now.difference(latest).inDays;
          if (inactiveDays >= 2) {
            alerts.add(
              _DashboardAlertItem(
                message: l10n.notificationInactive(child.name, inactiveDays),
                icon: Icons.schedule_outlined,
                color: parentTheme.info,
                onTap: () => context.go(Routes.parentReports),
              ),
            );
          }
        }

        final displayAlerts = alerts.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ParentSectionHeader(
              title: l10n.notifications,
              subtitle: l10n.notificationsSubtitle,
              actionLabel: l10n.viewAll,
              onAction: () => context.go(Routes.parentNotifications),
            ),
            const SizedBox(height: 12),
            if (displayAlerts.isEmpty)
              ParentCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: parentTheme.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.noActiveAlerts,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ParentCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: List.generate(displayAlerts.length, (index) {
                    final item = displayAlerts[index];
                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item.color.withValuesCompat(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, size: 18, color: item.color),
                          ),
                          title: Text(
                            item.message,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          onTap: item.onTap,
                        ),
                        if (index != displayAlerts.length - 1)
                          Divider(
                            height: 1,
                            indent: 52,
                            color: colors.outlineVariant
                                .withValuesCompat(alpha: 0.4),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ParentDashboardQuickActionsSection extends StatelessWidget {
  const ParentDashboardQuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentSectionHeader(
          title: l10n.quickActions,
          subtitle: l10n.parentDashboardSubtitle,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ParentDashboardQuickActionTile(
              icon: Icons.child_care_outlined,
              label: l10n.childManagement,
              subtitle: l10n.manageChildProfiles,
              onTap: () => context.go(Routes.parentChildManagement),
            ),
            ParentDashboardQuickActionTile(
              icon: Icons.bar_chart_rounded,
              label: l10n.reports,
              subtitle: l10n.reportsAndAnalytics,
              onTap: () => context.go(Routes.parentReports),
            ),
            ParentDashboardQuickActionTile(
              icon: Icons.shield_outlined,
              label: l10n.safetyDashboard,
              subtitle: l10n.safetyDashboardSubtitle,
              onTap: () => context.go(Routes.parentSafetyDashboard),
            ),
            ParentDashboardQuickActionTile(
              icon: Icons.timer_outlined,
              label: l10n.dailyLimit,
              subtitle: l10n.screenTimeLimits,
              onTap: () => context.go(Routes.parentControls),
            ),
          ],
        ),
      ],
    );
  }
}

class ParentDashboardQuickActionTile extends StatelessWidget {
  const ParentDashboardQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 420 ? width - 32 : (width - 42) / 2;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SizedBox(
      width: cardWidth,
      child: ParentCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary.withValuesCompat(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentDashboardChildrenOverviewSection extends StatelessWidget {
  const ParentDashboardChildrenOverviewSection({
    super.key,
    required this.children,
  });

  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (children.isEmpty) {
      return ParentEmptyState(
        icon: Icons.child_care_outlined,
        title: l10n.noChildrenAddedTitle,
        subtitle: l10n.noChildrenAddedSubtitleDashboard,
        action: FilledButton.icon(
          onPressed: () => context.go('/parent/child-management'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.addChild),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentSectionHeader(
          title: l10n.yourChildren,
          subtitle: l10n.childrenLinkedCount(children.length),
          actionLabel: l10n.manage,
          onAction: () => context.go('/parent/child-management'),
        ),
        const SizedBox(height: 14),
        ...children.map(
          (child) => ParentDashboardChildCard(child: child),
        ),
      ],
    );
  }
}

class ParentDashboardChildCard extends StatelessWidget {
  const ParentDashboardChildCard({
    super.key,
    required this.child,
  });

  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;
    final ageLabel = child.age > 0 ? l10n.yearsOld(child.age) : '-';
    final xpFraction = child.xpProgress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ParentCard(
        onTap: () => context.push('/parent/reports', extra: child.id),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarView(
                      avatarId: child.avatar,
                      avatarPath: child.avatarPath,
                      radius: 26,
                      backgroundColor:
                          colors.primary.withValuesCompat(alpha: 0.15),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'L${child.level}',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              child.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (child.streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: childTheme.streak
                                    .withValuesCompat(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 13,
                                    color: childTheme.streak,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${child.streak}d',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: childTheme.streak,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$ageLabel \u2022 ${child.activitiesCompleted} ${l10n.activities} \u2022 ${child.totalTimeSpent} ${l10n.minutesLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  l10n.levelLabel(child.level),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: xpFraction,
                      minHeight: 6,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.xpProgressDisplay(LevelThresholds.xpInCurrentLevel(child.xp), LevelThresholds.xpRangeForCurrentLevel(child.xp)),
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: childTheme.xp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ParentDashboardQuickStatsSection extends StatelessWidget {
  const ParentDashboardQuickStatsSection({
    super.key,
    required this.children,
    required this.recentActivitiesFuture,
  });

  final List<ChildProfile> children;
  final Future<List<ProgressRecord>> recentActivitiesFuture;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox();

    final l10n = AppLocalizations.of(context)!;
    final parentTheme = context.parentTheme;
    final childTheme = context.childTheme;
    final width = MediaQuery.sizeOf(context).width;
    final availableWidth = width - 32;
    final compact = width < 420;
    final itemWidth =
        compact ? (availableWidth - 12) / 2 : (availableWidth - 24) / 3;

    return FutureBuilder<List<ProgressRecord>>(
      future: recentActivitiesFuture,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <ProgressRecord>[];
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final weekStart = todayStart.subtract(const Duration(days: 6));
        final prevWeekStart = weekStart.subtract(const Duration(days: 7));

        final todayRecords =
            records.where((record) => !record.date.isBefore(todayStart));
        final yesterdayRecords = records.where(
          (record) =>
              !record.date.isBefore(yesterdayStart) &&
              record.date.isBefore(todayStart),
        );
        final thisWeekRecords = records.where(
          (record) =>
              !record.date.isBefore(weekStart) && !record.date.isAfter(now),
        );
        final prevWeekRecords = records.where(
          (record) =>
              !record.date.isBefore(prevWeekStart) &&
              record.date.isBefore(weekStart),
        );

        final profileMinutes =
            children.fold<int>(0, (sum, child) => sum + child.totalTimeSpent);
        final profileActivities = children.fold<int>(
          0,
          (sum, child) => sum + child.activitiesCompleted,
        );
        final avgXp = (children.fold<int>(0, (sum, child) => sum + child.xp) ~/
            children.length.clamp(1, 9999));

        final todayMinutes = records.isEmpty
            ? profileMinutes
            : todayRecords.fold<int>(0, (sum, record) => sum + record.duration);
        final todayCompleted = records.isEmpty
            ? profileActivities
            : todayRecords
                .where(
                  (record) =>
                      record.completionStatus == CompletionStatus.completed,
                )
                .length;
        final weekCompleted = thisWeekRecords
            .where(
              (record) => record.completionStatus == CompletionStatus.completed,
            )
            .length;

        final yesterdayMinutes = yesterdayRecords.fold<int>(
          0,
          (sum, record) => sum + record.duration,
        );
        final yesterdayCompleted = yesterdayRecords
            .where(
              (record) => record.completionStatus == CompletionStatus.completed,
            )
            .length;
        final previousWeekCompleted = prevWeekRecords
            .where(
              (record) => record.completionStatus == CompletionStatus.completed,
            )
            .length;

        final minutesTrend = _percentageTrend(todayMinutes, yesterdayMinutes);
        final activityTrend = _signedTrend(todayCompleted - yesterdayCompleted);
        final weeklyTrend = _signedTrend(weekCompleted - previousWeekCompleted);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ParentSectionHeader(
              title: l10n.todayOverviewTitle,
              subtitle: l10n.aggregatedAcrossChildren,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: ParentStatCard(
                    value: '$todayMinutes',
                    label: l10n.minutesLabel,
                    icon: Icons.timer_outlined,
                    color: parentTheme.info,
                    trend: minutesTrend,
                    trendUp: todayMinutes >= yesterdayMinutes,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: ParentStatCard(
                    value: '$todayCompleted',
                    label: l10n.activities,
                    icon: Icons.check_circle_outline_rounded,
                    color: parentTheme.primary,
                    trend: activityTrend,
                    trendUp: todayCompleted >= yesterdayCompleted,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: ParentStatCard(
                    value: records.isEmpty ? '$avgXp' : '$weekCompleted',
                    label:
                        records.isEmpty ? l10n.avgXpLabel : l10n.weeklyActivity,
                    icon: Icons.star_outline_rounded,
                    color: childTheme.xp,
                    trend: records.isEmpty ? null : weeklyTrend,
                    trendUp: weekCompleted >= previousWeekCompleted,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ParentDashboardAiInsightsSection extends StatelessWidget {
  const ParentDashboardAiInsightsSection({
    super.key,
    required this.children,
  });

  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ParentCard(
      backgroundColor: colors.primary.withValuesCompat(alpha: 0.05),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withValuesCompat(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiInsights,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.premiumAnalysis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const ParentStatusBadge(status: ParentBadgeStatus.premium),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _generateInsightMessage(context, children),
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/parent/reports'),
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: Text(l10n.viewFullReport),
            ),
          ),
        ],
      ),
    );
  }
}

class ParentDashboardRecentActivitiesSection extends StatelessWidget {
  const ParentDashboardRecentActivitiesSection({
    super.key,
    required this.children,
    required this.recentActivitiesFuture,
  });

  final List<ChildProfile> children;
  final Future<List<ProgressRecord>> recentActivitiesFuture;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox();

    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<ProgressRecord>>(
      future: recentActivitiesFuture,
      builder: (context, snapshot) {
        final displayActivities = (snapshot.data ?? []).take(4).toList();
        final colors = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ParentSectionHeader(
              title: l10n.recentActivitiesTitle,
              actionLabel: l10n.viewAll,
              onAction: () => context.go('/parent/reports'),
            ),
            const SizedBox(height: 14),
            if (displayActivities.isEmpty)
              ParentCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: colors.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.noRecentActivities,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ParentCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(displayActivities.length, (index) {
                    final record = displayActivities[index];
                    final child = children.firstWhere(
                      (child) => child.id == record.childId,
                      orElse: () => children.first,
                    );
                    final isLast = index == displayActivities.length - 1;
                    return ParentDashboardActivityRow(
                      childName: child.name,
                      time: _formatTimeAgo(context, record.createdAt),
                      isLast: isLast,
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ParentDashboardActivityRow extends StatelessWidget {
  const ParentDashboardActivityRow({
    super.key,
    required this.childName,
    required this.time,
    required this.isLast,
  });

  final String childName;
  final String time;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.parentTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.completedAnActivity(childName),
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 36,
            color: colors.outlineVariant.withValuesCompat(alpha: 0.4),
          ),
      ],
    );
  }
}

class ParentDashboardWeeklyProgressChartSection extends StatelessWidget {
  const ParentDashboardWeeklyProgressChartSection({
    super.key,
    required this.children,
    required this.recentActivitiesFuture,
  });

  final List<ChildProfile> children;
  final Future<List<ProgressRecord>> recentActivitiesFuture;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final days = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    return FutureBuilder<List<ProgressRecord>>(
      future: recentActivitiesFuture,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <ProgressRecord>[];
        final weekData = _activitiesPerWeekDay(records);
        final hasAnyData = weekData.any((value) => value > 0);

        return ParentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParentSectionHeader(
                title: l10n.weeklyActivity,
                subtitle: l10n.activitiesCompletedPerDay,
              ),
              const SizedBox(height: 20),
              if (!hasAnyData)
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colors.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.noRecentActivities,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(enabled: true),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: colors.outlineVariant
                              .withValuesCompat(alpha: 0.4),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= days.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  days[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: weekData.asMap().entries.map((entry) {
                        final isToday = entry.key == DateTime.now().weekday - 1;
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: isToday
                                  ? colors.primary
                                  : colors.primary
                                      .withValuesCompat(alpha: 0.35),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardAlertItem {
  const _DashboardAlertItem({
    required this.message,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

String _generateInsightMessage(
  BuildContext context,
  List<ChildProfile> children,
) {
  if (children.isEmpty) return '';

  final l10n = AppLocalizations.of(context)!;
  final joiner =
      Localizations.localeOf(context).languageCode == 'ar' ? ' \u0648 ' : ', ';
  final names = children.map((child) => child.name).join(joiner);
  final totalActivities = children.fold<int>(
    0,
    (sum, child) => sum + child.activitiesCompleted,
  );

  return l10n.insightsSummary(names, totalActivities, children.length);
}

String _formatTimeAgo(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays > 0) {
    return '${difference.inDays}d';
  }
  if (difference.inHours > 0) {
    return '${difference.inHours}h';
  }
  if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${l10n.minutesAgo}';
  }
  return l10n.justNow;
}

List<int> _activitiesPerWeekDay(List<ProgressRecord> records) {
  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final counts = List<int>.filled(7, 0);

  for (final record in records) {
    if (record.completionStatus != CompletionStatus.completed) continue;
    if (record.date.isBefore(weekStart)) continue;
    final weekdayIndex = record.date.weekday - 1;
    if (weekdayIndex >= 0 && weekdayIndex < counts.length) {
      counts[weekdayIndex] += 1;
    }
  }

  return counts;
}

String? _percentageTrend(int current, int previous) {
  if (previous <= 0) return null;
  final delta = ((current - previous) / previous) * 100;
  final rounded = delta.abs().round();
  final prefix = delta >= 0 ? '+' : '-';
  return '$prefix$rounded%';
}

String? _signedTrend(int delta) {
  if (delta == 0) return null;
  return delta > 0 ? '+$delta' : '$delta';
}
