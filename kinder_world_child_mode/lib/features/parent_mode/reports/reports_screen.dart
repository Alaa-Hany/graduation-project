import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/plan_provider.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/premium_section_upsell.dart';
import 'package:kinder_world/features/parent_mode/reports/mood_report_section.dart';
import 'package:kinder_world/features/parent_mode/reports/report_models.dart';
import 'package:kinder_world/features/parent_mode/reports/report_service.dart';
import 'package:kinder_world/router.dart';

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
  Future<List<ChildProfile>>? _childrenFuture;
  Future<ChildReportData>? _reportFuture;
  String? _cachedParentId;
  bool _isResolvingParent = true;
  String? _reportKey;
  int _childrenRequestId = 0;
  final Map<String, ChildReportData> _reportCache = <String, ChildReportData>{};

  @override
  void initState() {
    super.initState();
    _resolveParentContext();
  }

  void _resolveParentContext() {
    final secureStorage = ref.read(secureStorageProvider);
    final cachedParentId = secureStorage.hasCachedUserId
        ? secureStorage.cachedUserId
        : null;
    if (cachedParentId != null && cachedParentId.isNotEmpty) {
      _cachedParentId = cachedParentId;
      _childrenFuture = _loadChildrenForParent(cachedParentId);
      _isResolvingParent = false;
      return;
    }

    Future<void>(() async {
      final parentId = await secureStorage.getParentId();
      if (!mounted) return;
      setState(() {
        _cachedParentId = parentId;
        _childrenFuture =
            parentId == null ? null : _loadChildrenForParent(parentId);
        _isResolvingParent = false;
      });
    });
  }

  List<Map<String, dynamic>> _extractChildrenList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      final listData =
          data['children'] ?? data['data'] ?? data['results'] ?? data['items'];
      if (listData is List) {
        return listData
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return [];
  }

  String? _parseChildId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['child_id'] ?? data['childId'];
    return raw?.toString();
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    required String parentId,
    String? parentEmail,
    ChildProfile? existing,
  }) {
    final childId = _parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final resolvedName =
        (apiName != null && apiName.isNotEmpty) ? apiName : (existing?.name ?? childId);

    return ChildProfile(
      id: childId,
      name: resolvedName,
      age: _parseInt(data['age'], existing?.age ?? 0),
      avatar: existing?.avatar ??
          data['avatar']?.toString() ??
          AppConstants.defaultChildAvatar,
      interests: existing?.interests ?? const [],
      level: existing?.level ?? 1,
      xp: existing?.xp ?? 0,
      streak: existing?.streak ?? 0,
      favorites: existing?.favorites ?? const [],
      parentId: parentId,
      parentEmail: existing?.parentEmail ?? parentEmail,
      picturePassword: existing?.picturePassword ?? const [],
      createdAt: existing?.createdAt ?? _parseDate(data['created_at'], now),
      updatedAt: _parseDate(data['updated_at'], now),
      lastSession: existing?.lastSession,
      totalTimeSpent: existing?.totalTimeSpent ?? 0,
      activitiesCompleted: existing?.activitiesCompleted ?? 0,
      currentMood: existing?.currentMood,
      learningStyle: existing?.learningStyle,
      specialNeeds: existing?.specialNeeds,
      accessibilityNeeds: existing?.accessibilityNeeds,
      avatarPath: existing?.avatarPath ?? AppConstants.defaultChildAvatar,
    );
  }

  Future<List<ChildProfile>> _loadChildrenForParent(String parentId) async {
    final repo = ref.read(childRepositoryProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final requestId = ++_childrenRequestId;
    final parentEmail = secureStorage.hasCachedUserEmail
        ? secureStorage.cachedUserEmail
        : await secureStorage.getParentEmail();
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await repo.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }

    final localChildren = await repo.getChildProfilesForParent(parentId);
    final childrenById = {for (final child in localChildren) child.id: child};

    final token = secureStorage.hasCachedAuthToken
        ? secureStorage.cachedAuthToken
        : await secureStorage.getAuthToken();
    if (token == null || token.startsWith('child_session_')) {
      return childrenById.values.toList();
    }

    unawaited(
      _syncRemoteChildrenForParent(
        requestId: requestId,
        parentId: parentId,
        parentEmail: parentEmail,
        initialChildren: childrenById,
      ),
    );

    return childrenById.values.toList();
  }

  Future<void> _syncRemoteChildrenForParent({
    required int requestId,
    required String parentId,
    required String? parentEmail,
    required Map<String, ChildProfile> initialChildren,
  }) async {
    final repo = ref.read(childRepositoryProvider);
    final childrenById = Map<String, ChildProfile>.from(initialChildren);

    try {
      final response =
          await ref.read(networkServiceProvider).get<dynamic>('/children');
      final apiChildren = _extractChildrenList(response.data);
      final writeOperations = <Future<Object?>>[];
      for (final childData in apiChildren) {
        final childId = _parseChildId(childData);
        if (childId == null || childId.isEmpty) continue;
        final existing = childrenById[childId];
        final merged = _mergeChildProfileFromApi(
          childData,
          parentId: parentId,
          parentEmail: parentEmail,
          existing: existing,
        );
        if (merged == null) continue;
        childrenById[childId] = merged;
        writeOperations.add(
          existing == null
              ? repo.createChildProfile(merged)
              : repo.updateChildProfile(merged),
        );
      }
      if (writeOperations.isNotEmpty) {
        await Future.wait(writeOperations);
      }
      if (!mounted ||
          requestId != _childrenRequestId ||
          _cachedParentId != parentId) {
        return;
      }
      setState(() {
        _childrenFuture = Future<List<ChildProfile>>.value(
          childrenById.values.toList(growable: false),
        );
        _reportFuture = null;
        _reportKey = null;
        _reportCache.clear();
      });
    } catch (_) {
      // Keep the local children snapshot if the remote sync is unavailable.
    }
  }

  String _reportCacheKey(String childId, ReportPeriod period) {
    return '$childId:${period.index}';
  }

  Future<ChildReportData> _loadReport(
    ChildProfile child,
    ReportPeriod period,
  ) async {
    final report = await ref.read(parentReportServiceProvider).buildChildReport(
          child: child,
          period: period,
        );
    _reportCache[_reportCacheKey(child.id, period)] = report;
    return report;
  }

  Future<ChildReportData> _reportFutureFor(ChildProfile child) {
    final key = _reportCacheKey(child.id, _period);
    if (_reportKey == key && _reportFuture != null) {
      return _reportFuture!;
    }
    final cached = _reportCache[key];
    if (cached != null) {
      _reportKey = key;
      _reportFuture = Future<ChildReportData>.value(cached);
      return _reportFuture!;
    }
    _reportKey = key;
    _reportFuture = _loadReport(child, _period);
    return _reportFuture!;
  }

  void _setSelectedChild(ChildProfile child) {
    if (_selectedChild?.id == child.id) return;
    setState(() {
      _selectedChild = child;
      _reportFuture = null;
      _reportKey = null;
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
                subtitle: Text('${AppLocalizations.of(context)!.childAge} ${child.age}'),
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
    final plan =
        ref.watch(planInfoProvider).asData?.value ?? PlanInfo.fromTier(PlanTier.free);

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
            : FutureBuilder<List<ChildProfile>>(
                future: _childrenFuture,
                builder: (context, childrenSnapshot) {
                  if (childrenSnapshot.connectionState == ConnectionState.waiting &&
                      childrenSnapshot.data == null) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }

                  final children = childrenSnapshot.data ?? const <ChildProfile>[];
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

                  return FutureBuilder<ChildReportData>(
                    future: _reportFutureFor(selectedChild),
                    builder: (context, reportSnapshot) {
                      if (reportSnapshot.connectionState == ConnectionState.waiting &&
                          reportSnapshot.data == null) {
                        return Center(
                          child: CircularProgressIndicator(color: colors.primary),
                        );
                      }

                      final report = reportSnapshot.data;
                      if (report == null) {
                        return ParentEmptyState(
                          icon: Icons.insert_chart_outlined_rounded,
                          title: l10n.error,
                          subtitle: l10n.tryAgain,
                        );
                      }

                      return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.learningProgressReports,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.trackChildDevelopment,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          const PlanStatusBanner(),
                          const SizedBox(height: 16),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        '${l10n.childAge} ${selectedChild.age} • ${l10n.level} ${selectedChild.level}',
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
                          _buildSourceBanner(context, report),
                          const SizedBox(height: 16),
                          _buildSummaryGrid(context, report),
                          const SizedBox(height: 16),
                          _buildProgressCard(context, report),
                          const SizedBox(height: 16),
                          _buildGamificationSnapshot(context, selectedChild.id),
                          const SizedBox(height: 16),
                          MoodReportSection(childId: selectedChild.id),
                          const SizedBox(height: 16),
                          _buildDailyTrendCard(context, report),
                          const SizedBox(height: 16),
                          _buildRecentSessionsCard(context, report),
                          const SizedBox(height: 16),
                          if (plan.hasAdvancedReports) ...[
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
                    emoji: '⭐',
                    value: '${state.totalXP}',
                    label: l10n.gamificationTotalXp,
                    color: const Color(0xFFFFB300),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '🏆',
                    value: '${state.level}',
                    label: l10n.gamificationLevelLabel,
                    color: const Color(0xFF7C4DFF),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '🔥',
                    value: '${state.streak}',
                    label: l10n.gamificationStreakLabel,
                    color: const Color(0xFFFF6D00),
                  ),
                  const SizedBox(width: 8),
                  _GamStat(
                    emoji: '✅',
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
                        color: b.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: b.color.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.iconEmoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            _badgeName(b.nameKey),
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
                              _achievementName(a.titleKey),
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
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+${a.xpReward} XP',
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

  String _badgeName(String key) {
    const names = {
      'badgeFirstSteps': 'First Steps',
      'badgeExplorer': 'Explorer',
      'badgeStreakStar': 'Streak Star',
      'badgeActivityChamp': 'Activity Champ',
      'badgeLevelUp': 'Level Up',
      'badgePerfectionist': 'Perfectionist',
    };
    return names[key] ?? key;
  }

  String _achievementName(String key) {
    const names = {
      'achievementFirstLessonTitle': 'First Lesson',
      'achievementFirstActivityTitle': 'First Activity',
      'achievementStreak3Title': '3-Day Streak',
      'achievementStreak7Title': 'Week Warrior',
      'achievementStreak30Title': 'Monthly Master',
      'achievementActivities10Title': 'Activity Pro',
      'achievementActivities50Title': 'Activity Legend',
      'achievementLevel5Title': 'Level 5 Hero',
      'achievementXP1000Title': '1,000 XP',
      'achievementPerfectScoreTitle': 'Perfect Score',
      'achievementExplorerTitle': 'Explorer',
      'achievementFirstBadgeTitle': 'First Badge',
    };
    return names[key] ?? key;
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

  Widget _buildSourceBanner(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isRecorded = report.usesRecordedSessions;
    return ParentCard(
      backgroundColor: (isRecorded ? colors.primary : colors.tertiary)
          .withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            isRecorded ? Icons.insights_rounded : Icons.info_outline_rounded,
            color: isRecorded ? colors.primary : colors.tertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRecorded
                  ? l10n.recordedSessionsNotice
                  : l10n.profileFallbackNotice,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final parent = context.parentTheme;
    final cards = [
      ParentStatCard(
        value: '${report.totalActivitiesCompleted}',
        label: l10n.activities,
        icon: Icons.task_alt_rounded,
        color: parent.primary,
      ),
      ParentStatCard(
        value: '${report.totalLessonsCompleted}',
        label: l10n.lessonsCompletedLabel,
        icon: Icons.menu_book_rounded,
        color: context.infoColor,
      ),
      ParentStatCard(
        value: _formatMinutes(report.totalScreenTimeMinutes),
        label: l10n.screenTime,
        icon: Icons.timer_rounded,
        color: context.rewardColor,
      ),
      ParentStatCard(
        value: report.averageScore > 0
            ? '${report.averageScore.round()}%'
            : '—',
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
                icon: Icons.trending_up_rounded,
                label: '${l10n.level} ${report.child.level}',
              ),
              _MetaPill(
                icon: Icons.local_fire_department_rounded,
                label: '${report.child.streak} ${l10n.daysAgo}',
              ),
              _MetaPill(
                icon: Icons.emoji_events_rounded,
                label: '${report.child.xp} ${l10n.xp}',
              ),
              _MetaPill(
                icon: Icons.check_circle_rounded,
                label: '${(report.completionRate * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: report.child.xpProgress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
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
      (max, point) => point.activitiesCompleted > max ? point.activitiesCompleted : max,
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

  Widget _buildRecentSessionsCard(BuildContext context, ChildReportData report) {
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
                      color: parent.reward.withValues(alpha: 0.12),
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
                          '${_contentTypeLabel(l10n, session.contentType)} • ${session.durationMinutes} min • ${session.score}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildAdvancedInsightsCard(BuildContext context, ChildReportData report) {
    final l10n = AppLocalizations.of(context)!;
    final parent = context.parentTheme;
    final moodEntries = report.moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(title: l10n.activityBreakdown),
          const SizedBox(height: 16),
          _InsightRow(
            label: l10n.mostUsedContentLabel,
            value: _contentTypeLabel(l10n, report.topContentType),
          ),
          const SizedBox(height: 10),
          _InsightRow(
            label: l10n.currentMoodLabel,
            value: report.currentMood != null
                ? _moodLabel(l10n, report.currentMood!)
                : l10n.notAvailable,
          ),
          const SizedBox(height: 10),
          _InsightRow(
            label: l10n.moodTrendLabel,
            value: moodEntries.isEmpty
                ? l10n.notAvailable
                : moodEntries.take(2).map((entry) {
                    return '${_moodLabel(l10n, entry.key)} (${entry.value})';
                  }).join(' • '),
          ),
          const SizedBox(height: 16),
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
                      '${_achievementTitle(l10n, achievement.titleKey)} • ${achievement.detail}',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Gamification stat tile used in parent reports snapshot
// ─────────────────────────────────────────────────────────────────────────────

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
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
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
