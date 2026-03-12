// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/providers/content_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/child_header.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/features/child_mode/learn/coloring_gallery_screen.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentControllerProvider.notifier).loadAllActivities();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _categories {
    final childTheme = context.childTheme;
    return [
      {
        'title': 'Behavioral',
        'image': 'assets/images/behavioral_main.png',
        'color': childTheme.kindness,
        'route': 'behavioral',
      },
      {
        'title': 'Educational',
        'image': 'assets/images/educational_main.png',
        'color': childTheme.learning,
        'route': 'educational',
      },
      {
        'title': 'Skillful',
        'image': 'assets/images/skillful_main.png',
        'color': childTheme.skill,
        'route': 'skillful',
      },
      {
        'title': 'Entertaining',
        'image': 'assets/images/entertaining_main.png',
        'color': childTheme.fun,
        'route': 'entertaining',
      },
    ];
  }

  final List<Map<String, String>> _searchItems = const [
    {'title': 'Behavioral', 'route': 'behavioral'},
    {'title': 'Educational', 'route': 'educational'},
    {'title': 'Skillful', 'route': 'skillful'},
    {'title': 'Entertaining', 'route': 'entertaining'},
    {'title': 'Values', 'route': 'behavioral'},
    {'title': 'Methods', 'route': 'behavioral'},
    {'title': 'Activities', 'route': 'behavioral'},
    {'title': 'Value Details', 'route': 'behavioral'},
    {'title': 'Method Content', 'route': 'behavioral'},
    {'title': 'Stories', 'route': 'entertaining'},
    {'title': 'Games', 'route': 'entertaining'},
    {'title': 'Music', 'route': 'entertaining'},
    {'title': 'Videos', 'route': 'entertaining'},
    {'title': 'Subjects', 'route': 'educational'},
    {'title': 'Lessons', 'route': 'educational'},
    {'title': 'Lesson Detail', 'route': 'educational'},
    {'title': 'Skills', 'route': 'skillful'},
    {'title': 'Skill Details', 'route': 'skillful'},
    {'title': 'Skill Video', 'route': 'skillful'},
    {'title': 'Behavioral Values', 'route': 'behavioral'},
    {'title': 'Behavioral Methods', 'route': 'behavioral'},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _slideAnimation.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onSubmitted: (value) {
                    final query = value.trim().toLowerCase();
                    if (query.isEmpty) return;
                    final match = _searchItems.firstWhere(
                      (c) => (c['title'] as String).toLowerCase() == query,
                      orElse: () => {},
                    );
                    if (match.isNotEmpty) {
                      _openCategory(context, match['route'] as String);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.searchPages,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const ChildHeader(
                  padding: EdgeInsets.only(bottom: 24),
                ),

                // 2. Chat Bubble Message
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wb_sunny_outlined,
                            color: Theme.of(context).colorScheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n.letsExploreAndLearn,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Expanded(
                  child: _buildSearchResults(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _searchQuery.trim().toLowerCase();
    final results = query.isEmpty
        ? _categories
        : _searchItems
            .where((c) => (c['title'] as String).toLowerCase().contains(query))
            .toList();

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
        final category = results[index];
        if (category.containsKey('image')) {
          return _buildCategoryCard(
            context,
            _localizedSearchTitle(context, category['title'] as String),
            category['image'],
            category['color'],
            category['route'],
          );
        }
        return InkWell(
          onTap: () => _openCategory(context, category['route']),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _localizedSearchTitle(context, category['title'] as String),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppConstants.fontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCategory(BuildContext context, String route) {
    switch (route) {
      case 'educational':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const EducationalScreen()),
        );
        break;
      case 'behavioral':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const BehavioralScreen()),
        );
        break;
      case 'skillful':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SkillfulScreen()),
        );
        break;
      case 'entertaining':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const EntertainingScreen()),
        );
        break;
      default:
        break;
    }
  }

  String _localizedSearchTitle(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context)!;
    switch (title) {
      case 'Behavioral':
        return l10n.categoryBehavioral;
      case 'Educational':
        return l10n.categoryEducational;
      case 'Skillful':
        return l10n.categorySkillful;
      case 'Entertaining':
        return l10n.categoryEntertaining;
      default:
        return title;
    }
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    String imagePath,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () {
        Widget screen;
        switch (route) {
          case 'educational':
            screen = const EducationalScreen();
            break;
          case 'behavioral':
            screen = const BehavioralScreen();
            break;
          case 'skillful':
            screen = const SkillfulScreen();
            break;
          case 'entertaining':
            screen = const EntertainingScreen();
            break;
          default:
            screen = const EducationalScreen();
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => screen,
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SPECIFIC SCREENS IMPLEMENTATIONS
// ==========================================

/// 1. UPDATED Entertaining Screen (With Navigation Logic)
class EntertainingScreen extends StatelessWidget {
  const EntertainingScreen({super.key});

  static const List<Map<String, dynamic>> _items = [
    {
      'title': 'Puppet Show',
      'image': 'assets/images/ent_puppet_show.png',
      'color': Colors.orange
    },
    {
      'title': 'Interactive Stories',
      'image': 'assets/images/ent_stories.png',
      'color': Colors.purple
    },
    {
      'title': 'Songs & Music',
      'image': 'assets/images/ent_music.png',
      'color': Colors.pink
    },
    {
      'title': 'Funny Clips',
      'image': 'assets/images/ent_clips.png',
      'color': Colors.yellow
    },
    {
      'title': 'Brain Teasers',
      'image': 'assets/images/ent_teasers.png',
      'color': Colors.teal
    },
    {
      'title': 'Games',
      'image': 'assets/images/ent_games.png',
      'color': Colors.blue
    },
    {
      'title': 'Cartoons',
      'image': 'assets/images/ent_cartoons.png',
      'color': Colors.indigo
    },
  ];

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
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.sentiment_satisfied_alt,
                      color: context.childTheme.fun, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.foundSomethingFun,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.childTheme.fun,
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
              color: color.withValues(alpha: 0.15),
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
                Colors.black.withValues(alpha: 0.6),
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

/// NEW: Entertainment Detail Screen (Shows content for Games, Cartoons, etc.)
class EntertainmentDetailScreen extends StatelessWidget {
  final String categoryTitle;
  const EntertainmentDetailScreen({super.key, required this.categoryTitle});

  List<Map<String, dynamic>> _getItems() {
    // Mock data based on category
    switch (categoryTitle) {
      case 'Games':
        return [
          {'title': 'Puzzle Game', 'image': 'assets/images/ent_games.png'},
          {'title': 'Racing Cars', 'image': 'assets/images/ent_clips.png'},
          {'title': 'Memory Match', 'image': 'assets/images/ent_teasers.png'},
          {
            'title': 'Coloring Fun',
            'image': 'assets/images/skill_coloring.png'
          },
        ];
      case 'Cartoons':
        return [
          {
            'title': 'Adventure Time',
            'image': 'assets/images/ent_cartoons.png'
          },
          {'title': 'Funny Animals', 'image': 'assets/images/edu_animals.png'},
          {'title': 'Space Heroes', 'image': 'assets/images/edu_science.png'},
          {'title': 'Magic World', 'image': 'assets/images/ent_stories.png'},
        ];
      case 'Songs & Music':
        return [
          {'title': 'ABC Song', 'image': 'assets/images/ent_music.png'},
          {'title': 'Baby Shark', 'image': 'assets/images/skill_singing.png'},
          {'title': 'Twinkle Star', 'image': 'assets/images/skill_music.png'},
        ];
      default:
        return [
          {'title': 'Item 1', 'image': 'assets/images/ent_puppet_show.png'},
          {'title': 'Item 2', 'image': 'assets/images/ent_stories.png'},
          {'title': 'Item 3', 'image': 'assets/images/ent_teasers.png'},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _getItems();

    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5),
      appBar: AppBar(
        title: Text(
          _localizedCategoryTitle(l10n),
          style: TextStyle(
              color: context.childTheme.fun, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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
                  childAspectRatio: 0.9,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildContentCard(
                    context,
                    _localizedContentTitle(item['title'], l10n),
                    item['image'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(
      BuildContext context, String title, String imagePath) {
    return InkWell(
      onTap: () {
        // Open video/content player if needed
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                Colors.black.withValues(alpha: 0.6),
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

  String _localizedCategoryTitle(AppLocalizations l10n) {
    return switch (categoryTitle) {
      'Games' => l10n.entertainmentGames,
      'Cartoons' => l10n.entertainmentCartoons,
      'Songs & Music' => l10n.songsAndMusic,
      'Puppet Show' => l10n.puppetShows,
      'Interactive Stories' => l10n.interactiveStories,
      'Funny Clips' => l10n.funnyClips,
      'Brain Teasers' => l10n.entertainmentBrainTeasers,
      _ => categoryTitle,
    };
  }

  String _localizedContentTitle(String raw, AppLocalizations l10n) {
    return switch (raw) {
      'Puzzle Game' => l10n.contentPuzzleGame,
      'Racing Cars' => l10n.contentRacingCars,
      'Memory Match' => l10n.historyMemoryGame,
      'Coloring Fun' => l10n.videoColoringFun,
      'Adventure Time' => l10n.contentAdventureTime,
      'Funny Animals' => l10n.contentFunnyAnimals,
      'Space Heroes' => l10n.contentSpaceHeroes,
      'Magic World' => l10n.contentMagicWorld,
      'ABC Song' => l10n.contentAbcSong,
      'Baby Shark' => l10n.contentBabyShark,
      'Twinkle Star' => l10n.contentTwinkleStar,
      _ => raw,
    };
  }
}

/// 2. UPDATED Behavioral Screen (Changed to Grid Layout)
class BehavioralScreen extends StatelessWidget {
  const BehavioralScreen({super.key});

  final List<Map<String, dynamic>> _values = const [
    {'title': 'Giving', 'image': 'assets/images/behavior_giving.png'},
    {'title': 'Respect', 'image': 'assets/images/behavior_respect.png'},
    {'title': 'Tolerance', 'image': 'assets/images/behavior_tolerance.png'},
    {'title': 'Kindness', 'image': 'assets/images/behavior_kindness.png'},
    {'title': 'Cooperation', 'image': 'assets/images/behavior_cooperation.png'},
    {
      'title': 'Responsibility',
      'image': 'assets/images/behavior_responsibility.png'
    },
    {'title': 'Honesty', 'image': 'assets/images/behavior_honesty.png'},
    {'title': 'Patience', 'image': 'assets/images/behavior_patience.png'},
    {'title': 'Courage', 'image': 'assets/images/behavior_courage.png'},
    {'title': 'Gratitude', 'image': 'assets/images/behavior_gratitude.png'},
    {'title': 'Peace', 'image': 'assets/images/behavior_peace.png'},
    {'title': 'Love', 'image': 'assets/images/behavior_love.png'},
  ];

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
                color: context.childTheme.kindness,
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
              color: context.childTheme.kindness.withValues(alpha: 0.15),
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
                Colors.black.withValues(alpha: 0.7),
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

  final List<Map<String, dynamic>> _methods = const [
    {'title': 'Relaxation', 'image': 'assets/images/method_relaxation.png'},
    {'title': 'Imagination', 'image': 'assets/images/method_imagination.png'},
    {'title': 'Meditation', 'image': 'assets/images/method_meditation.png'},
    {'title': 'Art Expression', 'image': 'assets/images/method_art.png'},
    {'title': 'Social Bonding', 'image': 'assets/images/method_social.png'},
    {'title': 'Self Development', 'image': 'assets/images/method_self_dev.png'},
    {
      'title': 'Social Justice Focus',
      'image': 'assets/images/method_justice.png'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8F5E9),
      appBar: AppBar(
        title: Text(
          valueTitle,
          style: TextStyle(
              color: context.childTheme.kindness, fontWeight: FontWeight.bold),
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
            builder: (context) => MethodContentScreen(methodTitle: title),
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
              color: Colors.black.withValues(alpha: 0.1),
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
                Colors.black.withValues(alpha: 0.7),
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
class MethodContentScreen extends ConsumerWidget {
  final String methodTitle;

  const MethodContentScreen({super.key, required this.methodTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activities = [
      l10n.videoKindnessChallenge,
      l10n.activityRespectSharing
    ];
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
                          color: context.childTheme.kindness.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.arrow_back, color: context.childTheme.kindness),
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
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: context.childTheme.kindness, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.letsTryNewSkill,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.childTheme.kindness,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  methodTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: activities.map((activity) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildActivityCard(context, activity),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, String title) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.childTheme.kindness.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.extension,
                    color: context.childTheme.kindness,
                    size: 32,
                  ),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. UPDATED Skillful Screen (Vertical List with New Categories)
class SkillfulScreen extends StatelessWidget {
  const SkillfulScreen({super.key});

  final List<Map<String, dynamic>> _skills = const [
    {
      'title': 'Cooking',
      'image': 'assets/images/skill_cooking.png',
      'desc': 'Yummy food'
    },
    {
      'title': 'Drawing',
      'image': 'assets/images/skill_drawing.png',
      'desc': 'Express art'
    },
    {
      'title': 'Coloring',
      'image': 'assets/images/skill_coloring.png',
      'desc': 'Use colors'
    },
    {
      'title': 'Music',
      'image': 'assets/images/skill_music.png',
      'desc': 'Play instruments'
    },
    {
      'title': 'Singing',
      'image': 'assets/images/skill_singing.png',
      'desc': 'Learn songs'
    },
    {
      'title': 'Handcrafts',
      'image': 'assets/images/skill_handcrafts.png',
      'desc': 'Cut & Paste'
    },
    {
      'title': 'Sports',
      'image': 'assets/images/skill_sports.png',
      'desc': 'Stay fit'
    },
  ];

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
                color: context.childTheme.skill,
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
              color: context.childTheme.skill.withValues(alpha: 0.1),
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
                  color: context.childTheme.skill.withValues(alpha: 0.2),
                  child: Icon(Icons.brush, color: context.childTheme.skill),
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
                  color: context.childTheme.skill, size: 18),
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
class SkillDetailScreen extends StatefulWidget {
  final String skillTitle;
  const SkillDetailScreen({super.key, required this.skillTitle});

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  String _searchQuery = "";
  String _selectedLevel = "all";

  final List<String> _levels = ["all", "beginner", "intermediate", "advanced"];

  List<Map<String, dynamic>> _getAllVideos() {
    final l10n = AppLocalizations.of(context)!;
    final skillTitle = _localizedSkillTitle(widget.skillTitle, l10n);
    return [
      {
        'title': l10n.skillVideoBasics(skillTitle),
        'level': 'beginner',
        'image': ''
      },
      {
        'title': l10n.skillVideoFun(skillTitle),
        'level': 'beginner',
        'image': ''
      },
      {
        'title': l10n.skillVideoAdvanced(skillTitle),
        'level': 'advanced',
        'image': ''
      },
      {
        'title': l10n.skillVideoMastering(skillTitle),
        'level': 'intermediate',
        'image': ''
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredVideos {
    return _getAllVideos().where((video) {
      final matchesQuery = video['title']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesLevel =
          _selectedLevel == "all" || video['level'] == _selectedLevel;
      return matchesQuery && matchesLevel;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0).withValues(alpha: 0.5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: context.childTheme.skill),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _localizedSkillTitle(widget.skillTitle, l10n),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.childTheme.skill,
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
                        color: Colors.grey.withValues(alpha: 0.1),
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
                          color: isSelected ? context.childTheme.skill : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? context.childTheme.skill
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
              child: _filteredVideos.isEmpty
                  ? Center(
                      child: Text(
                      l10n.noActivitiesFound,
                      style: TextStyle(color: Colors.grey[500]),
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredVideos.length,
                      itemBuilder: (context, index) {
                        final video = _filteredVideos[index];
                        return _buildVideoCard(video);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SkillVideoScreen(videoTitle: video['title']),
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
              color: Colors.black.withValues(alpha: 0.05),
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
              child: Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: context.childTheme.skill,
                  size: 50,
                ),
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
                      video['title'],
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
                        color: context.childTheme.skill.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.watchNow,
                        style: TextStyle(
                          color: context.childTheme.skill,
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
                  color: context.childTheme.skill.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, color: context.childTheme.skill),
              ),
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
  const SkillVideoScreen({super.key, required this.videoTitle});

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
                    icon: Icon(Icons.arrow_back_ios,
                        color: context.childTheme.skill),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      videoTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.childTheme.skill,
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
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: context.childTheme.skill.withValues(alpha: 0.2),
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
                                color: context.childTheme.skill,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: context.childTheme.skill
                                        .withValues(alpha: 0.4),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                  backgroundColor: context.childTheme.skill,
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

/// 4. Educational Screen
class EducationalScreen extends StatelessWidget {
  const EducationalScreen({super.key});

  final List<Map<String, dynamic>> _subjects = const [
    {
      'title': 'English',
      'image': 'assets/images/edu_english.png',
      'color': Colors.blueAccent
    },
    {
      'title': 'Arabic',
      'image': 'assets/images/edu_arabic.png',
      'color': Colors.green
    },
    {
      'title': 'Geography',
      'image': 'assets/images/edu_geography.png',
      'color': Colors.orange
    },
    {
      'title': 'History',
      'image': 'assets/images/edu_history.png',
      'color': Colors.brown
    },
    {
      'title': 'Science',
      'image': 'assets/images/edu_science.png',
      'color': Colors.purple
    },
    {
      'title': 'Math',
      'image': 'assets/images/edu_math.png',
      'color': Colors.red
    },
    {
      'title': 'Animals',
      'image': 'assets/images/edu_animals.png',
      'color': Colors.teal
    },
    {
      'title': 'Plants',
      'image': 'assets/images/edu_plants.png',
      'color': Colors.lightGreen
    },
  ];

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
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Builder(
                builder: (ctx) {
                  final l10n = AppLocalizations.of(ctx)!;
                  return Row(
                    children: [
                      Icon(Icons.lightbulb,
                          color: context.childTheme.learning, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        l10n.letsLearnSomethingNew,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.childTheme.learning,
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
              color: Colors.black.withValues(alpha: 0.06),
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
                Colors.black.withValues(alpha: 0.7),
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
class EducationalSubjectScreen extends StatefulWidget {
  final String subjectTitle;
  const EducationalSubjectScreen({super.key, required this.subjectTitle});

  @override
  State<EducationalSubjectScreen> createState() =>
      _EducationalSubjectScreenState();
}

class _EducationalSubjectScreenState extends State<EducationalSubjectScreen> {
  String _searchQuery = "";
  String _selectedLevel = "all";

  final List<String> _levels = ["all", "beginner", "intermediate", "advanced"];

  List<Map<String, dynamic>> get _allLessons {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'title': l10n.lessonIntroductionToBasics,
        'level': 'beginner',
        'image': ''
      },
      {'title': l10n.lessonAdvancedConcepts, 'level': 'advanced', 'image': ''},
      {
        'title': l10n.lessonIntermediatePractice,
        'level': 'intermediate',
        'image': ''
      },
      {'title': l10n.lessonFunWithMath, 'level': 'beginner', 'image': ''},
      {'title': l10n.lessonDeepDive, 'level': 'advanced', 'image': ''},
    ];
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
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: context.childTheme.learning),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _localizedSubjectTitle(widget.subjectTitle, l10n),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.childTheme.learning,
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
                        color: Colors.grey.withValues(alpha: 0.1),
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
                              isSelected ? context.childTheme.learning : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? context.childTheme.learning
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
              child: _filteredLessons.isEmpty
                  ? Center(
                      child: Text(
                      l10n.noLessonsFound,
                      style: TextStyle(color: Colors.grey[500]),
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredLessons.length,
                      itemBuilder: (context, index) {
                        final lesson = _filteredLessons[index];
                        return _buildLessonCard(lesson);
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
              color: Colors.black.withValues(alpha: 0.05),
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
                  color: context.childTheme.learning,
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
                        color: context.childTheme.learning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lesson['level'],
                        style: TextStyle(
                          color: context.childTheme.learning,
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
                  color: context.childTheme.learning, size: 32),
            ),
          ],
        ),
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
                    icon: Icon(Icons.arrow_back_ios,
                        color: context.childTheme.learning),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.lessonTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.childTheme.learning,
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.play_arrow,
                                  color: context.childTheme.learning, size: 40),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                                    color: context.childTheme.learning
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.quiz,
                                      color: context.childTheme.learning),
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
                                  backgroundColor: context.childTheme.learning,
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

  final List<Map<String, dynamic>> _quizData = const [
    {
      'question': 'What color is the sky?',
      'options': ['Blue', 'Green', 'Red', 'Yellow'],
      'correct': 0,
    },
    {
      'question': 'How many legs does a dog have?',
      'options': ['Two', 'Four', 'Six', 'Eight'],
      'correct': 1,
    },
    {
      'question': 'Which one is a fruit?',
      'options': ['Carrot', 'Apple', 'Potato', 'Onion'],
      'correct': 1,
    },
  ];

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.childTheme.learning,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.childTheme.learning),
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
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: context.childTheme.learning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.star, color: context.childTheme.learning),
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                      context.childTheme.learning),
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
                      bgColor = context.childTheme.learning.withValues(alpha: 0.1);
                      borderColor = context.childTheme.learning;
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
                    backgroundColor: context.childTheme.learning,
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

