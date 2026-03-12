import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/router.dart';

class CategoryScreen extends ConsumerWidget {
  final String category;

  const CategoryScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activities = _getMockActivities(category, l10n);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final headerColor = _getCategoryColor(context, category);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => context.appBack(fallback: Routes.childPlay),
        ),
        title: Text(
          _getCategoryDisplayName(category, l10n),
          style: textTheme.titleMedium?.copyWith(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChildHeader(compact: true),
              // Category header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: headerColor.onColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        size: 30,
                        color: headerColor.onColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCategoryDisplayName(category, l10n),
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: AppConstants.largeFontSize,
                              fontWeight: FontWeight.bold,
                              color: headerColor.onColor,
                            ),
                          ),
                          Text(
                            l10n.activityCount(activities.length),
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              color: headerColor.onColor.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Activities list
              Text(
                l10n.chooseActivity,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ActivityCard(
                      activity: activity,
                      onTap: () {
                        // In a real app, this would start the activity
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.startingActivity(
                                  activity['title'] as String),
                            ),
                          ),
                        );
                      },
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

  List<Map<String, dynamic>> _getMockActivities(
    String category,
    AppLocalizations l10n,
  ) {
    final allActivities = {
      'games': [
        {
          'id': 'game_01',
          'title': l10n.activityGame1Title,
          'description': l10n.activityGame1Desc,
          'icon': '🧮',
          'duration': 10,
          'xp': 25,
        },
        {
          'id': 'game_02',
          'title': l10n.activityGame2Title,
          'description': l10n.activityGame2Desc,
          'icon': '🧠',
          'duration': 8,
          'xp': 20,
        },
        {
          'id': 'game_03',
          'title': l10n.activityGame3Title,
          'description': l10n.activityGame3Desc,
          'icon': '🔤',
          'duration': 12,
          'xp': 30,
        },
        {
          'id': 'game_04',
          'title': l10n.activityGame4Title,
          'description': l10n.activityGame4Desc,
          'icon': '🎨',
          'duration': 6,
          'xp': 15,
        },
      ],
      'stories': [
        {
          'id': 'story_01',
          'title': l10n.activityStory1Title,
          'description': l10n.activityStory1Desc,
          'icon': '🐜',
          'duration': 15,
          'xp': 40,
        },
        {
          'id': 'story_02',
          'title': l10n.activityStory2Title,
          'description': l10n.activityStory2Desc,
          'icon': '🌈',
          'duration': 12,
          'xp': 35,
        },
        {
          'id': 'story_03',
          'title': l10n.activityStory3Title,
          'description': l10n.activityStory3Desc,
          'icon': '🌳',
          'duration': 18,
          'xp': 45,
        },
        {
          'id': 'story_04',
          'title': l10n.activityStory4Title,
          'description': l10n.activityStory4Desc,
          'icon': '🌊',
          'duration': 20,
          'xp': 50,
        },
      ],
      'music': [
        {
          'id': 'music_01',
          'title': l10n.activityMusic1Title,
          'description': l10n.activityMusic1Desc,
          'icon': '🎤',
          'duration': 8,
          'xp': 20,
        },
        {
          'id': 'music_02',
          'title': l10n.activityMusic2Title,
          'description': l10n.activityMusic2Desc,
          'icon': '🎺',
          'duration': 10,
          'xp': 25,
        },
        {
          'id': 'music_03',
          'title': l10n.activityMusic3Title,
          'description': l10n.activityMusic3Desc,
          'icon': '🥁',
          'duration': 6,
          'xp': 15,
        },
        {
          'id': 'music_04',
          'title': l10n.activityMusic4Title,
          'description': l10n.activityMusic4Desc,
          'icon': '💃',
          'duration': 12,
          'xp': 30,
        },
      ],
      'videos': [
        {
          'id': 'video_01',
          'title': l10n.activityVideo1Title,
          'description': l10n.activityVideo1Desc,
          'icon': '🦋',
          'duration': 25,
          'xp': 40,
        },
        {
          'id': 'video_02',
          'title': l10n.activityVideo2Title,
          'description': l10n.activityVideo2Desc,
          'icon': '🔬',
          'duration': 20,
          'xp': 35,
        },
        {
          'id': 'video_03',
          'title': l10n.activityVideo3Title,
          'description': l10n.activityVideo3Desc,
          'icon': '🐘',
          'duration': 18,
          'xp': 30,
        },
        {
          'id': 'video_04',
          'title': l10n.activityVideo4Title,
          'description': l10n.activityVideo4Desc,
          'icon': '🚀',
          'duration': 22,
          'xp': 45,
        },
      ],
    };

    return allActivities[category] ?? [];
  }

  String _getCategoryDisplayName(String category, AppLocalizations l10n) {
    switch (category) {
      case 'games':
        return l10n.categoryGames;
      case 'stories':
        return l10n.categoryStories;
      case 'music':
        return l10n.categoryMusic;
      case 'videos':
        return l10n.categoryVideos;
      default:
        return category;
    }
  }

  Color _getCategoryColor(BuildContext context, String category) {
    final child = context.childTheme;
    final colors = Theme.of(context).colorScheme;
    switch (category) {
      case 'games':
        return child.fun;
      case 'stories':
        return child.kindness;
      case 'music':
        return child.learning;
      case 'videos':
        return child.skill;
      default:
        return colors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'games':
        return Icons.games;
      case 'stories':
        return Icons.menu_book;
      case 'music':
        return Icons.music_note;
      case 'videos':
        return Icons.play_circle;
      default:
        return Icons.category;
    }
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final child = context.childTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              activity['icon'],
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              activity['title'],
              style: textTheme.titleSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              activity['description'],
              style: textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!
                      .activityMinutes(activity['duration'] as int),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.star,
                  size: 16,
                  color: child.xp,
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!
                      .activityXp(activity['xp'] as int),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: child.xp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
