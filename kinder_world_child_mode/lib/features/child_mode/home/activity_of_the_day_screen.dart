import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/progress_controller.dart';
import 'package:kinder_world/core/theme/app_colors.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noActiveChildSession)),
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

    if (!mounted) return;

    setState(() {
      _saving = false;
      _completed = record != null;
    });

    if (record != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.xpBonusEarned)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tryAgain)),
      );
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
                      AppColors.secondary.withValues(alpha: 0.2),
                      AppColors.xpColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
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
                        color: AppColors.xpColor.withValues(alpha: 0.2),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (!_started) {
                            setState(() => _started = true);
                          } else {
                            _completeActivity();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _completed ? AppColors.success : colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _completed
                        ? l10n.activityOfDayCompletedCta
                        : _started
                            ? (_saving
                                ? l10n.loading
                                : l10n.activityOfDayFinishCta)
                            : l10n.activityOfDayStartCta,
                    style: const TextStyle(
                      fontSize: AppConstants.fontSize,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStepCard(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceContainerHighest),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.15),
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
    );
  }
}
