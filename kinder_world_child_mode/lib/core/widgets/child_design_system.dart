// lib/core/widgets/child_design_system.dart
//
// Shared premium child-focused design system widgets.
// Used across Home, Learn, Play, AI Buddy, and Profile screens.

import 'package:flutter/material.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a localized, time-aware greeting prefix with emoji.
String childTimeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning,';
  if (hour < 17) return 'Good Afternoon,';
  return 'Good Evening,';
}

/// Child-specific accent colors that complement the themed palette.
class ChildColors {
  ChildColors._();

  static const Color xpGold = Color(0xFFFFD700);
  static const Color streakFire = Color(0xFFFF6B35);
  static const Color streakFireLight = Color(0xFFFF9800);
  static const Color levelPurple = Color(0xFF7C4DFF);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color kindnessPink = Color(0xFFE91E63);
  static const Color learningBlue = Color(0xFF3F51B5);
  static const Color skillPurple = Color(0xFF9C27B0);
  static const Color funCyan = Color(0xFF00BCD4);

  // Buddy character gradient
  static const Color buddyStart = Color(0xFF7B61FF);
  static const Color buddyEnd = Color(0xFF4A90E2);
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

/// Consistent, weighted section title with optional "See all" pill action.
class ChildSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ChildSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: colors.onSurface,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

/// Smooth animated XP progress bar with gold fill and level labels.
class ChildXpProgressBar extends StatefulWidget {
  /// 0.0 – 1.0 fraction of current level progress.
  final double progress;

  /// XP earned within the current level (display value).
  final int currentXp;

  /// XP needed to complete the current level (usually 1000).
  final int nextLevelXp;

  const ChildXpProgressBar({
    super.key,
    required this.progress,
    required this.currentXp,
    required this.nextLevelXp,
  });

  @override
  State<ChildXpProgressBar> createState() => _ChildXpProgressBarState();
}

class _ChildXpProgressBarState extends State<ChildXpProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim =
        Tween<double>(begin: 0, end: widget.progress.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '⭐ ${widget.currentXp} XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: childTheme.xp,
              ),
            ),
            Text(
              '${widget.nextLevelXp} XP to next level',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _anim.value,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                childTheme.xp,
              ),
              minHeight: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

/// Rounded square stat display used in the home progress overview.
class ChildStatBubble extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ChildStatBubble({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.24),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK BADGE
// ─────────────────────────────────────────────────────────────────────────────

/// Fire streak badge with gradient background.
/// Returns [SizedBox.shrink] when streak is 0.
class ChildStreakBadge extends StatelessWidget {
  final int streak;

  const ChildStreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final childTheme = context.childTheme;
    if (streak <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [childTheme.streak, childTheme.streakLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: childTheme.streak.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: context.colors.onPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KINDER CARD
// ─────────────────────────────────────────────────────────────────────────────

/// Premium surface card with a consistent, deeper shadow.
/// Supports an optional gradient and tap interaction via [InkWell].
class KinderCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;
  final Alignment gradientBegin;
  final Alignment gradientEnd;

  const KinderCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderRadius = 20,
    this.onTap,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colors.surface;

    final decoration = BoxDecoration(
      color: gradientColors == null ? bg : null,
      gradient: gradientColors != null
          ? LinearGradient(
              begin: gradientBegin,
              end: gradientEnd,
              colors: gradientColors!,
            )
          : null,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(decoration: decoration, child: inner),
        ),
      );
    }

    return Container(decoration: decoration, child: inner);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CHIP
// ─────────────────────────────────────────────────────────────────────────────

/// Animated filter chip for category browsing (Learn, Play).
class ChildCategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const ChildCategoryChip({
    super.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

/// Friendly empty-state view with large emoji, title, and subtitle.
class ChildEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget? action;

  const ChildEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED TYPING DOTS
// ─────────────────────────────────────────────────────────────────────────────

/// Three dots that animate sequentially to indicate AI is typing.
class TypingDotsIndicator extends StatefulWidget {
  final Color? color;

  const TypingDotsIndicator({super.key, this.color});

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _dotAnim(double delay) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 30),
      TweenSequenceItem(tween: ConstantTween(0.4), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeInOut),
    ));
  }

  Widget _dot(Animation<double> anim) {
    final dotColor =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(_dotAnim(0.0)),
        const SizedBox(width: 4),
        _dot(_dotAnim(0.2)),
        const SizedBox(width: 4),
        _dot(_dotAnim(0.4)),
      ],
    );
  }
}


