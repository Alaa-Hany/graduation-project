import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kinder_world/core/subscription/plan_info.dart';
import 'package:kinder_world/core/widgets/plan_guard.dart';
import 'package:kinder_world/core/widgets/plan_status_banner.dart';
import 'package:kinder_world/core/widgets/dashboard_theme_switch.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Future<List<ChildProfile>>? _childrenFuture;
  String? _cachedParentId;
  // Theme mode handled via ThemeController

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final id = data['id'] ?? data['child_id'] ?? data['childId'];
    if (id == null) return null;
    return id.toString();
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed ?? fallback;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return fallback;
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  int _ageFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) age -= 1;
    return age.clamp(0, 120);
  }

  int _resolveAgeFromApi(Map<String, dynamic> data, ChildProfile? existing) {
    final apiAge = _parseInt(data['age'], 0);
    final birthDate = _parseBirthDate(
      data['birthdate'] ??
          data['birth_date'] ??
          data['date_of_birth'] ??
          data['dob'],
    );
    final computedAge = _ageFromBirthDate(birthDate);

    if (kDebugMode) {
      debugPrint(
        'Child age resolve: apiAge=$apiAge, birthDate=$birthDate, computedAge=$computedAge, existing=${existing?.age}',
      );
    }

    if (apiAge > 0) return apiAge;
    if (computedAge > 0) return computedAge;
    return existing?.age ?? 0;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  List<String>? _parseNullableStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return null;
  }

  ChildProfile? _mergeChildProfileFromApi(
    Map<String, dynamic> data, {
    ChildProfile? existing,
    required String parentId,
    String? parentEmail,
  }) {
    final childId = _parseChildId(data);
    if (childId == null || childId.isEmpty) return null;

    final now = DateTime.now();
    final apiName = data['name']?.toString().trim();
    final resolvedName = (apiName != null && apiName.isNotEmpty)
        ? apiName
        : (existing?.name ?? childId);
    final age = _resolveAgeFromApi(data, existing);
    final existingLevel = existing?.level ?? 0;
    final level = existingLevel > 0 ? existingLevel : _parseInt(data['level'], 1);
    final avatar =
        existing?.avatar ?? data['avatar']?.toString() ?? 'avatar_1';
    final resolvedAvatarPath = existing?.avatarPath.isNotEmpty == true
        ? existing!.avatarPath
        : (avatar.startsWith('assets/')
            ? avatar
            : AppConstants.defaultChildAvatar);
    final picturePassword = (existing?.picturePassword.isNotEmpty ?? false)
        ? existing!.picturePassword
        : _parseStringList(data['picture_password']);
    final createdAt = existing?.createdAt ?? _parseDate(data['created_at'], now);
    final updatedAt = _parseDate(data['updated_at'], now);
    final lastSession =
        existing?.lastSession ?? _parseNullableDate(data['last_session']);

    return ChildProfile(
      id: childId,
      name: resolvedName,
      age: age,
      avatar: avatar,
      avatarPath: resolvedAvatarPath,
      interests: existing?.interests ?? _parseStringList(data['interests']),
      level: level,
      xp: existing?.xp ?? _parseInt(data['xp'], 0),
      streak: existing?.streak ?? _parseInt(data['streak'], 0),
      favorites: existing?.favorites ?? _parseStringList(data['favorites']),
      parentId: parentId,
      parentEmail: existing?.parentEmail ??
          parentEmail ??
          data['parent_email']?.toString(),
      picturePassword: picturePassword,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSession: lastSession,
      totalTimeSpent:
          existing?.totalTimeSpent ?? _parseInt(data['total_time_spent'], 0),
      activitiesCompleted: existing?.activitiesCompleted ??
          _parseInt(data['activities_completed'], 0),
      currentMood: existing?.currentMood ?? data['current_mood']?.toString(),
      learningStyle:
          existing?.learningStyle ?? data['learning_style']?.toString(),
      specialNeeds:
          existing?.specialNeeds ?? _parseNullableStringList(data['special_needs']),
      accessibilityNeeds: existing?.accessibilityNeeds ??
          _parseNullableStringList(data['accessibility_needs']),
    );
  }

  Future<List<ChildProfile>> _loadChildrenForParent(String parentId) async {
    final repo = ref.read(childRepositoryProvider);
    final parentEmail = await ref.read(secureStorageProvider).getParentEmail();
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await repo.linkChildrenToParent(
        parentId: parentId,
        parentEmail: parentEmail,
      );
    }
    final localChildren = await repo.getChildProfilesForParent(parentId);
    final childrenById = {
      for (final child in localChildren) child.id: child,
    };

    final token = await ref.read(secureStorageProvider).getAuthToken();
    if (token == null || token.startsWith('child_session_')) {
      return childrenById.values.toList();
    }

    final resolvedParentEmail = parentEmail;
    try {
      final response = await ref.read(networkServiceProvider).get<dynamic>(
        '/children',
      );
      final apiChildren = _extractChildrenList(response.data);
      for (final childData in apiChildren) {
        final childId = _parseChildId(childData);
        if (childId == null || childId.isEmpty) continue;
        final existing = await repo.getChildProfile(childId);
        final merged = _mergeChildProfileFromApi(
          childData,
          parentId: parentId,
          parentEmail: resolvedParentEmail,
          existing: existing,
        );
        if (merged == null) continue;
        childrenById[childId] = merged;
        if (existing == null) {
          await repo.createChildProfile(merged);
        } else {
          await repo.updateChildProfile(merged);
        }
      }
    } catch (_) {
      return childrenById.values.toList();
    }

    return childrenById.values.toList();
  }

  String _dashboardGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorningOverview;
    if (hour < 17) return l10n.goodAfternoonOverview;
    return l10n.goodEveningOverview;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: FutureBuilder<String?>(
            future: ref.read(secureStorageProvider).getParentId(),
            builder: (context, parentIdSnapshot) {
              if (!parentIdSnapshot.hasData || parentIdSnapshot.data == null) {
                return Center(
                  child: CircularProgressIndicator(color: colors.primary),
                );
              }

              final parentId = parentIdSnapshot.data!;
              if (_childrenFuture == null || _cachedParentId != parentId) {
                _cachedParentId = parentId;
                _childrenFuture = _loadChildrenForParent(parentId);
              }

              return FutureBuilder<List<ChildProfile>>(
                future: _childrenFuture,
                builder: (context, childrenSnapshot) {
                  if (childrenSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }

                  final children = childrenSnapshot.data ?? [];

                  return CustomScrollView(
                    slivers: [
                      // ── App Bar ───────────────────────────────────────
                      SliverAppBar(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        elevation: 0,
                        floating: true,
                        titleSpacing: 16,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.parentDashboard,
                              style: textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _dashboardGreeting(l10n),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: colors.onSurface,
                            ),
                            tooltip: l10n.notifications,
                            onPressed: () =>
                                context.go('/parent/notifications'),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.settings_outlined,
                              color: colors.onSurface,
                            ),
                            tooltip: l10n.settings,
                            onPressed: () => context.go('/parent/settings'),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final themeMode =
                                  ref.watch(themeControllerProvider).mode;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: DashboardThemeSwitch(
                                  value: themeMode == ThemeMode.dark,
                                  onChanged: (isDark) {
                                    ref
                                        .read(themeControllerProvider.notifier)
                                        .setMode(
                                          isDark
                                              ? ThemeMode.dark
                                              : ThemeMode.light,
                                        );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      
                      // Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PlanStatusBanner(),
                              // Children Overview
                              _buildChildrenOverview(children),
                              const SizedBox(height: 24),
                              
                              // Quick Stats
                              _buildQuickStats(children),
                              const SizedBox(height: 24),
                              
                              // AI Insights
                              PlanGuard(
                                requiredTier: PlanTier.premium,
                                featureLabel: l10n.aiInsights,
                                child: _buildAiInsights(children),
                              ),
                              const SizedBox(height: 24),
                              
                              // Recent Activities
                              _buildRecentActivities(children),
                              const SizedBox(height: 24),
                              
                              // Weekly Progress Chart
                              _buildWeeklyProgressChart(children),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        
        // Floating Action Button
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            context.go('/parent/child-management');
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.add),
          label: Text(l10n.addChild),
        ),
      ),
    );
  }

  Widget _buildChildrenOverview(List<ChildProfile> children) {
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
        ...children.map((child) => _buildChildCard(context, child)),
      ],
    );
  }

  Widget _buildChildCard(BuildContext context, ChildProfile child) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final ageLabel = child.age > 0 ? l10n.yearsOld(child.age) : '—';
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
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarView(
                      avatarId: child.avatar,
                      avatarPath: child.avatarPath,
                      radius: 26,
                      backgroundColor: colors.primary.withValues(alpha: 0.15),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'L${child.level}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              child.name,
                              style: const TextStyle(
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
                                color: ParentColors.streakOrange
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 13,
                                    color: ParentColors.streakOrange,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${child.streak}d',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ParentColors.streakOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$ageLabel • ${child.activitiesCompleted} ${l10n.activities} • ${child.totalTimeSpent} ${l10n.minutesLabel}',
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
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),

            // XP bar
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.xpProgressDisplay(child.xp % 1000, 1000),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.xpGold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(List<ChildProfile> children) {
    if (children.isEmpty) return const SizedBox();
    final l10n = AppLocalizations.of(context)!;

    final totalTime = children.fold<int>(0, (s, c) => s + c.totalTimeSpent);
    final totalActivities = children.fold<int>(0, (s, c) => s + c.activitiesCompleted);
    final avgXp = (children.fold<int>(0, (s, c) => s + c.xp) ~/
        children.length.clamp(1, 9999));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParentSectionHeader(
          title: l10n.todayOverviewTitle,
          subtitle: l10n.aggregatedAcrossChildren,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ParentStatCard(
                value: '$totalTime',
                label: l10n.minutesLabel,
                icon: Icons.timer_outlined,
                color: ParentColors.infoBlue,
                trend: '+12%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ParentStatCard(
                value: '$totalActivities',
                label: l10n.activities,
                icon: Icons.check_circle_outline_rounded,
                color: ParentColors.parentGreen,
                trend: '+5',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ParentStatCard(
                value: '$avgXp',
                label: l10n.avgXpLabel,
                icon: Icons.star_outline_rounded,
                color: ParentColors.xpGold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiInsights(List<ChildProfile> children) {
    if (children.isEmpty) return const SizedBox();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return ParentCard(
      backgroundColor: colors.primary.withValues(alpha: 0.05),
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
                    colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiInsights,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      l10n.premiumAnalysis,
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const ParentStatusBadge(status: ParentBadgeStatus.premium),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _generateInsightMessage(children),
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

  String _generateInsightMessage(List<ChildProfile> children) {
    if (children.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;
    final names = children.map((c) => c.name).join(' و ');
    final totalActivities = children.fold<int>(0, (sum, child) => sum + child.activitiesCompleted);

    return l10n.insightsSummary(names, totalActivities, children.length);
  }

  Widget _buildRecentActivities(List<ChildProfile> children) {
    if (children.isEmpty) return const SizedBox();
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<ProgressRecord>>(
      future: _getRecentActivitiesForAllChildren(children),
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
                    Icon(Icons.inbox_outlined,
                        color: colors.onSurfaceVariant, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      l10n.noRecentActivities,
                      style: TextStyle(
                          fontSize: 14, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ParentCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(displayActivities.length, (i) {
                    final record = displayActivities[i];
                    final child = children.firstWhere(
                      (c) => c.id == record.childId,
                      orElse: () => children.first,
                    );
                    final isLast = i == displayActivities.length - 1;
                    return _buildActivityRow(
                      child.name,
                      _formatTimeAgo(record.createdAt),
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

  Future<List<ProgressRecord>> _getRecentActivitiesForAllChildren(List<ChildProfile> children) async {
    final progressRepository = ref.read(progressRepositoryProvider);
    final allRecords = <ProgressRecord>[];
    
    for (final child in children) {
      final records = await progressRepository.getProgressForChild(child.id);
      allRecords.addAll(records);
    }
    
    // Sort by date, most recent first
    allRecords.sort((a, b) => b.date.compareTo(a.date));
    
    return allRecords.take(10).toList();
  }

  String _formatTimeAgo(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return isArabic
          ? 'منذ ${difference.inDays} يوم'
          : '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return isArabic
          ? 'منذ ${difference.inHours} ساعة'
          : '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return isArabic
          ? 'منذ ${difference.inMinutes} دقيقة'
          : '${difference.inMinutes} ${l10n.minutesAgo}';
    }
    return l10n.justNow;
  }

  Widget _buildActivityRow(String childName, String time,
      {required bool isLast}) {
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
                decoration: const BoxDecoration(
                  color: ParentColors.parentGreen,
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
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  Widget _buildWeeklyProgressChart(List<ChildProfile> children) {
    if (children.isEmpty) return const SizedBox();

    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // Placeholder data — replace with real progress records in production
    const weekData = [3, 5, 2, 4, 6, 3, 2];
    final days = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.weeklyActivity,
            subtitle: l10n.activitiesCompletedPerDay,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(enabled: true),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days[i],
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
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: weekData.asMap().entries.map((e) {
                  final isToday = e.key == DateTime.now().weekday - 1;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: isToday
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.35),
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
  }
}
