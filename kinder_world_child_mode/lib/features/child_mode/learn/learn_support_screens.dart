// ignore_for_file: prefer_const_constructors, unused_element, unused_element_parameter
part of 'learn_screen.dart';

class EntertainingScreen extends StatelessWidget {
  const EntertainingScreen({super.key});

  List<Map<String, dynamic>> get _items => entertainingItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValuesCompat(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sentiment_satisfied_alt,
                      color: AppColors.entertaining, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.foundSomethingFun,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.entertaining,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildFunCard(
                    context,
                    item['title'],
                    item['image'],
                    item['color'],
                    l10n,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunCard(
    BuildContext context,
    String title,
    String imagePath,
    Color color,
    AppLocalizations l10n,
  ) {
    return InkWell(
      // MODIFIED: Navigate to Detail Screen
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                EntertainmentDetailScreen(categoryTitle: title),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValuesCompat(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                _localizedEntertainmentTitle(title, l10n),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedEntertainmentTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Puppet Show' => l10n.puppetShows,
      'Interactive Stories' => l10n.interactiveStories,
      'Songs & Music' => l10n.songsAndMusic,
      'Funny Clips' => l10n.funnyClips,
      'Brain Teasers' => l10n.entertainmentBrainTeasers,
      'Games' => l10n.entertainmentGames,
      'Cartoons' => l10n.entertainmentCartoons,
      _ => raw,
    };
  }
}

String _normalizeCmsPlacementToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-–—&/]+'), '')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');
}

String _localizedCmsCategoryTitle(
  BuildContext context,
  PublicContentCategory category,
) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred =
      locale.startsWith('ar') ? category.titleAr : category.titleEn;
  final fallback =
      locale.startsWith('ar') ? category.titleEn : category.titleAr;
  return preferred.trim().isNotEmpty ? preferred : fallback;
}

String _localizedCmsCategoryDescription(
  BuildContext context,
  PublicContentCategory category,
) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred =
      locale.startsWith('ar') ? category.descriptionAr : category.descriptionEn;
  final fallback =
      locale.startsWith('ar') ? category.descriptionEn : category.descriptionAr;
  return (preferred ?? fallback ?? '').trim();
}

String _localizedCmsItemTitle(BuildContext context, PublicContentItem item) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred = locale.startsWith('ar') ? item.titleAr : item.titleEn;
  final fallback = locale.startsWith('ar') ? item.titleEn : item.titleAr;
  return preferred.trim().isNotEmpty ? preferred : fallback;
}

String _localizedCmsItemDescription(
    BuildContext context, PublicContentItem item) {
  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred =
      locale.startsWith('ar') ? item.descriptionAr : item.descriptionEn;
  final fallback =
      locale.startsWith('ar') ? item.descriptionEn : item.descriptionAr;
  return (preferred ?? fallback ?? '').trim();
}

Color _axisColor(String axisKey) {
  return switch (axisKey) {
    ActivityAspects.behavioral => AppColors.behavioral,
    ActivityAspects.skillful => AppColors.skillful,
    ActivityAspects.educational => AppColors.educational,
    ActivityAspects.entertaining => AppColors.entertaining,
    _ => AppColors.primary,
  };
}

IconData _axisIcon(String axisKey) {
  return switch (axisKey) {
    ActivityAspects.behavioral => Icons.favorite_rounded,
    ActivityAspects.skillful => Icons.brush_rounded,
    ActivityAspects.educational => Icons.school_rounded,
    ActivityAspects.entertaining => Icons.celebration_rounded,
    _ => Icons.auto_stories_rounded,
  };
}

class _CmsAxisCategoryGrid extends StatelessWidget {
  const _CmsAxisCategoryGrid({
    required this.categoriesState,
    required this.axisKey,
    required this.fallbackBuilder,
  });

  final AsyncValue<List<PublicContentCategory>> categoriesState;
  final String axisKey;
  final WidgetBuilder fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    final categories =
        (categoriesState.valueOrNull ?? const <PublicContentCategory>[])
            .where((category) => category.axisKey == axisKey)
            .toList(growable: false);

    if (categoriesState.isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (categories.isEmpty) {
      return fallbackBuilder(context);
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return _CmsCategoryCard(
          category: categories[index],
          axisKey: axisKey,
        );
      },
    );
  }
}

class _CmsAxisCategoryList extends StatelessWidget {
  const _CmsAxisCategoryList({
    required this.categoriesState,
    required this.axisKey,
    required this.fallbackBuilder,
  });

  final AsyncValue<List<PublicContentCategory>> categoriesState;
  final String axisKey;
  final WidgetBuilder fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    final categories =
        (categoriesState.valueOrNull ?? const <PublicContentCategory>[])
            .where((category) => category.axisKey == axisKey)
            .toList(growable: false);

    if (categoriesState.isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (categories.isEmpty) {
      return fallbackBuilder(context);
    }

    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _CmsCategoryListTile(
          category: categories[index],
          axisKey: axisKey,
        );
      },
    );
  }
}

class _CmsCategoryCard extends StatelessWidget {
  const _CmsCategoryCard({
    required this.category,
    required this.axisKey,
  });

  final PublicContentCategory category;
  final String axisKey;

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(axisKey);
    final count = category.contentCount + category.quizCount;
    return InkWell(
      onTap: () => _openCmsCategory(context, category, axisKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValuesCompat(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: color.withValuesCompat(alpha: 0.14),
              child: Icon(_axisIcon(axisKey), color: color, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              _localizedCmsCategoryTitle(context, category),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CmsCategoryListTile extends StatelessWidget {
  const _CmsCategoryListTile({
    required this.category,
    required this.axisKey,
  });

  final PublicContentCategory category;
  final String axisKey;

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(axisKey);
    final description = _localizedCmsCategoryDescription(context, category);
    return InkWell(
      onTap: () => _openCmsCategory(context, category, axisKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: color.withValuesCompat(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_axisIcon(axisKey), color: color, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedCmsCategoryTitle(context, category),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

void _openCmsCategory(
  BuildContext context,
  PublicContentCategory category,
  String axisKey,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CmsCategoryContentScreen(
        categorySlug: category.slug,
        axisKey: axisKey,
        title: _localizedCmsCategoryTitle(context, category),
      ),
    ),
  );
}

class CmsCategoryContentScreen extends ConsumerStatefulWidget {
  const CmsCategoryContentScreen({
    super.key,
    required this.categorySlug,
    required this.axisKey,
    required this.title,
  });

  final String categorySlug;
  final String axisKey;
  final String title;

  @override
  ConsumerState<CmsCategoryContentScreen> createState() =>
      _CmsCategoryContentScreenState();
}

class _CmsCategoryContentScreenState
    extends ConsumerState<CmsCategoryContentScreen> {
  late Future<List<PublicContentItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = ref.read(publicContentRepositoryProvider).fetchItems(
          categorySlug: widget.categorySlug,
        );
  }

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(widget.axisKey);
    return Scaffold(
      backgroundColor: color.withValuesCompat(alpha: 0.08),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ChildHeader(
              compact: true,
              padding: EdgeInsets.only(bottom: 16),
            ),
            Expanded(
              child: FutureBuilder<List<PublicContentItem>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? const <PublicContentItem>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.noPagesFound,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _CmsContentItemCard(
                        item: items[index],
                        axisKey: widget.axisKey,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CmsContentItemCard extends StatelessWidget {
  const _CmsContentItemCard({
    required this.item,
    required this.axisKey,
  });

  final PublicContentItem item;
  final String axisKey;

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(axisKey);
    final title = _localizedCmsItemTitle(context, item);
    final description = _localizedCmsItemDescription(context, item);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage =
        thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        if (item.hasVideo) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SkillVideoScreen(
                videoTitle: title,
                videoUrl: item.preferredVideoUrl,
                thumbnailUrl: item.effectiveThumbnailUrl,
                description: description.isNotEmpty ? description : null,
              ),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _GenericCmsTextContentScreen(
              item: item,
              axisKey: axisKey,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 92,
                height: 92,
                child: hasRemoteImage
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _CmsContentFallbackIcon(axisKey: axisKey),
                      )
                    : _CmsContentFallbackIcon(axisKey: axisKey),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Icon(
                    item.hasVideo
                        ? Icons.play_circle_fill_rounded
                        : Icons.article_rounded,
                    color: color,
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

class _CmsContentFallbackIcon extends StatelessWidget {
  const _CmsContentFallbackIcon({required this.axisKey});

  final String axisKey;

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(axisKey);
    return Container(
      color: color.withValuesCompat(alpha: 0.12),
      child: Icon(_axisIcon(axisKey), color: color, size: 38),
    );
  }
}

class _GenericCmsTextContentScreen extends StatelessWidget {
  const _GenericCmsTextContentScreen({
    required this.item,
    required this.axisKey,
  });

  final PublicContentItem item;
  final String axisKey;

  @override
  Widget build(BuildContext context) {
    final color = _axisColor(axisKey);
    final title = _localizedCmsItemTitle(context, item);
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final body = (locale.startsWith('ar') ? item.bodyAr : item.bodyEn) ??
        (locale.startsWith('ar') ? item.bodyEn : item.bodyAr) ??
        _localizedCmsItemDescription(context, item);
    return Scaffold(
      backgroundColor: color.withValuesCompat(alpha: 0.08),
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ChildHeader(
            compact: true,
            padding: EdgeInsets.only(bottom: 16),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              body.trim().isEmpty ? title : body,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// NEW: Entertainment Detail Screen (Shows content for Games, Cartoons, etc.)
class EntertainmentDetailScreen extends ConsumerStatefulWidget {
  final String categoryTitle;
  const EntertainmentDetailScreen({super.key, required this.categoryTitle});

  @override
  ConsumerState<EntertainmentDetailScreen> createState() =>
      _EntertainmentDetailScreenState();
}

class _EntertainmentDetailScreenState
    extends ConsumerState<EntertainmentDetailScreen> {
  late Future<List<PublicContentItem>> _cmsContentFuture;

  @override
  void initState() {
    super.initState();
    _cmsContentFuture = _loadCmsContent();
  }

  Future<List<PublicContentItem>> _loadCmsContent() async {
    final repository = ref.read(publicContentRepositoryProvider);
    final categorySlug = await _cmsCategorySlug(repository);
    if (categorySlug != null) {
      final directItems =
          await repository.fetchItems(categorySlug: categorySlug);
      if (directItems.isNotEmpty) {
        return directItems;
      }
    }

    final items = await repository.fetchItems();
    return items.where(_matchesCmsPlacement).toList();
  }

  Future<String?> _cmsCategorySlug(PublicContentRepository repository) async {
    final categories = await repository.fetchCategories();
    final selectedTerms = _entertainmentSearchTerms()
        .map(_normalizeCmsPlacementToken)
        .where((term) => term.isNotEmpty)
        .toSet();
    for (final category in categories) {
      if (category.axisKey != 'entertaining') {
        continue;
      }
      final categoryTerms = [
        category.slug,
        category.titleEn,
        category.titleAr,
      ].map(_normalizeCmsPlacementToken);
      if (categoryTerms.any(selectedTerms.contains)) {
        return category.slug;
      }
    }
    return null;
  }

  bool _matchesCmsPlacement(PublicContentItem item) {
    final isEntertaining = item.axisKey == 'entertaining' ||
        item.category?.axisKey == 'entertaining' ||
        item.metadata['axis_key'] == 'entertaining';
    if (!isEntertaining) {
      return false;
    }

    final terms = _entertainmentSearchTerms()
        .map(_normalizeCmsPlacementToken)
        .where((term) => term.isNotEmpty)
        .toList();
    final haystack = [
      item.slug,
      item.titleEn,
      item.titleAr,
      item.descriptionEn ?? '',
      item.descriptionAr ?? '',
      item.category?.slug ?? '',
      item.category?.titleEn ?? '',
      item.category?.titleAr ?? '',
    ].map(_normalizeCmsPlacementToken).join(' ');
    return terms.any(haystack.contains);
  }

  List<String> _entertainmentSearchTerms() {
    final raw = widget.categoryTitle.trim().toLowerCase();
    return switch (raw) {
      'puppet show' => [
          'puppet',
          'puppet show',
          'puppet shows',
          'puppets',
          'دمى',
          'عرائس',
        ],
      'interactive stories' => [
          'interactive stories',
          'interactive story',
          'stories',
          'story',
          'قصص',
          'حكايات',
        ],
      'songs & music' => [
          'songs',
          'music',
          'song',
          'اغاني',
          'أناشيد',
          'موسيقى',
        ],
      'funny clips' => ['funny clips', 'clips', 'funny', 'ضحك', 'مضحك'],
      'brain teasers' => [
          'brain teasers',
          'brain teaser',
          'teasers',
          'puzzle',
          'الغاز',
          'ألغاز',
        ],
      'games' => ['games', 'game', 'ألعاب', 'العاب'],
      'cartoons' => ['cartoons', 'cartoon', 'كرتون', 'رسوم'],
      _ => [raw],
    };
  }

  List<Map<String, String>> _getItems() {
    switch (widget.categoryTitle) {
      case 'Games':
        return const [
          {'title': 'Puzzle Game', 'image': 'assets/images/ent_games.png'},
          {'title': 'Memory Match', 'image': 'assets/images/ent_games.png'},
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _getItems();
    final isGamesCategory = widget.categoryTitle == 'Games';

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: Text(
          _localizedCategoryTitle(l10n),
          style: const TextStyle(
            color: AppColors.entertaining,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            if (isGamesCategory) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValuesCompat(alpha: 0.86),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.entertaining.withValuesCompat(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.entertaining
                            .withValuesCompat(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.games_rounded,
                        color: AppColors.entertaining,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _gameBannerMessage(context),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.entertaining,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: FutureBuilder<List<PublicContentItem>>(
                future: _cmsContentFuture,
                builder: (context, snapshot) {
                  final cmsItems = snapshot.data ?? const <PublicContentItem>[];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty && cmsItems.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noLessonsFound,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: cmsItems.length + items.length,
                    itemBuilder: (context, index) {
                      if (index < cmsItems.length) {
                        return _buildCmsContentCard(context, cmsItems[index]);
                      }
                      final item = items[index - cmsItems.length];
                      return _buildContentCard(
                        context,
                        rawTitle: item['title']!,
                        title: _localizedContentTitle(item['title']!, l10n),
                        imagePath: item['image']!,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmsContentCard(BuildContext context, PublicContentItem item) {
    final title = _localizedCmsTitle(item);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage = thumbnailUrl != null &&
        thumbnailUrl.trim().isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SkillVideoScreen(
            videoTitle: title,
            videoUrl: item.preferredVideoUrl,
            thumbnailUrl: item.effectiveThumbnailUrl,
            description: item.descriptionEn ?? item.descriptionAr,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasRemoteImage)
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildEntertainmentFallback(),
                )
              else
                _buildEntertainmentFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValuesCompat(alpha: 0.68),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntertainmentFallback() {
    return Container(
      color: AppColors.entertaining.withValuesCompat(alpha: 0.18),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: AppColors.entertaining,
          size: 58,
        ),
      ),
    );
  }

  String _localizedCmsTitle(PublicContentItem item) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final preferred = locale.startsWith('ar') ? item.titleAr : item.titleEn;
    final fallback = locale.startsWith('ar') ? item.titleEn : item.titleAr;
    return preferred.trim().isNotEmpty ? preferred : fallback;
  }

  Widget _buildContentCard(
    BuildContext context, {
    required String rawTitle,
    required String title,
    required String imagePath,
  }) {
    return InkWell(
      onTap: () => _openEntertainmentItem(context, rawTitle),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openEntertainmentItem(BuildContext context, String rawTitle) {
    Widget? screen;
    switch (rawTitle) {
      case 'Puzzle Game':
        screen = const PuzzleHubGameScreen();
        break;
      case 'Memory Match':
        screen = const PremiumMemoryMatchGameScreen();
        break;
      case 'Catch the Falling Stars':
        screen = _FunArcadeGameScreen(config: _arcadeGames[0]);
        break;
      case 'Whack the Animal':
        screen = _FunArcadeGameScreen(config: _arcadeGames[1]);
        break;
      case 'Pop the Balloons':
        screen = _FunArcadeGameScreen(config: _arcadeGames[2]);
        break;
      case 'Turtle Run':
        screen = _FunArcadeGameScreen(config: _arcadeGames[3]);
        break;
      case 'Funny Paint':
        screen = _FunArcadeGameScreen(config: _arcadeGames[4]);
        break;
    }

    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_comingSoonMessage(context))),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen!),
    );
  }

  String _localizedCategoryTitle(AppLocalizations l10n) {
    return switch (widget.categoryTitle) {
      'Games' => l10n.entertainmentGames,
      'Cartoons' => l10n.entertainmentCartoons,
      'Songs & Music' => l10n.songsAndMusic,
      'Puppet Show' => l10n.puppetShows,
      'Interactive Stories' => l10n.interactiveStories,
      'Funny Clips' => l10n.funnyClips,
      'Brain Teasers' => l10n.entertainmentBrainTeasers,
      _ => widget.categoryTitle,
    };
  }

  String _localizedContentTitle(String raw, AppLocalizations l10n) {
    final isArabic =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar';
    return switch (raw) {
      'Puzzle Game' => l10n.contentPuzzleGame,
      'Memory Match' => l10n.historyMemoryGame,
      'Catch the Falling Stars' => isArabic ? '?????? ??????' : raw,
      'Whack the Animal' => isArabic ? '???? ???????' : raw,
      'Pop the Balloons' => isArabic ? '????? ?????????' : raw,
      'Turtle Run' => isArabic ? '??? ????????' : raw,
      'Funny Paint' => isArabic ? '????? ?????' : raw,
      'Friendly Puppets' => isArabic ? 'الدمى المرحة' : raw,
      'Animal Parade' => isArabic ? 'موكب الحيوانات' : raw,
      'Rainbow Stage' => isArabic ? 'مسرح قوس المطر' : raw,
      'Bedtime Puppet Tale' => isArabic ? 'حكاية الدمى قبل النوم' : raw,
      'Brave Little Star' => isArabic ? 'النجمة الصغيرة الشجاعة' : raw,
      'Forest Adventure' => isArabic ? 'مغامرة في الغابة' : raw,
      'Sharing Day' => isArabic ? 'يوم المشاركة' : raw,
      'The Lost Balloon' => isArabic ? 'البالون الضائع' : raw,
      'Silly Faces' => isArabic ? 'وجوه مضحكة' : raw,
      'Dancing Penguin' => isArabic ? 'البطريق الراقص' : raw,
      'Giggle Train' => isArabic ? 'قطار الضحكات' : raw,
      'Jumpy Jelly Beans' => isArabic ? 'حبات الفاصوليا القافزة' : raw,
      'Match the Shadow' => isArabic ? 'طابق الظل' : raw,
      'Find the Difference' => isArabic ? 'اكتشف الاختلاف' : raw,
      'Shape Detective' => isArabic ? 'محقق الأشكال' : raw,
      'Color Clue Quest' => isArabic ? 'مهمة دليل الألوان' : raw,
      'Adventure Time' => l10n.contentAdventureTime,
      'Funny Animals' => l10n.contentFunnyAnimals,
      'Space Heroes' => l10n.contentSpaceHeroes,
      'Magic World' => l10n.contentMagicWorld,
      'ABC Song' => l10n.contentAbcSong,
      'Baby Shark' => l10n.contentBabyShark,
      'Twinkle Star' => l10n.contentTwinkleStar,
      'Dance Party' => isArabic ? 'حفلة الرقص' : raw,
      _ => raw,
    };
  }

  String _gameBannerMessage(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? 'في هذا القسم ستجدين Puzzle World ولعبة Memory Match مع مجموعة ألعاب ممتعة ومتدرجة.'
        : 'This section now includes Puzzle World and the new premium Memory Match game.';
  }

  String _comingSoonMessage(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? 'هذا المحتوى سيتوفر قريباً.'
        : 'This content is coming soon.';
  }

  String _gameBannerText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? 'في هذا القسم ستجدين Puzzle World ولعبة Memory Match الجديدة بتصميم أسود وذهبي ومستويات متدرجة.'
        : 'This section now includes Puzzle World and the new premium Memory Match game.';
  }

  String _comingSoonText(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? '??? ??????? ?????? ??????.'
        : 'This content is coming soon.';
  }
}

class PuzzleGameScreen extends ConsumerStatefulWidget {
  const PuzzleGameScreen({super.key});

  @override
  ConsumerState<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends ConsumerState<PuzzleGameScreen> {
  static final List<_PuzzleLevel> _levels = List.generate(50, (index) {
    const accents = [
      Color(0xFFFFA726),
      Color(0xFFEC407A),
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
    ];
    final number = index + 1;
    final size = number <= 15 ? 3 : (number <= 35 ? 4 : 5);
    final baseTime = size == 3 ? 210 : (size == 4 ? 170 : 130);
    final minTime = size == 3 ? 90 : (size == 4 ? 70 : 55);
    final step = size == 3 ? 4 : (size == 4 ? 3 : 2);
    final rawTime = baseTime - (index * step);
    final time = rawTime < minTime ? minTime : rawTime;
    return _PuzzleLevel(
      id: 'puzzle_$number',
      size: size,
      accent: accents[index % accents.length],
      timeLimitSeconds: time,
    );
  });

  static const List<String> _customArtworkFolders = [
    'assets/images/picture_puzzle/',
  ];

  late _PuzzleLevel _selectedLevel;
  final _GameAudioController _audio = _GameAudioController();
  Timer? _timer;
  int _moveCount = 0;
  int _remainingSeconds = 0;
  bool _isSolved = false;
  bool _isLost = false;
  bool _isLoadingProgress = true;
  bool _isLoadingGallery = true;
  bool _isRecordingCompletion = false;
  late List<int> _availablePieces;
  late List<String> _artworkPaths;
  Map<int, int> _placedPieces = <int, int>{};
  Map<String, _PuzzleLevelProgress> _progressByLevel = const {};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  int get _boardSize => _selectedLevel.size;
  int get _puzzleUnlockedLevelIndex {
    var unlocked = 0;
    for (var i = 0; i < _levels.length - 1; i++) {
      final stars = _progressByLevel[_levels[i].id]?.bestStars ?? 0;
      if (stars > 0) {
        unlocked = i + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }

  int _puzzleStarsFor(_PuzzleLevel level) =>
      _progressByLevel[level.id]?.bestStars ?? 0;
  bool get _hasArtworkLibrary => _artworkPaths.isNotEmpty;
  int get _pieceCount => _boardSize * _boardSize;
  int get _elapsedSeconds =>
      _selectedLevel.timeLimitSeconds - _remainingSeconds;
  int get _selectedLevelIndex => _levels.indexOf(_selectedLevel);
  int get _scorePoints {
    final placementPoints = _placedPieces.length * 12;
    final timeBonus = _remainingSeconds;
    final efficiencyBonus = math.max(0, (_pieceCount * 3) - _moveCount);
    return placementPoints + timeBonus + efficiencyBonus;
  }

  int get _currentArtworkIndex {
    if (_artworkPaths.isEmpty) return 0;
    return _selectedLevelIndex % _artworkPaths.length;
  }

  String get _currentImagePath => _artworkPaths[_currentArtworkIndex];
  _PuzzleLevelProgress get _currentProgress =>
      _progressByLevel[_selectedLevel.id] ?? const _PuzzleLevelProgress();

  @override
  void initState() {
    super.initState();
    _selectedLevel = _levels.first;
    _remainingSeconds = _selectedLevel.timeLimitSeconds;
    _availablePieces = const [];
    _artworkPaths = const [];
    unawaited(_audio.startBackground('sounds/games/puzzle_bg.mp3'));
    _loadArtworkLibrary();
    _loadProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _loadArtworkLibrary() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = manifest.listAssets().where((assetPath) {
        return _isSupportedArtwork(assetPath) &&
            _customArtworkFolders.any(assetPath.startsWith);
      }).toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _artworkPaths = discovered;
        _isLoadingGallery = false;
      });
      if (discovered.isNotEmpty) {
        _startLevel(resetClock: true);
      } else {
        _timer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkPaths = const [];
        _isLoadingGallery = false;
      });
      _timer?.cancel();
    }
  }

  bool _isSupportedArtwork(String assetPath) {
    final lower = assetPath.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoadingProgress = true);
    final prefs = await SharedPreferences.getInstance();
    final map = <String, _PuzzleLevelProgress>{};
    for (final level in _levels) {
      map[level.id] = _PuzzleLevelProgress(
        bestTimeSeconds: prefs.getInt('puzzle_best_time_${level.id}'),
        bestStars: prefs.getInt('puzzle_best_stars_${level.id}') ?? 0,
      );
    }
    if (!mounted) return;
    setState(() {
      _progressByLevel = map;
      _isLoadingProgress = false;
    });
  }

  Future<void> _saveProgressIfNeeded(int earnedStars) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _currentProgress;
    var bestTime = current.bestTimeSeconds;
    var bestStars = current.bestStars;
    if (bestTime == null || _elapsedSeconds < bestTime) {
      await prefs.setInt(
          'puzzle_best_time_${_selectedLevel.id}', _elapsedSeconds);
      bestTime = _elapsedSeconds;
    }
    if (earnedStars > bestStars) {
      await prefs.setInt('puzzle_best_stars_${_selectedLevel.id}', earnedStars);
      bestStars = earnedStars;
    }
    if (!mounted) return;
    setState(() {
      _progressByLevel = {
        ..._progressByLevel,
        _selectedLevel.id: _PuzzleLevelProgress(
            bestTimeSeconds: bestTime, bestStars: bestStars),
      };
    });
  }

  void _startLevel({bool resetClock = false}) {
    _timer?.cancel();
    final pieces = List<int>.generate(_pieceCount, (index) => index + 1)
      ..shuffle();
    setState(() {
      _availablePieces = pieces;
      _placedPieces = <int, int>{};
      _moveCount = 0;
      _isSolved = false;
      _isLost = false;
      if (resetClock) _remainingSeconds = _selectedLevel.timeLimitSeconds;
    });
    _startTimer();
  }

  void _changeLevel(_PuzzleLevel level) {
    setState(() {
      _selectedLevel = level;
      _remainingSeconds = level.timeLimitSeconds;
      _isSolved = false;
      _isLost = false;
    });
    _startLevel(resetClock: true);
  }

  Future<void> _openPuzzleLevelPicker() async {
    final picked = await Navigator.of(context).push<_PuzzleLevel>(
      MaterialPageRoute(
        builder: (context) => _PuzzleLevelGridScreen(
          title: _isArabic ? '??????? ??????' : 'Puzzle Levels',
          accent: _selectedLevel.accent,
          levels: _levels,
          selectedLevel: _selectedLevel,
          labelBuilder: _levelLabel,
          unlockedIndex: _puzzleUnlockedLevelIndex,
          starsForLevel: _puzzleStarsFor,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _changeLevel(picked);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isSolved || _isLost) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _isLost = true;
        });
        _timer?.cancel();
        unawaited(_audio.playEffect('sounds/games/puzzle_lose.mp3',
            fallback: SystemSoundType.click));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showLostDialog();
        });
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  bool _canAcceptPiece(int slotIndex, int pieceValue) {
    if (_isSolved || _isLost) return false;
    return pieceValue == slotIndex + 1 && !_placedPieces.containsKey(slotIndex);
  }

  void _placePiece(int slotIndex, int pieceValue) {
    if (!_canAcceptPiece(slotIndex, pieceValue)) return;
    setState(() {
      _placedPieces = {..._placedPieces, slotIndex: pieceValue};
      _availablePieces = List<int>.from(_availablePieces)..remove(pieceValue);
      _moveCount += 1;
      _isSolved = _placedPieces.length == _pieceCount;
    });
    if (_isSolved) {
      _timer?.cancel();
      unawaited(_audio.playEffect('sounds/games/puzzle_win.mp3',
          fallback: SystemSoundType.alert));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSolvedDialog();
      });
    }
  }

  int _calculateStars() {
    final accuracyRatio = _pieceCount / (_moveCount == 0 ? 1 : _moveCount);
    final timeRatio = _remainingSeconds / _selectedLevel.timeLimitSeconds;
    if (accuracyRatio >= 0.95 && timeRatio >= 0.40) return 3;
    if (accuracyRatio >= 0.75 && timeRatio >= 0.18) return 2;
    return 1;
  }

  Future<void> _recordPuzzleCompletion(int earnedStars) async {
    if (_isRecordingCompletion) return;

    final childProfile = ref.read(currentChildProvider);
    if (childProfile == null) {
      return;
    }

    _isRecordingCompletion = true;
    try {
      final score = switch (earnedStars) {
        3 => 100,
        2 => 88,
        _ => 76,
      };
      final durationMinutes = math.max(1, (_elapsedSeconds / 60).ceil());
      final xpEarned = (earnedStars * 20) + (_selectedLevel.size * 5);

      await ref
          .read(progressControllerProvider.notifier)
          .recordActivityCompletion(
        childId: childProfile.id,
        activityId: 'game_${_selectedLevel.id}',
        score: score,
        duration: durationMinutes,
        xpEarned: xpEarned,
        notes: 'Puzzle Game - ${_levelLabel(_selectedLevel)}',
        performanceMetrics: {
          'stars': earnedStars,
          'moves': _moveCount,
          'time_seconds': _elapsedSeconds,
          'time_remaining_seconds': _remainingSeconds,
          'board_size': _boardSize,
          'pieces': _pieceCount,
          'puzzle_score': _scorePoints,
          'image_path': _currentImagePath,
        },
      );
    } finally {
      _isRecordingCompletion = false;
    }
  }

  Future<void> _showSolvedDialog() async {
    final earnedStars = _calculateStars();
    await _saveProgressIfNeeded(earnedStars);
    await _recordPuzzleCompletion(earnedStars);
    if (!mounted) return;
    unawaited(_audio.playEffect('sounds/games/memory_win.mp3',
        fallback: SystemSoundType.alert));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _selectedLevel.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(_isArabic ? '?????!' : 'Great Job!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic
                  ? '?????? ?????? ?? ${_formatTime(_elapsedSeconds)} ??? $_moveCount ??????.'
                  : 'The picture was completed in ${_formatTime(_elapsedSeconds)} with $_moveCount placements.',
            ),
            const SizedBox(height: 14),
            _StarRow(stars: earnedStars, accent: _selectedLevel.accent),
            const SizedBox(height: 10),
            Text(
              _currentProgress.bestTimeSeconds == null
                  ? (_isArabic
                      ? '?? ??? ??? ????? ????? ???? ???????.'
                      : 'Your first best result for this level has been saved.')
                  : (_isArabic
                      ? '???? ???: ${_formatTime(_currentProgress.bestTimeSeconds!)}'
                      : 'Best time: ${_formatTime(_currentProgress.bestTimeSeconds!)}'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startLevel(resetClock: true);
            },
            child: Text(_isArabic ? '????? ???????' : 'Replay Level'),
          ),
          if (_selectedLevel != _levels.last)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _changeLevel(_levels[_levels.indexOf(_selectedLevel) + 1]);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: _selectedLevel.accent),
              child: Text(_isArabic ? '??????? ??????' : 'Next Level'),
            ),
        ],
      ),
    );
  }

  Future<void> _showLostDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(_isArabic ? '????? ?????' : 'Time Is Up')),
          ],
        ),
        content: Text(
          _isArabic
              ? '????? ????? ??? ?????? ??????. ???? ??? ????? ?? ??????? ??????? ????? ????.'
              : 'Time ran out before the picture was complete. Try placing the pieces faster.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startLevel(resetClock: true);
            },
            child: Text(_isArabic ? '????? ????????' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: _isArabic ? '???? ?????' : 'Picture Puzzle',
      subtitle: _isSolved
          ? (_isArabic
              ? '?????? ?????? ???????.'
              : 'The picture is fully assembled.')
          : _isLost
              ? (_isArabic
                  ? '????? ????? ??? ?????? ??????.'
                  : 'Time ran out before the picture was complete.')
              : (_isArabic
                  ? '????? ?? ???? ??? ?????? ?????? ??? ?????? ??????.'
                  : 'Drag each piece into its correct place to build the full picture.'),
      accent: _selectedLevel.accent,
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => _startLevel(resetClock: true),
            icon: const Icon(Icons.refresh),
            label: Text(_isArabic ? '?????' : 'Reset'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPuzzleHeader(),
          const SizedBox(height: 18),
          _buildPreviewCard(),
          if (_hasArtworkLibrary) ...[
            const SizedBox(height: 16),
            _buildAssemblyBoard(),
            const SizedBox(height: 18),
            _buildPieceTray(),
            const SizedBox(height: 18),
            _buildHowToPlay(),
          ] else ...[
            const SizedBox(height: 16),
            _buildPuzzleEmptyState(),
          ],
          const SizedBox(height: 18),
          _buildAchievementsBoard(),
        ],
      ),
    );
  }

  Widget _buildPuzzleHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelGridLauncher(
          title: _isArabic ? 'Choose Puzzle Level' : 'Choose Level',
          subtitle: _levelLabel(_selectedLevel),
          accent: _selectedLevel.accent,
          icon: Icons.extension_rounded,
          onTap: _openPuzzleLevelPicker,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PuzzleStatCard(
                icon: Icons.grid_view_rounded,
                label: 'Grid',
                value: 'x',
                accent: _selectedLevel.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PuzzleStatCard(
                icon: Icons.workspace_premium_rounded,
                label: 'Score',
                value: '',
                accent: Colors.amber.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PuzzleStatCard(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Time',
                value: _formatTime(_remainingSeconds),
                accent: _remainingSeconds <= 15
                    ? Colors.redAccent
                    : _selectedLevel.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PuzzleStatCard(
                icon: Icons.ads_click_rounded,
                label: 'Placed',
                value: '/',
                accent: _selectedLevel.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PuzzleStatCard(
                icon: Icons.touch_app_rounded,
                label: 'Moves',
                value: '',
                accent: const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    if (!_hasArtworkLibrary) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: _selectedLevel.accent.withValuesCompat(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: _selectedLevel.accent.withValuesCompat(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                color: _selectedLevel.accent,
                size: 36,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic ? '????? ??? ??????' : 'Add Puzzle Images',
                    style: TextStyle(
                      color: _selectedLevel.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isArabic
                        ? '?????? ???? ?????? ??? ????. ??? ???? ???? assets/images/picture_puzzle/ ?? ????? Hot Restart.'
                        : 'This game now uses only your images. Add puzzle photos inside assets/images/picture_puzzle/, then run a hot restart.',
                    style: const TextStyle(fontSize: 14.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.16)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(_currentImagePath,
                width: 92, height: 92, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic
                      ? '???? ??????? ${_selectedLevelIndex + 1}'
                      : 'Level ${_selectedLevelIndex + 1} Picture',
                  style: TextStyle(
                      color: _selectedLevel.accent,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLoadingGallery
                      ? (_isArabic
                          ? '??? ????? ??? ?????????...'
                          : 'Loading the picture library...')
                      : (_isArabic
                          ? '?? ????? ????? ????? ?????? ????????. ??? ??? ??? ????? ??? ?? ??? ????????? ????? ????? ????????? ????????.'
                          : 'Each level is linked to a different picture automatically. If there are fewer pictures than levels, they are reused in order.'),
                  style: const TextStyle(fontSize: 14.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: _selectedLevel.accent, size: 42),
          const SizedBox(height: 12),
          Text(
            _isArabic
                ? '?? ???? ??? ???? ????? ???'
                : 'No puzzle images added yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _selectedLevel.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? '????? ??? ????? ???? ?????? ????????? ???? assets/images/picture_puzzle/. ?? ???? ?? ??? ???????? ??? ????.'
                : 'Add only the images you want to use inside assets/images/picture_puzzle/. No built-in pictures are shown anymore.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsBoard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: _selectedLevel.accent),
              const SizedBox(width: 10),
              Text(
                  _isArabic
                      ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¬ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ²ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾'
                      : 'Achievements Board',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _selectedLevel.accent)),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingProgress)
            Text(
                _isArabic
                    ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¬ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¹ط£آ¢أ¢â€ڑآ¬ط¢آ  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¬...'
                    : 'Loading results...',
                style: const TextStyle(fontWeight: FontWeight.w600))
          else
            ..._levels.map((level) {
              final progress =
                  _progressByLevel[level.id] ?? const _PuzzleLevelProgress();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: level.accent.withValuesCompat(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_levelLabel(level),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: level.accent)),
                          const SizedBox(height: 4),
                          Text(progress.bestTimeSeconds == null
                              ? (_isArabic
                                  ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¬ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¯ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¶ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¯'
                                  : 'No best time yet')
                              : (_isArabic
                                  ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¶ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾: ${_formatTime(progress.bestTimeSeconds!)}'
                                  : 'Best time: ${_formatTime(progress.bestTimeSeconds!)}')),
                        ],
                      ),
                    ),
                    _StarRow(stars: progress.bestStars, accent: level.accent),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAssemblyBoard() {
    final spacing = _boardSize == 5 ? 3.0 : 4.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSizePx = constraints.maxWidth.clamp(220.0, 420.0).toDouble();
        final slotSize =
            (boardSizePx - ((_boardSize - 1) * spacing)) / _boardSize;
        return Center(
          child: Container(
            width: boardSizePx,
            height: boardSizePx,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: _selectedLevel.accent.withValuesCompat(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Opacity(
                      opacity: 0.14,
                      child: Image.asset(_currentImagePath, fit: BoxFit.cover),
                    ),
                  ),
                ),
                for (int slotIndex = 0; slotIndex < _pieceCount; slotIndex++)
                  Positioned(
                    left: (slotIndex % _boardSize) * (slotSize + spacing),
                    top: (slotIndex ~/ _boardSize) * (slotSize + spacing),
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (details) =>
                          _canAcceptPiece(slotIndex, details.data),
                      onAcceptWithDetails: (details) =>
                          _placePiece(slotIndex, details.data),
                      builder: (context, candidateData, rejectedData) {
                        final placedPiece = _placedPieces[slotIndex];
                        final isHot = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: slotSize,
                          height: slotSize,
                          decoration: BoxDecoration(
                            color: placedPiece == null
                                ? (isHot
                                    ? _selectedLevel.accent
                                        .withValuesCompat(alpha: 0.18)
                                    : _selectedLevel.accent
                                        .withValuesCompat(alpha: 0.08))
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: placedPiece != null
                                  ? Colors.green.withValuesCompat(alpha: 0.85)
                                  : _selectedLevel.accent.withValuesCompat(
                                      alpha: isHot ? 0.8 : 0.22),
                              width: placedPiece != null ? 2.4 : 1.4,
                            ),
                          ),
                          child: placedPiece != null
                              ? _PuzzleImageTile(
                                  imagePath: _currentImagePath,
                                  tileValue: placedPiece,
                                  boardSize: _boardSize,
                                  isCorrect: true)
                              : Icon(Icons.add_rounded,
                                  color: _selectedLevel.accent
                                      .withValuesCompat(alpha: 0.28)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPieceTray() {
    final remainingCount = _availablePieces.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic
                ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ·ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ²ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ©'
                : 'Remaining Puzzle Pieces',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: _selectedLevel.accent),
          ),
          const SizedBox(height: 6),
          Text(
            _isArabic
                ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ·ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¥ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ° ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¦ط£آ¢أ¢â€ڑآ¬أ¢â€‍آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ·ط¥â€™ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­. ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع© ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ· ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¯ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ·ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع© ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­.'
                : 'Drag a piece to its matching spot. It will snap only when the position is correct.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (remainingCount == 0)
            Center(
              child: Text(
                _isArabic
                    ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¦ط£آ¢أ¢â€ڑآ¬أ¢â€‍آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¬ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ·ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ° ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ©.'
                    : 'All pieces are placed on the board.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availablePieces.map((pieceValue) {
                return Draggable<int>(
                  data: pieceValue,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.black.withValuesCompat(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: _PuzzleImageTile(
                            imagePath: _currentImagePath,
                            tileValue: pieceValue,
                            boardSize: _boardSize,
                            isCorrect: true),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.18,
                    child: _TrayPuzzlePiece(
                        imagePath: _currentImagePath,
                        tileValue: pieceValue,
                        boardSize: _boardSize,
                        accent: _selectedLevel.accent),
                  ),
                  child: _TrayPuzzlePiece(
                      imagePath: _currentImagePath,
                      tileValue: pieceValue,
                      boardSize: _boardSize,
                      accent: _selectedLevel.accent),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: _selectedLevel.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isArabic
                  ? 'ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¦ط£آ¢أ¢â€ڑآ¬أ¢â€‍آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ·ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ© ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ  ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¦ط£آ¢أ¢â€ڑآ¬أ¢â€‍آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ·ط¥â€™ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ©. ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¦ط£آ¢أ¢â€ڑآ¬أ¢â€‍آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ  ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ­ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ·ط¥â€™ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ·ط¥â€™ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ«ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¹ط·آ¢ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع© ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¢ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ¨ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط·آ¹أ¢â‚¬ع©ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ¸ط·آ¢ط¢آ¹ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ£ط¢آ¢ط£آ¢أ¢â‚¬ع‘ط¢آ¬ط£آ¢أ¢â€ڑآ¬ط¹â€ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آµط·آ·ط¢آ·ط·آ¢ط¢آ¸ط·آ·ط¢آ«ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¢ط·آ¢ط¢آ©.'
                  : 'Drag each piece from the tray onto the board. When you drop it onto the correct spot, it snaps in and joins the picture.',
              style: const TextStyle(
                  fontSize: 14.5, height: 1.45, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(_PuzzleLevel level) {
    final levelNumber = _levels.indexOf(level) + 1;
    return _isArabic
        ? '??????? $levelNumber ? ${level.size}x${level.size}'
        : 'Level $levelNumber ? ${level.size}x${level.size}';
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PuzzleStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _PuzzleStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValuesCompat(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValuesCompat(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  final Color accent;

  const _StarRow({required this.stars, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final filled = index < stars;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? Colors.amber : accent.withValuesCompat(alpha: 0.35),
            size: 22,
          ),
        );
      }),
    );
  }
}

class _PuzzleImageTile extends StatelessWidget {
  final String imagePath;
  final int tileValue;
  final int boardSize;
  final bool isCorrect;

  const _PuzzleImageTile({
    required this.imagePath,
    required this.tileValue,
    required this.boardSize,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final row = (tileValue - 1) ~/ boardSize;
    final col = (tileValue - 1) % boardSize;

    return ClipRRect(
      borderRadius: BorderRadius.circular(boardSize == 5 ? 16 : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth;
          final tileHeight = constraints.maxHeight;
          final imageWidth = tileWidth * boardSize;
          final imageHeight = tileHeight * boardSize;

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: imageWidth,
                  maxWidth: imageWidth,
                  minHeight: imageHeight,
                  maxHeight: imageHeight,
                  child: Transform.translate(
                    offset: Offset(-col * tileWidth, -row * tileHeight),
                    child: Image.asset(
                      imagePath,
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (!isCorrect)
                Container(color: Colors.black.withValuesCompat(alpha: 0.08)),
            ],
          );
        },
      ),
    );
  }
}

class _TrayPuzzlePiece extends StatelessWidget {
  final String imagePath;
  final int tileValue;
  final int boardSize;
  final Color accent;

  const _TrayPuzzlePiece({
    required this.imagePath,
    required this.tileValue,
    required this.boardSize,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: accent.withValuesCompat(alpha: 0.24), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValuesCompat(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _PuzzleImageTile(
        imagePath: imagePath,
        tileValue: tileValue,
        boardSize: boardSize,
        isCorrect: true,
      ),
    );
  }
}

class _PuzzleLevelProgress {
  final int? bestTimeSeconds;
  final int bestStars;

  const _PuzzleLevelProgress({
    this.bestTimeSeconds,
    this.bestStars = 0,
  });
}

class _PuzzleLevel {
  final String id;
  final int size;
  final Color accent;
  final int timeLimitSeconds;

  const _PuzzleLevel({
    required this.id,
    required this.size,
    required this.accent,
    required this.timeLimitSeconds,
  });
}

class _GameAudioController {
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _fxPlayer = AudioPlayer();

  Future<void> startBackground(String assetPath, {double volume = 0.25}) async {
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(volume);
      await _bgPlayer.play(AssetSource(assetPath));
    } catch (_) {
      // Ignore missing custom assets during development.
    }
  }

  Future<void> playEffect(
    String assetPath, {
    SystemSoundType? fallback,
    double volume = 1,
  }) async {
    try {
      await _fxPlayer.setVolume(volume);
      await _fxPlayer.play(AssetSource(assetPath));
    } catch (_) {
      if (fallback != null) {
        unawaited(SystemSound.play(fallback));
      }
    }
  }

  Future<void> stopBackground() async {
    try {
      await _bgPlayer.stop();
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> dispose() async {
    try {
      await _bgPlayer.dispose();
      await _fxPlayer.dispose();
    } catch (_) {
      // Ignore.
    }
  }
}

class RacingCarsGameScreen extends StatefulWidget {
  const RacingCarsGameScreen({super.key});

  @override
  State<RacingCarsGameScreen> createState() => _RacingCarsGameScreenState();
}

class _RacingCarsGameScreenState extends State<RacingCarsGameScreen> {
  double _progress = 0;
  int _tapCount = 0;
  bool _finished = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  void _accelerate() {
    if (_finished) return;
    setState(() {
      _tapCount += 1;
      _progress = (_progress + 0.08).clamp(0, 1);
      if (_progress >= 1) {
        _finished = true;
      }
    });
  }

  void _resetRace() {
    setState(() {
      _progress = 0;
      _tapCount = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: _isArabic ? '???? ????????' : 'Racing Cars',
      subtitle: _finished
          ? (_isArabic
              ? '????? ??? ???????! ????? ????? ???? ????.'
              : 'You reached the finish line! Play again for a better score.')
          : (_isArabic
              ? '????? ?? ???????? ????? ??? ???? ???????.'
              : 'Tap the go button quickly until you reach the finish line.'),
      accent: const Color(0xFF42A5F5),
      trailing: TextButton.icon(
        onPressed: _resetRace,
        icon: const Icon(Icons.restart_alt),
        label: Text(_isArabic ? '?????' : 'Restart'),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isArabic
                        ? '??? ???????: $_tapCount'
                        : 'Taps: $_tapCount'),
                    Text(_isArabic
                        ? '??????: ${(_progress * 100).round()}%'
                        : 'Progress: ${(_progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueGrey.shade50,
                        Colors.blueGrey.shade100
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _RaceTrackPainter()),
                      ),
                      Align(
                        alignment: Alignment(_progress * 2 - 1, 0),
                        child:
                            const Text('???', style: TextStyle(fontSize: 38)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _accelerate,
                    icon: const Icon(Icons.flash_on),
                    label: Text(_finished
                        ? (_isArabic ? '????? ??????' : 'Race finished')
                        : (_isArabic ? '??????!' : 'Go!')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
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

class MemoryMatchGameScreen extends StatefulWidget {
  const MemoryMatchGameScreen({super.key});

  @override
  State<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends State<MemoryMatchGameScreen> {
  static final List<_MemoryLevel> _levels = List.generate(50, (index) {
    const accents = [
      Color(0xFFFFB74D),
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
      Color(0xFFBA68C8),
      Color(0xFFFF8A65),
    ];
    final number = index + 1;
    final pairCount = 4 + (index ~/ 6);
    final safePairCount = pairCount > 10 ? 10 : pairCount;
    final rawTime = 105 - (index * 2);
    final time = rawTime < 35 ? 35 : rawTime;
    return _MemoryLevel(
      id: 'memory_$number',
      pairCount: safePairCount,
      timeLimitSeconds: time,
      accent: accents[index % accents.length],
    );
  });

  static const String _memoryCardsFolder = 'assets/images/memory_cards/';

  late _MemoryLevel _selectedLevel;
  late List<_MemoryCardData> _cards;
  late List<_MemoryToken> _tokenPool;
  final _GameAudioController _audio = _GameAudioController();
  Timer? _timer;
  int? _firstIndex;
  bool _busy = false;
  bool _isLoadingProgress = true;
  bool _isLost = false;
  int _moves = 0;
  int _secondsElapsed = 0;
  int _remainingSeconds = 0;
  int _bestStars = 0;
  bool _didShowWinDialog = false;
  List<String> _lastRoundTokenPaths = const [];
  Map<String, int> _memoryBestStarsByLevel = const {};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  int get _matchedPairs => _cards.where((card) => card.isMatched).length ~/ 2;
  bool get _finished => _matchedPairs == _selectedLevel.pairCount;
  int get _memoryUnlockedLevelIndex {
    var unlocked = 0;
    for (var i = 0; i < _levels.length - 1; i++) {
      final stars = _memoryBestStarsByLevel[_levels[i].id] ?? 0;
      if (stars > 0) {
        unlocked = i + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }

  int _memoryStarsFor(_MemoryLevel level) =>
      _memoryBestStarsByLevel[level.id] ?? 0;
  bool get _hasEnoughMemoryCards => _tokenPool.length >= 4;
  bool get _canPlayCurrentLevel =>
      _hasEnoughMemoryCards && _tokenPool.length >= _selectedLevel.pairCount;

  @override
  void initState() {
    super.initState();
    _selectedLevel = _levels.first;
    _remainingSeconds = _selectedLevel.timeLimitSeconds;
    _tokenPool = const [];
    _cards = const [];
    unawaited(_audio.startBackground('sounds/games/memory_bg.mp3'));
    _loadBestStars();
    _loadCustomMemoryTokens();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _loadCustomMemoryTokens() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final customImages = manifest
          .listAssets()
          .where((assetPath) =>
              assetPath.startsWith(_memoryCardsFolder) &&
              _isSupportedArtwork(assetPath))
          .toList()
        ..sort();

      final palette = [
        const Color(0xFFE8F5E9),
        const Color(0xFFFCE4EC),
        const Color(0xFFFFF3E0),
        const Color(0xFFE1F5FE),
        const Color(0xFFF3E5F5),
        const Color(0xFFF1F8E9),
        const Color(0xFFFFFDE7),
        const Color(0xFFE3F2FD),
      ];
      final tokens = List<_MemoryToken>.generate(customImages.length, (index) {
        return _MemoryToken(
          imagePath: customImages[index],
          label: 'Card ${index + 1}',
          arabicLabel: '???? ${index + 1}',
          color: palette[index % palette.length],
        );
      });
      if (!mounted) return;
      setState(() {
        _tokenPool = tokens;
      });
      if (tokens.length >= 4) {
        _resetGame();
      } else {
        _timer?.cancel();
        setState(() {
          _cards = const [];
          _lastRoundTokenPaths = const [];
          _firstIndex = null;
          _busy = false;
          _moves = 0;
          _secondsElapsed = 0;
          _remainingSeconds = _selectedLevel.timeLimitSeconds;
          _isLost = false;
          _didShowWinDialog = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tokenPool = const [];
        _cards = const [];
      });
      _timer?.cancel();
    }
  }

  bool _isSupportedArtwork(String assetPath) {
    final lower = assetPath.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  Future<void> _loadBestStars() async {
    setState(() => _isLoadingProgress = true);
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final level in _levels) {
      map[level.id] = prefs.getInt('memory_best_stars_${level.id}') ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _memoryBestStarsByLevel = map;
      _bestStars = map[_selectedLevel.id] ?? 0;
      _isLoadingProgress = false;
    });
  }

  Future<void> _saveBestStars(int stars) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('memory_best_stars_${_selectedLevel.id}') ?? 0;
    final best = stars > current ? stars : current;
    if (stars > current) {
      await prefs.setInt('memory_best_stars_${_selectedLevel.id}', stars);
    }
    if (!mounted) return;
    setState(() {
      _bestStars = best;
      _memoryBestStarsByLevel = {
        ..._memoryBestStarsByLevel,
        _selectedLevel.id: best,
      };
    });
  }

  void _resetGame() {
    if (!_canPlayCurrentLevel) {
      _timer?.cancel();
      setState(() {
        _cards = const [];
        _lastRoundTokenPaths = const [];
        _firstIndex = null;
        _busy = false;
        _moves = 0;
        _secondsElapsed = 0;
        _remainingSeconds = _selectedLevel.timeLimitSeconds;
        _isLost = false;
        _didShowWinDialog = false;
      });
      return;
    }
    final shuffledTokens = List<_MemoryToken>.from(_tokenPool);
    List<_MemoryToken> tokens = const [];

    if (shuffledTokens.length <= _selectedLevel.pairCount) {
      tokens = shuffledTokens;
    } else {
      for (var attempt = 0; attempt < 6; attempt++) {
        shuffledTokens.shuffle();
        final candidate =
            shuffledTokens.take(_selectedLevel.pairCount).toList();
        final candidatePaths =
            candidate.map((token) => token.imagePath).toList()..sort();
        final previousPaths = List<String>.from(_lastRoundTokenPaths)..sort();
        tokens = candidate;
        if (candidatePaths.join('|') != previousPaths.join('|')) {
          break;
        }
      }
    }

    final cards = <_MemoryCardData>[];
    for (final token in tokens) {
      cards.add(_MemoryCardData(token: token));
      cards.add(_MemoryCardData(token: token));
    }
    cards.shuffle();
    _timer?.cancel();
    _startTimer();
    setState(() {
      _cards = cards;
      _lastRoundTokenPaths = tokens.map((token) => token.imagePath).toList();
      _firstIndex = null;
      _busy = false;
      _moves = 0;
      _secondsElapsed = 0;
      _remainingSeconds = _selectedLevel.timeLimitSeconds;
      _isLost = false;
      _didShowWinDialog = false;
    });
  }

  void _changeLevel(_MemoryLevel level) {
    setState(() {
      _selectedLevel = level;
      _remainingSeconds = level.timeLimitSeconds;
      _isLost = false;
    });
    _resetGame();
    _loadBestStars();
  }

  Future<void> _openMemoryLevelPicker() async {
    final picked = await Navigator.of(context).push<_MemoryLevel>(
      MaterialPageRoute(
        builder: (context) => _MemoryLevelGridScreen(
          title: _isArabic ? '??????? ????????' : 'Memory Levels',
          accent: _selectedLevel.accent,
          levels: _levels,
          selectedLevel: _selectedLevel,
          labelBuilder: _memoryLevelLabel,
          unlockedIndex: _memoryUnlockedLevelIndex,
          starsForLevel: _memoryStarsFor,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _changeLevel(picked);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished || _isLost) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        setState(() {
          _secondsElapsed += 1;
          _remainingSeconds = 0;
          _isLost = true;
        });
        unawaited(_audio.playEffect('sounds/games/memory_lose.mp3',
            fallback: SystemSoundType.click));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_showLostDialog());
          }
        });
        return;
      }
      setState(() {
        _secondsElapsed += 1;
        _remainingSeconds -= 1;
      });
    });
  }

  Future<void> _flipCard(int index) async {
    if (_busy || _isLost || _cards[index].isMatched || _cards[index].isFaceUp) {
      return;
    }

    setState(() {
      _cards[index].isFaceUp = true;
    });

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final firstIndex = _firstIndex!;
    setState(() {
      _moves += 1;
    });

    if (_cards[firstIndex].token.imagePath == _cards[index].token.imagePath) {
      unawaited(_audio.playEffect('sounds/games/memory_match.mp3',
          fallback: SystemSoundType.alert));
      setState(() {
        _cards[firstIndex].isMatched = true;
        _cards[index].isMatched = true;
        _firstIndex = null;
      });
      if (_finished && !_didShowWinDialog) {
        _didShowWinDialog = true;
        _timer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_showWinDialog());
          }
        });
      }
      return;
    }

    unawaited(_audio.playEffect('sounds/games/memory_tap.mp3',
        fallback: SystemSoundType.click));
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() {
      _cards[firstIndex].isFaceUp = false;
      _cards[index].isFaceUp = false;
      _firstIndex = null;
      _busy = false;
    });
  }

  Future<void> _showLostDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(_isArabic ? '????? ?????' : 'Time Is Up')),
          ],
        ),
        content: Text(
          _isArabic
              ? '????? ????? ??? ??? ?? ???????. ????? ???????? ????? ????.'
              : 'Time ran out before all pairs were matched. Try again a little faster.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _resetGame();
            },
            child: Text(_isArabic ? '????? ????????' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryEmptyState() {
    final needsMoreForLevel = _hasEnoughMemoryCards && !_canPlayCurrentLevel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined,
              size: 42, color: _selectedLevel.accent),
          const SizedBox(height: 12),
          Text(
            _isArabic
                ? (needsMoreForLevel
                    ? '????? ????? ???? ???? ???????'
                    : '????? ??? ???? ????????')
                : (needsMoreForLevel
                    ? 'Add more images for this level'
                    : 'Add memory card images'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _selectedLevel.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? (needsMoreForLevel
                    ? '??? ??????? ????? ${_selectedLevel.pairCount} ??? ?????? ??? ????? ???? assets/images/memory_cards/. ?????? ???? ${_tokenPool.length} ???.'
                    : '?????? ???? ?????? ??? ????? ???? ???????? ???? assets/images/memory_cards/. ????? 4 ??? ?????? ??? ????? ?? ????? Hot Restart.')
                : (needsMoreForLevel
                    ? 'This level needs at least ${_selectedLevel.pairCount} different images inside assets/images/memory_cards/. Right now only ${_tokenPool.length} are available.'
                    : 'This game now uses only the images you add inside assets/images/memory_cards/. Add at least 4 different images, then run a hot restart.'),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _showWinDialog() async {
    final stars = _moves <= _selectedLevel.pairCount + 2
        ? 3
        : _moves <= _selectedLevel.pairCount + 5
            ? 2
            : 1;
    await _saveBestStars(stars);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Row(
          children: [
            Icon(Icons.celebration_rounded, color: _selectedLevel.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(_isArabic ? '?????!' : 'Well Done!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic
                  ? '??????? ?? ??????? ?? ${_formatTime(_secondsElapsed)} ???? $_moves ??????.'
                  : 'You found all pairs in ${_formatTime(_secondsElapsed)} using $_moves tries.',
            ),
            const SizedBox(height: 14),
            _StarRow(stars: stars, accent: _selectedLevel.accent),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _isArabic ? '???? ????:' : 'Best stars:',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _StarRow(stars: _bestStars, accent: _selectedLevel.accent),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (_selectedLevel != _levels.last) {
                _changeLevel(_levels[_levels.indexOf(_selectedLevel) + 1]);
              } else {
                _resetGame();
              }
            },
            style:
                FilledButton.styleFrom(backgroundColor: _selectedLevel.accent),
            child: Text(
              _selectedLevel != _levels.last
                  ? (_isArabic ? '??????? ??????' : 'Next Level')
                  : (_isArabic ? '????? ?????' : 'Play Again'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = _selectedLevel.pairCount == 8 ? 4 : 3;

    return _GameScaffold(
      title: _isArabic ? '???? ??????' : 'Memory Match',
      subtitle: _finished
          ? (_isArabic
              ? '??????? ????? ?? ??????? ?????????.'
              : 'Amazing, you found every matching pair.')
          : _isLost
              ? (_isArabic
                  ? '????? ????? ??? ????? ??????.'
                  : 'Time ran out before the game was finished.')
              : (_isArabic
                  ? '????? ??????? ?????? ?? ???????? ??????????? ??? ?????? ?????.'
                  : 'Flip two cards and find the matching pair before time runs out.'),
      accent: _selectedLevel.accent,
      trailing: TextButton.icon(
        onPressed: _canPlayCurrentLevel ? _resetGame : null,
        icon: const Icon(Icons.refresh),
        label: Text(_isArabic ? '?????' : 'Shuffle'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMemoryHero(),
          const SizedBox(height: 16),
          _LevelGridLauncher(
            title: _isArabic ? '?????? ???????' : 'Choose Level',
            subtitle: _memoryLevelLabel(_selectedLevel),
            accent: _selectedLevel.accent,
            icon: Icons.auto_awesome_motion_rounded,
            onTap: _openMemoryLevelPicker,
          ),
          const SizedBox(height: 16),
          if (_isLost)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValuesCompat(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sentiment_dissatisfied_rounded,
                      color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isArabic
                          ? '????? ????? ??? ??? ?? ???????.'
                          : 'Time ran out before all pairs were matched.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _PuzzleStatCard(
                  icon: Icons.favorite_rounded,
                  label: _isArabic ? '???????' : 'Pairs',
                  value: '$_matchedPairs/${_selectedLevel.pairCount}',
                  accent: _selectedLevel.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PuzzleStatCard(
                  icon: Icons.touch_app_rounded,
                  label: _isArabic ? '?????????' : 'Moves',
                  value: '$_moves',
                  accent: _selectedLevel.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PuzzleStatCard(
                  icon: Icons.timer_rounded,
                  label: _isArabic ? '?????' : 'Time',
                  value: _formatTime(_remainingSeconds),
                  accent: _selectedLevel.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selectedLevel.accent.withValuesCompat(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isLoadingProgress
                        ? (_isArabic
                            ? '???? ????? ??????...'
                            : 'Loading stars...')
                        : (_isArabic
                            ? '???? ????? ????? ???? ???????'
                            : 'Best saved rating for this level'),
                    style: TextStyle(
                      color: _selectedLevel.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _StarRow(stars: _bestStars, accent: _selectedLevel.accent),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_canPlayCurrentLevel)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.84,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return _MemoryCardTile(
                  card: card,
                  accent: _selectedLevel.accent,
                  isArabic: _isArabic,
                  onTap: () => _flipCard(index),
                );
              },
            )
          else
            _buildMemoryEmptyState(),
        ],
      ),
    );
  }

  Widget _buildMemoryHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedLevel.accent.withValuesCompat(alpha: 0.22),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('??', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic ? '???? ??????? ???????' : 'Playful Memory Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _selectedLevel.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isArabic
                      ? '????? ????? ??????? ????? ??? ???? ????? ???? ????? ???????.'
                      : 'Soft colors and bigger cards make matching easier and more fun for kids.',
                  style: const TextStyle(fontSize: 14.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _memoryLevelLabel(_MemoryLevel level) {
    switch (level.id) {
      default:
        final number = _levels.indexOf(level) + 1;
        return _isArabic ? '??????? $number' : 'Level $number';
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MemoryCardTile extends StatelessWidget {
  final _MemoryCardData card;
  final Color accent;
  final bool isArabic;
  final VoidCallback onTap;

  const _MemoryCardTile({
    required this.card,
    required this.accent,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showFront = card.isFaceUp || card.isMatched;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: showFront ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutBack,
        builder: (context, value, child) {
          final angle = value * 3.1415926535;
          final isFrontVisible = value >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              decoration: BoxDecoration(
                gradient: isFrontVisible
                    ? LinearGradient(
                        colors: [
                          card.token.color,
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [accent, accent.withValuesCompat(alpha: 0.76)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: card.isMatched
                      ? Colors.green.withValuesCompat(alpha: 0.9)
                      : accent.withValuesCompat(
                          alpha: isFrontVisible ? 0.25 : 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValuesCompat(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateY(isFrontVisible ? 3.1415926535 : 0),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: card.isMatched ? 0.96 : 1,
                    child: isFrontVisible
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      card.token.imagePath,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isArabic
                                      ? card.token.arabicLabel
                                      : card.token.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          'assets/images/memory_card_back.png',
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    accent.withValuesCompat(
                                                        alpha: 0.95),
                                                    accent.withValuesCompat(
                                                        alpha: 0.72),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.auto_awesome_rounded,
                                                  color: Colors.white,
                                                  size: 34,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withValuesCompat(
                                                    alpha: 0.08),
                                                Colors.black.withValuesCompat(
                                                    alpha: 0.22),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isArabic ? '??????' : 'Flip Me',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelGridLauncher extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _LevelGridLauncher({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValuesCompat(alpha: 0.20),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValuesCompat(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.grid_view_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _PuzzleLevelGridScreen extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_PuzzleLevel> levels;
  final _PuzzleLevel selectedLevel;
  final String Function(_PuzzleLevel) labelBuilder;
  final int unlockedIndex;
  final int Function(_PuzzleLevel) starsForLevel;

  const _PuzzleLevelGridScreen({
    required this.title,
    required this.accent,
    required this.levels,
    required this.selectedLevel,
    required this.labelBuilder,
    required this.unlockedIndex,
    required this.starsForLevel,
  });

  @override
  Widget build(BuildContext context) {
    return _LevelGridShell<_PuzzleLevel>(
      title: title,
      accent: accent,
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        final selected = level.id == selectedLevel.id;
        final stars = starsForLevel(level);
        final locked = index > unlockedIndex;
        return _LevelGridCard(
          number: index + 1,
          label: labelBuilder(level),
          accent: level.accent,
          selected: selected,
          locked: locked,
          stars: stars,
          isCurrent: selected,
          isCompleted: stars > 0,
          detail: '${level.size}x${level.size} ? ${level.timeLimitSeconds}s',
          onTap: () => Navigator.of(context).pop(level),
        );
      },
    );
  }
}

class _MemoryLevelGridScreen extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_MemoryLevel> levels;
  final _MemoryLevel selectedLevel;
  final String Function(_MemoryLevel) labelBuilder;
  final int unlockedIndex;
  final int Function(_MemoryLevel) starsForLevel;

  const _MemoryLevelGridScreen({
    required this.title,
    required this.accent,
    required this.levels,
    required this.selectedLevel,
    required this.labelBuilder,
    required this.unlockedIndex,
    required this.starsForLevel,
  });

  @override
  Widget build(BuildContext context) {
    return _LevelGridShell<_MemoryLevel>(
      title: title,
      accent: accent,
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        final selected = level.id == selectedLevel.id;
        final stars = starsForLevel(level);
        final locked = index > unlockedIndex;
        return _LevelGridCard(
          number: index + 1,
          label: labelBuilder(level),
          accent: level.accent,
          selected: selected,
          locked: locked,
          stars: stars,
          isCurrent: selected,
          isCompleted: stars > 0,
          detail: '${level.pairCount} pairs ? ${level.timeLimitSeconds}s',
          onTap: () => Navigator.of(context).pop(level),
        );
      },
    );
  }
}

class _LevelGridShell<T> extends StatelessWidget {
  final String title;
  final Color accent;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _LevelGridShell({
    required this.title,
    required this.accent,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValuesCompat(alpha: 0.18),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Choose a level and keep climbing.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelGridCard extends StatelessWidget {
  final int number;
  final String label;
  final String detail;
  final Color accent;
  final bool selected;
  final bool locked;
  final bool isCurrent;
  final bool isCompleted;
  final int stars;
  final VoidCallback onTap;

  const _LevelGridCard({
    required this.number,
    required this.label,
    required this.detail,
    required this.accent,
    required this.selected,
    required this.locked,
    required this.isCurrent,
    required this.isCompleted,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: locked
                ? [Colors.grey.shade200, Colors.grey.shade100]
                : selected
                    ? [accent.withValuesCompat(alpha: 0.28), Colors.white]
                    : [Colors.white, accent.withValuesCompat(alpha: 0.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: locked
                ? Colors.grey.shade400
                : (selected ? accent : accent.withValuesCompat(alpha: 0.20)),
            width: selected ? 2.4 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: locked ? Colors.grey : accent,
                      child: locked
                          ? const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 18)
                          : Text(
                              '$number',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const Spacer(),
                    _MiniStars(stars: stars),
                  ],
                ),
                const SizedBox(height: 10),
                if (isCurrent)
                  _LevelBadge(label: 'Current', color: accent)
                else if (isCompleted)
                  _LevelBadge(label: 'Completed', color: Colors.green)
                else if (locked)
                  _LevelBadge(label: 'Locked', color: Colors.grey),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: locked ? Colors.grey.shade700 : accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: locked ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
            if (locked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValuesCompat(alpha: 0.32),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _LevelBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValuesCompat(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStars extends StatelessWidget {
  final int stars;

  const _MiniStars({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Icon(
          index < stars ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: index < stars ? Colors.amber : Colors.grey.shade400,
        );
      }),
    );
  }
}

class _GameScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final Widget? trailing;

  const _GameScaffold({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
        ),
        actions: [if (trailing != null) trailing!],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChildHeader(compact: true),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValuesCompat(alpha: 0.18),
                      Colors.white
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dashWidth = size.width / 9;
    for (var i = 0; i < 5; i++) {
      final start = Offset(i * dashWidth * 2 + 8, size.height / 2);
      final end = Offset(start.dx + dashWidth, size.height / 2);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MemoryLevel {
  final String id;
  final int pairCount;
  final int timeLimitSeconds;
  final Color accent;

  const _MemoryLevel({
    required this.id,
    required this.pairCount,
    required this.timeLimitSeconds,
    required this.accent,
  });
}

class _MemoryToken {
  final String imagePath;
  final String label;
  final String arabicLabel;
  final Color color;

  const _MemoryToken({
    required this.imagePath,
    required this.label,
    required this.arabicLabel,
    required this.color,
  });
}

class _MemoryCardData {
  final _MemoryToken token;
  bool isFaceUp = false;
  bool isMatched = false;

  _MemoryCardData({required this.token});
}

/// 2. UPDATED Behavioral Screen (Changed to Grid Layout)
class BehavioralScreen extends StatelessWidget {
  const BehavioralScreen({super.key});

  List<Map<String, dynamic>> get _values => behavioralValues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Text(
              l10n.letsPracticeKindness,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.behavioral,
              ),
            ),
            const SizedBox(height: 24),
            // CHANGED TO GRID (2 Columns)
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: _values.length,
                itemBuilder: (context, index) {
                  final value = _values[index];
                  return _buildValueCard(
                      context, value['title'], value['image']);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CHANGED CARD TO IMAGE BACKGROUND STYLE FOR GRID
  Widget _buildValueCard(BuildContext context, String title, String imagePath) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ValueDetailsScreen(valueTitle: title),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.behavioral.withValuesCompat(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValuesCompat(alpha: 0.7),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Level 2: Value Details Screen
class ValueDetailsScreen extends StatelessWidget {
  final String valueTitle;
  const ValueDetailsScreen({super.key, required this.valueTitle});

  List<Map<String, dynamic>> get _methods => behavioralMethods;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text(
          valueTitle,
          style: TextStyle(
              color: AppColors.behavioral, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _methods.length,
                itemBuilder: (context, index) {
                  final method = _methods[index];
                  return _buildMethodCard(
                      context, method['title'], method['image']);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(
      BuildContext context, String title, String imagePath) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MethodContentScreen(
              valueTitle: valueTitle,
              methodTitle: title,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValuesCompat(alpha: 0.7),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Level 3: Method Content Screen
class MethodContentScreen extends ConsumerStatefulWidget {
  final String valueTitle;
  final String methodTitle;

  const MethodContentScreen({
    super.key,
    required this.valueTitle,
    required this.methodTitle,
  });

  @override
  ConsumerState<MethodContentScreen> createState() =>
      _MethodContentScreenState();
}

class _MethodContentScreenState extends ConsumerState<MethodContentScreen> {
  late Future<List<PublicContentItem>> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadBehavioralContent();
  }

  Future<List<PublicContentItem>> _loadBehavioralContent() async {
    final repository = ref.read(publicContentRepositoryProvider);
    final categorySlug = await _behavioralValueCategorySlug(repository);
    if (categorySlug != null) {
      final directItems =
          await repository.fetchItems(categorySlug: categorySlug);
      final filteredDirectItems = directItems.where(_matchesPlacement).toList();
      if (filteredDirectItems.isNotEmpty) {
        return filteredDirectItems;
      }
    }
    final items = await repository.fetchItems();
    return items.where(_matchesPlacement).toList();
  }

  Future<String?> _behavioralValueCategorySlug(
    PublicContentRepository repository,
  ) async {
    final categories = await repository.fetchCategories();
    final selectedValue = _normalizeBehavioralToken(widget.valueTitle);
    for (final category in categories) {
      if (category.axisKey != 'behavioral') {
        continue;
      }
      final terms = [
        category.slug,
        category.titleEn,
        category.titleAr,
      ].map(_normalizeBehavioralToken);
      if (terms.contains(selectedValue)) {
        return category.slug;
      }
    }
    return null;
  }

  bool _matchesPlacement(PublicContentItem item) {
    final isBehavioral = item.axisKey == 'behavioral' ||
        item.category?.axisKey == 'behavioral' ||
        item.metadata['axis_key'] == 'behavioral';
    if (!isBehavioral) {
      return false;
    }

    final selectedValue = _normalizeBehavioralToken(widget.valueTitle);
    final selectedMethod = _normalizeBehavioralToken(widget.methodTitle);
    final itemValue = _normalizeBehavioralToken(
      item.metadata['behavioral_value']?.toString() ?? '',
    );
    final itemMethod = _normalizeBehavioralToken(
      item.metadata['behavioral_method']?.toString() ?? '',
    );

    final categoryTerms = [
      item.category?.slug ?? '',
      item.category?.titleEn ?? '',
      item.category?.titleAr ?? '',
    ].map(_normalizeBehavioralToken);
    final matchesValue =
        itemValue == selectedValue || categoryTerms.contains(selectedValue);
    final matchesMethod = itemMethod == selectedMethod;
    return matchesValue && matchesMethod;
  }

  String _normalizeBehavioralToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _localizedContentTitle(PublicContentItem item) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final preferred = locale.startsWith('ar') ? item.titleAr : item.titleEn;
    final fallback = locale.startsWith('ar') ? item.titleEn : item.titleAr;
    return preferred.trim().isNotEmpty ? preferred : fallback;
  }

  String _localizedContentDescription(PublicContentItem item) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final preferred =
        locale.startsWith('ar') ? item.descriptionAr : item.descriptionEn;
    final fallback =
        locale.startsWith('ar') ? item.descriptionEn : item.descriptionAr;
    return (preferred ?? fallback ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              AppColors.behavioral.withValuesCompat(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.arrow_back, color: AppColors.behavioral),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: ChildHeader(
                        compact: true,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValuesCompat(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.behavioral, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.letsTryNewSkill,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.behavioral,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.methodTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<PublicContentItem>>(
                  future: _contentFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final items = snapshot.data ?? const <PublicContentItem>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            l10n.noActivitiesFound,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildContentCard(context, item),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, PublicContentItem item) {
    final title = _localizedContentTitle(item);
    final description = _localizedContentDescription(item);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage = thumbnailUrl != null &&
        thumbnailUrl.trim().isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _BehavioralContentDetailScreen(item: item),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadiusDirectional.horizontal(
                start: Radius.circular(20),
              ),
              child: Container(
                width: 112,
                height: 128,
                color: AppColors.behavioral.withValuesCompat(alpha: 0.1),
                child: hasRemoteImage
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.extension,
                          color: AppColors.behavioral,
                          size: 36,
                        ),
                      )
                    : Icon(
                        item.hasVideo
                            ? Icons.play_circle_fill_rounded
                            : Icons.extension,
                        color: AppColors.behavioral,
                        size: 42,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Icon(
                      item.hasVideo
                          ? Icons.play_circle_fill_rounded
                          : Icons.arrow_forward_rounded,
                      color: AppColors.behavioral,
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

class _BehavioralContentDetailScreen extends ConsumerStatefulWidget {
  const _BehavioralContentDetailScreen({required this.item});

  final PublicContentItem item;

  @override
  ConsumerState<_BehavioralContentDetailScreen> createState() =>
      _BehavioralContentDetailScreenState();
}

class _BehavioralContentDetailScreenState
    extends ConsumerState<_BehavioralContentDetailScreen> {
  late Future<PublicContentItem?> _itemFuture;

  @override
  void initState() {
    super.initState();
    _itemFuture =
        ref.read(publicContentRepositoryProvider).fetchItem(widget.item.slug);
  }

  String _localized(String en, String ar) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    if (locale.startsWith('ar')) {
      return ar.trim().isNotEmpty ? ar : en;
    }
    return en.trim().isNotEmpty ? en : ar;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _localized(widget.item.titleEn, widget.item.titleAr),
          style: TextStyle(
            color: AppColors.behavioral,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<PublicContentItem?>(
        future: _itemFuture,
        builder: (context, snapshot) {
          final item = snapshot.data ?? widget.item;
          final description = _localized(
            item.descriptionEn ?? '',
            item.descriptionAr ?? '',
          );
          final body = _localized(item.bodyEn ?? '', item.bodyAr ?? '');
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const ChildHeader(compact: true),
              const SizedBox(height: 16),
              if ((item.effectiveThumbnailUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(
                    item.effectiveThumbnailUrl!,
                    height: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if ((item.effectiveThumbnailUrl ?? '').isNotEmpty)
                const SizedBox(height: 20),
              Text(
                _localized(item.titleEn, item.titleAr),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValuesCompat(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  body.isEmpty ? l10n.playNoBodyContentYet : body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (item.hasVideo) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: CloudinaryVideoPlayerView(
                    videoUrl: item.preferredVideoUrl!,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 3. UPDATED Skillful Screen (Vertical List with New Categories)
class SkillfulScreen extends StatelessWidget {
  const SkillfulScreen({super.key});

  List<Map<String, dynamic>> get _skills => skillCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Text(
              l10n.letsCreateSomethingFun,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.skillful,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _skills.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final skill = _skills[index];
                  return _buildSkillCard(context, skill);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCard(BuildContext context, Map<String, dynamic> skill) {
    final l10n = AppLocalizations.of(context)!;
    final rawTitle = skill['title'] as String;
    return InkWell(
      onTap: () {
        if (rawTitle == 'Coloring') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ColoringGalleryScreen(),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SkillDetailScreen(skillTitle: rawTitle),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.skillful.withValuesCompat(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Image.asset(
                skill['image'],
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 120,
                  height: 120,
                  color: AppColors.skillful.withValuesCompat(alpha: 0.2),
                  child: Icon(Icons.brush, color: AppColors.skillful),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _localizedSkillTitle(rawTitle, l10n),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localizedSkillDescription(rawTitle, l10n),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(Icons.arrow_forward_ios,
                  color: AppColors.skillful, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedSkillTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Cooking' => l10n.skillCooking,
      'Drawing' => l10n.skillDrawing,
      'Coloring' => l10n.coloringTitle,
      'Music' => l10n.music,
      'Singing' => l10n.skillSinging,
      'Handcrafts' => l10n.skillHandcrafts,
      'Sports' => l10n.skillSports,
      _ => raw,
    };
  }

  String _localizedSkillDescription(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Cooking' => l10n.skillCookingDesc,
      'Drawing' => l10n.skillDrawingDesc,
      'Coloring' => l10n.skillColoringDesc,
      'Music' => l10n.skillMusicDesc,
      'Singing' => l10n.skillSingingDesc,
      'Handcrafts' => l10n.skillHandcraftsDesc,
      'Sports' => l10n.skillSportsDesc,
      _ => '',
    };
  }
}

// Skill Detail Screen (With Search & Filters)
class SkillDetailScreen extends ConsumerStatefulWidget {
  final String skillTitle;
  const SkillDetailScreen({super.key, required this.skillTitle});

  @override
  ConsumerState<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends ConsumerState<SkillDetailScreen> {
  String _searchQuery = "";
  String _selectedLevel = "all";
  late Future<List<PublicContentItem>> _contentFuture;

  final List<String> _levels = ["all", "beginner", "intermediate", "advanced"];

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadCmsVideos();
  }

  Future<List<PublicContentItem>> _loadCmsVideos() async {
    final repository = ref.read(publicContentRepositoryProvider);
    final categorySlug = _cmsCategorySlug();
    if (categorySlug != null) {
      final directItems = await repository.fetchItems(
        categorySlug: categorySlug,
      );
      if (directItems.isNotEmpty) {
        return directItems;
      }
    }
    final items = await repository.fetchItems();
    return items.where(_matchesSkill).toList();
  }

  String? _cmsCategorySlug() {
    final raw = widget.skillTitle.trim().toLowerCase();
    return switch (raw) {
      'handcrafts' => 'crafts',
      'drawing' => 'drawing',
      'coloring' => 'coloring',
      'music' => 'music',
      'singing' => 'singing',
      'sports' => 'sports',
      'cooking' => 'cooking',
      _ => null,
    };
  }

  bool _matchesSkill(PublicContentItem item) {
    final terms = _skillSearchTerms();
    final haystack = [
      item.slug,
      item.titleEn,
      item.titleAr,
      item.descriptionEn ?? '',
      item.descriptionAr ?? '',
      item.category?.slug ?? '',
      item.category?.titleEn ?? '',
      item.category?.titleAr ?? '',
    ].join(' ').toLowerCase();
    return terms.any(haystack.contains);
  }

  List<String> _skillSearchTerms() {
    final raw = widget.skillTitle.trim().toLowerCase();
    return switch (raw) {
      'handcrafts' => [
          'handcraft',
          'handcrafts',
          'craft',
          'crafts',
          'أعمال',
          'يدوية'
        ],
      'drawing' => ['drawing', 'draw', 'رسم'],
      'coloring' => ['coloring', 'colouring', 'color', 'تلوين'],
      'music' => ['music', 'موسيقى'],
      'singing' => ['singing', 'song', 'غناء', 'أناشيد'],
      'sports' => ['sports', 'sport', 'رياضة'],
      'cooking' => ['cooking', 'cook', 'طبخ'],
      _ => [raw],
    };
  }

  List<PublicContentItem> _filteredCmsVideos(List<PublicContentItem> items) {
    return items.where((item) {
      final title = _localizedCmsTitle(item).toLowerCase();
      final matchesQuery = title.contains(_searchQuery.toLowerCase());
      final matchesLevel =
          _selectedLevel == "all" || _cmsLevel(item) == _selectedLevel;
      return matchesQuery && matchesLevel;
    }).toList();
  }

  String _localizedCmsTitle(PublicContentItem item) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final preferred = locale.startsWith('ar') ? item.titleAr : item.titleEn;
    return preferred.trim().isNotEmpty ? preferred : item.titleEn;
  }

  String _cmsLevel(PublicContentItem item) {
    final metadataLevel =
        (item.metadata['difficulty'] ?? item.metadata['level'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (metadataLevel.contains('advanced') || metadataLevel.contains('متقدم')) {
      return 'advanced';
    }
    if (metadataLevel.contains('intermediate') ||
        metadataLevel.contains('متوسط')) {
      return 'intermediate';
    }
    return 'beginner';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0).withValuesCompat(alpha: 0.5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.skillful),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _localizedSkillTitle(widget.skillTitle, l10n),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.skillful,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: ChildHeader(
                compact: true,
                padding: EdgeInsets.only(bottom: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withValuesCompat(alpha: 0.1),
                        blurRadius: 5)
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.searchActivities,
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _levels.length,
                itemBuilder: (context, index) {
                  final level = _levels[index];
                  final isSelected = _selectedLevel == level;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLevel = level;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.skillful : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.skillful
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          _levelLabel(level, l10n),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<PublicContentItem>>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  final cmsItems =
                      _filteredCmsVideos(snapshot.data ?? const []);
                  if (cmsItems.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noActivitiesFound,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: cmsItems.map(_buildCmsVideoCard).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmsVideoCard(PublicContentItem item) {
    final l10n = AppLocalizations.of(context)!;
    final title = _localizedCmsTitle(item);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage = thumbnailUrl != null &&
        thumbnailUrl.trim().isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SkillVideoScreen(
              videoTitle: title,
              videoUrl: item.preferredVideoUrl,
              thumbnailUrl: item.effectiveThumbnailUrl,
              description: item.descriptionEn ?? item.descriptionAr,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: hasRemoteImage
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildCmsVideoFallbackIcon(),
                      )
                    : _buildCmsVideoFallbackIcon(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.skillful.withValuesCompat(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.watchNow,
                        style: const TextStyle(
                          color: AppColors.skillful,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.skillful.withValuesCompat(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: AppColors.skillful),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmsVideoFallbackIcon() {
    return Center(
      child: Icon(
        Icons.play_circle_fill,
        color: AppColors.skillful,
        size: 50,
      ),
    );
  }

  String _localizedSkillTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Cooking' => l10n.skillCooking,
      'Drawing' => l10n.skillDrawing,
      'Coloring' => l10n.coloringTitle,
      'Music' => l10n.music,
      'Singing' => l10n.skillSinging,
      'Handcrafts' => l10n.skillHandcrafts,
      'Sports' => l10n.skillSports,
      _ => raw,
    };
  }

  String _levelLabel(String level, AppLocalizations l10n) {
    return switch (level) {
      'all' => l10n.all,
      'beginner' => l10n.beginner,
      'intermediate' => l10n.intermediate,
      'advanced' => l10n.advanced,
      _ => level,
    };
  }
}

// Skill Video Player Screen
class SkillVideoScreen extends StatelessWidget {
  final String videoTitle;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? description;
  const SkillVideoScreen({
    super.key,
    required this.videoTitle,
    this.videoUrl,
    this.thumbnailUrl,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.skillful),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      videoTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.skillful,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: ChildHeader(
                compact: true,
                padding: EdgeInsets.only(bottom: 12),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      if ((videoUrl ?? '').trim().isNotEmpty)
                        Column(
                          children: [
                            CloudinaryVideoPlayerView(videoUrl: videoUrl!),
                            const SizedBox(height: 16),
                            if ((description ?? '').trim().isNotEmpty)
                              Text(
                                description!,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.grey[700],
                                ),
                              ),
                          ],
                        )
                      else
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.skillful
                                    .withValuesCompat(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.play_circle_outline,
                                      size: 60, color: Colors.grey[400]),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.skillful,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.skillful
                                          .withValuesCompat(alpha: 0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 40),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValuesCompat(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.star,
                                      color: Colors.orange[700]),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.letsCreate,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Text(
                              l10n.followStepsInVideo(videoTitle),
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.skillful,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text(
                                  l10n.imDone,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCmsVideoHeroCard extends StatelessWidget {
  const _SkillCmsVideoHeroCard({
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.onWatch,
  });

  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasThumbnail = (thumbnailUrl ?? '').trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.skillful.withValuesCompat(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: hasThumbnail
                      ? Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _SkillCmsVideoFallbackThumbnail(),
                        )
                      : _SkillCmsVideoFallbackThumbnail(),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.skillful.withValuesCompat(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.skillful.withValuesCompat(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onWatch,
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onWatch,
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: Text(l10n.playWatchVideoAction),
          ),
        ],
      ),
    );
  }
}

class _SkillCmsVideoFallbackThumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 64,
          color: AppColors.skillful,
        ),
      ),
    );
  }
}

Future<void> _launchSkillCmsVideo(BuildContext context, String rawUrl) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.playVideoLaunchFailed)),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.playVideoLaunchFailed)),
    );
  }
}

/// 4. Educational Screen
class EducationalScreen extends StatelessWidget {
  const EducationalScreen({super.key});

  List<Map<String, dynamic>> get _subjects => educationalSubjects;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ChildHeader(compact: true),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValuesCompat(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Builder(
                builder: (ctx) {
                  final l10n = AppLocalizations.of(ctx)!;
                  return Row(
                    children: [
                      const Icon(Icons.lightbulb,
                          color: AppColors.educational, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        l10n.letsLearnSomethingNew,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.educational,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.0,
                ),
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  return _buildSubjectCard(context, subject);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Map<String, dynamic> subject) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                EducationalSubjectScreen(subjectTitle: subject['title']),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(subject['image']),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValuesCompat(alpha: 0.7),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                subject['title'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Educational Subject Detail Screen
class EducationalSubjectScreen extends ConsumerStatefulWidget {
  final String subjectTitle;
  const EducationalSubjectScreen({super.key, required this.subjectTitle});

  @override
  ConsumerState<EducationalSubjectScreen> createState() =>
      _EducationalSubjectScreenState();
}

class _EducationalSubjectScreenState
    extends ConsumerState<EducationalSubjectScreen> {
  String _searchQuery = "";
  String _selectedLevel = "all";
  late Future<List<PublicContentItem>> _cmsLessonsFuture;

  final List<String> _levels = ["all", "beginner", "intermediate", "advanced"];

  @override
  void initState() {
    super.initState();
    _cmsLessonsFuture = _loadCmsLessons();
  }

  Future<List<PublicContentItem>> _loadCmsLessons() async {
    final repository = ref.read(publicContentRepositoryProvider);
    final categorySlug = await _educationalCategorySlug(repository);
    if (categorySlug != null) {
      final directItems = await repository.fetchItems(
        categorySlug: categorySlug,
      );
      if (directItems.isNotEmpty) {
        return directItems;
      }
    }

    final items = await repository.fetchItems();
    return items.where(_matchesEducationalSubject).toList();
  }

  Future<String?> _educationalCategorySlug(
    PublicContentRepository repository,
  ) async {
    final selectedTerms = _educationalSearchTerms()
        .map(_normalizeCmsPlacementToken)
        .where((term) => term.isNotEmpty)
        .toSet();
    final categories = await repository.fetchCategories();
    for (final category in categories) {
      if (category.axisKey != 'educational') {
        continue;
      }
      final categoryTerms = [
        category.slug,
        category.titleEn,
        category.titleAr,
      ].map(_normalizeCmsPlacementToken);
      if (categoryTerms.any(selectedTerms.contains)) {
        return category.slug;
      }
    }
    return null;
  }

  bool _matchesEducationalSubject(PublicContentItem item) {
    final isEducational = item.axisKey == 'educational' ||
        item.category?.axisKey == 'educational' ||
        item.metadata['axis_key'] == 'educational';
    if (!isEducational) {
      return false;
    }

    final terms = _educationalSearchTerms()
        .map(_normalizeCmsPlacementToken)
        .where((term) => term.isNotEmpty)
        .toList();
    final haystack = [
      item.slug,
      item.titleEn,
      item.titleAr,
      item.descriptionEn ?? '',
      item.descriptionAr ?? '',
      item.category?.slug ?? '',
      item.category?.titleEn ?? '',
      item.category?.titleAr ?? '',
    ].map(_normalizeCmsPlacementToken).join(' ');
    return terms.any(haystack.contains);
  }

  List<String> _educationalSearchTerms() {
    final raw = widget.subjectTitle.trim().toLowerCase();
    return switch (raw) {
      'english' => ['english', 'en', 'انجليزي', 'إنجليزي'],
      'arabic' => ['arabic', 'ar', 'عربي', 'لغة عربية'],
      'geography' => ['geography', 'geo', 'جغرافيا'],
      'history' => ['history', 'تاريخ'],
      'science' => ['science', 'علوم'],
      'math' => ['math', 'mathematics', 'رياضيات', 'حساب'],
      'animals' => ['animals', 'animal', 'حيوانات'],
      'plants' => ['plants', 'plant', 'نباتات'],
      _ => [raw],
    };
  }

  List<Map<String, dynamic>> get _allLessons {
    final l10n = AppLocalizations.of(context)!;
    return buildLegacyEducationalLessons(l10n);
  }

  List<Map<String, dynamic>> get _filteredLessons {
    return _allLessons.where((lesson) {
      final matchesQuery = lesson['title']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesLevel =
          _selectedLevel == "all" || lesson['level'] == _selectedLevel;
      return matchesQuery && matchesLevel;
    }).toList();
  }

  List<PublicContentItem> _filteredCmsLessons(List<PublicContentItem> items) {
    return items.where((item) {
      final title = _localizedCmsTitle(item).toLowerCase();
      final matchesQuery = title.contains(_searchQuery.toLowerCase());
      final matchesLevel =
          _selectedLevel == "all" || _cmsLevel(item) == _selectedLevel;
      return matchesQuery && matchesLevel;
    }).toList();
  }

  String _localizedCmsTitle(PublicContentItem item) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final preferred = locale.startsWith('ar') ? item.titleAr : item.titleEn;
    final fallback = locale.startsWith('ar') ? item.titleEn : item.titleAr;
    return preferred.trim().isNotEmpty ? preferred : fallback;
  }

  String _cmsLevel(PublicContentItem item) {
    final metadataLevel =
        (item.metadata['difficulty'] ?? item.metadata['level'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (metadataLevel.contains('advanced') || metadataLevel.contains('متقدم')) {
      return 'advanced';
    }
    if (metadataLevel.contains('intermediate') ||
        metadataLevel.contains('متوسط')) {
      return 'intermediate';
    }
    return 'beginner';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.educational),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _localizedSubjectTitle(widget.subjectTitle, l10n),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.educational,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: ChildHeader(
                compact: true,
                padding: EdgeInsets.only(bottom: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withValuesCompat(alpha: 0.1),
                        blurRadius: 5)
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.searchLessons,
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _levels.length,
                itemBuilder: (context, index) {
                  final level = _levels[index];
                  final isSelected = _selectedLevel == level;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLevel = level;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.educational : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.educational
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          _levelLabel(level, l10n),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<PublicContentItem>>(
                future: _cmsLessonsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _filteredLessons.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cmsLessons =
                      _filteredCmsLessons(snapshot.data ?? const []);
                  if (_filteredLessons.isEmpty && cmsLessons.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noLessonsFound,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ...cmsLessons.map(_buildCmsLessonCard),
                      ..._filteredLessons.map(_buildLessonCard),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => LessonDetailScreen(
              lessonTitle: lesson['title'],
              lessonImage: lesson['image'],
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: AppColors.educational,
                  size: 50,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lesson['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppColors.educational.withValuesCompat(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lesson['level'],
                        style: const TextStyle(
                          color: AppColors.educational,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(Icons.play_circle_outline,
                  color: AppColors.educational, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmsLessonCard(PublicContentItem item) {
    final title = _localizedCmsTitle(item);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage = thumbnailUrl != null &&
        thumbnailUrl.trim().isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SkillVideoScreen(
              videoTitle: title,
              videoUrl: item.preferredVideoUrl,
              thumbnailUrl: item.effectiveThumbnailUrl,
              description: item.descriptionEn ?? item.descriptionAr,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValuesCompat(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: hasRemoteImage
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildCmsLessonFallbackIcon(),
                      )
                    : _buildCmsLessonFallbackIcon(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppColors.educational.withValuesCompat(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _levelLabel(
                            _cmsLevel(item), AppLocalizations.of(context)!),
                        style: const TextStyle(
                          color: AppColors.educational,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                Icons.play_circle_outline,
                color: AppColors.educational,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmsLessonFallbackIcon() {
    return Center(
      child: Icon(
        Icons.play_circle_fill,
        color: AppColors.educational,
        size: 50,
      ),
    );
  }

  String _localizedSubjectTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'English' => l10n.english,
      'Arabic' => l10n.arabic,
      'Geography' => l10n.geography,
      'History' => l10n.history,
      'Science' => l10n.science,
      'Math' => l10n.mathematics,
      _ => raw,
    };
  }

  String _levelLabel(String level, AppLocalizations l10n) {
    return switch (level) {
      'all' => l10n.all,
      'beginner' => l10n.beginner,
      'intermediate' => l10n.intermediate,
      'advanced' => l10n.advanced,
      _ => level,
    };
  }
}

/// Lesson Detail Screen (Video + Kids Quiz)
class LessonDetailScreen extends StatefulWidget {
  final String lessonTitle;
  final String? lessonImage;

  const LessonDetailScreen(
      {super.key, required this.lessonTitle, this.lessonImage});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFE1F5FE),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.educational),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.lessonTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.educational,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: ChildHeader(
                compact: true,
                padding: EdgeInsets.only(bottom: 12),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValuesCompat(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                color: Colors.indigo[50],
                                width: double.infinity,
                                height: double.infinity,
                                child: const Icon(Icons.play_circle_outline,
                                    size: 60, color: Colors.grey),
                              ),
                            ),
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValuesCompat(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow,
                                  color: AppColors.educational, size: 40),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValuesCompat(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.educational
                                        .withValuesCompat(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.quiz,
                                      color: AppColors.educational),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.readyForFunQuiz,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n.playQuizToEarnStars,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => LessonQuizScreen(
                                        lessonTitle: widget.lessonTitle,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_circle_fill),
                                label: Text(
                                  l10n.startQuiz,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.educational,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonQuizScreen extends StatefulWidget {
  final String lessonTitle;

  const LessonQuizScreen({super.key, required this.lessonTitle});

  @override
  State<LessonQuizScreen> createState() => _LessonQuizScreenState();
}

class _LessonQuizScreenState extends State<LessonQuizScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _showResult = false;

  List<Map<String, dynamic>> get _quizData => lessonQuizQuestions;

  void _checkAnswer(int selectedIndex) {
    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _showResult = true;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _quizData.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _showResult = false;
      });
    } else {
      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              Text(l10n.greatJob),
            ],
          ),
          content: Text(l10n.youCompletedQuiz),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l10n.awesome,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentQ = _quizData[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.lessonTitle} Quiz',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.educational,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.educational),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValuesCompat(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            AppColors.educational.withValuesCompat(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.star, color: AppColors.educational),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.quizTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.questionOf(
                                _currentQuestionIndex + 1, _quizData.length),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _quizData.length,
                  backgroundColor: Colors.orange[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.educational),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  currentQ['question'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: List.generate(currentQ['options'].length, (index) {
                    final option = currentQ['options'][index];
                    final isCorrect = index == currentQ['correct'];
                    final isSelected = _selectedAnswerIndex == index;

                    Color bgColor = Colors.white;
                    Color borderColor = Colors.orange[200]!;
                    Color textColor = Colors.black87;

                    if (_showResult) {
                      if (isCorrect) {
                        bgColor = Colors.green[100]!;
                        borderColor = Colors.green;
                        textColor = Colors.green[900]!;
                      } else if (isSelected && !isCorrect) {
                        bgColor = Colors.red[100]!;
                        borderColor = Colors.red;
                        textColor = Colors.red[900]!;
                      }
                    } else if (isSelected) {
                      bgColor =
                          AppColors.educational.withValuesCompat(alpha: 0.1);
                      borderColor = AppColors.educational;
                    }

                    return InkWell(
                      onTap: _showResult ? null : () => _checkAnswer(index),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showResult ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.educational,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _currentQuestionIndex < _quizData.length - 1
                        ? l10n.nextQuestion
                        : l10n.lessonFinish,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
