// ignore_for_file: unused_element

part of 'learn_screen.dart';

const String kMemoryMatchCardBackAsset =
    'assets/images/memory_match/card_back.png';

class PremiumMemoryMatchGameScreen extends ConsumerStatefulWidget {
  const PremiumMemoryMatchGameScreen({super.key});

  @override
  ConsumerState<PremiumMemoryMatchGameScreen> createState() =>
      _PremiumMemoryMatchGameScreenState();
}

class _PremiumMemoryMatchGameScreenState
    extends ConsumerState<PremiumMemoryMatchGameScreen> {
  static final List<_MemoryLevel> _levels = List.generate(50, (index) {
    const accents = [
      Color(0xFFFFD76A),
      Color(0xFFF8C64B),
      Color(0xFFE7B53D),
      Color(0xFFFFE08A),
      Color(0xFFD9A441),
    ];
    final number = index + 1;
    final pairCount = 3 + (index ~/ 5);
    final safePairCount = pairCount > 12 ? 12 : pairCount;
    final rawTime = 80 - index;
    final time = rawTime < 34 ? 34 : rawTime;
    return _MemoryLevel(
      id: 'premium_memory_$number',
      pairCount: safePairCount,
      timeLimitSeconds: time,
      accent: accents[index % accents.length],
    );
  });

  static const String _memoryCardsFolder = 'assets/images/memory_match/cards/';

  static const List<String> _memoryCardAssets = [
    'assets/images/memory_match/cards/5971890951665946091_121.jpg',
    'assets/images/memory_match/cards/5971890951665946092_120.jpg',
    'assets/images/memory_match/cards/5971890951665946093_120.jpg',
    'assets/images/memory_match/cards/5971890951665946094_120.jpg',
    'assets/images/memory_match/cards/5971890951665946095_120.jpg',
    'assets/images/memory_match/cards/5971890951665946096_120.jpg',
    'assets/images/memory_match/cards/5971890951665946097_120.jpg',
    'assets/images/memory_match/cards/5971890951665946098_120.jpg',
    'assets/images/memory_match/cards/5971890951665946099_120.jpg',
    'assets/images/memory_match/cards/5971890951665946100_121.jpg',
    'assets/images/memory_match/cards/5971890951665946101_120.jpg',
    'assets/images/memory_match/cards/5971890951665946102_120.jpg',
    'assets/images/memory_match/cards/5971890951665946103_120.jpg',
    'assets/images/memory_match/cards/5971890951665946104_120.jpg',
    'assets/images/memory_match/cards/5971890951665946105_120.jpg',
    'assets/images/memory_match/cards/5971890951665946106_120.jpg',
    'assets/images/memory_match/cards/5971890951665946107_120.jpg',
    'assets/images/memory_match/cards/5971890951665946108_120.jpg',
    'assets/images/memory_match/cards/5971890951665946109_120.jpg',
    'assets/images/memory_match/cards/5971890951665946110_120.jpg',
    'assets/images/memory_match/cards/5971890951665946111_120.jpg',
    'assets/images/memory_match/cards/5971890951665946112_121.jpg',
    'assets/images/memory_match/cards/5971890951665946113_120.jpg',
    'assets/images/memory_match/cards/5971890951665946114_120.jpg',
    'assets/images/memory_match/cards/5971890951665946115_120.jpg',
    'assets/images/memory_match/cards/5971890951665946116_120.jpg',
    'assets/images/memory_match/cards/5971890951665946117_121.jpg',
    'assets/images/memory_match/cards/5971890951665946118_120.jpg',
    'assets/images/memory_match/cards/5971890951665946119_120.jpg',
    'assets/images/memory_match/cards/5971890951665946120_120.jpg',
    'assets/images/memory_match/cards/5971890951665946121_120.jpg',
    'assets/images/memory_match/cards/5971890951665946122_120.jpg',
    'assets/images/memory_match/cards/5971890951665946123_120.jpg',
    'assets/images/memory_match/cards/5971890951665946124_121.jpg',
    'assets/images/memory_match/cards/5971890951665946125_120.jpg',
    'assets/images/memory_match/cards/5971890951665946126_121.jpg',
    'assets/images/memory_match/cards/5971890951665946127_120.jpg',
    'assets/images/memory_match/cards/5971890951665946128_121.jpg',
    'assets/images/memory_match/cards/5971890951665946129_120.jpg',
    'assets/images/memory_match/cards/5971890951665946130_121.jpg',
    'assets/images/memory_match/cards/5971890951665946131_120.jpg',
    'assets/images/memory_match/cards/5971890951665946132_121.jpg',
    'assets/images/memory_match/cards/5971890951665946133_121.jpg',
    'assets/images/memory_match/cards/5971890951665946134_120.jpg',
    'assets/images/memory_match/cards/5971890951665946135_120.jpg',
    'assets/images/memory_match/cards/5971890951665946136_120.jpg',
    'assets/images/memory_match/cards/5971890951665946137_121.jpg',
    'assets/images/memory_match/cards/5971890951665946138_120.jpg',
    'assets/images/memory_match/cards/5971890951665946139_120.jpg',
    'assets/images/memory_match/cards/5971890951665946140_120.jpg',
    'assets/images/memory_match/cards/5971890951665946141_120.jpg',
    'assets/images/memory_match/cards/5971890951665946142_121.jpg',
    'assets/images/memory_match/cards/5971890951665946143_120.jpg',
    'assets/images/memory_match/cards/5971890951665946144_120.jpg',
  ];

  final _GameAudioController _audio = _GameAudioController();
  late _MemoryLevel _selectedLevel;
  List<_MemoryToken> _tokenPool = const [];
  List<_MemoryCardData> _cards = const [];
  Timer? _timer;
  int? _firstIndex;
  bool _busy = false;
  bool _isPreviewing = false;
  bool _isLoadingAssets = true;
  bool _isLost = false;
  bool _didShowWinDialog = false;
  bool _isRecordingCompletion = false;
  int _moves = 0;
  int _secondsElapsed = 0;
  int _remainingSeconds = 0;
  int _bestStars = 0;
  Map<String, int> _bestStarsByLevel = const {};

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  int get _matchedPairs => _cards.where((card) => card.isMatched).length ~/ 2;
  bool get _finished => _matchedPairs == _selectedLevel.pairCount;
  bool get _canPlayCurrentLevel =>
      _tokenPool.length >= _selectedLevel.pairCount;
  int get _memoryUnlockedLevelIndex {
    var unlocked = 0;
    for (var i = 0; i < _levels.length - 1; i++) {
      final stars = _bestStarsByLevel[_levels[i].id] ?? 0;
      if (stars > 0) {
        unlocked = i + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }

  int _starsForLevel(_MemoryLevel level) => _bestStarsByLevel[level.id] ?? 0;

  int get _scorePoints {
    final matchPoints = _matchedPairs * 20;
    final timeBonus = _remainingSeconds * 2;
    final efficiencyBonus =
        math.max(0, (_selectedLevel.pairCount * 6) - _moves);
    return matchPoints + timeBonus + efficiencyBonus;
  }

  @override
  void initState() {
    super.initState();
    _selectedLevel = _levels.first;
    _remainingSeconds = _selectedLevel.timeLimitSeconds;
    if (!kIsWeb) {
      unawaited(
        _audio.startBackground('sounds/games/memory_bg.mp3', volume: 0.18),
      );
    }
    _loadBestStars();
    _loadLevelAssets();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _loadLevelAssets() async {
    try {
      final tokens = <_MemoryToken>[];
      for (var i = 0; i < _memoryCardAssets.length; i++) {
        final assetPath = _memoryCardAssets[i];
        final cardNumber = i + 1;
        tokens.add(
          _MemoryToken(
            imagePath: assetPath,
            label: 'Card $cardNumber',
            arabicLabel: 'بطاقة $cardNumber',
            color: const Color(0xFFFFD76A),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _tokenPool = tokens;
        _isLoadingAssets = false;
      });
      _resetGame();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tokenPool = const [];
        _cards = const [];
        _isLoadingAssets = false;
      });
      _timer?.cancel();
    }
  }

  bool _isMemoryImageAsset(String assetPath) {
    final lower = assetPath.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  Future<void> _loadBestStars() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final level in _levels) {
      map[level.id] = prefs.getInt('memory_best_stars_${level.id}') ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _bestStarsByLevel = map;
      _bestStars = map[_selectedLevel.id] ?? 0;
    });
    // Resume at the highest unlocked level instead of always restarting at 1,
    // so leaving and re-entering (or a web refresh) keeps the player's progress.
    final resumeLevel = _levels[_memoryUnlockedLevelIndex];
    if (resumeLevel.id != _selectedLevel.id) {
      _changeLevel(resumeLevel);
    }
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
      _bestStarsByLevel = {
        ..._bestStarsByLevel,
        _selectedLevel.id: best,
      };
    });
  }

  void _resetGame() {
    if (!_canPlayCurrentLevel) {
      _timer?.cancel();
      setState(() {
        _cards = const [];
        _firstIndex = null;
        _busy = false;
        _isPreviewing = false;
        _moves = 0;
        _secondsElapsed = 0;
        _remainingSeconds = _selectedLevel.timeLimitSeconds;
        _isLost = false;
        _didShowWinDialog = false;
      });
      return;
    }

    final tokens = List<_MemoryToken>.from(_tokenPool)..shuffle();
    final selectedTokens = tokens.take(_selectedLevel.pairCount).toList();
    final cards = <_MemoryCardData>[];
    for (final token in selectedTokens) {
      cards.add(_MemoryCardData(token: token));
      cards.add(_MemoryCardData(token: token));
    }
    cards.shuffle();
    for (final card in cards) {
      card.isFaceUp = true;
    }

    _timer?.cancel();
    setState(() {
      _cards = cards;
      _firstIndex = null;
      _busy = false;
      _isPreviewing = false;
      _moves = 0;
      _secondsElapsed = 0;
      _remainingSeconds = _selectedLevel.timeLimitSeconds;
      _isLost = false;
      _didShowWinDialog = false;
    });
    unawaited(_runOpeningPreview());
  }

  Future<void> _runOpeningPreview() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      for (final card in _cards) {
        if (!card.isMatched) {
          card.isFaceUp = false;
        }
      }
      _isPreviewing = false;
      _firstIndex = null;
      _busy = false;
    });
    _startTimer();
  }

  void _changeLevel(_MemoryLevel level) {
    setState(() {
      _selectedLevel = level;
      _remainingSeconds = level.timeLimitSeconds;
      _isLost = false;
      _bestStars = _bestStarsByLevel[level.id] ?? 0;
    });
    _resetGame();
  }

  Future<void> _openMemoryLevelPicker() async {
    final picked = await Navigator.of(context).push<_MemoryLevel>(
      MaterialPageRoute(
        builder: (context) => _MemoryLevelGridScreen(
          title: _isArabic
              ? 'مستويات الذاكرة'
              : 'Memory Levels',
          accent: _selectedLevel.accent,
          levels: _levels,
          selectedLevel: _selectedLevel,
          labelBuilder: _memoryLevelLabel,
          unlockedIndex: _memoryUnlockedLevelIndex,
          starsForLevel: _starsForLevel,
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
        unawaited(
          _audio.playEffect(
            'sounds/games/memory_lose.mp3',
            fallback: SystemSoundType.click,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
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
    if (_busy ||
        _isPreviewing ||
        _isLost ||
        _cards[index].isMatched ||
        _cards[index].isFaceUp) {
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
    setState(() => _moves += 1);

    if (_cards[firstIndex].token.imagePath == _cards[index].token.imagePath) {
      unawaited(
        _audio.playEffect(
          'sounds/games/memory_match.mp3',
          fallback: SystemSoundType.alert,
        ),
      );
      setState(() {
        _cards[firstIndex].isMatched = true;
        _cards[index].isMatched = true;
        _firstIndex = null;
      });
      if (_finished && !_didShowWinDialog) {
        _didShowWinDialog = true;
        _timer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            unawaited(_showWinDialog());
          }
        });
      }
      return;
    }

    _busy = true;
    unawaited(
      _audio.playEffect(
        'sounds/games/memory_tap.mp3',
        fallback: SystemSoundType.click,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _cards[firstIndex].isFaceUp = false;
      _cards[index].isFaceUp = false;
      _firstIndex = null;
      _busy = false;
    });
  }

  int _calculateStars() {
    final perfectMoves = _selectedLevel.pairCount;
    final timeRatio = _remainingSeconds / _selectedLevel.timeLimitSeconds;
    if (_moves <= perfectMoves + 1 && timeRatio >= 0.32) return 3;
    if (_moves <= perfectMoves + 4 && timeRatio >= 0.16) return 2;
    return 1;
  }

  Future<void> _recordMemoryCompletion(int stars) async {
    if (_isRecordingCompletion) return;
    final childProfile = ref.read(currentChildProvider);
    if (childProfile == null) return;

    _isRecordingCompletion = true;
    try {
      await ref
          .read(progressControllerProvider.notifier)
          .recordActivityCompletion(
        childId: childProfile.id,
        activityId: 'game_memory_${_selectedLevel.id}',
        score: stars == 3 ? 100 : (stars == 2 ? 88 : 76),
        duration: math.max(1, (_secondsElapsed / 60).ceil()),
        xpEarned: 18 + (stars * 16) + (_selectedLevel.pairCount * 2),
        notes: 'Memory Match - ${_memoryLevelLabel(_selectedLevel)}',
        performanceMetrics: {
          'stars': stars,
          'moves': _moves,
          'time_seconds': _secondsElapsed,
          'time_remaining_seconds': _remainingSeconds,
          'pair_count': _selectedLevel.pairCount,
          'cards_count': _selectedLevel.pairCount * 2,
          'memory_score': _scorePoints,
          'image_pool': _memoryCardsFolder,
        },
      );
      // Award coins for this level (once per level via activityId dedup)
      await ref.read(gamificationStateProvider.notifier).recordActivity(
        childId: childProfile.id,
        type: ActivityType.play,
        category: 'entertaining',
        score: stars == 3 ? 100 : (stars == 2 ? 88 : 76),
        awardXp: false, // XP already added via recordActivityCompletion
        activityId: 'game_memory_${_selectedLevel.id}',
      );
    } finally {
      _isRecordingCompletion = false;
    }
  }

  Future<void> _showLostDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17110A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.timer_off_rounded, color: Color(0xFFFFD76A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isArabic
                    ? 'انتهى الوقت'
                    : 'Time Is Up',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          _isArabic
              ? 'انتهى الوقت قبل العثور على كل الأزواج. جربي مرة أخرى بسرعة وتركيز أعلى.'
              : 'Time ran out before all pairs were matched. Try again with faster focus.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _resetGame();
            },
            child: Text(_isArabic
                ? 'إعادة'
                : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: _selectedLevel.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: _selectedLevel.accent),
          const SizedBox(height: 14),
          Text(
            _isArabic
                ? 'جار تحميل صور المستوى...'
                : 'Loading level images...',
            style: TextStyle(
              color: _selectedLevel.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: _selectedLevel.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Icon(Icons.image_search_rounded,
              size: 42, color: _selectedLevel.accent),
          const SizedBox(height: 12),
          Text(
            _isArabic
                ? 'أضيفي صور اللعبة'
                : 'Add game images',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _selectedLevel.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? 'أضيفي على الأقل ${_selectedLevel.pairCount} صور مختلفة داخل $_memoryCardsFolder، ثم اعملي إعادة تشغيل كاملة. اللعبة ستختار صورًا عشوائية من نفس الفولدر لكل مستوى.'
                : 'Add at least ${_selectedLevel.pairCount} different images inside $_memoryCardsFolder, then do a full restart. The game will choose random images from the shared folder for each level.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWinDialog() async {
    final stars = _calculateStars();
    final earnedXp = 18 + (stars * 16) + (_selectedLevel.pairCount * 2);
    await _saveBestStars(stars);
    await _recordMemoryCompletion(stars);
    if (!mounted) return;

    showXpGainPopup(context, xp: earnedXp);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17110A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _selectedLevel.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isArabic
                    ? 'أحسنتِ!'
                    : 'Well Done!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isArabic
                  ? 'تم العثور على كل الأزواج في ${_formatTime(_secondsElapsed)} وبعدد $_moves محاولة.'
                  : 'All pairs were matched in ${_formatTime(_secondsElapsed)} using $_moves tries.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
            ),
            const SizedBox(height: 14),
            _StarRow(stars: stars, accent: _selectedLevel.accent),
            const SizedBox(height: 12),
            Text(
              _isArabic
                  ? 'النتيجة: $_scorePoints نقطة'
                  : 'Score: $_scorePoints points',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _resetGame();
            },
            child: Text(_isArabic
                ? 'إعادة المستوى'
                : 'Replay'),
          ),
          if (_selectedLevel != _levels.last)
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _selectedLevel.accent),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _changeLevel(_levels[_levels.indexOf(_selectedLevel) + 1]);
              },
              child: Text(_isArabic
                  ? 'المستوى التالي'
                  : 'Next Level'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = _selectedLevel.pairCount * 2;
    final crossAxisCount = cardCount <= 8 ? 4 : (cardCount <= 16 ? 4 : 5);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isArabic
              ? 'لعبة الذاكرة'
              : 'Memory Match',
          style: TextStyle(
              color: _selectedLevel.accent, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _canPlayCurrentLevel ? _resetGame : null,
            icon: Icon(Icons.refresh_rounded, color: _selectedLevel.accent),
            label: Text(
              _isArabic
                  ? 'إعادة'
                  : 'Reset',
              style: TextStyle(color: _selectedLevel.accent),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildLevelLauncher(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MemoryGoldStatCard(
                      icon: Icons.favorite_rounded,
                      label: _isArabic
                          ? 'الأزواج'
                          : 'Pairs',
                      value: '$_matchedPairs/${_selectedLevel.pairCount}',
                      accent: _selectedLevel.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MemoryGoldStatCard(
                      icon: Icons.touch_app_rounded,
                      label: _isArabic
                          ? 'المحاولات'
                          : 'Moves',
                      value: '$_moves',
                      accent: _selectedLevel.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MemoryGoldStatCard(
                      icon: Icons.timer_rounded,
                      label: _isArabic
                          ? 'الوقت'
                          : 'Time',
                      value: _formatTime(_remainingSeconds),
                      accent: _remainingSeconds <= 12
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
                    child: _MemoryGoldStatCard(
                      icon: Icons.workspace_premium_rounded,
                      label: _isArabic
                          ? 'النتيجة'
                          : 'Score',
                      value: '$_scorePoints',
                      accent: const Color(0xFFFFD76A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MemoryGoldStatCard(
                      icon: Icons.stars_rounded,
                      label: _isArabic
                          ? 'أفضل نجوم'
                          : 'Best Stars',
                      value: '$_bestStars/3',
                      accent: const Color(0xFFFFD76A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MemoryGoldStatCard(
                      icon: Icons.lock_open_rounded,
                      label: _isArabic
                          ? 'المفتوح'
                          : 'Open',
                      value: '${_memoryUnlockedLevelIndex + 1}/50',
                      accent: _selectedLevel.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isLoadingAssets)
                _buildLoadingPanel()
              else if (_canPlayCurrentLevel)
                _buildBoard(crossAxisCount)
              else
                _buildMemoryEmptyState(),
              const SizedBox(height: 18),
              _buildHowToPlayCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0A0A),
            _selectedLevel.accent.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: _selectedLevel.accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: _selectedLevel.accent.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFF4BF),
                  _selectedLevel.accent,
                  const Color(0xFF8A5A0E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _selectedLevel.accent.withValues(alpha: 0.40),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF2A1700), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic
                      ? 'ذاكرة ليلية فاخرة'
                      : 'Premium Night Memory',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _selectedLevel.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isArabic
                      ? 'خلفية سوداء، كروت ذهبية، وكل مستوى له مجموعة صور مختلفة تخصه وحده.'
                      : 'Black background, glowing gold cards, and a different image set for every level.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelLauncher() {
    return InkWell(
      onTap: _openMemoryLevelPicker,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: _selectedLevel.accent.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFF0B1),
                    _selectedLevel.accent,
                    const Color(0xFF9B6A16),
                  ],
                ),
              ),
              child:
                  const Icon(Icons.grid_view_rounded, color: Color(0xFF2A1700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic
                        ? 'اختيار المستوى'
                        : 'Choose Level',
                    style: TextStyle(
                      color: _selectedLevel.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _memoryLevelLabel(_selectedLevel),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _selectedLevel.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(int crossAxisCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: _selectedLevel.accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: _selectedLevel.accent.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount >= 5 ? 0.82 : 0.86,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];
          return _PremiumMemoryCardTile(
            card: card,
            accent: _selectedLevel.accent,
            onTap: () => _flipCard(index),
            backImagePath: kMemoryMatchCardBackAsset,
          );
        },
      ),
    );
  }

  Widget _buildHowToPlayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: _selectedLevel.accent.withValues(alpha: 0.18)),
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
                _isArabic
                    ? 'كيف نلعب'
                    : 'How to Play',
                style: TextStyle(
                  color: _selectedLevel.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isArabic
                ? '1. افتحي بطاقتين في كل مرة.'
                : '1. Flip two cards at a time.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84), height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? '2. إذا تطابقت الصورتان فسيبقيان مفتوحتين.'
                : '2. If the two images match, they stay open.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84), height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? '3. انهي كل الأزواج قبل انتهاء الوقت للانتقال إلى المستوى التالي.'
                : '3. Match every pair before the timer ends to unlock the next level.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84), height: 1.45),
          ),
        ],
      ),
    );
  }

  String _memoryLevelLabel(_MemoryLevel level) {
    final number = _levels.indexOf(level) + 1;
    return _isArabic
        ? 'المستوى $number - ${level.pairCount * 2} بطاقة'
        : 'Level $number - ${level.pairCount * 2} cards';
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MemoryGoldStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MemoryGoldStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMemoryCardTile extends StatelessWidget {
  final _MemoryCardData card;
  final Color accent;
  final VoidCallback onTap;
  final String? backImagePath;

  const _PremiumMemoryCardTile({
    required this.card,
    required this.accent,
    required this.onTap,
    required this.backImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final showFront = card.isFaceUp || card.isMatched;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: showFront ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          final angle = value * math.pi;
          final isFrontVisible = value >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: card.isMatched
                      ? const Color(0xFFFFF0B1)
                      : accent.withValues(alpha: isFrontVisible ? 0.30 : 0.62),
                  width: 2.1,
                ),
                gradient: isFrontVisible
                    ? const LinearGradient(
                        colors: [Color(0xFF1B1B1B), Color(0xFF101010)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : RadialGradient(
                        colors: [
                          const Color(0xFFFFF4BF),
                          accent,
                          const Color(0xFF8A5A0E),
                        ],
                        radius: 1.1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color:
                        accent.withValues(alpha: isFrontVisible ? 0.14 : 0.34),
                    blurRadius: isFrontVisible ? 14 : 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateY(isFrontVisible ? math.pi : 0),
                child: isFrontVisible
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(card.token.imagePath,
                              fit: BoxFit.cover),
                        ),
                      )
                    : Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF2E1B00).withValues(alpha: 0.24),
                            border: Border.all(
                                color: const Color(0xFFFFF0B1), width: 1.4),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF2A1700),
                            size: 28,
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
