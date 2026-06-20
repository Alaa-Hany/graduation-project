import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/public_content.dart';
import 'package:kinder_world/core/repositories/public_content_repository.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/core/widgets/cloudinary_video_player_view.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_screen.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  late Future<List<PublicContentItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = ref.read(publicContentRepositoryProvider).fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _itemsFuture =
                  ref.read(publicContentRepositoryProvider).fetchItems();
            });
            await _itemsFuture;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(colors, l10n),
              _buildTypeTabs(l10n),
              const SizedBox(height: 14),
              _buildSearchBar(colors, l10n),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<PublicContentItem>>(
                  future: _itemsFuture,
                  builder: (context, snapshot) {
                    final filtered = _filteredItems(snapshot.data ?? const []);
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        filtered.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (filtered.isEmpty) {
                      return ChildEmptyState(
                        emoji: '...',
                        title: l10n.nothingFound,
                        subtitle: l10n.playContentEmptyStateSubtitle,
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16),
                      children: [
                        if (_selectedType == 'all' && _searchQuery.isEmpty) ...[
                          ChildSectionHeader(title: l10n.featured),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filtered.take(3).length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) =>
                                  _FeaturedContentCard(item: filtered[index]),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        ChildSectionHeader(
                          title: _sectionTitle(_selectedType, l10n),
                        ),
                        const SizedBox(height: 12),
                        ...filtered.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PlayableContentCard(item: item),
                          ),
                        ),
                      ],
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

  List<PublicContentItem> _filteredItems(List<PublicContentItem> items) {
    final allowed = items.where((item) {
      if (_selectedType == 'all') {
        return true;
      }
      return item.contentType == _selectedType;
    }).toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return allowed;
    }
    return allowed.where((item) {
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

  Widget _buildHeader(ColorScheme colors, AppLocalizations l10n) {
    final successColor = context.successColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.playTime,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                l10n.safeAndFunVideos,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: successColor.withValuesCompat(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: successColor.withValuesCompat(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 14, color: successColor),
                const SizedBox(width: 4),
                Text(
                  l10n.safeMode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: successColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _iconBubble(
            Icons.settings_rounded,
            colors: colors,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChildSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs(AppLocalizations l10n) {
    final tabs = [
      ('all', l10n.all),
      ('video', l10n.categoryVideos),
      ('story', l10n.categoryStories),
      ('activity', l10n.activities),
      ('lesson', l10n.availableLessons),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          return ChoiceChip(
            label: Text(tab.$2),
            selected: _selectedType == tab.$1,
            onSelected: (_) => setState(() => _selectedType = tab.$1),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colors, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: l10n.searchVideos,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _iconBubble(
    IconData icon, {
    required ColorScheme colors,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18, color: colors.onSurface),
      ),
    );
  }
}

class _FeaturedContentCard extends StatelessWidget {
  const _FeaturedContentCard({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent =
        _categoryColor(item.category?.slug ?? item.contentType, context);
    return SizedBox(
      width: 220,
      child: KinderCard(
        padding: EdgeInsets.zero,
        borderRadius: 18,
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumbnail(
                    url: item.effectiveThumbnailUrl,
                    icon: _contentIcon(item.contentType),
                    color: accent,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _displayType(
                            item.contentType, AppLocalizations.of(context)!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _localized(item.titleEn, item.titleAr, context),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayContentDetailScreen(initialItem: item),
      ),
    );
  }
}

class _PlayableContentCard extends StatelessWidget {
  const _PlayableContentCard({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagColor =
        _categoryColor(item.category?.slug ?? item.contentType, context);
    return KinderCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PlayContentDetailScreen(initialItem: item),
          ),
        );
      },
      child: Row(
        children: [
          _Thumbnail(
            url: item.effectiveThumbnailUrl,
            icon: _contentIcon(item.contentType),
            color: tagColor,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localized(item.titleEn, item.titleAr, context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagColor.withValuesCompat(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _displayType(
                          item.contentType, AppLocalizations.of(context)!),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayContentDetailScreen extends ConsumerStatefulWidget {
  const _PlayContentDetailScreen({
    required this.initialItem,
  });

  final PublicContentItem initialItem;

  @override
  ConsumerState<_PlayContentDetailScreen> createState() =>
      _PlayContentDetailScreenState();
}

class _PlayContentDetailScreenState
    extends ConsumerState<_PlayContentDetailScreen> {
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _localized(
            widget.initialItem.titleEn,
            widget.initialItem.titleAr,
            context,
          ),
        ),
      ),
      body: FutureBuilder<PublicContentItem?>(
        future: _itemFuture,
        builder: (context, snapshot) {
          final item = snapshot.data ?? widget.initialItem;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PlayDetailHero(item: item),
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
                  _localized(
                    item.descriptionEn ?? '',
                    item.descriptionAr ?? '',
                    context,
                  ),
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
                  _localized(item.bodyEn ?? '', item.bodyAr ?? '', context)
                          .isEmpty
                      ? l10n.playNoBodyContentYet
                      : _localized(
                          item.bodyEn ?? '',
                          item.bodyAr ?? '',
                          context,
                        ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                ),
              ),
              if (item.hasVideo) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.playVideoSectionTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if ((item.effectiveVideoProvider ??
                              item.videoHostTier ??
                              '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((item.effectiveVideoProvider ?? '').isNotEmpty)
                              _VideoMetaChip(
                                label: item.effectiveVideoProvider!,
                                icon: Icons.cloud_outlined,
                              ),
                            if ((item.videoHostTier ?? '').isNotEmpty)
                              _VideoMetaChip(
                                label: item.videoHostTier!,
                                icon: Icons.speed_rounded,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      CloudinaryVideoPlayerView(
                        videoUrl: item.preferredVideoUrl!,
                      ),
                    ],
                  ),
                ),
              ],
              if (item.quizzes.isNotEmpty) ...[
                const SizedBox(height: 20),
                ChildSectionHeader(title: l10n.playPublishedQuizzes),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${quiz.questionCount} ${l10n.adminCmsQuestionsLabel}'),
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

class _PlayDetailHero extends StatelessWidget {
  const _PlayDetailHero({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final accent =
        _categoryColor(item.category?.slug ?? item.contentType, context);
    final thumbnailUrl = item.effectiveThumbnailUrl;
    final hasRemoteImage = thumbnailUrl != null &&
        thumbnailUrl.trim().isNotEmpty &&
        (thumbnailUrl.startsWith('http://') ||
            thumbnailUrl.startsWith('https://'));

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValuesCompat(alpha: 0.24),
            accent.withValuesCompat(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: hasRemoteImage
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _PlayDetailHeroFallback(
                  icon: _contentIcon(item.contentType),
                  color: accent,
                ),
              )
            : _PlayDetailHeroFallback(
                icon: _contentIcon(item.contentType),
                color: accent,
              ),
      ),
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayDetailHeroFallback extends StatelessWidget {
  const _PlayDetailHeroFallback({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValuesCompat(alpha: 0.22),
            color.withValuesCompat(alpha: 0.10),
          ],
        ),
      ),
      child: Icon(icon, size: 34, color: color),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.url,
    required this.icon,
    required this.color,
  });

  final String? url;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasRemoteImage = url != null &&
        url!.trim().isNotEmpty &&
        (url!.startsWith('http://') || url!.startsWith('https://'));
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
      child: SizedBox(
        width: 110,
        height: 80,
        child: hasRemoteImage
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(),
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
            color.withValuesCompat(alpha: 0.22),
            color.withValuesCompat(alpha: 0.10),
          ],
        ),
      ),
      child: Icon(icon, size: 30, color: color),
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

String _displayType(String contentType, AppLocalizations l10n) {
  switch (contentType) {
    case 'lesson':
      return l10n.playTypeLesson;
    case 'story':
      return l10n.playTypeStory;
    case 'video':
      return l10n.playTypeVideo;
    case 'activity':
      return l10n.playTypeActivity;
    default:
      return contentType;
  }
}

String _sectionTitle(String selectedType, AppLocalizations l10n) {
  switch (selectedType) {
    case 'video':
      return l10n.categoryVideos;
    case 'story':
      return l10n.categoryStories;
    case 'activity':
      return l10n.activities;
    case 'lesson':
      return l10n.availableLessons;
    default:
      return l10n.playPublishedContent;
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
