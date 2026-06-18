// lib/features/child_mode/mood/mood_picker_widget.dart
//
// Child-facing mood tracking UI.
// MoodPickerSection   â€” animated emoji mood buttons shown on home screen.
// MoodRecommendationsSection â€” content cards based on selected mood.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/child_profile.dart';
import 'package:kinder_world/core/models/mood_entry.dart';
import 'package:kinder_world/core/providers/child_session_controller.dart';
import 'package:kinder_world/core/providers/mood_provider.dart';
import 'package:kinder_world/core/services/mood_recommendation_service.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MOOD PICKER SECTION
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Displays a row of animated emoji buttons for the child to pick their mood.
/// Shows an encouragement message after selection.
/// If the child already recorded a mood today, shows the current mood instead.
class MoodPickerSection extends ConsumerStatefulWidget {
  const MoodPickerSection({super.key});

  @override
  ConsumerState<MoodPickerSection> createState() => _MoodPickerSectionState();
}

class _MoodPickerSectionState extends ConsumerState<MoodPickerSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  String? _tappedMood;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMoodTap(String mood, String childId) async {
    setState(() => _tappedMood = mood);
    // Bounce animation
    await _bounceCtrl.reverse();
    await _bounceCtrl.forward();

    await ref.read(moodNotifierProvider.notifier).recordMood(childId, mood);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final childTheme = context.childTheme;

    final moodState = ref.watch(moodNotifierProvider);
    final childId = ref.watch(currentChildIdProvider);
    final justSaved = ref.watch(moodJustSavedProvider);

    if (childId == null) return const SizedBox.shrink();

    final alreadyRecorded = moodState.hasRecordedToday;
    final currentMood = moodState.todayMood;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: KinderCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(
              children: [
                Text(
                  alreadyRecorded ? '\u2728' : '\u{1F4AD}',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alreadyRecorded
                            ? l10n.moodTodayLabel
                            : l10n.moodPickerTitle,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: colors.onSurface,
                        ),
                      ),
                      if (!alreadyRecorded)
                        Text(
                          l10n.moodPickerSubtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Saved badge
                if (justSaved)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: childTheme.xp.withValuesCompat(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.moodSaved,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: childTheme.xp,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // â”€â”€ Mood Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!alreadyRecorded)
              _MoodButtonsRow(
                selectedMood: _tappedMood,
                onMoodTap: (mood) => _onMoodTap(mood, childId),
                bounceCtrl: _bounceCtrl,
                tappedMood: _tappedMood,
              )
            else
              _CurrentMoodDisplay(mood: currentMood!),

            // â”€â”€ Encouragement â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (alreadyRecorded && currentMood != null) ...[
              const SizedBox(height: 12),
              _EncouragementBanner(mood: currentMood),
            ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MOOD BUTTONS ROW
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MoodButtonsRow extends StatelessWidget {
  const _MoodButtonsRow({
    required this.selectedMood,
    required this.onMoodTap,
    required this.bounceCtrl,
    required this.tappedMood,
  });

  final String? selectedMood;
  final ValueChanged<String> onMoodTap;
  final AnimationController bounceCtrl;
  final String? tappedMood;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 320 ? 4.0 : 6.0;

        return Row(
          children: MoodMeta.displayOrder.map((mood) {
            final isSelected = selectedMood == mood;
            final isTapped = tappedMood == mood;

            Widget button = _MoodEmojiButton(
              mood: mood,
              isSelected: isSelected,
              onTap: () => onMoodTap(mood),
              compact: constraints.maxWidth < 320,
            );

            if (isTapped) {
              button = ScaleTransition(
                scale: bounceCtrl,
                child: button,
              );
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                child: button,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SINGLE MOOD EMOJI BUTTON
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MoodEmojiButton extends StatelessWidget {
  const _MoodEmojiButton({
    required this.mood,
    required this.isSelected,
    required this.onTap,
    required this.compact,
  });

  final String mood;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: compact ? 58 : 62,
        decoration: BoxDecoration(
          color: isSelected
              ? moodColor.withValuesCompat(alpha: 0.18)
              : colors.surfaceContainerHighest.withValuesCompat(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? moodColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: moodColor.withValuesCompat(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              MoodMeta.emoji(mood),
              style: TextStyle(
                fontSize:
                    compact ? (isSelected ? 24 : 20) : (isSelected ? 26 : 22),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: compact ? 8 : 9,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? moodColor : colors.onSurfaceVariant,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _moodShortLabel(mood, l10n),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moodShortLabel(String mood, AppLocalizations l10n) {
    switch (mood) {
      case ChildMoods.happy:
        return l10n.moodNameHappy;
      case ChildMoods.excited:
        return l10n.moodNameExcited;
      case ChildMoods.calm:
        return l10n.moodNameCalm;
      case ChildMoods.tired:
        return l10n.moodNameTired;
      case ChildMoods.sad:
        return l10n.moodNameSad;
      case ChildMoods.angry:
        return l10n.moodNameAngry;
      default:
        return mood;
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// CURRENT MOOD DISPLAY (already recorded today)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CurrentMoodDisplay extends StatelessWidget {
  const _CurrentMoodDisplay({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    final localizedName = _localizedMoodName(mood, l10n);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: moodColor.withValuesCompat(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: moodColor.withValuesCompat(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MoodMeta.emoji(mood), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: moodColor,
                ),
              ),
              Text(
                l10n.moodTodaySubLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _localizedMoodName(String mood, AppLocalizations l10n) {
    switch (mood) {
      case ChildMoods.happy:
        return l10n.moodNameHappy;
      case ChildMoods.excited:
        return l10n.moodNameExcited;
      case ChildMoods.calm:
        return l10n.moodNameCalm;
      case ChildMoods.tired:
        return l10n.moodNameTired;
      case ChildMoods.sad:
        return l10n.moodNameSad;
      case ChildMoods.angry:
        return l10n.moodNameAngry;
      default:
        return mood;
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ENCOURAGEMENT BANNER
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EncouragementBanner extends StatelessWidget {
  const _EncouragementBanner({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: moodColor.withValuesCompat(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _encouragementText(mood, l10n),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  String _encouragementText(String mood, AppLocalizations l10n) {
    switch (mood) {
      case ChildMoods.happy:
        return '\u{1F31F} ${l10n.moodEncouragementHappy}';
      case ChildMoods.excited:
        return '\u26A1 ${l10n.moodEncouragementExcited}';
      case ChildMoods.calm:
        return '\u{1F33F} ${l10n.moodEncouragementCalm}';
      case ChildMoods.tired:
        return '\u{1F4A4} ${l10n.moodEncouragementTired}';
      case ChildMoods.sad:
        return '\u{1F499} ${l10n.moodEncouragementSad}';
      case ChildMoods.angry:
        return '\u{1F60C} ${l10n.moodEncouragementAngry}';
      default:
        return '\u2728 ${l10n.moodEncouragementHappy}';
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MOOD RECOMMENDATIONS SECTION
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Shows 2â€“3 content recommendation cards based on the child's current mood.
/// Only visible after a mood has been recorded today.
class MoodRecommendationsSection extends ConsumerWidget {
  const MoodRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final moodState = ref.watch(moodNotifierProvider);

    // Only show if mood has been recorded today
    if (!moodState.hasRecordedToday || moodState.todayMood == null) {
      return const SizedBox.shrink();
    }

    final mood = moodState.todayMood!;
    final recs = MoodRecommendationService.getRecommendations(mood);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          ChildSectionHeader(title: l10n.moodRecommendationsTitle),
          const SizedBox(height: 4),
          Text(
            l10n.moodRecommendationsSubtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Recommendation cards â€” horizontal scroll
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _RecommendationCard(rec: recs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// RECOMMENDATION CARD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec});

  final MoodRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.go(rec.route),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              rec.color.withValuesCompat(alpha: 0.85),
              rec.color.withValuesCompat(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: rec.color.withValuesCompat(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Emoji + icon row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rec.emoji, style: const TextStyle(fontSize: 24)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.surface.withValuesCompat(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(rec.icon, size: 14, color: Colors.white),
                ),
              ],
            ),

            // Title
            Text(
              moodRecTitleFallback(rec.titleKey),
              style: textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Subtitle
            Text(
              moodRecSubtitleFallback(rec.subtitleKey),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Colors.white.withValuesCompat(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
