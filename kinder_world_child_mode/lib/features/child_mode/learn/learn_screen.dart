import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/public_content.dart';
import 'package:kinder_world/core/repositories/public_content_repository.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/child_header.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  late Future<List<PublicContentCategory>> _categoriesFuture;
  late Future<List<PublicContentItem>> _latestItemsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ref.read(publicContentRepositoryProvider).fetchCategories();
    _latestItemsFuture = ref.read(publicContentRepositoryProvider).fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _categoriesFuture =
                  ref.read(publicContentRepositoryProvider).fetchCategories();
              _latestItemsFuture = ref.read(publicContentRepositoryProvider).fetchItems();
            });
            await Future.wait([_categoriesFuture, _latestItemsFuture]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: l10n.searchPages,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const ChildHeader(padding: EdgeInsets.only(bottom: 20)),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      childTheme.learning.withValues(alpha: 0.14),
                      childTheme.fun.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.explore_rounded, color: childTheme.learning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.letsExploreAndLearn,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ChildSectionHeader(title: l10n.categoryEducational),
              const SizedBox(height: 12),
              FutureBuilder<List<PublicContentCategory>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  final categories = _filterCategories(snapshot.data ?? const []);
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      categories.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (categories.isEmpty) {
                    return ChildEmptyState(
                      emoji: '...',
                      title: l10n.noPagesFound,
                      subtitle: 'No published learning categories are available yet.',
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategoryCard(
                        category: category,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChildCategoryContentScreen(category: category),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const ChildSectionHeader(title: 'Latest Published Content'),
              const SizedBox(height: 12),
              FutureBuilder<List<PublicContentItem>>(
                future: _latestItemsFuture,
                builder: (context, snapshot) {
                  final items = _filterItems(snapshot.data ?? const []);
                  if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return ChildEmptyState(
                      emoji: '...',
                      title: l10n.noPagesFound,
                      subtitle: 'Publish lessons, stories, or activities from admin CMS.',
                    );
                  }
                  return Column(
                    children: items
                        .take(8)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ContentCard(
                              item: item,
                              onTap: () => _openItem(item),
                            ),
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
    );
  }

  List<PublicContentCategory> _filterCategories(List<PublicContentCategory> items) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((item) {
      final haystack = [
        item.slug,
        item.titleEn,
        item.titleAr,
        item.descriptionEn ?? '',
        item.descriptionAr ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<PublicContentItem> _filterItems(List<PublicContentItem> items) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((item) {
      final haystack = [
        item.slug,
        item.titleEn,
        item.titleAr,
        item.descriptionEn ?? '',
        item.descriptionAr ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _openItem(PublicContentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildContentDetailScreen(initialItem: item),
      ),
    );
  }
}

class ChildCategoryContentScreen extends ConsumerStatefulWidget {
  const ChildCategoryContentScreen({
    super.key,
    required this.category,
  });

  final PublicContentCategory category;

  @override
  ConsumerState<ChildCategoryContentScreen> createState() =>
      _ChildCategoryContentScreenState();
}

class _ChildCategoryContentScreenState
    extends ConsumerState<ChildCategoryContentScreen> {
  late Future<List<PublicContentItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = ref.read(publicContentRepositoryProvider).fetchItems(
          categorySlug: widget.category.slug,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_localized(widget.category.titleEn, widget.category.titleAr, context)),
      ),
      body: FutureBuilder<List<PublicContentItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const ChildEmptyState(
              emoji: '...',
              title: 'No published items',
              subtitle: 'Publish content in this category from admin CMS.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ContentCard(
                item: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChildContentDetailScreen(initialItem: item),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
      backgroundColor: colors.surface,
    );
  }
}

class ChildContentDetailScreen extends ConsumerStatefulWidget {
  const ChildContentDetailScreen({
    super.key,
    required this.initialItem,
  });

  final PublicContentItem initialItem;

  @override
  ConsumerState<ChildContentDetailScreen> createState() =>
      _ChildContentDetailScreenState();
}

class _ChildContentDetailScreenState extends ConsumerState<ChildContentDetailScreen> {
  late Future<PublicContentItem?> _itemFuture;

  @override
  void initState() {
    super.initState();
    _itemFuture = ref.read(publicContentRepositoryProvider).fetchItem(
          widget.initialItem.slug,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_localized(widget.initialItem.titleEn, widget.initialItem.titleAr, context)),
      ),
      body: FutureBuilder<PublicContentItem?>(
        future: _itemFuture,
        builder: (context, snapshot) {
          final item = snapshot.data ?? widget.initialItem;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _DetailHero(item: item),
              const SizedBox(height: 20),
              Text(
                _localized(item.titleEn, item.titleAr, context),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              if ((item.descriptionEn ?? item.descriptionAr ?? '').isNotEmpty)
                Text(
                  _localized(item.descriptionEn ?? '', item.descriptionAr ?? '', context),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _localized(item.bodyEn ?? '', item.bodyAr ?? '', context).isEmpty
                      ? 'No published body content yet.'
                      : _localized(item.bodyEn ?? '', item.bodyAr ?? '', context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
              if (item.quizzes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const ChildSectionHeader(title: 'Published Quizzes'),
                const SizedBox(height: 12),
                ...item.quizzes.map(
                  (quiz) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.quiz_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localized(quiz.titleEn, quiz.titleAr, context),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text('${quiz.questionCount} questions'),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final PublicContentCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _categoryColor(category.slug, context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.18),
              accent.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_categoryIcon(category.slug), color: accent, size: 28),
            const Spacer(),
            Text(
              _localized(category.titleEn, category.titleAr, context),
              maxLines: 2,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${category.contentCount} items',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.item,
    required this.onTap,
  });

  final PublicContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return KinderCard(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        children: [
          _Thumbnail(
            url: item.thumbnailUrl,
            icon: _contentIcon(item.contentType),
            color: _categoryColor(item.category?.slug ?? item.contentType, context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localized(item.titleEn, item.titleAr, context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _localized(item.descriptionEn ?? '', item.descriptionAr ?? '', context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(label: _displayType(item.contentType)),
                      if ((item.ageGroup ?? '').isNotEmpty) _MetaChip(label: item.ageGroup!),
                      if (item.quizzes.isNotEmpty) _MetaChip(label: '${item.quizzes.length} quiz'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor(item.category?.slug ?? item.contentType, context);
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: _Thumbnail(
        url: item.thumbnailUrl,
        icon: _contentIcon(item.contentType),
        color: accent,
        borderRadius: 24,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.url,
    required this.icon,
    required this.color,
    this.borderRadius = 18,
  });

  final String? url;
  final IconData icon;
  final Color color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasRemoteImage = url != null &&
        url!.trim().isNotEmpty &&
        (url!.startsWith('http://') || url!.startsWith('https://'));
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: 120,
        height: double.infinity,
        child: hasRemoteImage
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Icon(icon, size: 34, color: color),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _localized(String en, String ar, BuildContext context) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  if (isArabic && ar.trim().isNotEmpty) {
    return ar;
  }
  if (en.trim().isNotEmpty) {
    return en;
  }
  return ar;
}

String _displayType(String contentType) {
  switch (contentType) {
    case 'lesson':
      return 'Lesson';
    case 'story':
      return 'Story';
    case 'video':
      return 'Video';
    case 'activity':
      return 'Activity';
    default:
      return contentType;
  }
}

IconData _categoryIcon(String slug) {
  switch (slug) {
    case 'behavioral':
      return Icons.favorite_rounded;
    case 'skillful':
      return Icons.auto_awesome_rounded;
    case 'entertaining':
      return Icons.celebration_rounded;
    case 'educational':
      return Icons.menu_book_rounded;
    default:
      return Icons.explore_rounded;
  }
}

IconData _contentIcon(String contentType) {
  switch (contentType) {
    case 'lesson':
      return Icons.school_rounded;
    case 'story':
      return Icons.auto_stories_rounded;
    case 'video':
      return Icons.play_circle_fill_rounded;
    case 'activity':
      return Icons.extension_rounded;
    default:
      return Icons.article_rounded;
  }
}

Color _categoryColor(String key, BuildContext context) {
  final childTheme = context.childTheme;
  switch (key) {
    case 'behavioral':
      return childTheme.kindness;
    case 'skillful':
      return childTheme.skill;
    case 'entertaining':
      return childTheme.fun;
    case 'educational':
      return childTheme.learning;
    default:
      return childTheme.learning;
  }
}
