import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hindi in (STT), Hindi out (TTS) — both on-device. Every failure degrades
/// gracefully; speech must never crash or dead-end the demo.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool sttAvailable = false;
  final listening = ValueNotifier<bool>(false);

  /// One-line user-facing notices (e.g. "Hindi offline pack missing").
  /// UI shows these as snackbars.
  final notice = ValueNotifier<String?>(null);

  /// Offline-first; flips false when the device lacks the hi-IN offline
  /// pack (LANGUAGE_PACK error) so the retry uses online recognition.
  /// DEMO DAY: install the pack (Settings → System → Languages →
  /// On-device speech recognition → Hindi) and this stays true.
  bool preferOffline = true;

  void Function(String text)? _lastOnText; // for auto-retry after errors

  Future<void> init() async {
    if (Platform.isMacOS) {
      // Desktop dev rig: typed input only. Requesting speech-recognition
      // TCC permission from a bundle-unattributed process SIGABRTs the app.
      sttAvailable = false;
      try {
        await _tts.setLanguage('hi-IN');
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {}
      return;
    }
    try {
      sttAvailable = await _stt.initialize(
        onError: _onSttError,
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening.value = false;
        },
      );
    } catch (_) {
      sttAvailable = false;
    }
    try {
      await _tts.setLanguage('hi-IN');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  void _onSttError(dynamic e) {
    listening.value = false;
    final msg = '$e'.toLowerCase();
    debugPrint('stt error: $e');
    if (preferOffline &&
        (msg.contains('language') || msg.contains('error_13'))) {
      // Hindi offline pack missing — retry ONLINE so the demo flow keeps
      // moving, and tell the operator how to restore true offline.
      preferOffline = false;
      notice.value =
          'Hindi OFFLINE pack nahi mila — abhi online STT. Offline ke liye: '
          'Settings → System → Languages → On-device speech recognition → '
          'Hindi install karo.';
      final cb = _lastOnText;
      if (cb != null) listen(cb);
    }
  }

  /// Streams the growing transcript into [onText].
  Future<void> listen(void Function(String text) onText) async {
    if (listening.value) return;
    if (!sttAvailable) {
      await init(); // late permission grants / first-tap init retry
      if (!sttAvailable) {
        notice.value = 'Mic init nahi hua — permission check karo';
        return;
      }
    }
    _lastOnText = onText;
    listening.value = true;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'hi_IN',
        onDevice: preferOffline, // offline-first; online only as fallback
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (r) => onText(r.recognizedWords),
    );
  }

  Future<void> stopListening() async {
    if (listening.value) await _stt.stop();
    listening.value = false;
  }

  /// STT and TTS share the audio session — always stop the mic first.
  Future<void> speak(String hindiText) async {
    await stopListening();
    try {
      await _tts.speak(hindiText);
    } catch (_) {}
  }
}
