part of 'learn_screen.dart';

enum _ArcadeKind {
  catchStars,
  whackAnimal,
  balloons,
  turtleRun,
  funnyPaint,
  fishFeeding
}

const List<_ArcadeGameConfig> _arcadeGames = [
  _ArcadeGameConfig(
      title: 'Catch the Falling Stars',
      image: 'assets/images/star.png',
      accent: Color(0xFFFFC145),
      icon: Icons.auto_awesome_rounded,
      kind: _ArcadeKind.catchStars),
  _ArcadeGameConfig(
      title: 'Whack the Animal',
      image: 'assets/images/edu_animals.png',
      accent: Color(0xFFFF8A65),
      icon: Icons.pets_rounded,
      kind: _ArcadeKind.whackAnimal),
  _ArcadeGameConfig(
      title: 'Pop the Balloons',
      image: 'assets/images/small_stars.png',
      accent: Color(0xFFEC407A),
      icon: Icons.air_rounded,
      kind: _ArcadeKind.balloons),
  _ArcadeGameConfig(
      title: 'Turtle Run',
      image: 'assets/images/skill_sports.png',
      accent: Color(0xFF66BB6A),
      icon: Icons.directions_run_rounded,
      kind: _ArcadeKind.turtleRun),
  _ArcadeGameConfig(
      title: 'Funny Paint',
      image: 'assets/images/skill_drawing.png',
      accent: Color(0xFFAB47BC),
      icon: Icons.draw_rounded,
      kind: _ArcadeKind.funnyPaint),
  _ArcadeGameConfig(
      title: 'Fish Feeding',
      image: 'assets/images/edu_science.png',
      accent: Color(0xFF29B6F6),
      icon: Icons.water_rounded,
      kind: _ArcadeKind.fishFeeding),
];

class _FunArcadeGameScreen extends StatefulWidget {
  final _ArcadeGameConfig config;
  const _FunArcadeGameScreen({required this.config});

  @override
  State<_FunArcadeGameScreen> createState() => _FunArcadeGameScreenState();
}

class _FunArcadeGameScreenState extends State<_FunArcadeGameScreen> {
  final _audio = _GameAudioController();
  final _random = math.Random();
  final List<Offset> _paintDots = [];
  Timer? _timer;
  int _levelIndex = 0;
  int _unlockedIndex = 0;
  int _score = 0;
  int _remaining = 30;
  int _activeHole = 0;
  int _mistakes = 0;
  double _x = 0.5;
  double _y = 0.15;
  double _basket = 0.5;
  double _runnerY = 0;
  double _runnerVelocity = 0;
  double _obstacleX = 1.1;
  bool _finished = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  int get _target => 8 + (_levelIndex * 3);
  int get _duration => math.max(16, 30 - (_levelIndex * 2));
  String get _title =>
      _isArabic ? _titleAr(widget.config.kind) : widget.config.title;
  String get _subtitle => _isArabic
      ? _subtitleAr(widget.config.kind)
      : _subtitleEn(widget.config.kind);

  @override
  void initState() {
    super.initState();
    unawaited(_audio.startBackground('sounds/games/memory_bg.mp3'));
    _startLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _startLevel() {
    _timer?.cancel();
    _score = 0;
    _mistakes = 0;
    _remaining = _duration;
    _finished = false;
    _paintDots.clear();
    _basket = 0.5;
    _x = 0.2 + _random.nextDouble() * 0.6;
    _y = widget.config.kind == _ArcadeKind.catchStars ? -0.05 : 0.2;
    _activeHole = _random.nextInt(6);
    _runnerY = 0;
    _runnerVelocity = 0;
    _obstacleX = 1.1;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => _tick());
    setState(() {});
  }

  void _tick() {
    if (!mounted || _finished) return;
    switch (widget.config.kind) {
      case _ArcadeKind.catchStars:
        _y += 0.05 + (_levelIndex * 0.012);
        if (_y > 0.84) {
          if ((_x - _basket).abs() < 0.12) {
            _score++;
          } else {
            _mistakes++;
          }
          _x = 0.1 + _random.nextDouble() * 0.8;
          _y = -0.05;
        }
        break;
      case _ArcadeKind.whackAnimal:
        _activeHole = _random.nextInt(6);
        break;
      case _ArcadeKind.balloons:
        _y -= 0.05 + (_levelIndex * 0.01);
        if (_y < -0.08) {
          _mistakes++;
          _x = 0.12 + _random.nextDouble() * 0.76;
          _y = 1.04;
        }
        break;
      case _ArcadeKind.turtleRun:
        _runnerVelocity -= 0.05;
        _runnerY = (_runnerY + _runnerVelocity).clamp(0.0, 0.46);
        if (_runnerY == 0 && _runnerVelocity < 0) _runnerVelocity = 0;
        _obstacleX -= 0.07 + (_levelIndex * 0.01);
        if (_obstacleX < -0.1) {
          _score++;
          _obstacleX = 1.1;
        }
        if ((_obstacleX - 0.2).abs() < 0.08 && _runnerY < 0.12) _mistakes++;
        break;
      case _ArcadeKind.funnyPaint:
        break;
      case _ArcadeKind.fishFeeding:
        _x += 0.07;
        if (_x > 0.9) _x = 0.1;
        break;
    }
    if (DateTime.now().millisecond < 140) _remaining--;
    if (_score >= _target) {
      _finish(true);
      return;
    }
    if (_remaining <= 0 || _mistakes >= 3) {
      _finish(false);
      return;
    }
    setState(() {});
  }

  void _onActionTap([Offset? local]) {
    if (_finished) return;
    switch (widget.config.kind) {
      case _ArcadeKind.catchStars:
        break;
      case _ArcadeKind.whackAnimal:
        _score++;
        break;
      case _ArcadeKind.balloons:
        _score++;
        _x = 0.12 + _random.nextDouble() * 0.76;
        _y = 1.04;
        break;
      case _ArcadeKind.turtleRun:
        if (_runnerY <= 0.02) _runnerVelocity = 0.22;
        break;
      case _ArcadeKind.funnyPaint:
        if (local != null) {
          _paintDots.add(local);
          if (_paintDots.length % 8 == 0) _score++;
        }
        break;
      case _ArcadeKind.fishFeeding:
        if ((_x - 0.5).abs() < 0.18) {
          _score += _levelIndex >= 4 ? 2 : 1;
        } else {
          _mistakes++;
        }
        break;
    }
    unawaited(_audio.playEffect('sounds/games/puzzle_tap.mp3',
        fallback: SystemSoundType.click));
    setState(() {});
  }

  Future<void> _finish(bool won) async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    if (won) {
      _unlockedIndex = math.max(_unlockedIndex, (_levelIndex + 1).clamp(0, 4));
      unawaited(_audio.playEffect('sounds/games/puzzle_win.mp3',
          fallback: SystemSoundType.alert));
    } else {
      unawaited(_audio.playEffect('sounds/games/puzzle_lose.mp3',
          fallback: SystemSoundType.click));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(won
            ? (_isArabic ? 'أحسنت!' : 'Well Done!')
            : (_isArabic ? 'حاولي مرة أخرى' : 'Try Again')),
        content: Text(won
            ? (_isArabic
                ? 'أنهيتِ المستوى بنجاح.'
                : 'You cleared the level successfully.')
            : (_isArabic
                ? 'الجولة انتهت. أعيدي المحاولة.'
                : 'The round is over. Give it another try.')),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (won && _levelIndex < 4) setState(() => _levelIndex++);
              _startLevel();
            },
            style:
                FilledButton.styleFrom(backgroundColor: widget.config.accent),
            child: Text(won && _levelIndex < 4
                ? (_isArabic ? 'التالي' : 'Next')
                : (_isArabic ? 'إعادة' : 'Retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: _title,
      subtitle: _subtitle,
      accent: widget.config.accent,
      trailing: TextButton.icon(
          onPressed: _startLevel,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_isArabic ? 'إعادة' : 'Reset')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ArcadeHeroCard(config: widget.config, isArabic: _isArabic),
        const SizedBox(height: 16),
        _ArcadeLevelStrip(
            accent: widget.config.accent,
            currentLevel: _levelIndex,
            unlockedLevel: _unlockedIndex,
            onSelect: (index) {
              setState(() => _levelIndex = index);
              _startLevel();
            }),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _PuzzleStatCard(
                  icon: Icons.flag_rounded,
                  label: _isArabic ? 'الهدف' : 'Goal',
                  value: '$_score/$_target',
                  accent: widget.config.accent)),
          const SizedBox(width: 12),
          Expanded(
              child: _PuzzleStatCard(
                  icon: Icons.timer_rounded,
                  label: _isArabic ? 'الوقت' : 'Time',
                  value: _formatArcadeMiniTime(_remaining),
                  accent: const Color(0xFF5C6BC0))),
          const SizedBox(width: 12),
          Expanded(
              child: _PuzzleStatCard(
                  icon: Icons.error_outline_rounded,
                  label: _isArabic ? 'الأخطاء' : 'Mistakes',
                  value: '$_mistakes/3',
                  accent: Colors.redAccent)),
        ]),
        const SizedBox(height: 18),
        _buildArena(),
        if (widget.config.kind == _ArcadeKind.turtleRun) ...[
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: _onActionTap,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  label: Text(_isArabic ? 'اقفز' : 'Jump'),
                  style: FilledButton.styleFrom(
                      backgroundColor: widget.config.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)))),
        ],
      ]),
    );
  }

  Widget _buildArena() {
    return LayoutBuilder(builder: (context, constraints) {
      final height = math.min(330.0, constraints.maxWidth * 0.82);
      return GestureDetector(
        onHorizontalDragUpdate: widget.config.kind == _ArcadeKind.catchStars
            ? (d) => setState(() => _basket =
                (_basket + d.delta.dx / constraints.maxWidth).clamp(0.12, 0.88))
            : null,
        onTapDown: widget.config.kind == _ArcadeKind.funnyPaint
            ? (d) => _onActionTap(d.localPosition)
            : widget.config.kind == _ArcadeKind.fishFeeding
                ? (_) => _onActionTap()
                : null,
        child: Container(
          width: constraints.maxWidth,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
                colors: _arenaColors(widget.config.kind),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          child: Stack(children: [
            if (widget.config.kind == _ArcadeKind.catchStars) ...[
              Positioned(
                  left: _x * constraints.maxWidth,
                  top: _y * height,
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFFD54F), size: 34)),
              Positioned(
                  left: (_basket * constraints.maxWidth) - 38,
                  bottom: 18,
                  child: Container(
                      width: 76,
                      height: 40,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.shopping_basket_rounded,
                          color: Colors.white))),
            ],
            if (widget.config.kind == _ArcadeKind.whackAnimal)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16),
                itemBuilder: (context, index) => GestureDetector(
                    onTap: index == _activeHole ? _onActionTap : null,
                    child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF6D4C41),
                            borderRadius: BorderRadius.circular(22)),
                        child: Center(
                            child: AnimatedScale(
                                scale: index == _activeHole ? 1 : 0.2,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                    index == _activeHole &&
                                            _levelIndex >= 2 &&
                                            index == 5
                                        ? Icons.warning_amber_rounded
                                        : Icons.pets_rounded,
                                    size: 38,
                                    color: index == _activeHole &&
                                            _levelIndex >= 2 &&
                                            index == 5
                                        ? Colors.redAccent
                                        : Colors.white))))),
              ),
            if (widget.config.kind == _ArcadeKind.balloons)
              Positioned(
                  left: _x * constraints.maxWidth,
                  top: _y * height,
                  child: GestureDetector(
                      onTap: _onActionTap,
                      child: Column(children: [
                        Container(
                            width: 46,
                            height: 56,
                            decoration: BoxDecoration(
                                color: widget.config.accent,
                                borderRadius: BorderRadius.circular(24)),
                            child: const Icon(Icons.air_rounded,
                                color: Colors.white)),
                        Container(
                            width: 2, height: 18, color: Colors.grey.shade400)
                      ]))),
            if (widget.config.kind == _ArcadeKind.turtleRun) ...[
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                      height: 48,
                      decoration: const BoxDecoration(
                          color: Color(0xFF8BC34A),
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(28))))),
              Positioned(
                  left: 46,
                  bottom: 18 + (_runnerY * height),
                  child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: widget.config.accent,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.bug_report_rounded,
                          color: Colors.white))),
              Positioned(
                  left: _obstacleX * constraints.maxWidth,
                  bottom: 18,
                  child: Icon(
                      _levelIndex == 4
                          ? Icons.crisis_alert_rounded
                          : Icons.landscape_rounded,
                      size: _levelIndex == 4 ? 46 : 34,
                      color: _levelIndex == 4
                          ? Colors.redAccent
                          : const Color(0xFF6D4C41))),
            ],
            if (widget.config.kind == _ArcadeKind.funnyPaint) ...[
              ..._paintDots.map((dot) => Positioned(
                  left: dot.dx - 10,
                  top: dot.dy - 10,
                  child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color:
                              widget.config.accent.withValuesCompat(alpha: 0.7),
                          shape: BoxShape.circle)))),
              Center(
                  child: Icon(Icons.palette_rounded,
                      size: 120,
                      color:
                          widget.config.accent.withValuesCompat(alpha: 0.08))),
            ],
            if (widget.config.kind == _ArcadeKind.fishFeeding) ...[
              Positioned(
                  left: _x * constraints.maxWidth,
                  top: height * 0.48,
                  child: const Icon(Icons.phishing_rounded,
                      color: Colors.white, size: 40)),
              const Positioned(
                  left: 18,
                  top: 18,
                  child: Icon(Icons.touch_app_rounded, color: Colors.white70)),
            ],
          ]),
        ),
      );
    });
  }
}

class _ArcadeHeroCard extends StatelessWidget {
  final _ArcadeGameConfig config;
  final bool isArabic;
  const _ArcadeHeroCard({required this.config, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: config.accent.withValuesCompat(alpha: 0.14))),
      child: Row(children: [
        Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: config.accent.withValuesCompat(alpha: 0.14),
                borderRadius: BorderRadius.circular(18)),
            child: Icon(config.icon, color: config.accent, size: 30)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isArabic ? _titleAr(config.kind) : config.title,
              style: TextStyle(
                  color: config.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          const SizedBox(height: 6),
          Text(isArabic ? _subtitleAr(config.kind) : _subtitleEn(config.kind),
              style: const TextStyle(height: 1.4))
        ]))
      ]),
    );
  }
}

class _ArcadeLevelStrip extends StatelessWidget {
  final Color accent;
  final int currentLevel;
  final int unlockedLevel;
  final ValueChanged<int> onSelect;
  const _ArcadeLevelStrip(
      {required this.accent,
      required this.currentLevel,
      required this.unlockedLevel,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: List.generate(5, (index) {
        final unlocked = index <= unlockedLevel;
        final selected = index == currentLevel;
        return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
                label: Text('L${index + 1}'),
                selected: selected,
                onSelected: unlocked ? (_) => onSelect(index) : null,
                avatar:
                    unlocked ? null : const Icon(Icons.lock_rounded, size: 16),
                selectedColor: accent,
                labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : (unlocked ? accent : Colors.grey))));
      })));
}

class _ArcadeGameConfig {
  final String title;
  final String image;
  final Color accent;
  final IconData icon;
  final _ArcadeKind kind;
  const _ArcadeGameConfig(
      {required this.title,
      required this.image,
      required this.accent,
      required this.icon,
      required this.kind});
}

List<Color> _arenaColors(_ArcadeKind kind) => switch (kind) {
      _ArcadeKind.catchStars => const [Color(0xFF102A56), Color(0xFF4527A0)],
      _ArcadeKind.whackAnimal => const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
      _ArcadeKind.balloons => const [Color(0xFFFFF0F6), Color(0xFFE1F5FE)],
      _ArcadeKind.turtleRun => const [Color(0xFFB2EBF2), Color(0xFFE8F5E9)],
      _ArcadeKind.funnyPaint => const [Color(0xFFFFFBFE), Color(0xFFF3E5F5)],
      _ArcadeKind.fishFeeding => const [Color(0xFF81D4FA), Color(0xFF0288D1)]
    };
String _formatArcadeMiniTime(int seconds) =>
    '${(seconds < 0 ? 0 : seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds < 0 ? 0 : seconds % 60).toString().padLeft(2, '0')}';
String _titleAr(_ArcadeKind kind) => switch (kind) {
      _ArcadeKind.catchStars => 'التقاط النجوم',
      _ArcadeKind.whackAnimal => 'اضرب الحيوان',
      _ArcadeKind.balloons => 'فرقعة البالونات',
      _ArcadeKind.turtleRun => 'جري السلحفاة',
      _ArcadeKind.funnyPaint => 'الرسم المرح',
      _ArcadeKind.fishFeeding => 'إطعام السمك'
    };
String _subtitleAr(_ArcadeKind kind) => switch (kind) {
      _ArcadeKind.catchStars => 'حركي السلة والتقطي النجوم بسرعة.',
      _ArcadeKind.whackAnimal => 'اضغطي بسرعة على الحيوان الظاهر.',
      _ArcadeKind.balloons => 'فرقعي البالونات قبل أن تختفي.',
      _ArcadeKind.turtleRun => 'اقفزي فوق العوائق حتى النهاية.',
      _ArcadeKind.funnyPaint => 'ارسمي بحرية وأنهي تحدي الفن.',
      _ArcadeKind.fishFeeding => 'أطعمي السمكة في الوقت المناسب.'
    };
String _subtitleEn(_ArcadeKind kind) => switch (kind) {
      _ArcadeKind.catchStars => 'Move the basket and catch the stars quickly.',
      _ArcadeKind.whackAnimal => 'Tap the animal as soon as it pops up.',
      _ArcadeKind.balloons => 'Pop the balloons before they disappear.',
      _ArcadeKind.turtleRun => 'Jump over obstacles and survive the run.',
      _ArcadeKind.funnyPaint => 'Paint freely and complete the art challenge.',
      _ArcadeKind.fishFeeding => 'Feed the fish at the perfect moment.'
    };
