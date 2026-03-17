// lib/core/widgets/gamification_widgets.dart
//
// Reusable UI components for the Gamification system.
// Includes: XPProgressBar, StreakCounter, LevelBadge, BadgeChip,
//           AchievementCard, LevelUpDialog, AchievementUnlockedBanner,
//           GamificationSummaryBar, BadgesRow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
// Import gamification models with alias to avoid conflict with Flutter's Badge
import 'package:kinder_world/core/models/achievement.dart' as gam
    show Badge, Achievement, LevelThresholds;
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/services/gamification_service.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// XP PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

/// Animated XP progress bar showing current level, XP, and progress to next level.
class XPProgressBar extends StatefulWidget {
  final int xp;
  final int level;
  final double progress; // 0.0–1.0
  final int xpToNext;
  final bool compact;

  const XPProgressBar({
    super.key,
    required this.xp,
    required this.level,
    required this.progress,
    required this.xpToNext,
    this.compact = false,
  });

  @override
  State<XPProgressBar> createState() => _XPProgressBarState();
}

class _XPProgressBarState extends State<XPProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(XPProgressBar old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _progressAnim = Tween<double>(
        begin: old.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final childTheme = context.childTheme;
    final isMaxLevel = widget.level >= gam.LevelThresholds.maxLevel;

    if (widget.compact) {
      return _buildCompact(context, colors, childTheme, isMaxLevel);
    }
    return _buildFull(context, theme, colors, childTheme, isMaxLevel);
  }

  Widget _buildCompact(
    BuildContext context,
    ColorScheme colors,
    ChildThemeTokens childTheme,
    bool isMaxLevel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        GamLevelCircle(level: widget.level, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: isMaxLevel ? 1.0 : _progressAnim.value,
                minHeight: 8,
                backgroundColor: childTheme.xp.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(childTheme.xp),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.gamificationXpReward(widget.xp).replaceFirst('+', ''),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: childTheme.xp,
          ),
        ),
      ],
    );
  }

  Widget _buildFull(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    ChildThemeTokens childTheme,
    bool isMaxLevel,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            childTheme.skill.withValues(alpha: 0.12),
            childTheme.xp.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: childTheme.xp.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GamLevelCircle(level: widget.level, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.gamificationLevelWithEmoji(
                            gam.LevelThresholds.emojiForLevel(widget.level),
                            widget.level,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: childTheme.skill,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: childTheme.skill.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            gam.LevelThresholds.titleForLevel(widget.level),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: childTheme.skill,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMaxLevel
                          ? l10n.gamificationMaxLevel
                          : l10n.gamificationXpToLevel(
                              widget.xpToNext,
                              widget.level + 1,
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.xp}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: childTheme.xp,
                    ),
                  ),
                  Text(
                    l10n.xp,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: childTheme.xp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: childTheme.xp.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: isMaxLevel ? 1.0 : _progressAnim.value,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [childTheme.xp, childTheme.streak],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: childTheme.xp.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL CIRCLE — public so it can be reused
// ─────────────────────────────────────────────────────────────────────────────

class GamLevelCircle extends StatelessWidget {
  final int level;
  final double size;

  const GamLevelCircle({super.key, required this.level, required this.size});

  @override
  Widget build(BuildContext context) {
    final childTheme = context.childTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [childTheme.skill, context.colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: childTheme.skill.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            color: childTheme.skill.onColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK COUNTER
// ─────────────────────────────────────────────────────────────────────────────

class StreakCounter extends StatefulWidget {
  final int streak;
  final bool compact;

  const StreakCounter({super.key, required this.streak, this.compact = false});

  @override
  State<StreakCounter> createState() => _StreakCounterState();
}

class _StreakCounterState extends State<StreakCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;
    final colors = Theme.of(context).colorScheme;
    final hasStreak = widget.streak > 0;
    final color = hasStreak ? childTheme.streak : colors.outline;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(
              scale: hasStreak ? _scaleAnim.value : 1.0,
              child: child,
            ),
            child: Text(
              hasStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.streak}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(
              scale: hasStreak ? _scaleAnim.value : 1.0,
              child: child,
            ),
            child: Text(
              hasStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.streak}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                hasStreak ? l10n.gamificationDayStreak : l10n.gamificationNoStreak,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE CHIP — small earned badge display
// ─────────────────────────────────────────────────────────────────────────────

class BadgeChip extends StatelessWidget {
  final gam.Badge badge;
  final bool showLabel;
  final double size;

  const BadgeChip({
    super.key,
    required this.badge,
    this.showLabel = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEarned = badge.isEarned;
    final color = isEarned ? badge.color : Theme.of(context).colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isEarned ? 0.15 : 0.06),
            border: Border.all(
              color: color.withValues(alpha: isEarned ? 0.5 : 0.2),
              width: 2,
            ),
            boxShadow: isEarned
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              isEarned ? badge.iconEmoji : '🔒',
              style: TextStyle(fontSize: size * 0.42),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: size + 8,
            child: Text(
              l10n.badgeName(badge.nameKey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isEarned ? color : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGES ROW — horizontal scrollable row of badges
// ─────────────────────────────────────────────────────────────────────────────

class BadgesRow extends ConsumerWidget {
  final bool showAll;
  final VoidCallback? onViewAll;

  const BadgesRow({super.key, this.showAll = false, this.onViewAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(allBadgesProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final displayBadges = showAll ? badges : badges.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.gamificationMyBadges,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!showAll && onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  l10n.viewAll,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: displayBadges.map((badge) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: BadgeChip(badge: badge, showLabel: true, size: 52),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class AchievementCard extends StatelessWidget {
  final gam.Achievement achievement;
  final bool compact;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;
    final childTheme = context.childTheme;
    final isUnlocked = achievement.isUnlocked;

    final bgColor = isUnlocked
        ? childTheme.xp.withValues(alpha: 0.08)
        : colors.surfaceContainerHighest.withValues(alpha: 0.5);

    final borderColor = isUnlocked
        ? childTheme.xp.withValues(alpha: 0.35)
        : colors.outlineVariant.withValues(alpha: 0.4);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Text(
              isUnlocked ? achievement.iconEmoji : '🔒',
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? null : colors.outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.achievementTitle(achievement.titleKey),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isUnlocked
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isUnlocked && achievement.unlockedAt != null)
                    Text(
                      _formatDate(achievement.unlockedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isUnlocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: childTheme.xp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.gamificationXpReward(achievement.xpReward),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: childTheme.xp,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Full card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: childTheme.xp.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUnlocked ? achievement.iconEmoji : '🔒',
                style: TextStyle(
                  fontSize: 32,
                  color: isUnlocked ? null : colors.outline,
                ),
              ),
              const Spacer(),
              if (isUnlocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: childTheme.xp.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.gamificationXpReward(achievement.xpReward),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: childTheme.xp,
                    ),
                  ),
                )
              else
                Icon(Icons.lock_outline_rounded,
                    size: 18, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.achievementTitle(achievement.titleKey),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isUnlocked ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.achievementDescription(achievement.descriptionKey),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (isUnlocked && achievement.unlockedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: context.successColor,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.gamificationUnlockedOn(_formatDate(achievement.unlockedAt!)),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAMIFICATION SUMMARY BAR — compact bar for child home/profile header
// ─────────────────────────────────────────────────────────────────────────────

class GamificationSummaryBar extends ConsumerWidget {
  const GamificationSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamState = ref.watch(currentGamificationStateProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final childTheme = context.childTheme;

    if (gamState == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GamStatPill(
            emoji: gam.LevelThresholds.emojiForLevel(gamState.level),
            value: l10n.gamificationCompactLevel(gamState.level),
            color: childTheme.skill,
          ),
          const SizedBox(width: 8),
          GamStatPill(
            emoji: '⭐',
            value:
                l10n.gamificationXpReward(gamState.totalXP).replaceFirst('+', ''),
            color: childTheme.xp,
          ),
          const SizedBox(width: 8),
          GamStatPill(
            emoji: gamState.streak > 0 ? '🔥' : '💤',
            value: l10n.gamificationCompactStreak(gamState.streak),
            color: gamState.streak > 0
                ? childTheme.streak
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          GamStatPill(
            emoji: '🎖️',
            value: '${gamState.earnedBadges.length}',
            color: childTheme.success,
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: gamState.levelProgress,
                minHeight: 6,
                backgroundColor: childTheme.xp.withValues(alpha: 0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(childTheme.xp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAM STAT PILL — top-level helper widget
// ─────────────────────────────────────────────────────────────────────────────

class GamStatPill extends StatelessWidget {
  final String emoji;
  final String value;
  final Color color;

  const GamStatPill({
    super.key,
    required this.emoji,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL UP DIALOG — shown when child levels up
// ─────────────────────────────────────────────────────────────────────────────

class LevelUpDialog extends StatefulWidget {
  final int newLevel;
  final int xpAwarded;
  final VoidCallback onDismiss;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.xpAwarded,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required int newLevel,
    required int xpAwarded,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
      builder: (_) => LevelUpDialog(
        newLevel: newLevel,
        xpAwarded: xpAwarded,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _starCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _starAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _starAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOut),
    );
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = gam.LevelThresholds.emojiForLevel(widget.newLevel);
    final title = gam.LevelThresholds.titleForLevel(widget.newLevel);
    final l10n = AppLocalizations.of(context)!;
    final childTheme = context.childTheme;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [childTheme.skill, colors.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: childTheme.skill.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars
              AnimatedBuilder(
                animation: _starAnim,
                builder: (_, __) => Transform.scale(
                  scale: _starAnim.value,
                  child: const Text('✨⭐✨', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.gamificationLevelUp,
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: childTheme.skill.onColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.gamificationLevelWithEmoji(emoji, widget.newLevel),
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: childTheme.xp,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: childTheme.skill.onColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: childTheme.skill.onColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.gamificationXpReward(widget.xpAwarded),
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: childTheme.xp,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDismiss();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: childTheme.skill,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.gamificationAwesome,
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
// ACHIEVEMENT UNLOCKED BANNER — shown at top of screen
// ─────────────────────────────────────────────────────────────────────────────

class AchievementUnlockedBanner extends StatefulWidget {
  final gam.Achievement achievement;
  final VoidCallback onDismiss;

  const AchievementUnlockedBanner({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  static OverlayEntry show(
    BuildContext context, {
    required gam.Achievement achievement,
    required VoidCallback onDismiss,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: AchievementUnlockedBanner(
          achievement: achievement,
          onDismiss: () {
            entry.remove();
            onDismiss();
          },
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    // Auto-dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (entry.mounted) {
        entry.remove();
        onDismiss();
      }
    });
    return entry;
  }

  @override
  State<AchievementUnlockedBanner> createState() =>
      _AchievementUnlockedBannerState();
}

class _AchievementUnlockedBannerState extends State<AchievementUnlockedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childTheme = context.childTheme;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final bannerTextColor = childTheme.xp.onColor;
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [childTheme.xp, childTheme.streak],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: childTheme.xp.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    widget.achievement.iconEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.gamificationAchievementUnlocked,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: bannerTextColor.withValues(alpha: 0.82),
                          ),
                        ),
                        Text(
                          l10n.achievementTitle(widget.achievement.titleKey),
                          style: textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: bannerTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bannerTextColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.gamificationXpReward(widget.achievement.xpReward),
                      style: textTheme.labelMedium?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: bannerTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// REWARD LISTENER — wraps a widget tree and shows reward dialogs automatically
// ─────────────────────────────────────────────────────────────────────────────

/// Wrap around child screens to automatically show level-up dialogs
/// and achievement banners when [pendingRewardProvider] has data.
class GamificationRewardListener extends ConsumerStatefulWidget {
  final Widget child;

  const GamificationRewardListener({super.key, required this.child});

  @override
  ConsumerState<GamificationRewardListener> createState() =>
      _GamificationRewardListenerState();
}

class _GamificationRewardListenerState
    extends ConsumerState<GamificationRewardListener> {
  bool _isShowingReward = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<ActivityResult?>(pendingRewardProvider, (prev, next) {
      if (next == null || _isShowingReward) return;
      _showRewards(next);
    });

    return widget.child;
  }

  Future<void> _showRewards(ActivityResult result) async {
    if (!mounted) return;
    _isShowingReward = true;

    // Show achievement banners first (staggered)
    for (final achievement in result.newlyUnlockedAchievements) {
      if (!mounted) break;
      AchievementUnlockedBanner.show(
        context,
        achievement: achievement,
        onDismiss: () {},
      );
      await Future.delayed(const Duration(milliseconds: 800));
    }

    // Then show level-up dialog if applicable
    if (result.leveledUp && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        await LevelUpDialog.show(
          context,
          newLevel: result.newLevel,
          xpAwarded: result.xpAwarded,
          onDismiss: () {},
        );
      }
    }

    _isShowingReward = false;
    // Dismiss the pending reward from state
    if (mounted) {
      ref.read(gamificationStateProvider.notifier).dismissPendingReward();
    }
  }
}
