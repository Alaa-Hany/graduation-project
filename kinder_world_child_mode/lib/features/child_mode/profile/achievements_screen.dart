import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/achievement.dart' as gam;
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/gamification_widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final child = ref.watch(currentChildProvider);
    final state = ref.watch(currentGamificationStateProvider);

    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.achievements)),
        body: Center(child: Text(l10n.noChildSelected)),
      );
    }

    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.achievements)),
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    final unlocked = state.unlockedAchievements;
    final locked = state.achievements.where((a) => !a.isUnlocked).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.achievements,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(gamificationStateProvider.notifier).refresh(child.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GamificationSummaryBar(),
                const SizedBox(height: 16),
                _StreakMilestoneCard(streak: state.streak),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: l10n.badges,
                  subtitle: l10n.achievementsCollectBadgesSubtitle,
                ),
                const SizedBox(height: 10),
                const BadgesRow(),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: l10n.achievementsUnlockedTitle,
                  subtitle: l10n.achievementsUnlockedSubtitle,
                ),
                const SizedBox(height: 10),
                if (unlocked.isEmpty)
                  _EmptyCard(
                    icon: Icons.emoji_events_outlined,
                    text: l10n.achievementsEmpty,
                  )
                else
                  ...unlocked.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AchievementCard(achievement: a),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: l10n.achievementsUpcomingTitle,
                  subtitle: l10n.achievementsUpcomingSubtitle,
                ),
                const SizedBox(height: 10),
                if (locked.isEmpty)
                  _EmptyCard(
                    icon: Icons.check_circle_outline_rounded,
                    text: l10n.achievementsAllUnlocked,
                  )
                else
                  ...locked.take(10).map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LockedAchievementCard(achievement: a),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedAchievementCard extends StatelessWidget {
  const _LockedAchievementCard({required this.achievement});

  final gam.Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;
    return Opacity(
      opacity: 0.72,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: childTheme.skill.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: childTheme.skill,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.achievementTitle(achievement.titleKey),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: childTheme.xp.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.gamificationXpReward(achievement.xpReward),
                style: TextStyle(
                  color: childTheme.xp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _StreakMilestoneCard extends StatelessWidget {
  const _StreakMilestoneCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final childTheme = context.childTheme;
    final nextMilestone = streak < 3
        ? 3
        : streak < 7
            ? 7
            : streak < 30
                ? 30
                : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: childTheme.streak.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: childTheme.streak.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const StreakCounter(streak: 0, compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.streak,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  nextMilestone == null
                      ? l10n.streakOnFire(streak)
                      : l10n.unlockWithStreak(nextMilestone),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$streak',
            style: theme.textTheme.titleMedium?.copyWith(
              color: childTheme.streak,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
