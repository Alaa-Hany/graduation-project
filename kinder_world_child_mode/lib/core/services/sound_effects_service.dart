import 'package:audioplayers/audioplayers.dart';

/// App-wide one-shot UI sound effects (nav taps, reward toasts, etc.).
///
/// Reuses the short clips already bundled for the games instead of
/// shipping new assets, so the whole app shares one consistent set of
/// "positive feedback" sounds. Per-game background music and win/lose
/// fanfares stay owned by each game's own audio controller.
class SoundEffectsService {
  SoundEffectsService._();
  static final SoundEffectsService instance = SoundEffectsService._();

  static const String _tapAsset = 'sounds/games/memory_tap.mp3';
  static const String _rewardAsset = 'sounds/games/memory_match.mp3';

  final AudioPlayer _player = AudioPlayer();

  Future<void> playTap() => _play(_tapAsset, volume: 0.5);

  Future<void> playReward() => _play(_rewardAsset, volume: 0.6);

  Future<void> _play(String assetPath, {required double volume}) async {
    try {
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Ignore playback failures (e.g. muted device, unsupported codec).
    }
  }
}
