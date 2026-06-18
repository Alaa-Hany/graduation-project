part of '../child_profile_screen.dart';

class _ChildProfileEmptyState extends StatelessWidget {
  const _ChildProfileEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.child_care_outlined,
                  size: 80,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noChildSelected,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: AppConstants.fontSize,
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/child/login'),
                  child: Text(l10n.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildProfileHeroSection extends StatelessWidget {
  const _ChildProfileHeroSection({
    required this.child,
    required this.childName,
    required this.onCustomizeAvatar,
  });

  final dynamic child;
  final String childName;
  final VoidCallback onCustomizeAvatar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final childTheme = context.childTheme;

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      colors.primary.withValuesCompat(alpha: 0.5),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    onTap: onCustomizeAvatar,
                    borderRadius: BorderRadius.circular(60),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                      ),
                      child: ChildCustomizableAvatar(
                        child: child,
                        radius: 56,
                        backgroundColor:
                            colors.primary.withValuesCompat(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        childTheme.buddyStart,
                        childTheme.buddyEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            childTheme.buddyStart.withValuesCompat(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.levelLabel(child.level),
                    style: textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          childName,
          style: textTheme.headlineSmall?.copyWith(
            fontSize: AppConstants.largeFontSize * 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.levelExplorer(child.level),
          style: textTheme.bodyMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCustomizeAvatar,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(l10n.customizeProfile),
          ),
        ),
      ],
    );
  }
}

class _ChildProfileStatsSection extends StatelessWidget {
  const _ChildProfileStatsSection({
    required this.child,
  });

  final dynamic child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChildStatBubble(
          value: '${child.xp % 1000}',
          label: l10n.xp,
          icon: Icons.star_rounded,
          color: childTheme.xp,
        ),
        ChildStatBubble(
          value: '${child.streak}',
          label: l10n.streak,
          icon: Icons.local_fire_department_rounded,
          color: childTheme.streak,
        ),
        ChildStatBubble(
          value: '${child.activitiesCompleted}',
          label: l10n.activities,
          icon: Icons.check_circle_rounded,
          color: childTheme.success,
        ),
      ],
    );
  }
}

class _ChildProfileProgressSection extends ConsumerWidget {
  const _ChildProfileProgressSection({
    required this.child,
  });

  final dynamic child;

  static const int _dailyTarget = 3;
  static const int _weeklyTarget = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;

    final childId = ref.watch(currentChildIdProvider) ?? '';
    final todayAsync = ref.watch(currentChildTodayProgressProvider);
    final weeklyAsync = ref.watch(weeklySummaryProvider(childId));

    final todayDone = todayAsync.valueOrNull?.length ?? 0;
    final weeklyDone =
        (weeklyAsync.valueOrNull?['totalActivities'] as int?) ?? 0;

    final dailyProgress = (todayDone / _dailyTarget).clamp(0.0, 1.0);
    final weeklyProgress = (weeklyDone / _weeklyTarget).clamp(0.0, 1.0);

    return KinderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChildSectionHeader(title: l10n.yourProgress),
          const SizedBox(height: 20),
          ChildXpProgressBar(
            progress: child.xpProgress.clamp(0.0, 1.0),
            currentXp: child.xp % 1000,
            nextLevelXp: 1000,
          ),
          const SizedBox(height: 16),
          _ChildProfileProgressMetric(
            label: l10n.dailyGoal,
            value: dailyProgress,
            color: childTheme.success,
            valueText: '$todayDone/$_dailyTarget ${l10n.activities}',
          ),
          const SizedBox(height: 16),
          _ChildProfileProgressMetric(
            label: l10n.weeklyChallenge,
            value: weeklyProgress,
            color: colors.secondary,
            valueText: '$weeklyDone/$_weeklyTarget',
          ),
        ],
      ),
    );
  }
}

class _ChildProfileProgressMetric extends StatelessWidget {
  const _ChildProfileProgressMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.valueText,
  });

  final String label;
  final double value;
  final Color color;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valueText,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _ChildProfileInterestsSection extends StatelessWidget {
  const _ChildProfileInterestsSection({
    required this.interests,
  });

  final List<String> interests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ChildProfileSectionCard(
      title: l10n.yourInterests,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: interests
            .map((interest) => _ChildProfileInterestChip(label: interest))
            .toList(),
      ),
    );
  }
}

class _ChildProfileInterestChip extends StatelessWidget {
  const _ChildProfileInterestChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValuesCompat(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChildProfileAchievementsSection extends StatelessWidget {
  const _ChildProfileAchievementsSection({
    required this.achievements,
  });

  final List<_ProfileAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ChildProfileSectionCard(
      title: l10n.recentAchievements,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: achievements
            .map((achievement) => _ChildProfileAchievementBadge(
                  achievement: achievement,
                ))
            .toList(),
      ),
    );
  }
}

class _ChildProfileAchievementBadge extends StatelessWidget {
  const _ChildProfileAchievementBadge({
    required this.achievement,
  });

  final _ProfileAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final childTheme = context.childTheme;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: childTheme.xp.withValuesCompat(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              achievement.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          achievement.title,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          achievement.description,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChildProfileLevelsSection extends StatelessWidget {
  const _ChildProfileLevelsSection({
    required this.currentLevel,
    required this.coins,
  });

  final int currentLevel;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return _ChildProfileSectionCard(
      title: l10n.levels,
      titleSpacing: 6,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.levelJourneySubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildLevelsScreen(
                    currentLevel: currentLevel,
                    coins: coins,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              elevation: 3,
            ),
            child: Text(
              l10n.levels,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildProfileEquippedItemsSection extends ConsumerWidget {
  const _ChildProfileEquippedItemsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeState = ref.watch(rewardStoreProvider);
    final equipped = rewardCatalog
        .where((item) => storeState.equippedByType[item.type] == item.id)
        .toList();
    if (equipped.isEmpty) return const SizedBox.shrink();

    final xpColor = context.childTheme.xp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: xpColor.withValuesCompat(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: xpColor.withValuesCompat(alpha: 0.40),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u2728 My Equipped Items',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: equipped
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: item.color.withValuesCompat(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: item.color, width: 1.5),
                      ),
                      child: Text(
                        '${item.emoji} ${item.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: item.color,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildProfileActionButton extends StatelessWidget {
  const _ChildProfileActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ChildProfileSectionCard extends StatelessWidget {
  const _ChildProfileSectionCard({
    required this.title,
    required this.child,
    this.titleSpacing = 16,
  });

  final String title;
  final Widget child;
  final double titleSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValuesCompat(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontSize: AppConstants.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: titleSpacing),
          child,
        ],
      ),
    );
  }
}

class _ProfileAchievement {
  const _ProfileAchievement({
    required this.emoji,
    required this.title,
    required this.description,
  });

  final String emoji;
  final String title;
  final String description;
}
