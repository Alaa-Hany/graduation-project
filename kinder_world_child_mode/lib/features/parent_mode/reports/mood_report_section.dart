import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/mood_provider.dart';
import 'package:kinder_world/core/widgets/parent_design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOOD REPORT SECTION — shown in parent reports for a specific child
// ─────────────────────────────────────────────────────────────────────────────

class MoodReportSection extends ConsumerWidget {
  const MoodReportSection({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final countsAsync = ref.watch(
      childMoodCountsProvider((childId: childId, days: 7)),
    );
    final mostFrequentAsync = ref.watch(
      childMostFrequentMoodProvider((childId: childId, days: 7)),
    );

    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ParentSectionHeader(
            title: l10n.moodReportTitle,
            subtitle: l10n.moodReportSubtitle,
          ),
          const SizedBox(height: 16),
          countsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _MoodEmptyState(l10n: l10n),
            data: (counts) {
              final total = counts.values.fold<int>(0, (s, v) => s + v);
              if (total == 0) return _MoodEmptyState(l10n: l10n);

              final mostFrequent = mostFrequentAsync.asData?.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Most frequent mood highlight ──────────────────────
                  if (mostFrequent != null) ...[
                    _MostFrequentBanner(
                      mood: mostFrequent,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Total entries label ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.moodEntriesCount(total),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        l10n.moodWeekLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Mood bar chart ────────────────────────────────────
                  _MoodBarChart(counts: counts, total: total, l10n: l10n),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOST FREQUENT MOOD BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _MostFrequentBanner extends StatelessWidget {
  const _MostFrequentBanner({required this.mood, required this.l10n});

  final String mood;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final info = _moodInfo(mood, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.moodMostFrequent,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: info.color,
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
// MOOD BAR CHART — horizontal bars per mood type
// ─────────────────────────────────────────────────────────────────────────────

class _MoodBarChart extends StatelessWidget {
  const _MoodBarChart({
    required this.counts,
    required this.total,
    required this.l10n,
  });

  final Map<String, int> counts;
  final int total;
  final AppLocalizations l10n;

  static const _orderedMoods = [
    'happy',
    'excited',
    'calm',
    'tired',
    'sad',
    'angry',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: _orderedMoods.map((mood) {
        final count = counts[mood] ?? 0;
        final fraction = total > 0 ? count / total : 0.0;
        final info = _moodInfo(mood, l10n);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              // Emoji
              SizedBox(
                width: 28,
                child: Text(
                  info.emoji,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),

              // Label
              SizedBox(
                width: 60,
                child: Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),

              // Bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(info.color),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Count
              SizedBox(
                width: 24,
                child: Text(
                  '$count',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: count > 0 ? info.color : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _MoodEmptyState extends StatelessWidget {
  const _MoodEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ParentEmptyState(
        icon: Icons.mood_rounded,
        title: l10n.moodNoHistory,
        subtitle: l10n.moodPickerSubtitle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOOD INFO HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _MoodInfo {
  final String emoji;
  final String label;
  final Color color;
  const _MoodInfo(this.emoji, this.label, this.color);
}

_MoodInfo _moodInfo(String mood, AppLocalizations l10n) {
  switch (mood) {
    case 'happy':
      return _MoodInfo('😊', l10n.happy, const Color(0xFFFFB300));
    case 'excited':
      return _MoodInfo('🤩', l10n.excited, const Color(0xFFFF6D00));
    case 'calm':
      return _MoodInfo('😌', l10n.calm, const Color(0xFF00BCD4));
    case 'tired':
      return _MoodInfo('😴', l10n.tired, const Color(0xFF9E9E9E));
    case 'sad':
      return _MoodInfo('😢', l10n.sad, const Color(0xFF5C6BC0));
    case 'angry':
      return _MoodInfo('😠', l10n.angry, const Color(0xFFE53935));
    default:
      return _MoodInfo('😐', mood, const Color(0xFF78909C));
  }
}
