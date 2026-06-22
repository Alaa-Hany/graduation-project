import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/models/achievement.dart';
import 'package:kinder_world/core/models/child_avatar_customization.dart';
import 'package:kinder_world/core/providers/child_avatar_customization_provider.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/providers/avatar_picker_provider.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/theme_provider.dart';
import 'package:kinder_world/core/theme/theme_palette.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/core/widgets/avatar_view.dart';
import 'package:kinder_world/core/widgets/child_customizable_avatar.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/core/widgets/gamification_widgets.dart';
import 'package:kinder_world/core/widgets/material_compat.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/core/providers/locale_provider.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/features/child_mode/store/reward_store_screen.dart';
import 'package:kinder_world/router.dart' show Routes;

part 'widgets/child_profile_sections.dart';
part 'child_profile_support_screens.dart';

class ChildProfileScreen extends ConsumerWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    if (child == null) {
      return const _ChildProfileEmptyState();
    }

    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;
    final childName = (child.name.isNotEmpty ? child.name : child.id).trim();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(
          fallback: Routes.childHome,
          icon: Icons.arrow_back,
          iconSize: 24,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _ChildProfileHeroSection(
                child: child,
                childName: childName,
                onCustomizeAvatar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsAvatarSelectionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _ChildProfileStatsSection(child: child),
              const SizedBox(height: 24),
              _ChildProfileProgressSection(child: child),
              const SizedBox(height: 24),
              _ChildProfileInterestsSection(interests: child.interests),
              const SizedBox(height: 24),
              _ChildProfileAchievementsSection(
                achievements: [
                  _ProfileAchievement(
                    emoji: '\u{1F9EE}',
                    title: l10n.achievementMathMasterTitle,
                    description: l10n.achievementMathMasterSubtitle,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ChildProfileLevelsSection(
                currentLevel: child.level,
                coins: child.xp,
              ),
              const SizedBox(height: 24),
              const GamificationSummaryBar(),
              const SizedBox(height: 12),
              const _ChildProfileEquippedItemsSection(),
              _ChildProfileActionButton(
                icon: Icons.emoji_events_rounded,
                label: l10n.gamificationSeeAllAchievements,
                backgroundColor: childTheme.skill,
                foregroundColor: childTheme.skill.onColor,
                onPressed: () => context.push(Routes.childAchievements),
              ),
              const SizedBox(height: 12),
              _ChildProfileActionButton(
                icon: Icons.storefront_rounded,
                label: l10n.rewardStoreTitle,
                backgroundColor: childTheme.fun,
                foregroundColor: childTheme.fun.onColor,
                onPressed: () => context.push(Routes.childStore),
              ),
              const SizedBox(height: 16),
              _ChildProfileActionButton(
                icon: Icons.settings,
                label: l10n.settings,
                backgroundColor: colors.surfaceContainerHighest,
                foregroundColor: colors.onSurface,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChildSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
