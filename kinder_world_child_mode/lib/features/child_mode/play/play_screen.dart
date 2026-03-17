import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/public_content.dart';
import 'package:kinder_world/core/repositories/public_content_repository.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/learn/learn_screen.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_screen.dart';

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
              _itemsFuture = ref.read(publicContentRepositoryProvider).fetchItems();
            });
            await _itemsFuture;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(colors, l10n),
              _buildTypeTabs(),
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
                        subtitle: 'Publish child-safe videos, stories, or activities from CMS.',
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      children: [
                        if (_selectedType == 'all' && _searchQuery.isEmpty) ...[
                          ChildSectionHeader(title: l10n.featured),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filtered.take(3).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) =>
                                  _FeaturedContentCard(item: filtered[index]),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        ChildSectionHeader(title: l10n.allVideos),
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
              color: successColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: successColor.withValues(alpha: 0.3),
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

  Widget _buildTypeTabs() {
    const tabs = [
      ('all', 'All'),
      ('video', 'Videos'),
      ('story', 'Stories'),
      ('activity', 'Activities'),
      ('lesson', 'Lessons'),
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
    final accent = _categoryColor(item.category?.slug ?? item.contentType, context);
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
                    url: item.thumbnailUrl,
                    icon: _contentIcon(item.contentType),
                    color: accent,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _displayType(item.contentType),
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
        builder: (_) => ChildContentDetailScreen(initialItem: item),
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
    final tagColor = _categoryColor(item.category?.slug ?? item.contentType, context);
    return KinderCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildContentDetailScreen(initialItem: item),
          ),
        );
      },
      child: Row(
        children: [
          _Thumbnail(
            url: item.thumbnailUrl,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _displayType(item.contentType),
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
