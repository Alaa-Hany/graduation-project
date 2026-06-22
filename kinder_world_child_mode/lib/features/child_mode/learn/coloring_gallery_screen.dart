import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/public_content.dart';
import 'package:kinder_world/core/repositories/public_content_repository.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/cloudinary_video_player_view.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/features/child_mode/learn/coloring_page_screen.dart';
import 'package:kinder_world/features/child_mode/learn/coloring_progress_storage.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ColoringGalleryScreen extends ConsumerStatefulWidget {
  const ColoringGalleryScreen({super.key});

  @override
  ConsumerState<ColoringGalleryScreen> createState() =>
      _ColoringGalleryScreenState();
}

class _ColoringGalleryScreenState extends ConsumerState<ColoringGalleryScreen> {
  String _selectedLevel = 'All';
  final Map<String, ColoringProgressData> _progressBySvgPath = {};
  final Map<String, SvgColoringTemplate> _templateBySvgPath = {};
  late Future<List<PublicContentItem>> _cmsVideosFuture;

  static const List<String> _levels = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const List<Map<String, String>> _items = [
    {
      'title': 'Coloring Page 1',
      'image': 'assets/images/coloring/kids_coloring_final_v4_1.svg',
      'svg': 'assets/images/coloring/kids_coloring_final_v4_1.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 2',
      'image': 'assets/images/coloring/house_coloring_fixed.svg',
      'svg': 'assets/images/coloring/house_coloring_fixed.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 3',
      'image': 'assets/images/coloring/fish_coloring_v2.svg',
      'svg': 'assets/images/coloring/fish_coloring_v2.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 4',
      'image': 'assets/images/coloring/butterfly_coloring.svg',
      'svg': 'assets/images/coloring/butterfly_coloring.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 5',
      'image': 'assets/images/coloring/apple_coloring.svg',
      'svg': 'assets/images/coloring/apple_coloring.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 6',
      'image': 'assets/images/coloring/rabbit2_coloring.svg',
      'svg': 'assets/images/coloring/rabbit2_coloring.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 7',
      'image': 'assets/images/coloring/coloring_bw_fixed.svg',
      'svg': 'assets/images/coloring/coloring_bw_fixed.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 8',
      'image': 'assets/images/coloring/bird_coloring.svg',
      'svg': 'assets/images/coloring/bird_coloring.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 9',
      'image': 'assets/images/coloring/new_coloring.svg',
      'svg': 'assets/images/coloring/new_coloring.svg',
      'level': 'Beginner',
    },
    {
      'title': 'Coloring Page 10',
      'image': 'assets/images/coloring/coloring3.svg',
      'svg': 'assets/images/coloring/coloring3.svg',
      'level': 'Beginner',
    },
  ];

  List<Map<String, String>> get _filteredItems {
    if (_selectedLevel == 'All') return _items;
    return _items.where((item) => item['level'] == _selectedLevel).toList();
  }

  @override
  void initState() {
    super.initState();
    _cmsVideosFuture = _loadCmsVideos();
    _loadGalleryProgress();
  }

  Future<List<PublicContentItem>> _loadCmsVideos() async {
    return ref.read(publicContentRepositoryProvider).fetchItems(
          categorySlug: 'coloring',
          contentType: 'video',
        );
  }

  Future<void> _loadGalleryProgress() async {
    final progressMap = <String, ColoringProgressData>{};
    final templateMap = <String, SvgColoringTemplate>{};

    for (final item in _items) {
      final svgPath = item['svg'];
      if (svgPath == null || svgPath.isEmpty) continue;
      progressMap[svgPath] = await ColoringProgressStorage.load(svgPath);

      try {
        final rawSvg = await rootBundle.loadString(svgPath);
        templateMap[svgPath] = SvgColoringTemplate.fromRawSvg(rawSvg);
      } catch (_) {
        // Keep gallery resilient if one SVG fails to parse.
      }
    }

    if (!mounted) return;
    setState(() {
      _progressBySvgPath
        ..clear()
        ..addAll(progressMap);
      _templateBySvgPath
        ..clear()
        ..addAll(templateMap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final child = context.childTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.coloringTitle,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      body: Stack(
        children: [
          const _PlayfulBackground(),
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ChildHeader(compact: true),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _levels.length,
                  itemBuilder: (context, index) {
                    final level = _levels[index];
                    final selected = level == _selectedLevel;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedLevel = level),
                        borderRadius: BorderRadius.circular(26),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: selected
                                ? child.kindness.withValuesCompat(alpha: 0.22)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: selected
                                  ? child.kindness
                                  : colors.outlineVariant,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (selected ? child.kindness : child.fun)
                                    .withValuesCompat(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              level == 'All'
                                  ? l10n.all
                                  : level == 'Beginner'
                                      ? l10n.beginner
                                      : level == 'Intermediate'
                                          ? l10n.intermediate
                                          : level == 'Advanced'
                                              ? l10n.advanced
                                              : level,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                                color: selected
                                    ? child.kindness.onColor
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<PublicContentItem>>(
                  future: _cmsVideosFuture,
                  builder: (context, snapshot) {
                    final cmsVideos =
                        snapshot.data ?? const <PublicContentItem>[];
                    if (_filteredItems.isEmpty && cmsVideos.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: colors.surface.withValuesCompat(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: child.fun.withValuesCompat(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Text(
                            l10n.noColoringPages,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ...cmsVideos
                            .map((item) => _CmsColoringVideoCard(item: item)),
                        ...List.generate(_filteredItems.length, (index) {
                          final item = _filteredItems[index];
                          final svgPath = item['svg']!;
                          final progress = _progressBySvgPath[svgPath];
                          final template = _templateBySvgPath[svgPath];
                          return _ColoringItemCard(
                            title: l10n.coloringPageN(index + 1),
                            imagePath: item['image']!,
                            previewTemplate: template,
                            previewColors:
                                progress?.colors ?? const <String, Color>{},
                            isCompleted: progress?.isCompleted ?? false,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ColoringPageScreen(
                                    svgAssetPath: item['svg']!,
                                    title: item['title']!,
                                  ),
                                ),
                              );
                              if (!mounted) return;
                              await _loadGalleryProgress();
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CmsColoringVideoCard extends StatelessWidget {
  const _CmsColoringVideoCard({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final title = Localizations.localeOf(context)
            .languageCode
            .toLowerCase()
            .startsWith('ar')
        ? item.titleAr
        : item.titleEn;
    final description = (Localizations.localeOf(context)
                .languageCode
                .toLowerCase()
                .startsWith('ar')
            ? (item.descriptionAr ?? item.descriptionEn ?? '')
            : (item.descriptionEn ?? item.descriptionAr ?? ''))
        .trim();
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValuesCompat(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95D5FF).withValuesCompat(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ColoringVideoPlayerScreen(item: item),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 17 : 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: const Color(0xFF0B4A75),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA5E17F),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA5E17F)
                                  .withValuesCompat(alpha: 0.55),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Tap to Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: compact ? 52 : 58,
                  height: compact ? 52 : 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD66B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD66B)
                            .withValuesCompat(alpha: 0.7),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: const Color(0xFF8B4E00),
                    size: compact ? 30 : 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColoringVideoPlayerScreen extends StatelessWidget {
  const _ColoringVideoPlayerScreen({required this.item});

  final PublicContentItem item;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final isArabic = locale.startsWith('ar');
    final title = isArabic ? item.titleAr : item.titleEn;
    final description = (isArabic
            ? (item.descriptionAr ?? item.descriptionEn ?? '')
            : (item.descriptionEn ?? item.descriptionAr ?? ''))
        .trim();
    final videoUrl = (item.preferredVideoUrl ?? '').trim();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Color(0xFF9C27B0),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9C27B0),
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ChildHeader(
                compact: true,
                padding: EdgeInsets.only(bottom: 12),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (videoUrl.isNotEmpty)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child:
                                CloudinaryVideoPlayerView(videoUrl: videoUrl),
                          ),
                          const SizedBox(height: 16),
                          if (description.isNotEmpty)
                            Text(
                              description,
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
                              color: const Color(0xFF9C27B0)
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
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9C27B0)
                                        .withValuesCompat(alpha: 0.35),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
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
                                child: Icon(
                                  Icons.star,
                                  color: Colors.orange[700],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Let's Watch!",
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
                            description.isNotEmpty
                                ? description
                                : 'Follow the video and enjoy coloring step by step.',
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
                                backgroundColor: const Color(0xFF9C27B0),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'I am done',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        ),
      ),
    );
  }
}

class _ColoringItemCard extends StatefulWidget {
  const _ColoringItemCard({
    required this.title,
    required this.imagePath,
    required this.previewColors,
    required this.isCompleted,
    required this.onTap,
    this.previewTemplate,
  });

  final String title;
  final String imagePath;
  final SvgColoringTemplate? previewTemplate;
  final Map<String, Color> previewColors;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  State<_ColoringItemCard> createState() => _ColoringItemCardState();
}

class _ColoringItemCardState extends State<_ColoringItemCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isSvg = widget.imagePath.toLowerCase().endsWith('.svg');
    final hasPreviewSvg = isSvg && widget.previewTemplate != null;
    final compact = MediaQuery.sizeOf(context).width < 390;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.97 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: compact ? 132 : 138,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFFF7D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF95D5FF).withValuesCompat(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child: Container(
                    width: compact ? 108 : 120,
                    color: const Color(0xFFDDF3FF),
                    child: hasPreviewSvg
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: SvgPicture.string(
                                    widget.previewTemplate!
                                        .buildAreasSvg(widget.previewColors),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: SvgPicture.string(
                                    widget.previewTemplate!.outlineSvg,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : isSvg
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: SvgPicture.asset(
                                  widget.imagePath,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                widget.imagePath,
                                width: 126,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 126,
                                    color: Colors.teal.shade50,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: context.childTheme.skill,
                                      size: 34,
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  fontSize: compact ? 15 : 17,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Cairo',
                                  color: const Color(0xFF0B4A75),
                                  height: 1.05,
                                ),
                              ),
                            ),
                            if (widget.isCompleted)
                              const _GallerySunStarBadge(),
                          ],
                        ),
                        if (widget.isCompleted) ...[
                          const SizedBox(height: 4),
                          Builder(
                            builder: (ctx) {
                              final l10n = AppLocalizations.of(ctx)!;
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.wb_sunny_rounded,
                                    size: 18,
                                    color: Color(0xFFFFB300),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.greatJob,
                                    style: TextStyle(
                                      fontSize: compact ? 12 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2E7D32),
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA5E17F),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA5E17F)
                                    .withValuesCompat(alpha: 0.55),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Builder(
                            builder: (ctx) {
                              final l10n = AppLocalizations.of(ctx)!;
                              return Text(
                                l10n.tapToColor,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: compact ? 34 : 38,
                    height: compact ? 34 : 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD66B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD66B)
                              .withValuesCompat(alpha: 0.7),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF8B4E00),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayfulBackground extends StatelessWidget {
  const _PlayfulBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD5F1FF), Color(0xFFFFF9C9)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 24,
          left: 20,
          child: Icon(Icons.star_rounded,
              color: Colors.white.withValuesCompat(alpha: 0.8), size: 18),
        ),
        Positioned(
          top: 58,
          right: 36,
          child: Icon(Icons.star_rounded,
              color: const Color(0xFFFFD54F).withValuesCompat(alpha: 0.9),
              size: 20),
        ),
      ],
    );
  }
}

class _GallerySunStarBadge extends StatelessWidget {
  const _GallerySunStarBadge();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          color: Color(0xFFFFC107),
          size: 22,
        ),
        Positioned(
          right: -3,
          top: -4,
          child: Icon(
            Icons.star_rounded,
            color: Color(0xFFFF8F00),
            size: 12,
          ),
        ),
      ],
    );
  }
}
