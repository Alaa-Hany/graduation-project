import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_screen.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';

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
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              return _NavItemWidget(
                item: items[i],
                isSelected: currentIndex == i,
                onTap: () => onTap(i),
                colors: colors,
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

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
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
                horizontal: isSelected ? 14 : 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childProfile = ref.read(currentChildProvider);
      if (childProfile != null) {
        ref
            .read(progressControllerProvider.notifier)
            .loadTodayProgress(childProfile.id);
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
              final isDark = themeState.mode == ThemeMode.dark;
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

                // 3. Continue Learning
                _buildContinueLearning(),
                const SizedBox(height: 24),

                // 4. Daily Goal
                _buildDailyGoal(childProfile),
                const SizedBox(height: 24),

                // 5. My Activities History
                _buildMyActivitiesHistory(),
                const SizedBox(height: 24),

                // 6. Activity of the Day
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
    final colors = Theme.of(context).colorScheme;
    final firstName = child.name.split(' ').first;
    final greeting = childTimeGreeting();
    final currentXpInLevel = child.xp % 1000;

    return KinderCard(
      padding: const EdgeInsets.all(20),
      gradientColors: [
        colors.primary,
        colors.primary.withValues(alpha: 0.75),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _motivationalLine(child, l10n),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              ChildStreakBadge(streak: child.streak),
            ],
          ),

          const SizedBox(height: 18),

          // XP bar
          Row(
            children: [
              Text(
                l10n.levelBubble(child.level),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: child.xpProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      ChildColors.xpGold,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.xpDisplay(currentXpInLevel),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ChildColors.xpGold,
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
            color: ChildColors.xpGold,
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
            color: ChildColors.streakFire,
          ),
          ChildStatBubble(
            value: '${child.activitiesCompleted}',
            label: l10n.done,
            icon: Icons.check_circle_rounded,
            color: ChildColors.successGreen,
          ),
        ],
      ),
    );
  }

  // ── CONTINUE LEARNING ──────────────────────────────────────────────────────

  Widget _buildContinueLearning() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.continueLearning),
        const SizedBox(height: 12),
        KinderCard(
          onTap: () => context.go('/child/learn'),
          gradientColors: [
            ChildColors.learningBlue,
            ChildColors.learningBlue.withValues(alpha: 0.75),
          ],
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.exploreLessons,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.newTopicsAwait,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.goLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
    return FutureBuilder<List<ProgressRecord>>(
      future: ref
          .read(progressControllerProvider.notifier)
          .loadTodayProgress(child.id),
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
              title: isComplete
                  ? '${l10n.dailyGoal} ✅'
                  : l10n.dailyGoal,
            ),
            const SizedBox(height: 12),
            KinderCard(
              gradientColors: isComplete
                  ? [
                      ChildColors.successGreen,
                      ChildColors.successGreen.withValues(alpha: 0.75),
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
                          color: isComplete
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? Colors.white.withValues(alpha: 0.25)
                              : ChildColors.successGreen
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$done/$target',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isComplete
                                ? Colors.white
                                : ChildColors.successGreen,
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
                          ? Colors.white.withValues(alpha: 0.25)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete
                            ? Colors.white
                            : ChildColors.successGreen,
                      ),
                      minHeight: 10,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.xpBonusEarned,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ChildColors.xpGold,
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
        color: ChildColors.kindnessPink,
        icon: Icons.favorite_rounded,
        items: const [
          _HistoryItem(title: 'Sharing Stars', subtitle: 'Today · 8 min', xp: 30),
          _HistoryItem(title: 'Kind Words', subtitle: 'Yesterday · 6 min', xp: 20),
          _HistoryItem(title: 'Helping Hands', subtitle: '2 days ago · 10 min', xp: 40),
        ],
      ),
      _AxisHistory(
        index: 1,
        label: l10n.learningTab,
        emoji: '📚',
        color: ChildColors.learningBlue,
        icon: Icons.school_rounded,
        items: const [
          _HistoryItem(title: 'Numbers Adventure', subtitle: 'Today · 12 min', xp: 45),
          _HistoryItem(title: 'Color Quest', subtitle: 'Yesterday · 7 min', xp: 25),
          _HistoryItem(title: 'Story Time', subtitle: '2 days ago · 9 min', xp: 35),
        ],
      ),
      _AxisHistory(
        index: 2,
        label: l10n.skillsTab,
        emoji: '🧩',
        color: ChildColors.skillPurple,
        icon: Icons.extension_rounded,
        items: const [
          _HistoryItem(title: 'Puzzle Builder', subtitle: 'Today · 5 min', xp: 18),
          _HistoryItem(title: 'Shape Match', subtitle: 'Yesterday · 8 min', xp: 28),
          _HistoryItem(title: 'Memory Game', subtitle: '2 days ago · 11 min', xp: 38),
        ],
      ),
      _AxisHistory(
        index: 3,
        label: l10n.funTab,
        emoji: '🎵',
        color: ChildColors.funCyan,
        icon: Icons.music_note_rounded,
        items: const [
          _HistoryItem(title: 'Dance Party', subtitle: 'Today · 6 min', xp: 22),
          _HistoryItem(title: 'Sing Along', subtitle: 'Yesterday · 5 min', xp: 18),
          _HistoryItem(title: 'Magic Show', subtitle: '2 days ago · 9 min', xp: 32),
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

  Widget _buildHistoryCard(_HistoryItem item, _AxisHistory axis) {
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
              '+${item.xp} XP',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.activityOfTheDay),
        const SizedBox(height: 12),
        KinderCard(
          onTap: () => context.go('/child/home/activity-of-day'),
          gradientColors: const [
            Color(0xFFFF9800),
            Color(0xFFFF6B35),
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
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('💡', style: TextStyle(fontSize: 36)),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.discoverSomethingAmazing,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.xpBonusLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ChildColors.xpGold,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  l10n.start,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B35),
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
