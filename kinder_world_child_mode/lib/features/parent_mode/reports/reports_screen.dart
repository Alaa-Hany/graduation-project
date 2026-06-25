import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/cache/app_cache_store.dart';
import 'package:kinder_world/core/models/ai_buddy_models.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/ai_buddy_provider.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/services/children_cache_service.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/app_connection_status.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';
import 'package:kinder_world/features/parent_mode/reports/development_report_card.dart';
import 'package:kinder_world/features/parent_mode/reports/report_interpreter.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:kinder_world/features/parent_mode/reports/report_service.dart';
import 'package:kinder_world/router.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

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
  static const ParentReportInterpreter _reportInterpreter =
      ParentReportInterpreter();

  ReportPeriod _period = ReportPeriod.week;
  ChildProfile? _selectedChild;
  String? _parentId;
  Future<ChildrenCacheResult>? _childrenFuture;
  Future<ChildReportLoadResult>? _reportFuture;
  Future<AiBuddyVisibilitySummary>? _aiBuddyFuture;
  bool _isResolvingParent = true;
  String? _reportKey;
  String? _aiBuddyKey;
  final Map<String, ChildReportLoadResult> _reportCache =
      <String, ChildReportLoadResult>{};
  final Map<String, AiBuddyVisibilitySummary> _aiBuddyCache =
      <String, AiBuddyVisibilitySummary>{};

  @override
  void initState() {
    super.initState();
    _resolveParentContext();
  }

  void _resolveParentContext() {
    Future<void>(() async {
      final secureStorage = ref.read(secureStorageProvider);
      final parentId = await secureStorage.getParentId();
      if (!mounted) return;
      setState(() {
        _parentId = parentId;
        _childrenFuture =
            parentId == null ? null : _loadChildrenForParent(parentId);
        _isResolvingParent = false;
      });
    });
  }

  Future<ChildrenCacheResult> _loadChildrenForParent(
    String parentId, {
    bool forceRefresh = false,
  }) async {
    final cacheService = ref.read(childrenCacheServiceProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final parentEmail = secureStorage.hasCachedUserEmail
        ? secureStorage.cachedUserEmail
        : await secureStorage.getParentEmail();
    return cacheService.loadChildrenForParent(
      parentId,
      parentEmail: parentEmail,
      forceRefresh: forceRefresh,
    );
  }

  String _reportCacheKey(
    String childId,
    ReportPeriod period, {
    required bool includeAdvancedReports,
  }) {
    return '$childId:${period.index}:${includeAdvancedReports ? 1 : 0}';
  }

  Future<ChildReportLoadResult> _loadReport(
    ChildProfile child,
    ReportPeriod period,
    bool includeAdvancedReports,
  ) async {
    final report = await ref.read(parentReportServiceProvider).loadChildReport(
          child: child,
          period: period,
          includeAdvancedReports: includeAdvancedReports,
        );
    _reportCache[_reportCacheKey(
      child.id,
      period,
      includeAdvancedReports: includeAdvancedReports,
    )] = report;
    return report;
  }

  Future<ChildReportLoadResult> _reportFutureFor(
    ChildProfile child, {
    required bool includeAdvancedReports,
  }) {
    final key = _reportCacheKey(
      child.id,
      _period,
      includeAdvancedReports: includeAdvancedReports,
    );
    if (_reportKey == key && _reportFuture != null) {
      return _reportFuture!;
    }
    final cached = _reportCache[key];
    if (cached != null) {
      _reportKey = key;
      _reportFuture = Future<ChildReportLoadResult>.value(cached);
      return _reportFuture!;
    }
    _reportKey = key;
    _reportFuture = _loadReport(
      child,
      _period,
      includeAdvancedReports,
    );
    return _reportFuture!;
  }

  Future<void> _refreshReportState() async {
    final parentId = _parentId;
    if (parentId == null || parentId.isEmpty) return;
    setState(() {
      _childrenFuture = _loadChildrenForParent(parentId, forceRefresh: true);
      _reportFuture = null;
      _reportKey = null;
      _reportCache.clear();
      _aiBuddyFuture = null;
      _aiBuddyKey = null;
    });
  }

  void _setSelectedChild(ChildProfile child) {
    if (_selectedChild?.id == child.id) return;
    setState(() {
      _selectedChild = child;
      _reportFuture = null;
      _reportKey = null;
      _aiBuddyFuture = null;
      _aiBuddyKey = null;
    });
  }

  void _setPeriod(ReportPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _reportFuture = null;
      _reportKey = null;
    });
  }

  Future<AiBuddyVisibilitySummary> _aiBuddyFutureFor(ChildProfile child) {
    final key = child.id;
    if (_aiBuddyKey == key && _aiBuddyFuture != null) {
      return _aiBuddyFuture!;
    }
    final cached = _aiBuddyCache[key];
    if (cached != null) {
      _aiBuddyKey = key;
      _aiBuddyFuture = Future<AiBuddyVisibilitySummary>.value(cached);
      return _aiBuddyFuture!;
    }
    _aiBuddyKey = key;
    _aiBuddyFuture = ref
        .read(aiBuddyServiceProvider)
        .getChildVisibilitySummary(childId: int.tryParse(child.id) ?? 0)
        .then((value) {
      _aiBuddyCache[key] = value;
      return value;
    });
    return _aiBuddyFuture!;
  }

  void _showChildSelection(List<ChildProfile> children) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final child = children[index];
              return ListTile(
                leading: AvatarView(
                  avatarId: child.avatar,
                  avatarPath: child.avatarPath,
                  radius: 20,
                ),
                title: Text(child.name),
                subtitle: Text(
                    '${AppLocalizations.of(context)!.childAge} ${child.age}'),
                trailing: _selectedChild?.id == child.id
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  _setSelectedChild(child);
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
    final colors = Theme.of(context).colorScheme;
    final plan = ref.watch(planInfoProvider).asData?.value ??
        PlanInfo.fromTier(PlanTier.free);

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
          l10n.reportsAndAnalytics,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.retry,
            onPressed: _isResolvingParent ? null : _refreshReportState,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isResolvingParent
            ? Center(
                child: CircularProgressIndicator(color: colors.primary),
              )
            : _childrenFuture == null
                ? ParentEmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: l10n.error,
                    subtitle: l10n.tryAgain,
                  )
                : FutureBuilder<ChildrenCacheResult>(
                    future: _childrenFuture,
                    builder: (context, childrenSnapshot) {
                      if (childrenSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          childrenSnapshot.data == null) {
                        return Center(
                          child:
                              CircularProgressIndicator(color: colors.primary),
                        );
                      }

                      final childrenResult = childrenSnapshot.data;
                      final children =
                          childrenResult?.children ?? const <ChildProfile>[];
                      if (children.isEmpty) {
                        return ParentEmptyState(
                          icon: Icons.bar_chart_rounded,
                          title: l10n.noChildSelected,
                          subtitle: l10n.addChildToViewReports,
                        );
                      }

                      final initialChild = widget.initialChildId != null
                          ? children.firstWhere(
                              (child) => child.id == widget.initialChildId,
                              orElse: () => children.first,
                            )
                          : children.first;
                      final selectedChild = children.firstWhere(
                        (child) => child.id == _selectedChild?.id,
                        orElse: () => _selectedChild ?? initialChild,
                      );
                      _selectedChild = selectedChild;

                      return FutureBuilder<ChildReportLoadResult>(
                        future: _reportFutureFor(
                          selectedChild,
                          includeAdvancedReports: plan.hasAdvancedReports,
                        ),
                        builder: (context, reportSnapshot) {
                          if (reportSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              reportSnapshot.data == null) {
                            return Center(
                              child: CircularProgressIndicator(
                                  color: colors.primary),
                            );
                          }

                          final reportResult = reportSnapshot.data;
                          if (reportResult == null) {
                            return ParentEmptyState(
                              icon: Icons.insert_chart_outlined_rounded,
                              title: l10n.error,
                              subtitle: l10n.tryAgain,
                            );
                          }
                          final report = reportResult.report;
                          final interpretation =
                              _reportInterpreter.interpret(report);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.learningProgressReports,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.trackChildDevelopment,
                                  style:
                                      TextStyle(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 16),
                                const AppConnectionStatusBanner.parent(),
                                const PlanStatusBanner(),
                                const SizedBox(height: 16),
                                if (childrenResult != null &&
                                    _shouldShowChildrenCacheBanner(
                                      childrenResult,
                                    )) ...[
                                  _buildChildrenCacheBanner(
                                    context,
                                    childrenResult,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                ParentCard(
                                  onTap: () => _showChildSelection(children),
                                  child: Row(
                                    children: [
                                      AvatarView(
                                        avatarId: selectedChild.avatar,
                                        avatarPath: selectedChild.avatarPath,
                                        radius: 24,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selectedChild.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${l10n.childAge} ${selectedChild.age} \u2022 ${l10n.level} ${selectedChild.level}',
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
                                const SizedBox(height: 16),
                                _buildPeriodSelector(context),
                                const SizedBox(height: 16),
                                _buildSourceBanner(context, reportResult),
                                const SizedBox(height: 16),
                                _buildSummaryGrid(context, report),
                                const SizedBox(height: 16),
                                _buildProgressCard(context, report),
                                const SizedBox(height: 16),
                                _buildInterpretationCard(
                                  context,
                                  report,
                                  interpretation,
                                ),
                                const SizedBox(height: 16),
                                _buildDailyTrendCard(context, report),
                                const SizedBox(height: 16),
                                _buildRecentSessionsCard(context, report),
                                const SizedBox(height: 16),
                                FutureBuilder<AiBuddyVisibilitySummary>(
                                  future: _aiBuddyFutureFor(selectedChild),
                                  builder: (context, aiSnapshot) {
                                    if (aiSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        aiSnapshot.data == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final aiSummary = aiSnapshot.data;
                                    if (aiSummary == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      children: [
                                        _buildAiBuddyCard(context, aiSummary),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  },
                                ),
                                if (plan.hasAdvancedReports) ...[
                                  DevelopmentReportCard(
                                    childId: selectedChild.id,
                                    days: _period.days,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAdvancedInsightsCard(context, report),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  PremiumSectionUpsell(
                                    title: l10n.activityBreakdown,
                                    description: l10n.advancedReportsLabel,
                                    showBadge: true,
                                  ),
                                  const SizedBox(height: 16),
                                ],
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

  // ignore: unused_element
  Widget _buildGamificationSnapshot(BuildContext context, String childId) {
    final l10n = AppLocalizations.of(context)!;
    final gamState = ref.watch(childGamificationStateProvider(childId));

    return gamState.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        final badges = state.earnedBadges;
        final achievements = state.unlockedAchievements;
        return ParentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParentSectionHeader(
                title: l10n.gamificationParentSnapshot,
                subtitle: l10n.gamificationParentSnapshotSubtitle,
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _GamStat(
                    emoji: '\u2B50',
                    value: '${state.totalXP}',
                    label: l10n.gamificationTotalXp,
                    color: const Color(0xFFFFB300),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '\u{1F3C6}',
                    value: '${state.level}',
                    label: l10n.gamificationLevelLabel,
                    color: const Color(0xFF7C4DFF),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '\u{1F525}',
                    value: '${state.streak}',
                    label: l10n.gamificationStreakLabel,
                    color: const Color(0xFFFF6D00),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '\u2705',
                    value: '${state.activitiesCompleted}',
                    label: l10n.gamificationActivitiesCompleted,
                    color: const Color(0xFF00C853),
                  ),
                ],
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.gamificationRecentBadges,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: badges.take(4).map((b) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: b.color.withValuesCompat(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: b.color.withValuesCompat(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.iconEmoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            l10n.badgeName(b.nameKey),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (achievements.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.gamificationAchievementsUnlocked,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...achievements.take(3).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(a.iconEmoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.achievementTitle(a.titleKey),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300)
                                  .withValuesCompat(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.gamificationXpReward(a.xpReward),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF795548),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              if (badges.isEmpty && achievements.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.gamificationNoAchievementsYet,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _PeriodChip(
          label: l10n.week,
          selected: _period == ReportPeriod.week,
          onTap: () => _setPeriod(ReportPeriod.week),
        ),
        const SizedBox(width: 8),
        _PeriodChip(
          label: l10n.month,
          selected: _period == ReportPeriod.month,
          onTap: () => _setPeriod(ReportPeriod.month),
        ),
        const SizedBox(width: 8),
        _PeriodChip(
          label: l10n.year,
          selected: _period == ReportPeriod.year,
          onTap: () => _setPeriod(ReportPeriod.year),
        ),
      ],
    );
  }

  Widget _buildChildrenCacheBanner(
    BuildContext context,
    ChildrenCacheResult result,
  ) {
    final snapshot = result.snapshot;

    final l10n = AppLocalizations.of(context)!;
    final subtitleParts = <String>[l10n.childProfilesCachedRefreshHint];
    final lastUpdated = _formatSnapshotTime(context, snapshot.lastFetchedAt);
    if (lastUpdated != null) {
      subtitleParts.add(l10n.reportLastUpdated(lastUpdated));
    }

    return _buildStatusCard(
      context,
      icon: snapshot.syncState == CacheSyncState.syncFailed
          ? Icons.cloud_off_rounded
          : Icons.inventory_2_outlined,
      accent: snapshot.syncState == CacheSyncState.syncFailed
          ? Theme.of(context).colorScheme.tertiary
          : Theme.of(context).colorScheme.secondary,
      title: l10n.childProfilesCachedTitle,
      subtitle: subtitleParts.join(' | '),
    );
  }

  bool _shouldShowChildrenCacheBanner(ChildrenCacheResult result) {
    final snapshot = result.snapshot;
    if (!snapshot.hasData) return false;
    if (snapshot.freshness == CacheFreshness.freshServerBacked) return false;
    if (snapshot.freshness == CacheFreshness.cachedFresh &&
        snapshot.syncState == CacheSyncState.synced) {
      return false;
    }
    return true;
  }

  Widget _buildSourceBanner(
    BuildContext context,
    ChildReportLoadResult result,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final report = result.report;
    late final IconData icon;
    late final Color accent;
    late final String title;
    late final String subtitle;

    switch (result.source) {
      case ChildReportSource.liveServer:
        icon = report.usesRecordedSessions
            ? Icons.insights_rounded
            : Icons.info_outline_rounded;
        accent = report.usesRecordedSessions ? colors.primary : colors.tertiary;
        title = report.usesRecordedSessions
            ? l10n.reportUsingSyncedDataTitle
            : l10n.noRecordedActivityYet;
        subtitle = report.usesRecordedSessions
            ? l10n.reportUsingSyncedDataSubtitle
            : l10n.profileFallbackNotice;
        break;
      case ChildReportSource.localDevice:
        icon = Icons.offline_bolt_rounded;
        accent = colors.secondary;
        title = l10n.reportUsingDeviceDataTitle;
        subtitle = result.hasPendingLocalChanges
            ? l10n.reportPendingSyncSubtitle
            : l10n.reportUsingDeviceDataSubtitle;
        break;
      case ChildReportSource.cachedSnapshot:
        icon = Icons.history_rounded;
        accent = colors.tertiary;
        final lastUpdated = _formatSnapshotTime(
          context,
          result.cacheSnapshot?.lastFetchedAt,
        );
        title = l10n.reportUsingCachedSnapshotTitle;
        subtitle = lastUpdated == null
            ? l10n.reportUsingCachedSnapshotSubtitle
            : '${l10n.reportUsingCachedSnapshotSubtitle} | ${l10n.reportLastUpdated(lastUpdated)}';
        break;
      case ChildReportSource.profileFallback:
        icon = Icons.info_outline_rounded;
        accent = colors.tertiary;
        title = l10n.reportUsingLimitedSummaryTitle;
        subtitle = l10n.profileFallbackNotice;
        break;
    }

    return _buildStatusCard(
      context,
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ParentCard(
      backgroundColor: accent.withValuesCompat(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formatSnapshotTime(BuildContext context, DateTime? value) {
    if (value == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('MMM d, h:mm a', locale).format(value.toLocal());
  }

  Widget _buildSummaryGrid(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final parent = context.parentTheme;
    // Active days = calendar days in the period with at least one completed
    // activity. This is always meaningful, unlike "lessons" which only counts
    // learning-path lessons and is 0 for children who mostly play games/stories.
    final totalDays = report.dailyPoints.isNotEmpty
        ? report.dailyPoints.length
        : report.period.days;
    final activeDays = report.dailyPoints
        .where((point) => point.activitiesCompleted > 0)
        .length;
    final cards = [
      ParentStatCard(
        value: '${report.totalActivitiesCompleted}',
        label: l10n.activities,
        icon: Icons.task_alt_rounded,
        color: parent.primary,
      ),
      // Show real lesson count only when the child actually completed lessons;
      // otherwise show active days so the slot is never a confusing "0".
      if (report.totalLessonsCompleted > 0)
        ParentStatCard(
          value: '${report.totalLessonsCompleted}',
          label: l10n.lessonsCompletedLabel,
          icon: Icons.menu_book_rounded,
          color: context.infoColor,
        )
      else
        ParentStatCard(
          value: '$activeDays/$totalDays',
          label: l10n.activeDaysLabel,
          icon: Icons.event_available_rounded,
          color: context.infoColor,
        ),
      ParentStatCard(
        value: _formatMinutes(report.totalScreenTimeMinutes),
        label: l10n.screenTime,
        icon: Icons.timer_rounded,
        color: context.rewardColor,
      ),
      ParentStatCard(
        value:
            report.averageScore > 0 ? '${report.averageScore.round()}%' : '-',
        label: l10n.avgScoreLabel,
        icon: Icons.star_rounded,
        color: parent.reward,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map((card) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 50) / 2,
                child: card,
              ))
          .toList(),
    );
  }

  Widget _buildProgressCard(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final totalDays = report.dailyPoints.isNotEmpty
        ? report.dailyPoints.length
        : report.period.days;
    final activeDays = report.dailyPoints
        .where((point) => point.activitiesCompleted > 0)
        .length;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.learningProgress,
            subtitle: l10n.completionRateLabel,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetaPill(
                icon: Icons.check_circle_rounded,
                label: '${(report.completionRate * 100).round()}%',
              ),
              _MetaPill(
                icon: Icons.task_alt_rounded,
                label: '${report.totalActivitiesCompleted} ${l10n.activities}',
              ),
              _MetaPill(
                icon: Icons.event_available_rounded,
                label: '$activeDays/$totalDays ${l10n.activeDaysLabel}',
              ),
              // Only surface lessons when the child actually completed some.
              if (report.totalLessonsCompleted > 0)
                _MetaPill(
                  icon: Icons.menu_book_rounded,
                  label:
                      '${report.totalLessonsCompleted} ${l10n.lessonsCompletedLabel}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: report.completionRate.clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretationCard(
    BuildContext context,
    ChildReportData report,
    ParentReportInterpretation interpretation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final parent = context.parentTheme;
    final insights = interpretation.insights;
    final recommendations = interpretation.recommendations;
    if (insights.isEmpty && recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.reportInsightsTitle,
            subtitle: l10n.reportInsightsSubtitle,
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReportInterpretationTile(
                icon: _insightIcon(insight.type),
                accent: _insightColor(context, insight.tone),
                text: _insightText(context, report, insight),
              ),
            );
          }),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.reportNextStepsTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
            ),
            const SizedBox(height: 10),
            ...recommendations.map((recommendation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: parent.primary.withValuesCompat(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: parent.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _recommendationText(context, recommendation),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyTrendCard(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final points = report.dailyPoints;
    final info = context.infoColor;
    final maxValue = points.fold<int>(
      1,
      (max, point) =>
          point.activitiesCompleted > max ? point.activitiesCompleted : max,
    );
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.dailyTrendLabel,
            subtitle: _periodLabel(l10n),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((point) {
                final heightFactor = point.activitiesCompleted / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: point.activitiesCompleted > 0
                                    ? info
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              height: 18 + (92 * heightFactor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${point.date.day}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard(
      BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final parent = context.parentTheme;
    if (report.recentSessions.isEmpty) {
      return ParentCard(
        child: ParentEmptyState(
          icon: Icons.history_rounded,
          title: l10n.recentActivities,
          subtitle: l10n.noRecordedActivityYet,
        ),
      );
    }

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(title: l10n.recentActivities),
          const SizedBox(height: 12),
          ...report.recentSessions.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: parent.reward.withValuesCompat(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: parent.reward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_contentTypeLabel(l10n, session.contentType)} \u2022 ${session.durationMinutes} min \u2022 ${session.score}%',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiBuddyCard(
    BuildContext context,
    AiBuddyVisibilitySummary summary,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final provider = summary.provider;
    final isFallback = provider.isFallback;
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.aiBuddy,
            subtitle: l10n.safety,
          ),
          if (isFallback) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer.withValuesCompat(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.tertiary.withValuesCompat(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: colors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.reason ?? l10n.aiBuddyFallbackSummary,
                      style: TextStyle(
                          color: colors.onTertiaryContainer, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            summary.parentSummary,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaPill(
                icon: Icons.analytics_outlined,
                label:
                    '${summary.usageMetrics.sessionsCount} ${l10n.analyticsTitle}',
              ),
              _MetaPill(
                icon: Icons.message_outlined,
                label:
                    '${summary.usageMetrics.messagesCount} ${l10n.recentActivities}',
              ),
              _MetaPill(
                icon: Icons.shield_outlined,
                label:
                    '${summary.usageMetrics.refusalCount + summary.usageMetrics.safeRedirectCount} ${l10n.safety}',
              ),
              _MetaPill(
                icon: Icons.schedule_rounded,
                label:
                    '${summary.retentionPolicy.messagesRetainedDays}d ${l10n.activityReports}',
              ),
            ],
          ),
          if (summary.recentFlags.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...summary.recentFlags.map(
              (flag) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  flag.classification == 'needs_refusal'
                      ? Icons.block_rounded
                      : Icons.shield_outlined,
                  color: flag.classification == 'needs_refusal'
                      ? colors.error
                      : colors.tertiary,
                ),
                title: Text(flag.topic ?? l10n.notAvailable),
                subtitle: Text(flag.reason ?? l10n.notAvailable),
                trailing: Text(_formatTimestamp(flag.occurredAt)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedInsightsCard(
      BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final parent = context.parentTheme;
    final moodEntries = report.moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final insightRows = <Widget>[];
    final hasContentType =
        report.topContentType != null && report.topContentType!.isNotEmpty;
    final hasCurrentMood =
        report.currentMood != null && report.currentMood!.isNotEmpty;
    final moodSamples =
        report.moodCounts.values.fold<int>(0, (sum, value) => sum + value);

    if (hasContentType) {
      insightRows.add(
        _InsightRow(
          label: l10n.mostUsedContentLabel,
          value: _contentTypeLabel(l10n, report.topContentType),
        ),
      );
    }
    if (hasCurrentMood) {
      if (insightRows.isNotEmpty) {
        insightRows.add(const SizedBox(height: 10));
      }
      insightRows.add(
        _InsightRow(
          label: l10n.currentMoodLabel,
          value: _moodLabel(l10n, report.currentMood!),
        ),
      );
    }
    if (moodEntries.isNotEmpty && moodSamples >= 2) {
      if (insightRows.isNotEmpty) {
        insightRows.add(const SizedBox(height: 10));
      }
      insightRows.add(
        _InsightRow(
          label: l10n.moodTrendLabel,
          value: moodEntries.take(2).map((entry) {
            return '${_moodLabel(l10n, entry.key)} (${entry.value})';
          }).join(' \u2022 '),
        ),
      );
    }

    if (insightRows.isEmpty && report.achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (insightRows.isNotEmpty) ...[
            ParentSectionHeader(title: l10n.activityBreakdown),
            const SizedBox(height: 16),
            ...insightRows,
          ],
          if (report.achievements.isNotEmpty) ...[
            if (insightRows.isNotEmpty) const SizedBox(height: 16),
            ParentSectionHeader(title: l10n.recentAchievements),
            const SizedBox(height: 12),
            ...report.achievements.map((achievement) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      achievement.achieved
                          ? Icons.verified_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: achievement.achieved
                          ? parent.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_achievementTitle(l10n, achievement.titleKey)} \u2022 ${achievement.detail}',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String _contentTypeLabel(AppLocalizations l10n, String? type) {
    switch (type) {
      case 'lessons':
        return l10n.lesson;
      case 'activity_of_day':
        return l10n.activityOfTheDay;
      case 'games':
        return l10n.categoryGames;
      case 'stories':
        return l10n.categoryStories;
      case 'music':
        return l10n.categoryMusic;
      case 'videos':
        return l10n.categoryVideos;
      default:
        return l10n.notAvailable;
    }
  }

  String _moodLabel(AppLocalizations l10n, String mood) {
    switch (mood) {
      case 'happy':
        return l10n.happy;
      case 'excited':
        return l10n.excited;
      case 'calm':
        return l10n.calm;
      case 'tired':
        return l10n.tired;
      case 'sad':
        return l10n.sad;
      case 'angry':
        return l10n.angry;
      default:
        return mood;
    }
  }

  String _achievementTitle(AppLocalizations l10n, String key) {
    switch (key) {
      case 'streak':
        return l10n.streak;
      case 'lessons':
        return l10n.lessonsCompletedLabel;
      case 'activities':
        return l10n.activities;
      case 'score':
        return l10n.avgScoreLabel;
      default:
        return key;
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    if (totalMinutes < 60) return '${totalMinutes}m';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _periodLabel(AppLocalizations l10n) {
    switch (_period) {
      case ReportPeriod.week:
        return l10n.week;
      case ReportPeriod.month:
        return l10n.month;
      case ReportPeriod.year:
        return l10n.year;
    }
  }

  IconData _insightIcon(ParentReportInsightType type) {
    switch (type) {
      case ParentReportInsightType.noRecentActivity:
        return Icons.insights_rounded;
      case ParentReportInsightType.momentumStrong:
      case ParentReportInsightType.momentumNeedsRoutine:
        return Icons.timeline_rounded;
      case ParentReportInsightType.completionStrong:
      case ParentReportInsightType.completionNeedsSupport:
        return Icons.task_alt_rounded;
      case ParentReportInsightType.scoreStrong:
      case ParentReportInsightType.scoreNeedsReview:
        return Icons.school_rounded;
      case ParentReportInsightType.contentPreference:
        return Icons.auto_stories_rounded;
      case ParentReportInsightType.moodPositive:
      case ParentReportInsightType.moodNeedsCheckIn:
        return Icons.mood_rounded;
    }
  }

  Color _insightColor(BuildContext context, ParentReportTone tone) {
    final colors = Theme.of(context).colorScheme;
    switch (tone) {
      case ParentReportTone.positive:
        return context.infoColor;
      case ParentReportTone.neutral:
        return colors.primary;
      case ParentReportTone.attention:
        return colors.tertiary;
    }
  }

  String _insightText(
    BuildContext context,
    ChildReportData report,
    ParentReportInsight insight,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (insight.type) {
      case ParentReportInsightType.noRecentActivity:
        return l10n.reportInsightNoRecentActivity(report.child.name);
      case ParentReportInsightType.momentumStrong:
        return l10n.reportInsightMomentumStrong(
          insight.primaryValue ?? 0,
          insight.secondaryValue ?? report.period.days,
        );
      case ParentReportInsightType.momentumNeedsRoutine:
        return l10n.reportInsightMomentumNeedsRoutine(
          insight.primaryValue ?? 0,
          insight.secondaryValue ?? report.period.days,
        );
      case ParentReportInsightType.completionStrong:
        return l10n.reportInsightCompletionStrong(insight.primaryValue ?? 0);
      case ParentReportInsightType.completionNeedsSupport:
        return l10n
            .reportInsightCompletionNeedsSupport(insight.primaryValue ?? 0);
      case ParentReportInsightType.scoreStrong:
        return l10n.reportInsightScoreStrong(insight.primaryValue ?? 0);
      case ParentReportInsightType.scoreNeedsReview:
        return l10n.reportInsightScoreNeedsReview(insight.primaryValue ?? 0);
      case ParentReportInsightType.contentPreference:
        return l10n.reportInsightContentPreference(
          _contentTypeLabel(l10n, insight.contentType),
        );
      case ParentReportInsightType.moodPositive:
        return l10n.reportInsightMoodPositive(
          _moodLabel(l10n, insight.mood ?? report.currentMood ?? ''),
        );
      case ParentReportInsightType.moodNeedsCheckIn:
        return l10n.reportInsightMoodNeedsCheckIn(
          _moodLabel(l10n, insight.mood ?? report.currentMood ?? ''),
        );
    }
  }

  String _recommendationText(
    BuildContext context,
    ParentReportRecommendation recommendation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (recommendation.type) {
      case ParentReportRecommendationType.startShortSession:
        return l10n.reportRecommendationStartShortSession;
      case ParentReportRecommendationType.setSimpleRoutine:
        return l10n.reportRecommendationSetSimpleRoutine;
      case ParentReportRecommendationType.chooseShorterActivities:
        return l10n.reportRecommendationChooseShorterActivities;
      case ParentReportRecommendationType.reviewRecentLessons:
        return l10n.reportRecommendationReviewRecentLessons;
      case ParentReportRecommendationType.usePreferredContentAsWarmup:
        return l10n.reportRecommendationUsePreferredContent(
          _contentTypeLabel(l10n, recommendation.contentType),
        );
      case ParentReportRecommendationType.checkMoodBeforeStarting:
        return l10n.reportRecommendationCheckMoodBeforeStarting;
      case ParentReportRecommendationType.keepRoutineAndStretch:
        return l10n.reportRecommendationKeepRoutineAndStretch;
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Gamification stat tile used in parent reports snapshot
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GamStat extends StatelessWidget {
  const _GamStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValuesCompat(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValuesCompat(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.onPrimary : colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ReportInterpretationTile extends StatelessWidget {
  const _ReportInterpretationTile({
    required this.icon,
    required this.accent,
    required this.text,
  });

  final IconData icon;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValuesCompat(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValuesCompat(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
