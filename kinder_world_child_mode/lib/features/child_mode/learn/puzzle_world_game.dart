part of 'learn_screen.dart';

class PuzzleHubGameScreen extends StatelessWidget {
  const PuzzleHubGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const cards = <_PuzzleHubCardData>[
      _PuzzleHubCardData(
          title: 'Picture Puzzle',
          subtitle: 'Classic image puzzle with a polished gallery feel.',
          accent: Color(0xFFFFA726),
          icon: Icons.image_rounded,
          badge: 'Classic',
          screenBuilder: PuzzleGameScreen.new),
      _PuzzleHubCardData(
          title: 'Shuffle Puzzle',
          subtitle: 'Rebuild a scrambled picture by swapping image tiles.',
          accent: Color(0xFFEF5350),
          icon: Icons.shuffle_rounded,
          badge: 'New',
          screenBuilder: ShufflePuzzleScreen.new),
    ];
    return _GameScaffold(
      title: 'Puzzle World',
      subtitle: 'Choose from two polished picture puzzle styles.',
      accent: const Color(0xFFFFA726),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PremiumBanner(
              title: 'Two Puzzle Styles',
              subtitle:
                  'A polished picture puzzle hub with classic and shuffle play.',
              accent: Color(0xFFFFA726),
              icon: Icons.auto_awesome_rounded,
              tag: 'HD Play'),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.93),
            itemCount: cards.length,
            itemBuilder: (context, index) => _PuzzleHubCard(card: cards[index]),
          ),
        ],
      ),
    );
  }
}

class _PuzzleHubCardData {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String badge;
  final Widget Function() screenBuilder;

  const _PuzzleHubCardData(
      {required this.title,
      required this.subtitle,
      required this.accent,
      required this.icon,
      required this.badge,
      required this.screenBuilder});
}

class _PuzzleHubCard extends StatelessWidget {
  final _PuzzleHubCardData card;

  const _PuzzleHubCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => card.screenBuilder())),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF11151C),
            card.accent.withValuesCompat(alpha: 0.24)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: card.accent.withValuesCompat(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
                color: card.accent.withValuesCompat(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withValuesCompat(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(card.icon, color: Colors.white, size: 28)),
                const Spacer(),
                _GlassTag(text: card.badge),
              ],
            ),
            const Spacer(),
            Text(card.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(card.subtitle,
                style: TextStyle(
                    color: Colors.white.withValuesCompat(alpha: 0.78),
                    fontSize: 13.2,
                    height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  final String text;

  const _GlassTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValuesCompat(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValuesCompat(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String tag;

  const _PremiumBanner({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF11151C),
            accent.withValuesCompat(alpha: 0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValuesCompat(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValuesCompat(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValuesCompat(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassTag(text: tag),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValuesCompat(alpha: 0.78),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

String _logicTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

abstract class _PremiumPuzzleState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  Widget buildStats(List<Widget> children) {
    return Row(children: [
      for (var i = 0; i < children.length; i++) ...[
        Expanded(child: children[i]),
        if (i < children.length - 1) const SizedBox(width: 12)
      ]
    ]);
  }

  Future<void> recordLogicCompletion(
      {required String activityId,
      required int score,
      required int durationMinutes,
      required int xpEarned,
      required String notes,
      Map<String, dynamic>? performanceMetrics}) async {
    final childProfile = ref.read(currentChildProvider);
    if (childProfile == null) return;
    await ref
        .read(progressControllerProvider.notifier)
        .recordActivityCompletion(
            childId: childProfile.id,
            activityId: activityId,
            score: score,
            duration: durationMinutes,
            xpEarned: xpEarned,
            notes: notes,
            performanceMetrics: performanceMetrics);
  }
}

class ShufflePuzzleScreen extends ConsumerStatefulWidget {
  const ShufflePuzzleScreen({super.key});

  @override
  ConsumerState<ShufflePuzzleScreen> createState() =>
      _ShufflePuzzleScreenState();
}

class _ShufflePuzzleScreenState
    extends _PremiumPuzzleState<ShufflePuzzleScreen> {
  static final List<_PuzzleLevel> _levels = List.generate(50, (index) {
    const accents = [
      Color(0xFFEF5350),
      Color(0xFFFF7043),
      Color(0xFFFFA726),
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
    ];
    final number = index + 1;
    final size = switch (number) {
      <= 10 => 3,
      <= 20 => 4,
      <= 30 => 5,
      <= 40 => 6,
      _ => 7,
    };
    final stageIndex = (number - 1) ~/ 10;
    final indexInStage = (number - 1) % 10;
    final baseTime = [150, 130, 110, 95, 80][stageIndex];
    final minimumTime = [70, 60, 50, 42, 34][stageIndex];
    final time = math.max(minimumTime, baseTime - (indexInStage * 8));
    return _PuzzleLevel(
      id: 'shuffle_puzzle_$number',
      size: size,
      accent: accents[index % accents.length],
      timeLimitSeconds: time,
    );
  });

  static const String _assetFolder = 'assets/images/puzzle_shuffle/';

  final _GameAudioController _audio = _GameAudioController();
  late _PuzzleLevel _selectedLevel;
  Timer? _timer;
  List<int> _tiles = const [];
  List<String> _artworkPaths = const [];
  Map<String, _PuzzleLevelProgress> _progressByLevel = const {};
  int? _selectedTileIndex;
  int _remainingSeconds = 0;
  int _moveCount = 0;
  bool _isSolved = false;
  bool _isLost = false;
  bool _isLoadingGallery = true;
  bool _isRecordingCompletion = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  int get _boardSize => _selectedLevel.size;
  int get _pieceCount => _boardSize * _boardSize;
  int get _elapsedSeconds =>
      _selectedLevel.timeLimitSeconds - _remainingSeconds;
  int get _selectedLevelIndex => _levels.indexOf(_selectedLevel);

  int get _solvedTilesCount {
    var count = 0;
    for (var i = 0; i < _tiles.length; i++) {
      if (_tiles[i] == i + 1) {
        count += 1;
      }
    }
    return count;
  }

  int get _scorePoints {
    final matchPoints = _solvedTilesCount * 10;
    final timeBonus = _remainingSeconds;
    final efficiencyBonus = math.max(0, (_pieceCount * 4) - (_moveCount * 2));
    return matchPoints + timeBonus + efficiencyBonus;
  }

  bool get _hasArtworkLibrary => _artworkPaths.isNotEmpty;

  int get _unlockedLevelIndex {
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

  int _starsForLevel(_PuzzleLevel level) =>
      _progressByLevel[level.id]?.bestStars ?? 0;

  _PuzzleLevelProgress get _currentProgress =>
      _progressByLevel[_selectedLevel.id] ?? const _PuzzleLevelProgress();

  String get _currentImagePath {
    if (_artworkPaths.isEmpty) {
      return '';
    }
    final safeIndex = _selectedLevelIndex % _artworkPaths.length;
    return _artworkPaths[safeIndex];
  }

  @override
  void initState() {
    super.initState();
    _selectedLevel = _levels.first;
    _remainingSeconds = _selectedLevel.timeLimitSeconds;
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
        final lower = assetPath.toLowerCase();
        final supported = lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp');
        return supported && assetPath.startsWith(_assetFolder);
      }).toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _artworkPaths = discovered;
        _isLoadingGallery = false;
      });
      if (discovered.isNotEmpty) {
        _startLevel(resetClock: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkPaths = const [];
        _isLoadingGallery = false;
      });
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final next = <String, _PuzzleLevelProgress>{};
    for (final level in _levels) {
      next[level.id] = _PuzzleLevelProgress(
        bestTimeSeconds: prefs.getInt('shuffle_best_time_${level.id}'),
        bestStars: prefs.getInt('shuffle_best_stars_${level.id}') ?? 0,
      );
    }
    if (!mounted) return;
    setState(() => _progressByLevel = next);
  }

  Future<void> _saveProgressIfNeeded(int earnedStars) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _currentProgress;
    var bestTime = current.bestTimeSeconds;
    var bestStars = current.bestStars;
    if (bestTime == null || _elapsedSeconds < bestTime) {
      await prefs.setInt(
          'shuffle_best_time_${_selectedLevel.id}', _elapsedSeconds);
      bestTime = _elapsedSeconds;
    }
    if (earnedStars > bestStars) {
      await prefs.setInt(
          'shuffle_best_stars_${_selectedLevel.id}', earnedStars);
      bestStars = earnedStars;
    }
    if (!mounted) return;
    setState(() {
      _progressByLevel = {
        ..._progressByLevel,
        _selectedLevel.id: _PuzzleLevelProgress(
          bestTimeSeconds: bestTime,
          bestStars: bestStars,
        ),
      };
    });
  }

  void _startLevel({bool resetClock = false}) {
    _timer?.cancel();
    final tiles = List<int>.generate(_pieceCount, (index) => index + 1);
    do {
      tiles.shuffle();
    } while (_isSolvedOrder(tiles) || _matchesTooManyTiles(tiles));
    setState(() {
      _tiles = List<int>.from(tiles);
      _selectedTileIndex = null;
      _moveCount = 0;
      _isSolved = false;
      _isLost = false;
      if (resetClock) {
        _remainingSeconds = _selectedLevel.timeLimitSeconds;
      }
    });
    _startTimer();
  }

  bool _matchesTooManyTiles(List<int> tiles) {
    var matches = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] == i + 1) {
        matches += 1;
      }
    }
    return matches > math.max(1, _pieceCount ~/ 3);
  }

  bool _isSolvedOrder(List<int> tiles) {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != i + 1) {
        return false;
      }
    }
    return true;
  }

  void _changeLevel(_PuzzleLevel level) {
    setState(() {
      _selectedLevel = level;
      _remainingSeconds = level.timeLimitSeconds;
      _selectedTileIndex = null;
      _isSolved = false;
      _isLost = false;
    });
    if (_hasArtworkLibrary) {
      _startLevel(resetClock: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isSolved || _isLost) {
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _isLost = true;
          _selectedTileIndex = null;
        });
        _timer?.cancel();
        unawaited(_audio.playEffect(
          'sounds/games/puzzle_lose.mp3',
          fallback: SystemSoundType.click,
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showLostDialog();
          }
        });
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _openLevelPicker() async {
    final picked = await Navigator.of(context).push<_PuzzleLevel>(
      MaterialPageRoute(
        builder: (context) => _PuzzleLevelGridScreen(
          title:
              _isArabic ? 'مستويات البازل المتلخبط' : 'Shuffle Puzzle Levels',
          accent: _selectedLevel.accent,
          levels: _levels,
          selectedLevel: _selectedLevel,
          labelBuilder: _levelLabel,
          unlockedIndex: _unlockedLevelIndex,
          starsForLevel: _starsForLevel,
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    _changeLevel(picked);
  }

  void _handleTileTap(int index) {
    if (_isSolved || _isLost) {
      return;
    }
    final selected = _selectedTileIndex;
    if (selected == null) {
      setState(() => _selectedTileIndex = index);
      return;
    }
    if (selected == index) {
      setState(() => _selectedTileIndex = null);
      return;
    }
    _swapTiles(selected, index);
  }

  void _swapTiles(int sourceIndex, int targetIndex) {
    if (_isSolved || _isLost || sourceIndex == targetIndex) {
      return;
    }
    final nextTiles = List<int>.from(_tiles);
    final sourceValue = nextTiles[sourceIndex];
    nextTiles[sourceIndex] = nextTiles[targetIndex];
    nextTiles[targetIndex] = sourceValue;
    final solved = _isSolvedOrder(nextTiles);
    setState(() {
      _tiles = nextTiles;
      _selectedTileIndex = null;
      _moveCount += 1;
      _isSolved = solved;
    });
    unawaited(_audio.playEffect(
      'sounds/games/card_flip.mp3',
      fallback: SystemSoundType.click,
      volume: 0.55,
    ));
    if (solved) {
      _timer?.cancel();
      unawaited(_audio.playEffect(
        'sounds/games/puzzle_win.mp3',
        fallback: SystemSoundType.alert,
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSolvedDialog();
        }
      });
    }
  }

  int _calculateStars() {
    final timeRatio = _remainingSeconds / _selectedLevel.timeLimitSeconds;
    final moveBudget = (_pieceCount * 2.4).ceil();
    if (_moveCount <= moveBudget && timeRatio >= 0.35) {
      return 3;
    }
    if (_moveCount <= moveBudget + (_boardSize * 3) && timeRatio >= 0.18) {
      return 2;
    }
    return 1;
  }

  Future<void> _recordCompletion(int earnedStars) async {
    if (_isRecordingCompletion) {
      return;
    }
    _isRecordingCompletion = true;
    try {
      await recordLogicCompletion(
        activityId: 'game_${_selectedLevel.id}',
        score: switch (earnedStars) {
          3 => 100,
          2 => 88,
          _ => 76,
        },
        durationMinutes: math.max(1, (_elapsedSeconds / 60).ceil()),
        xpEarned: (earnedStars * 20) + (_boardSize * 6),
        notes: 'Shuffle Puzzle - ${_levelLabel(_selectedLevel)}',
        performanceMetrics: {
          'stars': earnedStars,
          'moves': _moveCount,
          'time_seconds': _elapsedSeconds,
          'time_remaining_seconds': _remainingSeconds,
          'board_size': _boardSize,
          'pieces': _pieceCount,
          'solved_tiles': _solvedTilesCount,
          'shuffle_score': _scorePoints,
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
    await _recordCompletion(earnedStars);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _selectedLevel.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_isArabic ? 'اكتملت الصورة!' : 'Picture Complete!'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic
                  ? 'رتبت الصورة كاملة في ${_logicTime(_elapsedSeconds)} وبعدد $_moveCount حركة.'
                  : 'You restored the full picture in ${_logicTime(_elapsedSeconds)} with $_moveCount moves.',
            ),
            const SizedBox(height: 14),
            _StarRow(stars: earnedStars, accent: _selectedLevel.accent),
            const SizedBox(height: 10),
            Text(
              _isArabic
                  ? 'النتيجة: $_scorePoints نقطة'
                  : 'Score: $_scorePoints points',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _currentProgress.bestTimeSeconds == null
                  ? (_isArabic
                      ? 'تم حفظ أفضل نتيجة لهذا المستوى.'
                      : 'Your best result for this level has been saved.')
                  : (_isArabic
                      ? 'أفضل وقت: ${_logicTime(_currentProgress.bestTimeSeconds!)}'
                      : 'Best time: ${_logicTime(_currentProgress.bestTimeSeconds!)}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startLevel(resetClock: true);
            },
            child: Text(_isArabic ? 'إعادة المستوى' : 'Replay Level'),
          ),
          if (_selectedLevel != _levels.last)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _selectedLevel.accent,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _changeLevel(_levels[_selectedLevelIndex + 1]);
              },
              child: Text(_isArabic ? 'المستوى التالي' : 'Next Level'),
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
            Expanded(child: Text(_isArabic ? 'انتهى الوقت' : 'Time Is Up')),
          ],
        ),
        content: Text(
          _isArabic
              ? 'لم تكتمل الصورة قبل انتهاء الوقت. جربي تبديل القطع أسرع في المحاولة القادمة.'
              : 'The picture was not restored before the timer ended. Try swapping the tiles faster next time.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startLevel(resetClock: true);
            },
            child: Text(_isArabic ? 'حاولي مرة أخرى' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  String _levelLabel(_PuzzleLevel level) {
    final number = _levels.indexOf(level) + 1;
    return _isArabic
        ? 'المستوى $number - ${level.size}x${level.size}'
        : 'Level $number - ${level.size}x${level.size}';
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: _isArabic ? 'البازل المتلخبط' : 'Shuffle Puzzle',
      subtitle: _isSolved
          ? (_isArabic
              ? 'اكتملت الصورة بالكامل.'
              : 'The scrambled image has been restored.')
          : _isLost
              ? (_isArabic
                  ? 'انتهى الوقت قبل اكتمال الصورة.'
                  : 'Time ran out before the picture was complete.')
              : (_isArabic
                  ? 'اسحبي قطعة فوق أخرى أو اضغطي قطعتين لتبديل مكانهما حتى تعود الصورة كاملة.'
                  : 'Drag one tile onto another, or tap two tiles, to swap them until the picture is complete.'),
      accent: _selectedLevel.accent,
      trailing: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed:
                _hasArtworkLibrary ? () => _startLevel(resetClock: true) : null,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_isArabic ? 'إعادة' : 'Reset'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildPreviewCard(),
          const SizedBox(height: 18),
          if (_hasArtworkLibrary) ...[
            _buildBoard(),
            const SizedBox(height: 18),
            _buildHowToPlay(),
          ] else ...[
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LevelGridLauncher(
          title: _isArabic ? 'اختيار المستوى' : 'Choose Level',
          subtitle: _levelLabel(_selectedLevel),
          accent: _selectedLevel.accent,
          icon: Icons.grid_view_rounded,
          onTap: _openLevelPicker,
        ),
        const SizedBox(height: 14),
        buildStats([
          _PuzzleStatCard(
            icon: Icons.grid_on_rounded,
            label: 'Grid',
            value: '${_boardSize}x$_boardSize',
            accent: _selectedLevel.accent,
          ),
          _PuzzleStatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Score',
            value: '$_scorePoints',
            accent: Colors.amber.shade700,
          ),
          _PuzzleStatCard(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Time',
            value: _logicTime(_remainingSeconds),
            accent: _remainingSeconds <= 15
                ? Colors.redAccent
                : _selectedLevel.accent,
          ),
        ]),
        const SizedBox(height: 12),
        buildStats([
          _PuzzleStatCard(
            icon: Icons.extension_rounded,
            label: 'Solved',
            value: '$_solvedTilesCount/$_pieceCount',
            accent: _selectedLevel.accent,
          ),
          _PuzzleStatCard(
            icon: Icons.swipe_rounded,
            label: 'Moves',
            value: '$_moveCount',
            accent: const Color(0xFF7E57C2),
          ),
          _PuzzleStatCard(
            icon: Icons.lock_open_rounded,
            label: 'Open',
            value: '${_unlockedLevelIndex + 1}/50',
            accent: const Color(0xFF26A69A),
          ),
        ]),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final shortage = _levels.length - _artworkPaths.length;
    if (!_hasArtworkLibrary) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _selectedLevel.accent.withValuesCompat(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
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
                    _isArabic ? 'أضيفي صور المستويات' : 'Add Level Images',
                    style: TextStyle(
                      color: _selectedLevel.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isArabic
                        ? 'ضعي صور اللعبة داخل assets/images/puzzle_shuffle/ ويفضل صورة لكل مستوى باسم مرتب مثل level_01.png ثم اعملي Hot Restart.'
                        : 'Add the level images inside assets/images/puzzle_shuffle/. One image per level is recommended, with ordered names like level_01.png, then run a hot restart.',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              _currentImagePath,
              width: 94,
              height: 94,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic
                      ? 'صورة المستوى ${_selectedLevelIndex + 1}'
                      : 'Level ${_selectedLevelIndex + 1} Picture',
                  style: TextStyle(
                    color: _selectedLevel.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isLoadingGallery
                      ? (_isArabic
                          ? 'جار تحميل مكتبة الصور...'
                          : 'Loading the image library...')
                      : shortage > 0
                          ? (_isArabic
                              ? 'يوجد حاليًا ${_artworkPaths.length} صورة فقط. يمكن إعادة استخدام الصور تلقائيًا، لكن الأفضل إضافة 50 صورة مرتبة للمستويات.'
                              : 'Only ${_artworkPaths.length} images are available right now. The game can reuse them, but adding 50 ordered level images is best.')
                          : (_isArabic
                              ? 'كل مستوى يعرض صورة من مجلدك ثم يبعثرها داخل اللوحة لتعيدي ترتيبها.'
                              : 'Each level uses one of your asset images, scrambles it on the board, then asks the player to rebuild it.'),
                  style: const TextStyle(fontSize: 14.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12161F),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedLevel.accent.withValuesCompat(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _boardSize,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: _pieceCount,
          itemBuilder: (context, index) {
            final tileValue = _tiles[index];
            final selected = _selectedTileIndex == index;
            return DragTarget<int>(
              onWillAcceptWithDetails: (details) =>
                  !_isSolved && !_isLost && details.data != index,
              onAcceptWithDetails: (details) => _swapTiles(details.data, index),
              builder: (context, candidateData, rejectedData) {
                final highlighted = candidateData.isNotEmpty;
                return LongPressDraggable<int>(
                  data: index,
                  maxSimultaneousDrags: _isSolved || _isLost ? 0 : 1,
                  feedback: SizedBox.square(
                    dimension: 82,
                    child: _buildBoardTile(
                      index: index,
                      tileValue: tileValue,
                      selected: true,
                      highlighted: true,
                      dragging: false,
                    ),
                  ),
                  childWhenDragging: _buildBoardTile(
                    index: index,
                    tileValue: tileValue,
                    selected: false,
                    highlighted: false,
                    dragging: true,
                  ),
                  child: GestureDetector(
                    onTap: () => _handleTileTap(index),
                    child: _buildBoardTile(
                      index: index,
                      tileValue: tileValue,
                      selected: selected,
                      highlighted: highlighted,
                      dragging: false,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBoardTile({
    required int index,
    required int tileValue,
    required bool selected,
    required bool highlighted,
    required bool dragging,
  }) {
    final isCorrect = tileValue == index + 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dragging
            ? Colors.white.withValuesCompat(alpha: 0.08)
            : Colors.white.withValuesCompat(alpha: 0.06),
        borderRadius: BorderRadius.circular(_boardSize >= 6 ? 14 : 18),
        border: Border.all(
          color: selected
              ? Colors.white
              : highlighted
                  ? _selectedLevel.accent
                  : isCorrect
                      ? _selectedLevel.accent.withValuesCompat(alpha: 0.92)
                      : Colors.white.withValuesCompat(alpha: 0.12),
          width: selected || highlighted || isCorrect ? 2.2 : 1.1,
        ),
        boxShadow: [
          if (selected || highlighted || isCorrect)
            BoxShadow(
              color: _selectedLevel.accent.withValuesCompat(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: dragging ? 0.25 : 1,
            child: _PuzzleImageTile(
              imagePath: _currentImagePath,
              tileValue: tileValue,
              boardSize: _boardSize,
              isCorrect: true,
            ),
          ),
          if (!dragging)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_boardSize >= 6 ? 12 : 16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black
                        .withValuesCompat(alpha: isCorrect ? 0.02 : 0.14),
                  ],
                ),
              ),
            ),
          if (isCorrect)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _selectedLevel.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  color: _selectedLevel.accent),
              const SizedBox(width: 10),
              Text(
                _isArabic ? 'كيف نلعب' : 'How to Play',
                style: TextStyle(
                  color: _selectedLevel.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isArabic
                ? '1. اسحبي أي قطعة فوق قطعة أخرى لتبديل مكانهما.'
                : '1. Drag any tile onto another tile to swap their positions.',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? '2. يمكنك أيضًا الضغط على قطعتين بالتتابع إذا كان السحب صعبًا.'
                : '2. You can also tap two tiles in sequence if dragging feels harder.',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? '3. افحصي معاينة الصورة وحاولي إعادة كل جزء إلى مكانه الصحيح قبل انتهاء الوقت.'
                : '3. Use the preview image to guide you and restore every tile before the timer ends.',
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _selectedLevel.accent.withValuesCompat(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_search_rounded,
            color: _selectedLevel.accent,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            _isArabic ? 'لم تتم إضافة صور بعد' : 'No level images added yet',
            style: TextStyle(
              color: _selectedLevel.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? 'أضيفي صور المستويات داخل assets/images/puzzle_shuffle/ ثم نفذي Hot Restart. يفضل استخدام 50 صورة مرتبة، صورة لكل مستوى.'
                : 'Add your level images inside assets/images/puzzle_shuffle/ and run a hot restart. Using 50 ordered images, one per level, is recommended.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}
