import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';

enum ReportPeriod { week, month, year }

class _ActivitySegment {
  const _ActivitySegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({
    super.key,
    this.initialChildId,
  });

  final String? initialChildId;

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.week;
  ChildProfile? _selectedChild;
  List<Map<String, dynamic>> _basicReports = [];
  bool _isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final response = await ref
          .read(networkServiceProvider)
          .get<Map<String, dynamic>>('/reports/basic');
      final list = response.data?['reports'];
      if (list is List) {
        _basicReports = list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  String _periodLabel(AppLocalizations l10n) {
    switch (_period) {
      case ReportPeriod.week:
        return l10n.weeklyProgress;
      case ReportPeriod.month:
        return l10n.monthlyProgress;
      case ReportPeriod.year:
        return l10n.yearlyProgress;
    }
  }

  Map<String, String> _periodMetrics() {
    if (_basicReports.isNotEmpty) {
      final totalMinutes = _basicReports.fold<int>(
        0,
        (sum, item) => sum + (item['screen_time_minutes'] ?? 0) as int,
      );
      final hours = (totalMinutes / 60).toStringAsFixed(1);
      return {
        'activities': '${_basicReports.length}',
        'score': '85%',
        'time': '${hours}h',
      };
    }
    switch (_period) {
      case ReportPeriod.week:
        return {'activities': '25', 'score': '85%', 'time': '5.2h'};
      case ReportPeriod.month:
        return {'activities': '92', 'score': '88%', 'time': '21.4h'};
      case ReportPeriod.year:
        return {'activities': '480', 'score': '90%', 'time': '115h'};
    }
  }

  List<_ActivitySegment> _activitySegments(
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    return [
      _ActivitySegment(
        value: 30,
        color: colors.primary,
        label: l10n.educationalContent,
      ),
      _ActivitySegment(
        value: 25,
        color: colors.secondary,
        label: l10n.entertainment,
      ),
      _ActivitySegment(
        value: 25,
        color: colors.tertiary,
        label: l10n.skillfulActivities,
      ),
      _ActivitySegment(
        value: 20,
        color: colors.error,
        label: l10n.behavioralSkills,
      ),
    ];
  }

  String _formatPercentLabel(double value, double total) {
    if (total <= 0 || value <= 0) return '';
    final percent = ((value / total) * 100).round();
    return '$percent%';
  }

  TextStyle _sliceLabelStyle(
    Color color,
    TextTheme textTheme,
    ColorScheme colors,
  ) {
    final isDark = color.computeLuminance() < 0.45;
    return textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? colors.onPrimary : colors.onSurface,
          shadows: isDark
              ? [
                  Shadow(
                    color: colors.shadow.withValues(alpha: 0.35),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ) ??
        TextStyle(
          fontSize: AppConstants.fontSize - 2,
          fontWeight: FontWeight.w600,
          color: isDark ? colors.onPrimary : colors.onSurface,
          shadows: isDark
              ? [
                  Shadow(
                    color: colors.shadow.withValues(alpha: 0.35),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        );
  }

  Widget _buildActivityLegend(
    List<_ActivitySegment> segments,
    TextDirection textDirection,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: textDirection,
      children: List.generate(segments.length, (index) {
        final segment = segments[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == segments.length - 1 ? 0 : 8),
          child: Row(
            textDirection: textDirection,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: segment.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  segment.label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showChildSelection(List<ChildProfile> children) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final child = children[index];
              return ListTile(
                leading: AvatarView(
                  avatarId: child.avatar,
                  avatarPath: child.avatarPath,
                  radius: 20,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
                title: Text(child.name),
                subtitle: Builder(builder: (ctx) {
                  final loc = AppLocalizations.of(ctx)!;
                  return Text(
                    child.age > 0
                        ? '${loc.childAge} ${child.age} · ${loc.level} ${child.level}'
                        : '${loc.level} ${child.level}',
                  );
                }),
                trailing: _selectedChild?.id == child.id
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _selectedChild = child;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final plan =
        ref.watch(planInfoProvider).asData?.value ?? PlanInfo.fromTier(PlanTier.free);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/parent/dashboard');
            }
          },
        ),
        title: Text(
          l10n.reportsAndAnalytics,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: ref.read(secureStorageProvider).getParentId(),
          builder: (context, parentIdSnapshot) {
            final parentId = parentIdSnapshot.data ?? '';
            return FutureBuilder<List<ChildProfile>>(
              future: ref
                  .read(childRepositoryProvider)
                  .getChildProfilesForParent(parentId),
              builder: (context, childrenSnapshot) {
                if (childrenSnapshot.connectionState == ConnectionState.waiting &&
                    childrenSnapshot.data == null) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  );
                }

                final children = childrenSnapshot.data ?? [];

                if (_selectedChild == null && children.isNotEmpty) {
                  final initialChild = widget.initialChildId != null
                      ? children.firstWhere(
                          (child) => child.id == widget.initialChildId,
                          orElse: () => children.first,
                        )
                      : children.first;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedChild = initialChild;
                    });
                  });
                }

                final selectedChild =
                    _selectedChild ?? (children.isNotEmpty ? children.first : null);
                final metrics = _periodMetrics();
                final segments = _activitySegments(l10n, colors);
                final textDirection = Directionality.of(context);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        l10n.learningProgressReports,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.trackChildDevelopment,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      if (_isLoadingReports) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_basicReports.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.recentActivities,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._basicReports.map((report) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(report['date']?.toString() ?? ''),
                                Text(
                                  '${report['screen_time_minutes']} min',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      const PlanStatusBanner(),
                      const SizedBox(height: 24),

                      // Child Selection
                      ParentCard(
                        onTap: children.isEmpty
                            ? null
                            : () => _showChildSelection(children),
                        child: Row(
                          children: [
                            AvatarView(
                              avatarId: selectedChild?.avatar,
                              avatarPath: selectedChild?.avatarPath,
                              radius: 25,
                              backgroundColor: colors.primaryContainer,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedChild?.name ?? l10n.noChildSelected,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedChild != null
                                        ? '${l10n.childAge} ${selectedChild.age} · ${l10n.level} ${selectedChild.level}'
                                        : l10n.addChildToViewReports,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Time Period Selection
                      Row(
                        children: [
                          _buildPeriodButton(l10n.week, ReportPeriod.week),
                          const SizedBox(width: 8),
                          _buildPeriodButton(l10n.month, ReportPeriod.month),
                          const SizedBox(width: 8),
                          _buildPeriodButton(l10n.year, ReportPeriod.year),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Progress Overview
                      _buildProgressOverview(
                        _periodLabel(l10n),
                        metrics['activities'] ?? '-',
                        metrics['score'] ?? '-',
                        metrics['time'] ?? '-',
                      ),
                      const SizedBox(height: 24),

                      if (plan.hasAdvancedReports)
                        _buildAdvancedReportSection(
                          l10n: l10n,
                          colors: colors,
                          textTheme: textTheme,
                          segments: segments,
                          textDirection: textDirection,
                        )
                      else
                        _buildPremiumLockedCard(
                          context,
                          title: l10n.activityBreakdown,
                          message: l10n.planAdvancedReports,
                        ),
                      const SizedBox(height: 24),
                      if (plan.hasAdvancedReports)
                        _buildAchievementsSection(
                          l10n: l10n,
                          colors: colors,
                          textTheme: textTheme,
                        )
                      else
                        _buildPremiumLockedCard(
                          context,
                          title: l10n.recentAchievements,
                          message: l10n.planAdvancedReports,
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            );
          },
        ),
        ),
      );
  }

  Widget _buildPeriodButton(String text, ReportPeriod period) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = _period == period;
    return InkWell(
      onTap: () {
        setState(() {
          _period = period;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(
          text,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedReportSection({
    required AppLocalizations l10n,
    required ColorScheme colors,
    required TextTheme textTheme,
    required List<_ActivitySegment> segments,
    required TextDirection textDirection,
  }) {
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(title: l10n.activityBreakdown),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              const chartHeight = 180.0;
              final chartSize = math.min(constraints.maxWidth, chartHeight);
              final chartRadius = math.max(
                0.0,
                (chartSize / 2) - 14.0,
              );
              final centerSpaceRadius = chartRadius * 0.6;
              final ringCenter =
                  centerSpaceRadius + ((chartRadius - centerSpaceRadius) / 2);
              final titleOffset =
                  chartRadius > 0 ? ringCenter / chartRadius : 0.5;
              final total = segments.fold<double>(
                0,
                (sum, segment) => sum + segment.value,
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: chartHeight,
                    child: PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        centerSpaceRadius: centerSpaceRadius,
                        sectionsSpace: 2,
                        sections: segments.map((segment) {
                          final title = _formatPercentLabel(
                            segment.value,
                            total,
                          );
                          return PieChartSectionData(
                            value: segment.value,
                            color: segment.color,
                            radius: chartRadius,
                            showTitle: title.isNotEmpty,
                            title: title,
                            titleStyle: _sliceLabelStyle(
                              segment.color,
                              textTheme,
                              colors,
                            ),
                            titlePositionPercentageOffset: titleOffset,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityLegend(segments, textDirection, textTheme),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection({
    required AppLocalizations l10n,
    required ColorScheme colors,
    required TextTheme textTheme,
  }) {
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(title: l10n.recentAchievements),
          const SizedBox(height: 16),
          _buildAchievementItem(
            '*',
            l10n.achievementMathMasterTitle,
            l10n.achievementMathMasterReportSubtitle,
            '2 ${l10n.daysAgo}',
            textTheme,
            colors,
          ),
          const SizedBox(height: 12),
          _buildAchievementItem(
            '!',
            l10n.achievementPerfectScoreTitle,
            l10n.achievementPerfectScoreSubtitle,
            '3 ${l10n.daysAgo}',
            textTheme,
            colors,
          ),
          const SizedBox(height: 12),
          _buildAchievementItem(
            '+',
            l10n.achievementFiveDayStreakTitle,
            l10n.achievementFiveDayStreakSubtitle,
            l10n.justNow,
            textTheme,
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLockedCard(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return PremiumSectionUpsell(
      title: title,
      description: message,
      showBadge: true,
    );
  }

  Widget _buildProgressOverview(
    String title,
    String activities,
    String score,
    String time,
  ) {
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(title: title),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Builder(builder: (ctx) {
                  final loc = AppLocalizations.of(ctx)!;
                  return ParentStatCard(
                    value: activities,
                    label: loc.activities,
                    icon: Icons.check_circle_rounded,
                    color: ParentColors.parentGreen,
                  );
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(builder: (ctx) {
                  final loc = AppLocalizations.of(ctx)!;
                  return ParentStatCard(
                    value: score,
                    label: loc.avgScoreLabel,
                    icon: Icons.star_rounded,
                    color: ParentColors.xpGold,
                  );
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(builder: (ctx) {
                  final loc = AppLocalizations.of(ctx)!;
                  return ParentStatCard(
                    value: time,
                    label: loc.screenTime,
                    icon: Icons.timer_rounded,
                    color: ParentColors.infoBlue,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildAchievementItem(
    String emoji,
    String title,
    String description,
    String time,
    TextTheme textTheme,
    ColorScheme colors,
  ) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style:
              textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

}
