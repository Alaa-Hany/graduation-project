import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/gamification_provider.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/services/gamification_service.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/widgets/child_safe_ui.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ActivityOfTheDayScreen extends ConsumerStatefulWidget {
  const ActivityOfTheDayScreen({super.key});

  @override
  ConsumerState<ActivityOfTheDayScreen> createState() =>
      _ActivityOfTheDayScreenState();
}

class _ActivityOfTheDayScreenState
    extends ConsumerState<ActivityOfTheDayScreen> {
  bool _started = false;
  bool _completed = false;
  bool _saving = false;

  Future<void> _completeActivity() async {
    if (_saving || _completed) return;
    final l10n = AppLocalizations.of(context)!;
    final childProfile = ref.read(childSessionControllerProvider).childProfile;
    if (childProfile == null) {
      if (mounted) {
        showChildFeedbackSnackBar(
          context,
          l10n.noActiveChildSession,
          success: false,
        );
      }
      return;
    }

    setState(() {
      _saving = true;
    });

    final record = await ref
        .read(progressControllerProvider.notifier)
        .recordActivityCompletion(
          childId: childProfile.id,
          activityId: 'activity_of_the_day',
          score: 100,
          duration: 5,
          xpEarned: 50,
          notes: l10n.activityOfTheDay,
        );

    if (record != null) {
      await ref.read(gamificationStateProvider.notifier).recordActivity(
            childId: childProfile.id,
            type: ActivityType.activity,
            category: 'behavioral',
            score: 100,
            awardXp: false,
            activityId: 'activity_of_the_day',
          );
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
      _completed = record != null;
    });

    if (record != null) {
      unawaited(HapticFeedback.lightImpact());
      showChildFeedbackSnackBar(context, l10n.xpBonusEarned);
    } else {
      unawaited(HapticFeedback.heavyImpact());
      showChildFeedbackSnackBar(context, l10n.tryAgain, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityOfTheDay),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withValuesCompat(alpha: 0.2),
                      AppColors.xpColor.withValuesCompat(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.secondary.withValuesCompat(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValuesCompat(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        size: 34,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.activityOfDayTreasureHuntTitle,
                            style: TextStyle(
                              fontSize: AppConstants.fontSize,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.activityOfDayTreasureHuntSubtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.xpColor.withValuesCompat(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '+50 XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.xpColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.activityOfDayMissionTitle,
                style: TextStyle(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildStepCard(
                context,
                index: 1,
                title: l10n.activityOfDayFindColorsTitle,
                subtitle: l10n.activityOfDayFindColorsSubtitle,
                icon: Icons.palette,
                color: AppColors.educational,
              ),
              const SizedBox(height: 12),
              _buildStepCard(
                context,
                index: 2,
                title: l10n.activityOfDaySpotShapesTitle,
                subtitle: l10n.activityOfDaySpotShapesSubtitle,
                icon: Icons.category,
                color: AppColors.skillful,
              ),
              const SizedBox(height: 12),
              _buildStepCard(
                context,
                index: 3,
                title: l10n.activityOfDayShareSmileTitle,
                subtitle: l10n.activityOfDayShareSmileSubtitle,
                icon: Icons.emoji_emotions,
                color: AppColors.behavioral,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.surfaceContainerHighest),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.activityOfDayTimeHint,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ChildPrimaryActionButton(
                label: _completed
                    ? l10n.activityOfDayCompletedCta
                    : _started
                        ? (_saving ? l10n.loading : l10n.activityOfDayFinishCta)
                        : l10n.activityOfDayStartCta,
                semanticLabel: _completed
                    ? l10n.activityOfDayCompletedCta
                    : (_started
                        ? l10n.activityOfDayFinishCta
                        : l10n.activityOfDayStartCta),
                icon: _completed
                    ? Icons.check_circle
                    : (_started ? Icons.flag : Icons.play_arrow_rounded),
                isBusy: _saving,
                backgroundColor:
                    _completed ? AppColors.success : colors.primary,
                foregroundColor: colors.onPrimary,
                onPressed: () {
                  if (!_started) {
                    HapticFeedback.selectionClick();
                    setState(() => _started = true);
                  } else {
                    _completeActivity();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$index. $title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.surfaceContainerHighest),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValuesCompat(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValuesCompat(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. $title',
                    style: TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
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
