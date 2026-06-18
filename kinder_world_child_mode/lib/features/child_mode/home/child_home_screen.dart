import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/models/activity.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/progress_record.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/content_controller.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/core/widgets/app_connection_status.dart';
import 'package:kinder_world/core/widgets/app_skeleton_widgets.dart';
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
  bool _isSleepTime = false;

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
    _checkSleepMode();
  }

  Future<void> _checkSleepMode() async {
    try {
      final response = await ref
          .read(networkServiceProvider)
          .get<Map<String, dynamic>>('/parental-controls/settings');
      final data = response.data?['settings'];
      if (data is! Map) return;

      final sleepMode = data['sleep_mode'] == true;
      if (!sleepMode) return;

      final bedtime = _parseTime(data['bedtime']?.toString() ?? '8:00 PM');
      final wakeTime = _parseTime(data['wake_time']?.toString() ?? '7:00 AM');
      final now = TimeOfDay.now();

      if (_isInSleepWindow(now, bedtime, wakeTime)) {
        if (mounted) setState(() => _isSleepTime = true);
      }
    } catch (_) {
      // silently ignore — don't block child if check fails
    }
  }

  /// Returns true if [now] is between [bedtime] and [wakeTime],
  /// handling the midnight crossing case (e.g. 8 PM → 7 AM).
  bool _isInSleepWindow(TimeOfDay now, TimeOfDay bedtime, TimeOfDay wakeTime) {
    final nowMins = now.hour * 60 + now.minute;
    final bedMins = bedtime.hour * 60 + bedtime.minute;
    final wakeMins = wakeTime.hour * 60 + wakeTime.minute;

    if (bedMins > wakeMins) {
      // crosses midnight: sleep from 8 PM (1200) to 7 AM (420)
      return nowMins >= bedMins || nowMins < wakeMins;
    } else {
      return nowMins >= bedMins && nowMins < wakeMins;
    }
  }

  TimeOfDay _parseTime(String time) {
    // Parses formats like "8:00 PM" or "7:00 AM"
    final parts = time.trim().split(' ');
    final timeParts = parts[0].split(':');
    var hour = int.tryParse(timeParts[0]) ?? 8;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
    final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
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
    if (_isSleepTime) return const _SleepModeScreen();

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
            color: colors.shadow.withValuesCompat(alpha: 0.08),
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
                      ? colors.primary.withValuesCompat(alpha: 0.12)
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
// SLEEP MODE SCREEN — shown when parent's bedtime restriction is active
// ─────────────────────────────────────────────────────────────────────────────

class _SleepModeScreen extends StatelessWidget {
  const _SleepModeScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bedtime_rounded,
                    size: 80, color: Colors.white70),
                const SizedBox(height: 24),
                Text(
                  l10n.sleepMode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.sleepModeMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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

  // ── loading / error states ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(childSessionControllerProvider);
    final homeFeedAsync = ref.watch(currentChildHomeFeedProvider);
    final todayProgressAsync = ref.watch(currentChildTodayProgressProvider);
    final childProfile = sessionState.childProfile;

    if (sessionState.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const ChildHomeSkeleton(),
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
                const AppConnectionStatusBanner.child(),
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

                // 4. Continue Learning
                _buildContinueLearning(homeFeedAsync),
                const SizedBox(height: 24),

                // 5. Daily Goal
                _buildDailyGoal(todayProgressAsync),
                const SizedBox(height: 24),

                // 6. My Activities History
                _buildMyActivitiesHistory(homeFeedAsync),
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
                        color: colors.onPrimary.withValuesCompat(alpha: 0.85),
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
                        color: colors.onPrimary.withValuesCompat(alpha: 0.85),
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
                  color: colors.onPrimary.withValuesCompat(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: child.xpProgress.clamp(0.0, 1.0),
                    backgroundColor:
                        colors.onPrimary.withValuesCompat(alpha: 0.25),
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

  Widget _buildContinueLearning(AsyncValue<ChildHomeFeed?> homeFeedAsync) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final feed = homeFeedAsync.valueOrNull;
    final continueRecord = feed?.continueLearningRecord;
    final continueActivity = feed?.continueLearningActivity;
    final fallbackRecommendation = continueRecord == null &&
            feed != null &&
            feed.recommendedActivities.isNotEmpty
        ? feed.recommendedActivities.first
        : null;
    final displayActivity = continueActivity ?? fallbackRecommendation;
    final hasRecentActivity = continueRecord != null;
    if (displayActivity == null) {
      return const SizedBox.shrink();
    }

    final sectionTitle =
        hasRecentActivity ? l10n.continueLearning : l10n.recommendedForYou;
    final title = hasRecentActivity
        ? _displayActivityTitle(
            activity: continueActivity,
            record: continueRecord,
          )
        : displayActivity.title;
    final subtitle = hasRecentActivity
        ? _recordSubtitle(continueRecord, l10n)
        : '${l10n.minutesShort(displayActivity.duration)} | ${l10n.activityXp(displayActivity.xpReward)}';
    final icon = _iconForActivity(
      activity: displayActivity,
      record: continueRecord,
    );
    final route = _destinationForActivity(
      activity: displayActivity,
      record: continueRecord,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: sectionTitle),
        const SizedBox(height: 12),
        KinderCard(
          onTap: () => context.go(route),
          gradientColors: _gradientForActivity(
            activity: displayActivity,
            record: continueRecord,
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValuesCompat(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
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
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: colors.onPrimary.withValuesCompat(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValuesCompat(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasRecentActivity ? l10n.goLabel : l10n.start,
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

  Widget _buildDailyGoal(AsyncValue<List<ProgressRecord>> todayProgressAsync) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;
    final l10n = AppLocalizations.of(context)!;
    final done = todayProgressAsync.valueOrNull?.length ?? 0;
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
                      color: isComplete ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isComplete
                          ? colors.onPrimary.withValuesCompat(alpha: 0.25)
                          : childTheme.success.withValuesCompat(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$done/$target',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color:
                            isComplete ? colors.onPrimary : childTheme.success,
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
                      ? colors.onPrimary.withValuesCompat(alpha: 0.25)
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
  }

  // ── ACTIVITIES HISTORY ─────────────────────────────────────────────────────

  Widget _buildMyActivitiesHistory(AsyncValue<ChildHomeFeed?> homeFeedAsync) {
    final l10n = AppLocalizations.of(context)!;
    final feed = homeFeedAsync.valueOrNull;
    final axes =
        feed == null ? const <_AxisHistory>[] : _buildHistoryAxes(feed);
    final hasHistory = axes.isNotEmpty;
    if (!hasHistory) {
      return const SizedBox.shrink();
    }

    final selectedAxisIndex =
        hasHistory ? _selectedAxisIndex.clamp(0, axes.length - 1) : 0;
    final selectedAxis = hasHistory ? axes[selectedAxisIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.myActivities),
        const SizedBox(height: 12),
        ...[
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
                  isSelected: i == selectedAxisIndex,
                  onTap: () => setState(() => _selectedAxisIndex = i),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: List.generate(selectedAxis!.items.length, (i) {
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
      ],
    );
  }

  String _recordSubtitle(ProgressRecord record, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay =
        DateTime(record.date.year, record.date.month, record.date.day);
    final dayOffset = today.difference(recordDay).inDays;
    final dayLabel = switch (dayOffset) {
      0 => l10n.todayLabel,
      1 => l10n.yesterdayLabel,
      _ => l10n.daysAgoCount(dayOffset),
    };
    return '$dayLabel | ${l10n.minutesShort(record.duration)} | ${l10n.activityXp(record.xpEarned)}';
  }

  List<_AxisHistory> _buildHistoryAxes(ChildHomeFeed feed) {
    final grouped = <String, List<_HistoryItem>>{};
    final order = <String>[];

    for (final record in feed.recentRecords) {
      final activity = feed.resolvedActivities[record.id];
      final axis = _axisForRecord(activity: activity, record: record);
      if (!grouped.containsKey(axis.key)) {
        grouped[axis.key] = <_HistoryItem>[];
        order.add(axis.key);
      }
      grouped[axis.key]!.add(
        _HistoryItem(
          title: _displayActivityTitle(activity: activity, record: record),
          subtitle: _recordSubtitle(
            record,
            AppLocalizations.of(context)!,
          ),
          xp: record.xpEarned,
        ),
      );
    }

    return [
      for (var i = 0; i < order.length; i++)
        _axisForKey(
          key: order[i],
          index: i,
          items: grouped[order[i]] ?? const [],
        ),
    ];
  }

  _AxisHistory _axisForRecord({
    Activity? activity,
    ProgressRecord? record,
  }) {
    final type = activity?.type ?? _inferredActivityType(record?.activityId);
    final aspect = activity?.aspect;

    if (aspect == ActivityAspects.behavioral) {
      return _axisForKey(
        key: 'behavioral',
        index: 0,
        items: const [],
      );
    }
    if (aspect == ActivityAspects.skillful ||
        type == ActivityTypes.challenge ||
        type == ActivityTypes.craft ||
        type == ActivityTypes.simulation) {
      return _axisForKey(
        key: 'skillful',
        index: 0,
        items: const [],
      );
    }
    if (type == ActivityTypes.game || type == ActivityTypes.song) {
      return _axisForKey(
        key: 'fun',
        index: 0,
        items: const [],
      );
    }
    return _axisForKey(
      key: 'learning',
      index: 0,
      items: const [],
    );
  }

  _AxisHistory _axisForKey({
    required String key,
    required int index,
    required List<_HistoryItem> items,
  }) {
    final theme = context.childTheme;
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'behavioral':
        return _AxisHistory(
          key: key,
          index: index,
          label: l10n.kindnessTab,
          emoji: '\u{1F496}',
          color: theme.kindness,
          icon: Icons.favorite_rounded,
          items: items,
        );
      case 'skillful':
        return _AxisHistory(
          key: key,
          index: index,
          label: l10n.skillsTab,
          emoji: '\u{1F9E9}',
          color: theme.skill,
          icon: Icons.extension_rounded,
          items: items,
        );
      case 'fun':
        return _AxisHistory(
          key: key,
          index: index,
          label: l10n.funTab,
          emoji: '\u{1F3B5}',
          color: theme.fun,
          icon: Icons.music_note_rounded,
          items: items,
        );
      case 'learning':
      default:
        return _AxisHistory(
          key: key,
          index: index,
          label: l10n.learningTab,
          emoji: '\u{1F4DA}',
          color: theme.learning,
          icon: Icons.school_rounded,
          items: items,
        );
    }
  }

  String _displayActivityTitle({
    Activity? activity,
    ProgressRecord? record,
  }) {
    if (activity != null) return activity.title;
    final note = record?.notes?.trim();
    if (note != null && note.isNotEmpty) return note;
    final raw = record?.activityId ?? '';
    return raw
        .replaceAll(RegExp(r'^(lesson_|game_|story_|video_|music_|quiz_)'), '')
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  String _destinationForActivity({
    Activity? activity,
    ProgressRecord? record,
  }) {
    final type = activity?.type ?? _inferredActivityType(record?.activityId);
    switch (type) {
      case ActivityTypes.game:
      case ActivityTypes.song:
      case ActivityTypes.challenge:
      case ActivityTypes.simulation:
        return '/child/play';
      default:
        return '/child/learn';
    }
  }

  IconData _iconForActivity({
    Activity? activity,
    ProgressRecord? record,
  }) {
    final type = activity?.type ?? _inferredActivityType(record?.activityId);
    switch (type) {
      case ActivityTypes.game:
        return Icons.sports_esports_rounded;
      case ActivityTypes.song:
        return Icons.music_note_rounded;
      case ActivityTypes.video:
        return Icons.play_circle_rounded;
      case ActivityTypes.story:
      case ActivityTypes.interactiveStory:
        return Icons.auto_stories_rounded;
      case ActivityTypes.quiz:
        return Icons.quiz_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  List<Color> _gradientForActivity({
    Activity? activity,
    ProgressRecord? record,
  }) {
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;
    final type = activity?.type ?? _inferredActivityType(record?.activityId);
    switch (type) {
      case ActivityTypes.game:
      case ActivityTypes.song:
        return [
          childTheme.fun,
          Color.lerp(childTheme.fun, colors.secondary, 0.35)!,
        ];
      case ActivityTypes.challenge:
      case ActivityTypes.simulation:
        return [
          childTheme.skill,
          Color.lerp(childTheme.skill, colors.secondary, 0.35)!,
        ];
      default:
        return [
          colors.primary,
          colors.secondary,
        ];
    }
  }

  String _inferredActivityType(String? activityId) {
    if (activityId == null || activityId.isEmpty) return ActivityTypes.lesson;
    if (activityId.startsWith('game_')) return ActivityTypes.game;
    if (activityId.startsWith('story_')) return ActivityTypes.story;
    if (activityId.startsWith('video_')) return ActivityTypes.video;
    if (activityId.startsWith('music_')) return ActivityTypes.song;
    if (activityId.startsWith('quiz_')) return ActivityTypes.quiz;
    if (activityId == 'activity_of_the_day') return ActivityTypes.challenge;
    return ActivityTypes.lesson;
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
              color: axis.color.withValuesCompat(alpha: 0.14),
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
              color: axis.color.withValuesCompat(alpha: 0.14),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS (local)
// ─────────────────────────────────────────────────────────────────────────────

class _AxisHistory {
  final String key;
  final int index;
  final String label;
  final String emoji;
  final Color color;
  final IconData icon;
  final List<_HistoryItem> items;

  const _AxisHistory({
    required this.key,
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
