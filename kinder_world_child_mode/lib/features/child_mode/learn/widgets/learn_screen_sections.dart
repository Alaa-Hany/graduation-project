part of '../learn_screen.dart';

class _LearnSearchField extends StatelessWidget {
  const _LearnSearchField({
    required this.onChanged,
    required this.onSubmitted,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.searchPages,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _LearnContentErrorCard extends StatelessWidget {
  const _LearnContentErrorCard({
    required this.errorText,
    required this.onRetry,
  });

  final String errorText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }
}

class _LearnIntroBanner extends StatelessWidget {
  const _LearnIntroBanner({
    required this.activityCount,
  });

  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValuesCompat(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                activityCount > 0
                    ? '${l10n.letsExploreAndLearn} - $activityCount'
                    : l10n.letsExploreAndLearn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnResultsGrid extends StatelessWidget {
  const _LearnResultsGrid({
    required this.results,
    required this.activities,
    required this.publicCategories,
    required this.localizedTitleBuilder,
    required this.onOpenSearchResult,
    required this.onOpenCategory,
  });

  final List<Map<String, dynamic>> results;
  final List<Activity> activities;
  final List<PublicContentCategory> publicCategories;
  final String Function(String title) localizedTitleBuilder;
  final ValueChanged<Map<String, dynamic>> onOpenSearchResult;
  final ValueChanged<String> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (results.isEmpty) {
      return Center(
        child: Text(
          l10n.noPagesFound,
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.05,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        if (result.containsKey('image')) {
          return _LearnCategoryCard(
            title: localizedTitleBuilder(result['title'] as String),
            imagePath: result['image'] as String,
            color: result['color'] as Color,
            availableCount: _availableCountForAxis(result['route'] as String),
            onTap: () => onOpenCategory(result['route'] as String),
          );
        }

        return _LearnSearchResultCard(
          title: localizedTitleBuilder(result['title'] as String),
          onTap: () => onOpenSearchResult(result),
        );
      },
    );
  }

  int _availableCountForAxis(String axisKey) {
    final activityCount =
        activities.where((activity) => activity.aspect == axisKey).length;
    final cmsCount = publicCategories
        .where((category) => category.axisKey == axisKey)
        .fold<int>(
          0,
          (total, category) =>
              total + category.contentCount + category.quizCount,
        );
    return activityCount + cmsCount;
  }
}

class _LearnSearchResultCard extends StatelessWidget {
  const _LearnSearchResultCard({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValuesCompat(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConstants.fontSize,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnCategoryCard extends StatelessWidget {
  const _LearnCategoryCard({
    required this.title,
    required this.imagePath,
    required this.color,
    required this.availableCount,
    required this.onTap,
  });

  final String title;
  final String imagePath;
  final Color color;
  final int availableCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValuesCompat(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
            onError: (error, stackTrace) {},
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValuesCompat(alpha: 0.6),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withValuesCompat(alpha: 0.3),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (availableCount > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValuesCompat(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '$availableCount',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
