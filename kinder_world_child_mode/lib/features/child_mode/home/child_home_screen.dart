import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_screen.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/child_mode/mood/mood_picker_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NAVIGATION SHELL — wraps all child tabs with the premium bottom nav bar
// ─────────────────────────────────────────────────────────────────────────────

class ChildHomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ChildHomeScreen({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: widget.navigationShell,
        bottomNavigationBar: _ChildBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTap,
          colors: colors,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION
// ─────────────────────────────────────────────────────────────────────────────

class _ChildBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ColorScheme colors;

  const _ChildBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final items = [
      _NavItem(icon: Icons.home_rounded, label: l10n.home),
      _NavItem(icon: Icons.auto_stories_rounded, label: l10n.learn),
      _NavItem(icon: Icons.sports_esports_rounded, label: l10n.play),
      _NavItem(icon: Icons.smart_toy_rounded, label: l10n.aiBuddy),
      _NavItem(icon: Icons.face_rounded, label: l10n.profile),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: isCompact ? 72 : 76,
          child: Row(
            children: List.generate(items.length, (i) {
              return _NavItemWidget(
                item: items[i],
                isSelected: currentIndex == i,
                onTap: () => onTap(i),
                colors: colors,
                isCompact: isCompact,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavItemWidget extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;
  final bool isCompact;

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.colors,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isSelected ? (isCompact ? 10 : 14) : (isCompact ? 6 : 8),
                  vertical: isCompact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: isCompact ? 20 : 22, color: color),
              ),
              SizedBox(height: isCompact ? 2 : 3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: isCompact ? 8.5 : 10,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME CONTENT — the actual home tab page
// ─────────────────────────────────────────────────────────────────────────────

class ChildHomeContent extends ConsumerStatefulWidget {
  const ChildHomeContent({super.key});

  @override
  ConsumerState<ChildHomeContent> createState() => _ChildHomeContentState();
}

class _ChildHomeContentState extends ConsumerState<ChildHomeContent> {
  int _selectedAxisIndex = 0;

  /// Cached Future so [_buildDailyGoal]'s FutureBuilder does not create a new
  /// network call on every rebuild.
  Future<List<ProgressRecord>>? _dailyGoalFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childProfile = ref.read(currentChildProvider);
      if (childProfile != null) {
        setState(() {
          _dailyGoalFuture = ref
              .read(progressControllerProvider.notifier)
              .loadTodayProgress(childProfile.id);
        });
      }
    });
  }

  // ── loading / error states ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(childSessionControllerProvider);
    final childProfile = sessionState.childProfile;

    if (sessionState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (sessionState.error != null || childProfile == null) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ChildEmptyState(
              emoji: '🔒',
              title: sessionState.error ?? l10n.noActiveChildSession,
              subtitle: l10n.signInToContinue,
              action: ElevatedButton(
                onPressed: () => context.go('/child/login'),
                child: Text(l10n.goToLogin),
              ),
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Compact header bar ──────────────────────────────────────────
        SliverAppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          floating: true,
          title: const ChildHeader(compact: true, padding: EdgeInsets.zero),
          actions: [
            Consumer(builder: (context, ref, _) {
              final themeState = ref.watch(themeControllerProvider);
              final isDark = themeState.mode.resolvesToDark(
                Theme.of(context).brightness,
              );
              return IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () {
                  ref.read(themeControllerProvider.notifier).setMode(
                        isDark ? ThemeMode.light : ThemeMode.dark,
                      );
                },
              );
            }),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(
                Icons.palette_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChildThemeScreen()),
                );
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ChildSettingsScreen()),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),

        // ── Main scrollable content ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 1. Hero greeting + XP
                _buildHeroSection(childProfile),
                const SizedBox(height: 24),

                // 2. Stats row
                _buildStatsRow(childProfile),
                const SizedBox(height: 24),

                // 3. Mood Picker
                const MoodPickerSection(),
                const SizedBox(height: 16),

                // 4. Mood Recommendations (shown only after mood is picked)
                const MoodRecommendationsSection(),

                // 5. Continue Learning
                _buildContinueLearning(),
                const SizedBox(height: 24),

                // 6. Daily Goal
                _buildDailyGoal(childProfile),
                const SizedBox(height: 24),

                // 7. My Activities History
                _buildMyActivitiesHistory(),
                const SizedBox(height: 24),

                // 8. Activity of the Day
                _buildActivityOfTheDay(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── HERO SECTION ───────────────────────────────────────────────────────────

  Widget _buildHeroSection(ChildProfile child) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;
    final firstName = child.name.split(' ').first;
    final greeting = childTimeGreeting();
    final currentXpInLevel = child.xp % 1000;

    return KinderCard(
      padding: const EdgeInsets.all(24),
      gradientColors: [
        colors.primary,
        Color.lerp(colors.primary, colors.secondary, 0.35)!,
      ],
      gradientBegin: Alignment.topLeft,
      gradientEnd: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row + streak badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        color: colors.onPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstName,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.onPrimary,
                        letterSpacing: -0.6,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _motivationalLine(child, l10n),
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: colors.onPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ChildStreakBadge(streak: child.streak),
            ],
          ),

          const SizedBox(height: 24),

          // XP bar
          Row(
            children: [
              Text(
                l10n.levelBubble(child.level),
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: child.xpProgress.clamp(0.0, 1.0),
                    backgroundColor: colors.onPrimary.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      childTheme.xp,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.xpDisplay(currentXpInLevel),
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: childTheme.xp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _motivationalLine(ChildProfile child, AppLocalizations l10n) {
    if (child.streak >= 7) return l10n.streakOnFire(child.streak);
    if (child.streak >= 3) return l10n.streakDaysStrong(child.streak);
    if (child.activitiesCompleted >= 10) {
      return l10n.activitiesCompletedAmazing(child.activitiesCompleted);
    }
    return l10n.readyForAdventure;
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(ChildProfile child) {
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;
    final currentXpInLevel = child.xp % 1000;
    return KinderCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ChildStatBubble(
            value: l10n.levelBubble(child.level),
            label: l10n.level,
            icon: Icons.star_rounded,
            color: childTheme.xp,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildLevelsScreen(
                  currentLevel: child.level,
                  coins: currentXpInLevel,
                ),
              ),
            ),
          ),
          ChildStatBubble(
            value: '${child.streak}',
            label: l10n.streak,
            icon: Icons.local_fire_department_rounded,
            color: childTheme.streak,
          ),
          ChildStatBubble(
            value: '${child.activitiesCompleted}',
            label: l10n.done,
            icon: Icons.check_circle_rounded,
            color: childTheme.success,
          ),
        ],
      ),
    );
  }

  // ── CONTINUE LEARNING ──────────────────────────────────────────────────────

  Widget _buildContinueLearning() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.continueLearning),
        const SizedBox(height: 12),
        KinderCard(
          onTap: () => context.go('/child/learn'),
          gradientColors: [
            colors.primary,
            colors.secondary,
          ],
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 30,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.exploreLessons,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.newTopicsAwait,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: colors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.goLabel,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── DAILY GOAL ─────────────────────────────────────────────────────────────

  Widget _buildDailyGoal(ChildProfile child) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;
    return FutureBuilder<List<ProgressRecord>>(
      // Use the cached future — never recreated on rebuild.
      future: _dailyGoalFuture,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        final done = snapshot.hasData ? snapshot.data!.length : 0;
        const target = 3;
        final progress = (done / target).clamp(0.0, 1.0);
        final isComplete = done >= target;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChildSectionHeader(
              title: isComplete ? '${l10n.dailyGoal} ✅' : l10n.dailyGoal,
            ),
            const SizedBox(height: 12),
            KinderCard(
              gradientColors: isComplete
                  ? [
                      childTheme.success,
                      colors.primary,
                    ]
                  : null,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isComplete
                            ? l10n.goalComplete
                            : l10n.completeActivitiesToday(target),
                        style: TextStyle(
                          fontSize: AppConstants.fontSize,
                          fontWeight: FontWeight.w700,
                          color:
                              isComplete ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? colors.onPrimary.withValues(alpha: 0.25)
                              : childTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$done/$target',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isComplete
                                ? colors.onPrimary
                                : childTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isComplete
                          ? colors.onPrimary.withValues(alpha: 0.25)
                          : colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? colors.onPrimary : childTheme.success,
                      ),
                      minHeight: 10,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.xpBonusEarned,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: childTheme.xp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── ACTIVITIES HISTORY ─────────────────────────────────────────────────────

  Widget _buildMyActivitiesHistory() {
    final l10n = AppLocalizations.of(context)!;
    final axes = [
      _AxisHistory(
        index: 0,
        label: l10n.kindnessTab,
        emoji: '💖',
        color: context.childTheme.kindness,
        icon: Icons.favorite_rounded,
        items: [
          _HistoryItem(
            title: l10n.historySharingStars,
            subtitle: _historySubtitle(l10n, dayOffset: 0, minutes: 8),
            xp: 30,
          ),
          _HistoryItem(
            title: l10n.historyKindWords,
            subtitle: _historySubtitle(l10n, dayOffset: 1, minutes: 6),
            xp: 20,
          ),
          _HistoryItem(
            title: l10n.historyHelpingHands,
            subtitle: _historySubtitle(l10n, dayOffset: 2, minutes: 10),
            xp: 40,
          ),
        ],
      ),
      _AxisHistory(
        index: 1,
        label: l10n.learningTab,
        emoji: '📚',
        color: context.childTheme.learning,
        icon: Icons.school_rounded,
        items: [
          _HistoryItem(
            title: l10n.historyNumbersAdventure,
            subtitle: _historySubtitle(l10n, dayOffset: 0, minutes: 12),
            xp: 45,
          ),
          _HistoryItem(
            title: l10n.historyColorQuest,
            subtitle: _historySubtitle(l10n, dayOffset: 1, minutes: 7),
            xp: 25,
          ),
          _HistoryItem(
            title: l10n.historyStoryTime,
            subtitle: _historySubtitle(l10n, dayOffset: 2, minutes: 9),
            xp: 35,
          ),
        ],
      ),
      _AxisHistory(
        index: 2,
        label: l10n.skillsTab,
        emoji: '🧩',
        color: context.childTheme.skill,
        icon: Icons.extension_rounded,
        items: [
          _HistoryItem(
            title: l10n.historyPuzzleBuilder,
            subtitle: _historySubtitle(l10n, dayOffset: 0, minutes: 5),
            xp: 18,
          ),
          _HistoryItem(
            title: l10n.historyShapeMatch,
            subtitle: _historySubtitle(l10n, dayOffset: 1, minutes: 8),
            xp: 28,
          ),
          _HistoryItem(
            title: l10n.historyMemoryGame,
            subtitle: _historySubtitle(l10n, dayOffset: 2, minutes: 11),
            xp: 38,
          ),
        ],
      ),
      _AxisHistory(
        index: 3,
        label: l10n.funTab,
        emoji: '🎵',
        color: context.childTheme.fun,
        icon: Icons.music_note_rounded,
        items: [
          _HistoryItem(
            title: l10n.historyDanceParty,
            subtitle: _historySubtitle(l10n, dayOffset: 0, minutes: 6),
            xp: 22,
          ),
          _HistoryItem(
            title: l10n.historySingAlong,
            subtitle: _historySubtitle(l10n, dayOffset: 1, minutes: 5),
            xp: 18,
          ),
          _HistoryItem(
            title: l10n.historyMagicShow,
            subtitle: _historySubtitle(l10n, dayOffset: 2, minutes: 9),
            xp: 32,
          ),
        ],
      ),
    ];

    final selectedAxis = axes[_selectedAxisIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.myActivities),
        const SizedBox(height: 12),

        // Category chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: axes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final axis = axes[i];
              return ChildCategoryChip(
                label: axis.label,
                emoji: axis.emoji,
                color: axis.color,
                isSelected: i == _selectedAxisIndex,
                onTap: () => setState(() => _selectedAxisIndex = i),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // History cards
        Column(
          children: List.generate(selectedAxis.items.length, (i) {
            final item = selectedAxis.items[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == selectedAxis.items.length - 1 ? 0 : 10,
              ),
              child: _buildHistoryCard(item, selectedAxis),
            );
          }),
        ),
      ],
    );
  }

  String _historySubtitle(
    AppLocalizations l10n, {
    required int dayOffset,
    required int minutes,
  }) {
    final dayLabel = switch (dayOffset) {
      0 => l10n.todayLabel,
      1 => l10n.yesterdayLabel,
      _ => l10n.daysAgoCount(dayOffset),
    };
    return '$dayLabel | ${l10n.minutesShort(minutes)}';
  }

  Widget _buildHistoryCard(_HistoryItem item, _AxisHistory axis) {
    final l10n = AppLocalizations.of(context)!;
    return KinderCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: axis.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(axis.icon, color: axis.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: AppConstants.fontSize,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: axis.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.activityXp(item.xp),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: axis.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIVITY OF THE DAY ────────────────────────────────────────────────────

  Widget _buildActivityOfTheDay() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.activityOfTheDay),
        const SizedBox(height: 12),
        KinderCard(
          onTap: () => context.go('/child/home/activity-of-day'),
          gradientColors: [
            Color.lerp(colors.secondary, childTheme.streakLight, 0.35)!,
            childTheme.streak,
          ],
          gradientBegin: Alignment.topLeft,
          gradientEnd: Alignment.bottomRight,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Large emoji illustration
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Icon(
                    Icons.lightbulb_rounded,
                    size: 36,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.exploreNewActivities,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.discoverSomethingAmazing,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.xpBonusLabel,
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: childTheme.xp,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Start button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  l10n.start,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: childTheme.streak,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS (local)
// ─────────────────────────────────────────────────────────────────────────────

class _AxisHistory {
  final int index;
  final String label;
  final String emoji;
  final Color color;
  final IconData icon;
  final List<_HistoryItem> items;

  const _AxisHistory({
    required this.index,
    required this.label,
    required this.emoji,
    required this.color,
    required this.icon,
    required this.items,
  });
}

class _HistoryItem {
  final String title;
  final String subtitle;
  final int xp;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    required this.xp,
  });
}
