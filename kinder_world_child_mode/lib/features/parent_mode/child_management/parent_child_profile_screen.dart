import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';

class ParentChildProfileScreen extends StatelessWidget {
  const ParentChildProfileScreen({
    super.key,
    required this.child,
  });

  final ChildProfile child;

  static const Map<String, String> _avatarAssets = {
    'avatar_1': 'assets/images/avatars/boy1.png',
    'avatar_2': 'assets/images/avatars/boy2.png',
    'avatar_3': 'assets/images/avatars/boy3.png',
    'avatar_4': 'assets/images/avatars/boy4.png',
    'avatar_5': 'assets/images/avatars/girl1.png',
    'avatar_6': 'assets/images/avatars/girl2.png',
    'avatar_7': 'assets/images/avatars/girl3.png',
    'avatar_8': 'assets/images/avatars/girl4.png',
    'avatar_9': 'assets/images/avatars/av1.png',
    'avatar_10': 'assets/images/avatars/av2.png',
    'avatar_11': 'assets/images/avatars/av3.png',
    'avatar_12': 'assets/images/avatars/av4.png',
    'avatar_13': 'assets/images/avatars/av5.png',
    'avatar_14': 'assets/images/avatars/av6.png',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: colors.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/parent/child-management');
            }
          },
        ),
        title: Text(
          child.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar + name header ─────────────────────────────────
              ParentCard(
                child: Column(
                  children: [
                    // Avatar with gradient ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ParentColors.parentGreen,
                                ParentColors.parentGreenLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: AvatarView(
                                avatarId: child.avatar,
                                avatarPath: _avatarAssets[child.avatar] ??
                                    child.avatarPath,
                                radius: 46,
                                backgroundColor: ParentColors.parentGreen
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                ParentColors.parentGreen,
                                ParentColors.parentGreenLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: Text(
                            l10n.levelBadge(child.level),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      child.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.age > 0
                          ? '${l10n.yearsOld(child.age)} · ${l10n.level} ${child.level}'
                          : '— · ${l10n.level} ${child.level}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Picture password dots
                    PicturePasswordRow(
                      picturePassword: child.picturePassword,
                      size: 18,
                      showPlaceholders: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Stats row ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.activitiesCompleted}',
                      label: l10n.activities,
                      icon: Icons.check_circle_rounded,
                      color: ParentColors.parentGreenLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.totalTimeSpent}m',
                      label: l10n.timeSpent,
                      icon: Icons.timer_rounded,
                      color: ParentColors.infoBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ParentStatCard(
                      value: '${child.streak}',
                      label: l10n.dailyStreak,
                      icon: Icons.local_fire_department_rounded,
                      color: ParentColors.streakOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── XP progress ──────────────────────────────────────────
              ParentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParentSectionHeader(title: l10n.xpProgress),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.xpValue(child.xp % 1000),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ParentColors.xpGold,
                          ),
                        ),
                        Text(
                          l10n.xpToNextLevel(1000 - (child.xp % 1000)),
                          style: TextStyle(
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
                        value: child.xpProgress.clamp(0.0, 1.0),
                        backgroundColor: colors.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ParentColors.xpGold,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Interests ────────────────────────────────────────────
              if (child.interests.isNotEmpty)
                ParentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParentSectionHeader(title: l10n.childInterests),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: child.interests
                            .map((interest) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ParentColors.parentGreen
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    interest,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ParentColors.parentGreen,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              if (child.interests.isNotEmpty) const SizedBox(height: 16),

              // ── Reports CTA ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/parent/reports', extra: child.id),
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                  label: Text(l10n.activityReports),
                  style: FilledButton.styleFrom(
                    backgroundColor: ParentColors.parentGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
