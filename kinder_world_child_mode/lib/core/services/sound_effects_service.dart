import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Semantic, event-oriented sound effects shared across the whole app.
///
/// Children get instant, varied audio feedback for taps, rewards, correct /
/// wrong answers, level-ups, etc. Picking an effect by *meaning* (instead of an
/// asset path) lets a single event map to several clips that rotate for variety.
enum SoundEffect {
  /// Generic UI tap — rotates between two clips so repeated taps don't sound
  /// monotonous.
  tap,

  /// Selecting / picking an item (cards, options).
  select,

  /// Moving between screens / pages.
  navigate,

  /// Light "pop" for small playful interactions.
  pop,

  /// Quick swipe / slide feedback.
  whoosh,

  /// XP / reward toast.
  reward,

  /// Earning a coin or small collectible.
  coin,

  /// A correct answer in a quiz / lesson.
  correct,

  /// Completing an activity or winning a game.
  success,

  /// Levelling up — the biggest celebratory cue.
  levelUp,

  /// A wrong answer (gentle, not harsh).
  wrong,

  /// Losing / running out of time in a game.
  lose,
}

class _EffectSpec {
  /// One or more clips for this effect. When more than one is given they are
  /// rotated on each play so consecutive triggers vary.
  final List<String> assets;
  final double volume;

  const _EffectSpec(this.assets, this.volume);
}

/// App-wide one-shot sound effects with near-zero latency.
///
/// Each clip is loaded and decoded **once** into its own low-latency player
/// (see [warmUp]); playing it afterwards just seeks to the start and resumes,
/// so the sound fires in lock-step with the on-screen event instead of lagging
/// behind a fresh decode. Per-game background music stays owned by each game's
/// own audio controller, but their one-shot effects can route through
/// [playOneShot] to share the same preloaded, low-latency players.
class SoundEffectsService {
  SoundEffectsService._();
  static final SoundEffectsService instance = SoundEffectsService._();

  /// Maps each semantic effect to the bundled clip(s) and a sensible volume.
  /// Reuses the short clips already shipped for the games rather than adding
  /// new assets, so the whole app shares one consistent palette.
  static const Map<SoundEffect, _EffectSpec> _specs = {
    SoundEffect.tap: _EffectSpec(
      ['sounds/games/memory_tap.mp3', 'sounds/games/puzzle_tap.mp3'],
      0.5,
    ),
    SoundEffect.select: _EffectSpec(['sounds/games/puzzle_tap.mp3'], 0.55),
    SoundEffect.navigate: _EffectSpec(['sounds/games/memory_tap.mp3'], 0.45),
    SoundEffect.pop: _EffectSpec(['sounds/games/memory_tap.mp3'], 0.35),
    SoundEffect.whoosh: _EffectSpec(['sounds/games/puzzle_tap.mp3'], 0.4),
    SoundEffect.reward: _EffectSpec(['sounds/games/memory_match.mp3'], 0.6),
    SoundEffect.coin: _EffectSpec(['sounds/games/memory_match.mp3'], 0.5),
    SoundEffect.correct: _EffectSpec(['sounds/games/memory_match.mp3'], 0.6),
    SoundEffect.success: _EffectSpec(
      ['sounds/games/memory_win.mp3', 'sounds/games/puzzle_win.mp3'],
      0.7,
    ),
    SoundEffect.levelUp: _EffectSpec(['sounds/games/puzzle_win.mp3'], 0.8),
    SoundEffect.wrong: _EffectSpec(['sounds/games/puzzle_lose.mp3'], 0.55),
    SoundEffect.lose: _EffectSpec(['sounds/games/memory_lose.mp3'], 0.6),
  };

  /// One preloaded low-latency player per asset path, reused across plays.
  final Map<String, AudioPlayer> _players = {};

  /// Rotation cursor per effect so multi-clip effects cycle their variants.
  final Map<SoundEffect, int> _rotation = {};

  final Random _rng = Random();

  bool _warmedUp = false;

  /// When false, all app-wide sound effects are silenced. Controlled by the
  /// child's "music" toggle in the home header (see `soundControllerProvider`).
  bool enabled = true;

  /// Other audio sources (e.g. per-game background music players) that want to
  /// honour the same global mute toggle. Each is invoked when the child mutes
  /// so their currently-playing audio stops immediately, not just future plays.
  final Set<void Function()> _muteListeners = {};

  void addMuteListener(void Function() listener) => _muteListeners.add(listener);

  void removeMuteListener(void Function() listener) =>
      _muteListeners.remove(listener);

  void setEnabled(bool value) {
    enabled = value;
    if (!value) {
      // Stop anything currently playing the moment the child mutes.
      for (final player in _players.values) {
        player.stop().catchError((_) {});
      }
      for (final listener in _muteListeners.toList()) {
        listener();
      }
    }
  }

  /// Preloads and decodes every effect clip up front so the first time each one
  /// plays it fires instantly. Safe to call multiple times; runs once. Best
  /// invoked during app bootstrap (fire-and-forget) — it never throws.
  Future<void> warmUp() async {
    if (_warmedUp) return;
    _warmedUp = true;
    final assets = <String>{
      for (final spec in _specs.values) ...spec.assets,
    };
    for (final asset in assets) {
      await _playerFor(asset);
    }
  }

  /// Plays a semantic effect. Multi-clip effects rotate for variety.
  Future<void> play(SoundEffect effect) async {
    if (!enabled) return;
    final spec = _specs[effect]!;
    final asset = _pickAsset(effect, spec);
    try {
      await playOneShot(asset, volume: spec.volume);
    } catch (_) {
      // Ignore playback failures (e.g. muted device, unsupported codec).
    }
  }

  // --- Convenience helpers (kept terse for high-traffic call sites). ---

  Future<void> playTap() => play(SoundEffect.tap);
  Future<void> playSelect() => play(SoundEffect.select);
  Future<void> playNavigate() => play(SoundEffect.navigate);
  Future<void> playPop() => play(SoundEffect.pop);
  Future<void> playWhoosh() => play(SoundEffect.whoosh);
  Future<void> playReward() => play(SoundEffect.reward);
  Future<void> playCoin() => play(SoundEffect.coin);
  Future<void> playCorrect() => play(SoundEffect.correct);
  Future<void> playSuccess() => play(SoundEffect.success);
  Future<void> playLevelUp() => play(SoundEffect.levelUp);
  Future<void> playWrong() => play(SoundEffect.wrong);
  Future<void> playLose() => play(SoundEffect.lose);

  /// Plays a specific bundled clip through the shared low-latency player pool.
  ///
  /// Lets per-game controllers reuse the same preloaded players for their
  /// one-shot effects, so their feedback is as snappy as the UI's. Throws on
  /// failure so callers can fall back (e.g. to a [SystemSound]).
  Future<void> playOneShot(String asset, {double volume = 1}) async {
    if (!enabled) return;
    final player = await _playerFor(asset);
    await player.setVolume(volume.clamp(0.0, 1.0));
    // Restart from the top. In low-latency mode seek can be unsupported on some
    // platforms, so isolate it — a failed seek must not block the replay.
    try {
      await player.seek(Duration.zero);
    } catch (_) {}
    await player.resume();
  }

  String _pickAsset(SoundEffect effect, _EffectSpec spec) {
    if (spec.assets.length == 1) return spec.assets.first;
    final start = _rotation[effect] ?? _rng.nextInt(spec.assets.length);
    final next = (start + 1) % spec.assets.length;
    _rotation[effect] = next;
    return spec.assets[next];
  }

  /// Returns the preloaded low-latency player for [asset], creating and warming
  /// it on first use. Decode happens here, once per asset, never per play.
  Future<AudioPlayer> _playerFor(String asset) async {
    final existing = _players[asset];
    if (existing != null) return existing;
    final player = AudioPlayer(playerId: 'sfx_${asset.hashCode}');
    _players[asset] = player;
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setSource(AssetSource(asset));
    } catch (_) {
      // Keep the player cached even if preload failed; a later play() will
      // surface the error so callers can fall back.
    }
    return player;
  }
}
