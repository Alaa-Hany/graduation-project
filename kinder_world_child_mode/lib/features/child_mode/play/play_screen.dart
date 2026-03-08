import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/widgets/child_design_system.dart';
import 'package:kinder_world/features/child_mode/profile/child_profile_screen.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  int _selectedTab = 0;
  String _searchQuery = '';

  // 'key' is stable for filtering; 'label' is kept for legacy but not used for filtering
  static const _tabs = <Map<String, Object>>[
    {'key': 'all', 'emoji': '🌟', 'color': Color(0xFF6C63FF)},
    {'key': 'kindness', 'emoji': '💖', 'color': Color(0xFFE91E63)},
    {'key': 'learning', 'emoji': '📚', 'color': Color(0xFF3F51B5)},
    {'key': 'skills', 'emoji': '🧩', 'color': Color(0xFF9C27B0)},
    {'key': 'music', 'emoji': '🎵', 'color': Color(0xFF00BCD4)},
  ];

  static const _cards = <Map<String, String>>[
    {
      'title': 'Tom & Jerry | Keep Calm',
      'duration': '1:27:03',
      'image': 'assets/images/ent_tomjerry.png',
      'tag': 'Entertaining',
      'emoji': '😄',
    },
    {
      'title': 'Momo & Mimi | Arabic',
      'duration': '3:39',
      'image': 'assets/images/ent_momo.png',
      'tag': 'Entertaining',
      'emoji': '🌙',
    },
    {
      'title': 'Kindness Challenge',
      'duration': '7:00',
      'image': 'assets/images/behavior_kindness.png',
      'tag': 'Behavioral',
      'emoji': '💖',
    },
    {
      'title': 'Build & Create',
      'duration': '5:20',
      'image': 'assets/images/skill_handcrafts.png',
      'tag': 'Skillful',
      'emoji': '🏗️',
    },
    {
      'title': 'Math Basics | Fun',
      'duration': '8:10',
      'image': 'assets/images/educational_main.png',
      'tag': 'Educational',
      'emoji': '🔢',
    },
    {
      'title': 'Science Wonders',
      'duration': '6:45',
      'image': 'assets/images/edu_science.png',
      'tag': 'Educational',
      'emoji': '🔬',
    },
    {
      'title': 'Story Time',
      'duration': '4:12',
      'image': 'assets/images/behavior_love.png',
      'tag': 'Behavioral',
      'emoji': '📖',
    },
    {
      'title': 'Coloring Fun',
      'duration': '5:05',
      'image': 'assets/images/skill_coloring.png',
      'tag': 'Skillful',
      'emoji': '🎨',
    },
    {
      'title': 'Alphabet Song',
      'duration': '2:30',
      'image': 'assets/images/edu_english.png',
      'tag': 'Educational',
      'emoji': '🔤',
    },
    {
      'title': 'Animal Friends',
      'duration': '3:55',
      'image': 'assets/images/edu_animals.png',
      'tag': 'Educational',
      'emoji': '🦁',
    },
    {
      'title': 'Dance Party',
      'duration': '4:20',
      'image': 'assets/images/ent_clips.png',
      'tag': 'Entertaining',
      'emoji': '💃',
    },
    {
      'title': 'Sharing Time',
      'duration': '6:10',
      'image': 'assets/images/behavior_giving.png',
      'tag': 'Behavioral',
      'emoji': '🤝',
    },
    {
      'title': 'Puzzle Play',
      'duration': '5:40',
      'image': 'assets/images/skill_handcrafts.png',
      'tag': 'Skillful',
      'emoji': '🧩',
    },
  ];

  // ── featured picks (always shown at top) ──────────────────────────────────
  static const _featured = <Map<String, String>>[
    {
      'title': 'Tom & Jerry\nKeep Calm',
      'duration': '1:27:03',
      'image': 'assets/images/ent_tomjerry.png',
      'emoji': '😄',
      'label': 'Fan Favourite',
    },
    {
      'title': 'Kindness\nChallenge',
      'duration': '7:00',
      'image': 'assets/images/behavior_kindness.png',
      'emoji': '💖',
      'label': 'Today\'s Pick',
    },
    {
      'title': 'Math Basics\nFun Edition',
      'duration': '8:10',
      'image': 'assets/images/educational_main.png',
      'emoji': '🔢',
      'label': 'Top Rated',
    },
  ];

  List<Map<String, String>> _filteredCards(AppLocalizations l10n) {
    final query = _searchQuery.trim().toLowerCase();
    final key = _tabs[_selectedTab]['key'] as String;
    final tag = switch (key) {
      'kindness' => 'Behavioral',
      'learning' => 'Educational',
      'skills' => 'Skillful',
      'music' => 'Entertaining',
      _ => 'All',
    };
    final localizedCards = _cards
        .map(
          (card) => {
            ...card,
            'title': _localizedVideoTitle(card['title'] ?? '', l10n),
            'tag': _localizedTag(card['tag'] ?? '', l10n),
          },
        )
        .toList();
    final localizedTag = key == 'all' ? null : _localizedTag(tag, l10n);
    final base = localizedTag == null
        ? localizedCards
        : localizedCards.where((c) => c['tag'] == localizedTag).toList();
    final filtered = query.isEmpty
        ? base
        : base
            .where((c) => (c['title'] ?? '').toLowerCase().contains(query))
            .toList();
    final seed = query.hashCode ^ _selectedTab.hashCode;
    return (filtered.toList()..shuffle(Random(seed)))
        .cast<Map<String, String>>();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final filteredCards = _filteredCards(l10n);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors, l10n),
            _buildCategoryTabs(l10n),
            const SizedBox(height: 14),
            _buildSearchBar(colors, l10n),
            const SizedBox(height: 12),
            Expanded(
              child: filteredCards.isEmpty
                  ? ChildEmptyState(
                      emoji: '🎬',
                      title: l10n.nothingFound,
                      subtitle: l10n.tryDifferentSearch,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      children: [
                        // Featured row (only in "All" tab, no search active)
                        if (_selectedTab == 0 && _searchQuery.isEmpty) ...[
                          _buildFeaturedSection(l10n),
                          const SizedBox(height: 20),
                          ChildSectionHeader(title: l10n.allVideos),
                          const SizedBox(height: 12),
                        ],
                        ...filteredCards.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildMediaCard(c, colors),
                            )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme colors, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          // Screen title
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
          // Safe badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_rounded, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  l10n.safeMode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
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

  // ── CATEGORY TABS ──────────────────────────────────────────────────────────

  Widget _buildCategoryTabs(AppLocalizations l10n) {
    final tabLabels = [
      l10n.all,
      l10n.kindnessTab,
      l10n.learningTab,
      l10n.skillsTab,
      l10n.music,
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          return ChildCategoryChip(
            label: tabLabels[i],
            emoji: tab['emoji'] as String,
            color: tab['color'] as Color,
            isSelected: _selectedTab == i,
            onTap: () => setState(() => _selectedTab = i),
          );
        },
      ),
    );
  }

  // ── SEARCH BAR ─────────────────────────────────────────────────────────────

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

  // ── FEATURED SECTION ───────────────────────────────────────────────────────

  Widget _buildFeaturedSection(AppLocalizations l10n) {
    final featuredCards = _featured
        .map(
          (card) => {
            ...card,
            'title': _localizedFeaturedTitle(card['title'] ?? '', l10n),
          },
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildSectionHeader(title: l10n.featured),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featuredCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildFeaturedCard(featuredCards[i]),
          ),
        ),
      ],
    );
  }

  String _featuredLabel(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Fan Favourite' => l10n.fanFavourite,
      'Today\'s Pick' => l10n.todaysPick,
      'Top Rated' => l10n.topRated,
      _ => raw,
    };
  }

  String _localizedFeaturedTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Tom & Jerry\nKeep Calm' =>
        l10n.videoTomAndJerryKeepCalm.replaceAll(' | ', '\n'),
      'Kindness\nChallenge' =>
        l10n.videoKindnessChallenge.replaceAll(' ', '\n'),
      'Math Basics\nFun Edition' =>
        l10n.videoMathBasicsFun.replaceAll(' | ', '\n'),
      _ => raw,
    };
  }

  String _localizedVideoTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Tom & Jerry | Keep Calm' => l10n.videoTomAndJerryKeepCalm,
      'Momo & Mimi | Arabic' => l10n.videoMomoAndMimiArabic,
      'Kindness Challenge' => l10n.videoKindnessChallenge,
      'Build & Create' => l10n.videoBuildAndCreate,
      'Math Basics | Fun' => l10n.videoMathBasicsFun,
      'Science Wonders' => l10n.videoScienceWonders,
      'Story Time' => l10n.historyStoryTime,
      'Coloring Fun' => l10n.videoColoringFun,
      'Alphabet Song' => l10n.videoAlphabetSong,
      'Animal Friends' => l10n.videoAnimalFriends,
      'Dance Party' => l10n.historyDanceParty,
      'Sharing Time' => l10n.videoSharingTime,
      'Puzzle Play' => l10n.videoPuzzlePlay,
      _ => raw,
    };
  }

  String _localizedTag(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Behavioral' => l10n.categoryBehavioral,
      'Educational' => l10n.categoryEducational,
      'Skillful' => l10n.categorySkillful,
      'Entertaining' => l10n.categoryEntertaining,
      _ => raw,
    };
  }

  Widget _buildFeaturedCard(Map<String, String> card) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 200,
      child: KinderCard(
        padding: EdgeInsets.zero,
        borderRadius: 18,
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      card['image'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withValues(alpha: 0.6),
                              colors.primary.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            card['emoji'] ?? '🎬',
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                    // Dark overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    // Label pill
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _featuredLabel(card['label'] ?? '', l10n),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Duration
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          card['duration'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Play button
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                card['title'] ?? '',
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

  // ── LIST MEDIA CARD ────────────────────────────────────────────────────────

  Widget _buildMediaCard(Map<String, String> card, ColorScheme colors) {
    final tagColor = _tagColor(card['tag'] ?? '');
    return KinderCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      onTap: () {},
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(18),
            ),
            child: SizedBox(
              width: 110,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    card['image'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colors.surfaceContainerHighest,
                      child: Center(
                        child: Text(
                          card['emoji'] ?? '🎬',
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        card['duration'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title'] ?? '',
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
                  // Tag badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card['tag'] ?? '',
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

          // Arrow
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

  Color _tagColor(String tag) {
    final l10n = AppLocalizations.of(context)!;
    return switch (tag) {
      var value when value == l10n.categoryBehavioral =>
        ChildColors.kindnessPink,
      var value when value == l10n.categoryEducational =>
        ChildColors.learningBlue,
      var value when value == l10n.categorySkillful => ChildColors.skillPurple,
      var value when value == l10n.categoryEntertaining => ChildColors.funCyan,
      _ => ChildColors.learningBlue,
    };
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
