import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

/// Speaks AI Buddy replies aloud.
///
/// Prefers the device-native [FlutterTts] engine because it is instant, free,
/// and works offline. When a reply is Arabic but the device has no Arabic voice
/// installed, native TTS fails silently, so we fall back to the backend OpenAI
/// TTS endpoint (`/voice/synthesize`) and play the returned audio with
/// [AudioPlayer]. Speaking aloud is a nice-to-have, so every backend path fails
/// silently rather than interrupting the chat.
class VoiceTtsService {
  VoiceTtsService({
    required NetworkService network,
    required SecureStorage secureStorage,
    Logger? logger,
  })  : _network = network,
        _secureStorage = secureStorage,
        _logger = logger ?? Logger();

  final NetworkService _network;
  final SecureStorage _secureStorage;
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
    if (isArabic && !_arabicAvailable) {
      await _speakViaBackend(text, language: 'ar');
      return;
    }
    await _tts.setLanguage(isArabic ? 'ar-EG' : 'en-US');
    await _tts.speak(text);
  }

  Future<void> _speakViaBackend(String text, {required String language}) async {
    try {
      // The synthesize endpoint requires a parent (User) token; child-session
      // tokens are rejected and are not auto-attached by NetworkService.
      final token = await _secureStorage.getParentAccessToken();
      final response = await _network.post<Map<String, dynamic>>(
        '/voice/synthesize',
        data: {'text': text, 'language': language, 'speed': 1.0},
        options: (token == null || token.isEmpty)
            ? null
            : Options(headers: {'Authorization': 'Bearer $token'}),
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
