import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/avatar_picker_provider.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/app.dart';

// ==========================================
// 1. Child Profile Screen (Main Screen)
// ==========================================

class ChildProfileScreen extends ConsumerWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final child = ref.watch(currentChildProvider);
    final childName = (child?.name.isNotEmpty ?? false) ? child!.name : child?.id;

    if (child == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/child/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // ── Avatar with gradient ring + level badge ────────────────────
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Gradient ring
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
                            colors.primary.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SettingsAvatarSelectionScreen(),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(60),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surface,
                            ),
                            child: AvatarView(
                              avatarId: child.avatar,
                              avatarPath: child.avatarPath,
                              radius: 56,
                              backgroundColor:
                                  colors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Level badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              ChildColors.buddyStart,
                              ChildColors.buddyEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: ChildColors.buddyStart
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          l10n.levelLabel(child.level),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                childName ?? '',
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
              const SizedBox(height: 24),

              // ── Stats row using ChildStatBubble ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChildStatBubble(
                    value: '${child.xp % 1000}',
                    label: l10n.xp,
                    icon: Icons.star_rounded,
                    color: ChildColors.xpGold,
                  ),
                  ChildStatBubble(
                    value: '${child.streak}',
                    label: l10n.streak,
                    icon: Icons.local_fire_department_rounded,
                    color: ChildColors.streakFire,
                  ),
                  ChildStatBubble(
                    value: '${child.activitiesCompleted}',
                    label: l10n.activities,
                    icon: Icons.check_circle_rounded,
                    color: ChildColors.successGreen,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Progress card with fixed XP bar ────────────────────────────
              KinderCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChildSectionHeader(title: l10n.yourProgress),
                    const SizedBox(height: 20),
                    // XP bar — fixed: xpProgress is already 0.0–1.0
                    ChildXpProgressBar(
                      progress: child.xpProgress.clamp(0.0, 1.0),
                      currentXp: child.xp % 1000,
                      nextLevelXp: 1000,
                    ),
                    const SizedBox(height: 16),
                    _buildProgressBar(
                      context,
                      l10n.dailyGoal,
                      0.7,
                      AppColors.success,
                      '7/10 ${l10n.activities}',
                    ),
                    const SizedBox(height: 16),
                    _buildProgressBar(
                      context,
                      l10n.weeklyChallenge,
                      0.5,
                      AppColors.secondary,
                      '3/6',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.yourInterests,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: AppConstants.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: child.interests.map((interest) => _buildInterestChip(context, interest)).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.recentAchievements,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: AppConstants.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAchievementBadge(context, '🏆', l10n.achievementFirstQuizTitle, l10n.achievementFirstQuizSubtitle),
                        _buildAchievementBadge(context, '🔥', l10n.achievementStreakTitle, l10n.achievementStreakSubtitle),
                        _buildAchievementBadge(context, '⭐', l10n.achievementMathMasterTitle, l10n.achievementMathMasterSubtitle),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Text(
                            l10n.levels,
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: AppConstants.fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.levelJourneySubtitle,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChildLevelsScreen(
                              currentLevel: child.level,
                              coins: child.xp,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6D7F7),
                        foregroundColor: const Color(0xFF5D2E9E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        l10n.levels,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChildSettingsScreen()));
                },
                icon: const Icon(Icons.settings),
                label: Text(l10n.settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, String label, double value, Color color, String valueText) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(valueText, style: textTheme.bodySmall?.copyWith(fontSize: 12, color: colors.onSurfaceVariant)),
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

  Widget _buildInterestChip(BuildContext context, String interest) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(interest, style: textTheme.bodyMedium?.copyWith(fontSize: 14, color: colors.primary, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, String emoji, String title, String description) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.xpColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 8),
        Text(title, style: textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(description, style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colors.onSurfaceVariant), textAlign: TextAlign.center),
      ],
    );
  }
}

// ==========================================
// 1.5 Child Levels Screen
// ==========================================

class ChildLevelsScreen extends StatelessWidget {
  const ChildLevelsScreen({
    super.key,
    required this.currentLevel,
    required this.coins,
  });

  final int currentLevel;
  final int coins;

  List<_LevelNode> _buildLevels() {
    final levels = <_LevelNode>[];
    for (var level = 1; level <= 50; level += 1) {
      final isCurrent = level == currentLevel;
      final isUnlocked = level <= currentLevel;
      final stars = isUnlocked ? 3 : 0;
      levels.add(
        _LevelNode(
          level: level,
          stars: isCurrent ? 2 : stars,
          isCurrent: isCurrent,
          isUnlocked: isUnlocked,
        ),
      );
    }
    return levels;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final levels = _buildLevels();
    final displayLevels = levels.reversed.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A083F),
              Color(0xFF3B0C7A),
              Color(0xFF7E2FA8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _buildStatPill(
                      icon: Icons.emoji_events,
                      label: AppLocalizations.of(context)!.level,
                      value: '$currentLevel',
                      color: const Color(0xFFFFC34A),
                    ),
                    const SizedBox(width: 12),
                    _buildStatPill(
                      icon: Icons.star,
                      label: AppLocalizations.of(context)!.xp,
                      value: '$coins/1000',
                      color: const Color(0xFF7AE3FF),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final contentHeight = (displayLevels.length * 95).toDouble() + 220;
                    final height = math.max(contentHeight, constraints.maxHeight + 40);
                    final points = <Offset>[];
                    for (var i = 0; i < displayLevels.length; i++) {
                      final x = i.isEven ? width * 0.28 : width * 0.72;
                      final y = 95.0 * i + 140;
                      points.add(Offset(x, y));
                    }
                    return SingleChildScrollView(
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 40),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(width, height),
                              painter: _PathPainter(points: points),
                            ),
                            ...List.generate(displayLevels.length, (index) {
                              final node = displayLevels[index];
                              final point = points[index];
                              return Positioned(
                                left: point.dx - 40,
                                top: point.dy - 40,
                                child: _LevelBadge(
                                  node: node,
                                  onTap: () {
                                    final messenger = ScaffoldMessenger.of(context);
                                    messenger.hideCurrentSnackBar();
                                    if (!node.isUnlocked) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.lock_rounded, color: Colors.white),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  AppLocalizations.of(context)!.levelLockedMessage,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFFFF8AB3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      );
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.play_circle_fill, color: Colors.white),
                                            const SizedBox(width: 10),
                                            Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.levelStartMessage(node.level),
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(0xFF7ED6FF),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    );
                                    context.go('/child/learn');
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelNode {
  const _LevelNode({
    required this.level,
    required this.stars,
    required this.isCurrent,
    required this.isUnlocked,
  });

  final int level;
  final int stars;
  final bool isCurrent;
  final bool isUnlocked;
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.node, required this.onTap});

  final _LevelNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = node.isUnlocked
        ? (node.isCurrent ? const Color(0xFFD53DF2) : const Color(0xFFFFC34A))
        : const Color(0xFF8A8AA8);
    final glowColor = baseColor.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final active = index < node.stars;
              return Icon(
                active ? Icons.star : Icons.star_border,
                color: active ? const Color(0xFFFFD36A) : Colors.white.withValues(alpha: 0.45),
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 6),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  baseColor,
                  baseColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 3),
            ),
            child: Center(
              child: Text(
                '${node.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelActionPill extends StatelessWidget {
  const _LevelActionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final mid = Offset((prev.dx + current.dx) / 2, (prev.dy + current.dy) / 2);
      path.quadraticBezierTo(prev.dx, mid.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(current.dx, mid.dy, current.dx, current.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

// ==========================================
// 2. Child Settings Screen
// ==========================================

class ChildSettingsScreen extends ConsumerStatefulWidget {
  const ChildSettingsScreen({super.key});

  @override
  ConsumerState<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends ConsumerState<ChildSettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  String _settingsQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(l10n.settings, style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface)),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: colors.onSurface), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ChildHeader(compact: true),
          TextField(
            onChanged: (value) => setState(() => _settingsQuery = value),
            onSubmitted: (value) => _openSettingByQuery(value, locale),
            decoration: InputDecoration(
            hintText: l10n.searchSettingsHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._buildFilteredSettings(context, locale),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(childSessionControllerProvider.notifier).endChildSession();
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/welcome');
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredSettings(BuildContext context, Locale locale) {
    final l10n = AppLocalizations.of(context)!;
    final query = _settingsQuery.trim().toLowerCase();
    bool match(String text) =>
        query.isEmpty || text.toLowerCase().contains(query);

    final sections = <Widget>[];

    if (match('account') || match('edit profile') || match('change avatar')) {
      sections.add(_buildSectionHeader(context, l10n.accountSection));
      sections.add(const SizedBox(height: 10));
      sections.add(_buildSettingsCard(
        context,
        children: [
          _buildListTile(context, title: l10n.editProfile, icon: Icons.person_outline, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsEditProfileScreen()));
          }),
          _buildDivider(),
          _buildListTile(context, title: l10n.changeAvatar, icon: Icons.face_retouching_natural_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsAvatarSelectionScreen()));
          }),
        ],
      ));
      sections.add(const SizedBox(height: 30));
    }

    if (match('preferences') || match('sound') || match('music')) {
      sections.add(_buildSectionHeader(context, l10n.preferencesSection));
      sections.add(const SizedBox(height: 10));
      sections.add(_buildSettingsCard(
        context,
        children: [
          _buildSwitchTile(context, title: l10n.soundEffects, icon: Icons.volume_up_outlined, value: _soundEnabled, onChanged: (val) => setState(() => _soundEnabled = val)),
          _buildDivider(),
          _buildSwitchTile(context, title: l10n.backgroundMusic, icon: Icons.music_note_outlined, value: _musicEnabled, onChanged: (val) => setState(() => _musicEnabled = val)),
        ],
      ));
      sections.add(const SizedBox(height: 30));
    }

    if (match('app') || match('language') || match('themes') || match('about') || match('privacy')) {
      sections.add(_buildSectionHeader(context, l10n.appSettingsSection));
      sections.add(const SizedBox(height: 10));
      sections.add(_buildSettingsCard(
        context,
        children: [
          _buildListTile(context, title: l10n.language, subtitle: _languageLabel(locale), icon: Icons.language_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsLanguageScreen()));
          }),
          _buildDivider(),
          _buildListTile(context, title: l10n.themes, subtitle: l10n.lightAndCalm, icon: Icons.color_lens_outlined, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChildThemeScreen()));
          }),
          _buildDivider(),
          _buildListTile(context, title: l10n.aboutUs, icon: Icons.info_outline, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsAboutUsScreen()));
          }),
          _buildDivider(),
          _buildListTile(context, title: l10n.privacyPolicy, icon: Icons.lock_outline, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPrivacyPolicyScreen()));
          }),
        ],
      ));
      sections.add(const SizedBox(height: 30));
    }

    if (sections.isEmpty) {
      return [
        Center(
          child: Text(
            l10n.noSettingsFound,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    return sections;
  }

  void _openSettingByQuery(String value, Locale locale) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;

    if (query == 'edit profile' || query == 'profile') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SettingsEditProfileScreen()));
      return;
    }
    if (query == 'change avatar' || query == 'avatar') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SettingsAvatarSelectionScreen()));
      return;
    }
    if (query == 'language' ||
        query == _languageLabel(locale).toLowerCase() ||
        query == 'اللغة') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SettingsLanguageScreen()));
      return;
    }
    if (query == 'themes' || query == 'theme' || query == 'الثيمات' || query == 'المظهر') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChildThemeScreen()),
      );
      return;
    }
    if (query == 'about' || query == 'about us' || query == 'حول' || query == 'من نحن') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SettingsAboutUsScreen()));
      return;
    }
    if (query == 'privacy' || query == 'privacy policy' || query == 'الخصوصية' || query == 'سياسة الخصوصية') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SettingsPrivacyPolicyScreen()));
      return;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children, Color? color}) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(BuildContext context, {required String title, String? subtitle, required IconData icon, Color? iconColor, Color? titleColor, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: (iconColor ?? colors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor ?? colors.primary, size: 24),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: onTap != null ? Icon(Icons.arrow_forward_ios, size: 16, color: colors.onSurfaceVariant) : null,
      onTap: onTap,
    );
  }

  String _languageLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English (US)';
    }
  }

  Widget _buildSwitchTile(BuildContext context, {required String title, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: colors.primary, size: 24),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colors.primary,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, indent: 70, endIndent: 20, color: Theme.of(context).colorScheme.outlineVariant);
  }
}

// ==========================================
// 3. NEW: Settings Language Selection Screen (Renamed to avoid conflict)
// ==========================================

class SettingsLanguageScreen extends ConsumerWidget {
  const SettingsLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final colors = Theme.of(context).colorScheme;

    const languages = [
      {'code': 'en', 'name': 'English (US)'},
      {'code': 'ar', 'name': 'العربية'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectLanguage, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: ChildHeader(compact: true),
          ),
          ...languages.map((language) {
            final isSelected = locale.languageCode == language['code'];
            return InkWell(
              onTap: () {
                ref
                    .read(localeProvider.notifier)
                    .setLanguageCode(language['code'] as String);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.languageChanged(language['name'] as String))),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.flag, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        language['name'] as String,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: colors.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==========================================
// 4. NEW: Settings Avatar Selection Screen (Renamed)
// ==========================================

class SettingsAvatarSelectionScreen extends ConsumerStatefulWidget {
  const SettingsAvatarSelectionScreen({super.key});

  @override
  ConsumerState<SettingsAvatarSelectionScreen> createState() =>
      _SettingsAvatarSelectionScreenState();
}

class _SettingsAvatarSelectionScreenState
    extends ConsumerState<SettingsAvatarSelectionScreen> {
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    final child = ref.read(currentChildProvider);
    _selectedAvatarPath = child?.avatarPath.isNotEmpty == true
        ? child!.avatarPath
        : (child?.avatar.isNotEmpty == true ? child!.avatar : null);
  }

  @override
  Widget build(BuildContext context) {
    final avatars = ref.watch(availableAvatarsProvider);
    final child = ref.watch(currentChildProvider);
    final selectedPath = _selectedAvatarPath ??
        (avatars.isNotEmpty ? avatars.first : AppConstants.defaultChildAvatar);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseAvatar, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: child == null
                ? null
                : () async {
                    final updated = child.copyWith(
                      avatar: selectedPath,
                      avatarPath: selectedPath,
                    );
                    await ref
                        .read(childSessionControllerProvider.notifier)
                        .updateChildProfile(updated);
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.avatarSaved)),
                    );
                  },
            child: Text(AppLocalizations.of(context)!.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: ChildHeader(compact: true),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.0,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatarPath = avatars[index];
                final isSelected = selectedPath == avatarPath;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarPath = avatarPath;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: AssetImage(avatarPath),
                      onBackgroundImageError: (exception, stackTrace) {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. NEW: Settings Edit Profile Screen (Renamed)
// ==========================================

class SettingsEditProfileScreen extends ConsumerStatefulWidget {
  const SettingsEditProfileScreen({super.key});

  @override
  ConsumerState<SettingsEditProfileScreen> createState() =>
      _SettingsEditProfileScreenState();
}

class _SettingsEditProfileScreenState
    extends ConsumerState<SettingsEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final List<String> _selectedPictures = [];

  @override
  void initState() {
    super.initState();
    final child = ref.read(currentChildProvider);
    _nameController = TextEditingController(text: child?.name ?? '');
    if (child != null && child.picturePassword.isNotEmpty) {
      _selectedPictures.addAll(child.picturePassword.take(3));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _togglePicture(String pictureId) {
    setState(() {
      if (_selectedPictures.contains(pictureId)) {
        _selectedPictures.remove(pictureId);
      } else if (_selectedPictures.length < 3) {
        _selectedPictures.add(pictureId);
      }
    });
  }

  Future<void> _saveProfile(BuildContext context) async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    if (!_formKey.currentState!.validate()) return;
    if (_selectedPictures.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectThreePictures)),
      );
      return;
    }

    final newPassword = List<String>.from(_selectedPictures);
    final hasPasswordChange =
        child.picturePassword.length == 3 && child.picturePassword != newPassword;

    if (hasPasswordChange) {
      try {
        await ref.read(networkServiceProvider).post(
          '/auth/child/change-password',
          data: {
            'child_id': int.tryParse(child.id) ?? child.id,
            'name': child.name,
            'current_picture_password': child.picturePassword,
            'new_picture_password': newPassword,
          },
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToUpdatePicturePassword)),
        );
        return;
      }
    }

    final updated = child.copyWith(
      name: _nameController.text.trim(),
      picturePassword: newPassword,
    );

    await ref
        .read(childSessionControllerProvider.notifier)
        .updateChildProfile(updated);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChildHeader(compact: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  AvatarView(
                    avatarId: ref.watch(currentChildProvider)?.avatar,
                    avatarPath: ref.watch(currentChildProvider)?.avatarPath,
                    radius: 24,
                    backgroundColor: Colors.transparent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!.changeAvatarFromProfile,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.nameLabel, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enterYourName,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppLocalizations.of(context)!.pleaseEnterName;
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.picturePassword, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.chooseExactlyThreePictures, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 8),
              PicturePasswordRow(
                picturePassword: _selectedPictures,
                size: 24,
                showPlaceholders: true,
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: picturePasswordOptions.length,
                itemBuilder: (context, index) {
                  final option = picturePasswordOptions[index];
                  final isSelected = _selectedPictures.contains(option.id);
                  return InkWell(
                    onTap: () => _togglePicture(option.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? option.color.withValues(alpha: 0.2)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? option.color
                              : colors.surfaceContainerHighest,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        option.icon,
                        size: 28,
                        color: option.color,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _saveProfile(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(AppLocalizations.of(context)!.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5.5 NEW: Child Theme Screen
// ==========================================

class ChildThemeScreen extends ConsumerWidget {
  const ChildThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);
    final colors = Theme.of(context).colorScheme;

    const palettes = [
      ThemePalettes.blue,
      ThemePalettes.green,
      ThemePalettes.sunset,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.themes, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ChildHeader(compact: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.dark_mode),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(AppLocalizations.of(context)!.darkLight),
                ),
                Switch(
                  value: themeSettings.mode == ThemeMode.dark,
                  onChanged: (value) {
                    ref.read(themeControllerProvider.notifier).setMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.chooseCalmColor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ...palettes.map((palette) {
            final isSelected = themeSettings.paletteId == palette.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => ref
                    .read(themeControllerProvider.notifier)
                    .setPalette(palette.id),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          palette.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: colors.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==========================================
// 6. NEW: Settings About Us Screen
// ==========================================

class SettingsAboutUsScreen extends StatelessWidget {
  const SettingsAboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aboutUs, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const ChildHeader(compact: true),
            Center(child: Icon(Icons.child_care, size: 80, color: theme.colorScheme.primary)),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.kinderWorldAppTitle, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(AppLocalizations.of(context)!.versionLabel('1.0.0'), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 30),
            Text(
              AppLocalizations.of(context)!.aboutAppDescription,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.contactUs, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildContactRow(Icons.email, "support@kinderworld.com"),
            const SizedBox(height: 10),
            _buildContactRow(Icons.language, "www.kinderworld.com"),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(width: 15),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}

// ==========================================
// 7. NEW: Settings Privacy Policy Screen
// ==========================================

class SettingsPrivacyPolicyScreen extends StatelessWidget {
  const SettingsPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.privacyPolicy, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Text(AppLocalizations.of(context)!.privacyLastUpdated('October 2023'), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.privacyIntroTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.privacyIntroBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.privacyDataCollectionTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.privacyDataCollectionBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.privacySecurityTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.privacySecurityBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
