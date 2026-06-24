import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:logger/logger.dart';

/// Speaks AI Buddy replies aloud.
///
/// On mobile it prefers the device-native [FlutterTts] engine because it is
/// instant, free, and works offline. On web, browser speech synthesis is
/// unreliable (it often has no Arabic voice and can silently play nothing), so
/// there we always use the backend OpenAI TTS endpoint (`/voice/synthesize`)
/// and play the returned audio with [AudioPlayer]. The same backend path also
/// covers Arabic replies on devices with no installed Arabic voice. Speaking
/// aloud is a nice-to-have, so every backend path fails silently rather than
/// interrupting the chat.
class VoiceTtsService {
  VoiceTtsService({
    required NetworkService network,
    Logger? logger,
  })  : _network = network,
        _logger = logger ?? Logger();

  final NetworkService _network;
  final Logger _logger;

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  /// Whether the device has an Arabic voice. Assume true until [init] checks so
  /// we never wrongly route to the backend before the probe completes.
  bool _arabicAvailable = true;
  VoidCallback? _completionHandler;

  Future<void> init() async {
    // iOS and Android use different speech-rate scales: the same numeric value
    // sounds noticeably faster on Android, so slow it down there to keep the
    // gentle, child-friendly pace consistent across platforms. Guard the
    // Platform lookup with kIsWeb since dart:io is unavailable on web.
    final speechRate = kIsWeb ? 0.50 : (Platform.isIOS ? 0.50 : 0.42);
    await _tts.setSpeechRate(speechRate);
    await _tts.setPitch(1.1);
    await _tts.setVolume(1.0);
    // Make speak() resolve only when playback finishes, so callers can chain
    // stop()/speak() without the engine dropping or overlapping utterances.
    await _tts.awaitSpeakCompletion(true);
    // A native TTS error would otherwise leave the UI stuck in the "playing"
    // state, so clear it the same way completion does.
    _tts.setErrorHandler((msg) {
      _logger.w('Native TTS error: $msg');
      _completionHandler?.call();
    });
    try {
      final available = await _tts.isLanguageAvailable('ar-EG');
      _arabicAvailable = available == true;
    } catch (_) {
      _arabicAvailable = false;
    }
    // Backend audio finishing must clear the "playing" state just like native
    // TTS completion does.
    _player.onPlayerComplete.listen((_) => _completionHandler?.call());
  }

  Future<void> speak(String text, {required bool isArabic}) async {
    await stop();
    // On web the browser engine is unreliable, so always use the backend. On
    // mobile, only fall back to the backend when an Arabic reply has no native
    // Arabic voice available.
    if (kIsWeb || (isArabic && !_arabicAvailable)) {
      await _speakViaBackend(text, language: isArabic ? 'ar' : 'en');
      return;
    }
    await _tts.setLanguage(isArabic ? 'ar-EG' : 'en-US');
    await _tts.speak(text);
  }

  Future<void> _speakViaBackend(String text, {required String language}) async {
    try {
      // /voice/synthesize accepts the AI Buddy principal, so the active child
      // session token that NetworkService attaches automatically is enough — no
      // need to dig out a separate parent token that may already have expired.
      final response = await _network.post<Map<String, dynamic>>(
        '/voice/synthesize',
        data: {'text': text, 'language': language, 'speed': 1.0},
      );
      final data = response.data ?? const <String, dynamic>{};
      final audioBase64 = data['audio_base64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        _logger.w('Backend TTS returned no audio');
        _completionHandler?.call();
        return;
      }
      await _player.play(BytesSource(base64Decode(audioBase64)));
    } catch (e) {
      _logger.w('Backend TTS failed: $e');
      // Make sure the UI does not stay stuck in the "playing" state.
      _completionHandler?.call();
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }

  void setCompletionHandler(VoidCallback handler) {
    _completionHandler = handler;
    _tts.setCompletionHandler(handler);
  }

  void setCancelHandler(VoidCallback handler) {
    _tts.setCancelHandler(handler);
  }

  Future<void> dispose() async {
    await _tts.stop();
    await _player.dispose();
  }
}
