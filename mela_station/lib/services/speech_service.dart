import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hindi in (STT), Hindi out (TTS) — both on-device. Every failure degrades
/// silently to the typed-text fallback; speech must never crash the demo.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool sttAvailable = false;
  final listening = ValueNotifier<bool>(false);

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
        onError: (_) => listening.value = false,
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening.value = false;
        },
      );
    } catch (_) {
      sttAvailable = false; // e.g. macOS dev runs — typed fallback carries
    }
    try {
      await _tts.setLanguage('hi-IN');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  /// Streams the growing transcript into [onText].
  Future<void> listen(void Function(String text) onText) async {
    if (!sttAvailable || listening.value) return;
    listening.value = true;
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'hi_IN',
        onDevice: true, // the whole point: nothing leaves the phone
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
