# MELA Cheat Sheet — Offline Hindi STT + TTS in Flutter (verified 2026-07-11)

## Install (pubspec.yaml)
```yaml
dependencies:
  speech_to_text: ^7.4.0   # latest stable on pub.dev (7.5.0-beta.1 exists — do NOT use for demo)
  flutter_tts: ^4.2.5      # latest stable on pub.dev
```
Android: minSdk 21+, compileSdk 31+. flutter_tts wants Kotlin Gradle plugin >= 1.9.10.

## STT — init + Hindi listen (demo path)
```dart
import 'package:speech_to_text/speech_to_text.dart';

final speech = SpeechToText();

Future<String?> initAndFindHindi() async {
  final ok = await speech.initialize(
    onError: (e) => debugPrint('STT err: ${e.errorMsg}'),   // watch for error_no_match
    onStatus: (s) => debugPrint('STT status: $s'),
  );
  if (!ok) return null;
  final locales = await speech.locales();
  // DO NOT hardcode hi_IN vs hi-IN. Android reports "hi_IN" (underscore),
  // iOS reports "hi-IN" (hyphen). Always pick from locales():
  final hi = locales.where((l) => l.localeId.replaceAll('_', '-').toLowerCase().startsWith('hi')).firstOrNull;
  return hi?.localeId; // pass this exact string to listen()
}

void startListening(String hindiLocaleId) {
  speech.listen(
    onResult: (r) { debugPrint('${r.recognizedWords} final=${r.finalResult}'); },
    listenOptions: SpeechListenOptions(          // v7: top-level listen() params are @Deprecated
      localeId: hindiLocaleId,
      onDevice: true,                            // REQUIRED for your no-internet demo
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: true,
      listenMode: ListenMode.dictation,          // better for free-form Hindi sentences
    ),
  );
}
// stop: await speech.stop();  cancel: await speech.cancel();
```

## Does Hindi work OFFLINE? (critical)
- **Android: YES, with a preinstalled pack.** Preinstall NOW on demo phones: **Google app > profile > Settings > Voice > Offline speech recognition > All > download "Hindi (India)"** (older path) and/or **Gboard > Settings > Voice typing > Faster voice typing / offline languages > Hindi**. Pixel: Settings > System > Languages > On-device speech recognition. Then test in **airplane mode** — `onDevice: true` forces the offline recognizer.
- **iOS: NO. Hindi is NOT in Apple's on-device dictation language list** (on-device set is ~20 langs: EN/ES/FR/DE/IT/JA/KO/ZH/RU/AR/PT/TR...). `SFSpeechRecognizer` for hi-IN works only via Apple servers → dead with no internet. **Route all Hindi STT to an Android phone in the demo; the iPhone 16 can still do Hindi TTS (see below) and English STT offline.**

## TTS — speak Hindi + completion
```dart
import 'package:flutter_tts/flutter_tts.dart';
final tts = FlutterTts();

Future<void> initTts() async {
  await tts.awaitSpeakCompletion(true);          // makes speak() Future resolve on completion
  // iOS ONLY — required so TTS plays out the speaker after STT used the mic:
  await tts.setSharedInstance(true);
  await tts.setIosAudioCategory(
    IosTextToSpeechAudioCategory.playAndRecord,
    [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
     IosTextToSpeechAudioCategoryOptions.allowBluetooth,
     IosTextToSpeechAudioCategoryOptions.mixWithOthers],
    IosTextToSpeechAudioMode.voicePrompt,
  );
  final avail = await tts.isLanguageAvailable('hi-IN');   // TTS side always uses hyphen "hi-IN"
  debugPrint('Hindi TTS available: $avail');
  await tts.setLanguage('hi-IN');
  await tts.setSpeechRate(0.5);
}

Future<void> speakHindi(String text) async {
  await speech.stop();                                    // 1. release the mic first
  await Future.delayed(const Duration(milliseconds: 300));// 2. let audio session settle (iOS!)
  await tts.speak(text);                                  // 3. resolves when done (awaitSpeakCompletion)
}
// or: tts.setCompletionHandler(() { ... }); if you don't await
```
**Offline Hindi voices:** Android — Settings > (System/General management) > Text-to-speech output > Google TTS > gear > **Install voice data > Hindi** (preinstall now, test airplane mode). iOS — built-in **"Lekha" hi-IN** voice works offline; add more via Settings > Accessibility > Spoken Content > Voices > Hindi.

## Platform config
**iOS `ios/Runner/Info.plist`:**
```xml
<key>NSMicrophoneUsageDescription</key><string>Mic for lost-and-found voice reports</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Transcribes your speech on device</string>
```
**Android `android/app/src/main/AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>  <!-- harmless offline; keep for LAN -->
<queries>
  <intent><action android:name="android.speech.RecognitionService"/></intent>  <!-- SDK 30+: STT dies without this -->
  <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>  <!-- Android 11+: TTS engine invisible without this -->
</queries>
```
No Podfile changes needed beyond `platform :ios, '13.0'` (or project default >= 13).

## Noisy-hall Hindi accuracy tips
- Hold phone 15–25 cm from mouth; a cheap wired lav/headset mic beats ambient hall noise.
- Use `partialResults: true` and show live text — the speaker self-corrects when they see it.
- `pauseFor: 4s` — Hindi speakers pause mid-sentence; 2s cuts them off. Keep utterances short (one item description per listen()).
- Offline Hindi models are weaker than server ones: coach demoers to speak plain Hindi, avoid heavy code-mixing (Hinglish often transcribes badly offline); numbers may come out as Devanagari words — normalize before feeding Gemma.
- Retry loop on `error_no_match` / `error_speech_timeout` instead of crashing.

## Sources
- https://pub.dev/packages/speech_to_text (7.4.0) · https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechListenOptions-class.html
- https://pub.dev/packages/flutter_tts (4.2.5) · https://github.com/dlutton/flutter_tts (README: iOS audio category, queries element)
- https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition
- iOS on-device language reality check: https://medium.com/@toru_furuya/available-languages-in-on-device-speech-recognition-on-ios-in-2022-8c6383fac9f2 , https://voicescriber.com/offline-transcription/hindi
