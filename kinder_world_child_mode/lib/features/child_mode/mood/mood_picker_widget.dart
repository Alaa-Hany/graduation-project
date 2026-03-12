// lib/features/child_mode/mood/mood_picker_widget.dart
//
// Child-facing mood tracking UI.
// MoodPickerSection   — animated emoji mood buttons shown on home screen.
// MoodRecommendationsSection — content cards based on selected mood.

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

// ─────────────────────────────────────────────────────────────────────────────
// MOOD PICKER SECTION
// ─────────────────────────────────────────────────────────────────────────────

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
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  alreadyRecorded ? '✨' : '💭',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: childTheme.xp.withValues(alpha: 0.15),
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

            // ── Mood Buttons ─────────────────────────────────────────────────
            if (!alreadyRecorded)
              _MoodButtonsRow(
                selectedMood: _tappedMood,
                onMoodTap: (mood) => _onMoodTap(mood, childId),
                bounceCtrl: _bounceCtrl,
                tappedMood: _tappedMood,
              )
            else
              _CurrentMoodDisplay(mood: currentMood!),

            // ── Encouragement ────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// MOOD BUTTONS ROW
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE MOOD EMOJI BUTTON
// ─────────────────────────────────────────────────────────────────────────────

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
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: compact ? 58 : 62,
        decoration: BoxDecoration(
          color: isSelected
              ? moodColor.withValues(alpha: 0.18)
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? moodColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: moodColor.withValues(alpha: 0.3),
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
                fontSize: compact
                    ? (isSelected ? 24 : 20)
                    : (isSelected ? 26 : 22),
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
                    _moodShortLabel(mood),
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

  String _moodShortLabel(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return 'Happy';
      case ChildMoods.excited:
        return 'Excited';
      case ChildMoods.calm:
        return 'Calm';
      case ChildMoods.tired:
        return 'Tired';
      case ChildMoods.sad:
        return 'Sad';
      case ChildMoods.angry:
        return 'Angry';
      default:
        return mood;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CURRENT MOOD DISPLAY (already recorded today)
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentMoodDisplay extends StatelessWidget {
  const _CurrentMoodDisplay({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: moodColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: moodColor.withValues(alpha: 0.3)),
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
                MoodTypes.getLabel(mood),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: moodColor,
                ),
              ),
              Text(
                'Today\'s mood',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ENCOURAGEMENT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _EncouragementBanner extends StatelessWidget {
  const _EncouragementBanner({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final moodColor = Color(MoodMeta.colorValue(mood));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: moodColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _encouragementText(mood),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  String _encouragementText(String mood) {
    switch (mood) {
      case ChildMoods.happy:
        return '🌟 Great! Let\'s make the most of your happy mood!';
      case ChildMoods.excited:
        return '⚡ You\'re excited! Let\'s channel that energy!';
      case ChildMoods.calm:
        return '🍃 You\'re calm and focused. Perfect for learning!';
      case ChildMoods.tired:
        return '💤 Feeling tired? Let\'s do something light and fun.';
      case ChildMoods.sad:
        return '💛 It\'s okay to feel sad. Let\'s do something calming.';
      case ChildMoods.angry:
        return '🌬️ Let\'s take a deep breath and do something relaxing.';
      default:
        return '✨ Let\'s explore something fun today!';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOOD RECOMMENDATIONS SECTION
// ─────────────────────────────────────────────────────────────────────────────

/// Shows 2–3 content recommendation cards based on the child's current mood.
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

          // Recommendation cards — horizontal scroll
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

// ─────────────────────────────────────────────────────────────────────────────
// RECOMMENDATION CARD
// ─────────────────────────────────────────────────────────────────────────────

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
              rec.color.withValues(alpha: 0.85),
              rec.color.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: rec.color.withValues(alpha: 0.3),
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
                    color: colors.surface.withValues(alpha: 0.25),
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
                color: Colors.white.withValues(alpha: 0.85),
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
