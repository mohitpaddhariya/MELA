# flutter_gemma 0.13.6 Cheat Sheet (MELA demo path)

> ## ⚠⚠ PINNED TO flutter_gemma **0.13.6** — Dart 3.11 limit. ⚠⚠
> **Do NOT follow pub.dev 1.x docs** (`FlutterGemma.initialize(inferenceEngines:)`, `flutter_gemma_litertlm/_mediapipe` engine packages, `Message.withImages`, `maxOutputTokens` — NONE of that exists here).
> **iOS `.litertlm` = TEXT ONLY (no vision, no audio).** All vision demos happen on **Android**. iPhone 16 station = text path only.
> Source of truth: `~/.pub-cache/hosted/pub.dev/flutter_gemma-0.13.6/README.md` + CHANGELOG.

## 1. Install model (ONE time, persisted on device; sets it "active")
```dart
import 'package:flutter_gemma/flutter_gemma.dart';   // exports FlutterGemma, ModelType, Message, Tool, responses…

// From network with progress (progress is int 0-100). Gemma 4 repo is Apache-2.0 → NO token needed.
await FlutterGemma.installModel(modelType: ModelType.gemmaIt)      // Gemma 4 uses gemmaIt — there is NO ModelType.gemma4 in 0.13.6
  .fromNetwork(
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    // token: 'hf_...',  // only for gated repos (google/gemma-3n-*, Gemma3-1B-IT) — or set once via FlutterGemma.initialize(huggingFaceToken:)
  )
  .withProgress((progress) => print('$progress%'))
  .install();

// From a sideloaded file (adb push / Files app — our offline path). References the file, no copy:
await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
  .fromFile('/absolute/path/gemma-4-E2B-it.litertlm').install();
// Also: .fromAsset('models/x.litertlm')  .fromBundled('x.litertlm')
final ok = await FlutterGemma.isModelInstalled('gemma-4-E2B-it.litertlm');
```
`ModelType` values: `gemmaIt` (ALL Gemma incl. 4/3n/3), `deepSeek`, `qwen`, `qwen3`, `functionGemma`, `phi`, `general`, `llama`, `hammer`. `ModelFileType`: `.litertlm` files → `ModelFileType.litertlm` (added 0.13.0; auto-detected from extension, README says `.task`/`.litertlm` behave identically — MediaPipe handles chat templates).

## 2. Startup: load ONCE, keep warm (GemmaService singleton)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();          // REQUIRED since 0.11.10. Optional: huggingFaceToken:, maxDownloadRetries: 10
  runApp(MyApp());
}

// After install — do this ONCE behind the splash screen (first load = the slow weight load):
final model = await FlutterGemma.getActiveModel(
  maxTokens: 4096,                          // WHOLE context window (input+output). Default 1024. Example app uses 4096 for Gemma 4 E2B
  preferredBackend: PreferredBackend.gpu,   // or PreferredBackend.cpu (fallback toggle for flaky GPUs)
  supportImage: true,                       // Android vision; leave false on iOS (.litertlm text-only)
  maxNumImages: 1,
);
final chat = await model.createChat(
  temperature: 1.0, topK: 64, topP: 0.95,   // example app's Gemma 4 E2B settings (defaults: 0.8 / 1 / null)
  supportImage: true,                       // must ALSO be true here for vision
  systemInstruction: 'Extract a lost-person card. Reply ONLY with JSON.',  // Android .litertlm: native; iOS/.task: auto-prepended to 1st message
  // tokenBuffer: 256,  isThinking: false (default — keep false for speed),
);

// Send text, get full (non-streamed) response — returns ModelResponse, NOT String:
await chat.addQueryChunk(Message.text(text: hindiTranscript, isUser: true));
final ModelResponse response = await chat.generateChatResponse();
if (response is TextResponse) print(response.token);   // sync mode: full text in .token
// Streaming alt: chat.generateChatResponseAsync().listen((r) { if (r is TextResponse) buf += r.token; });
// Keep model+chat alive app-lifetime. model.close() only on exit. One-shot alt: model.createSession() → session.getResponse() returns String → session.close().
```

## 3. Vision (ANDROID ONLY with our .litertlm) — one photo → same JSON card
```dart
final Uint8List imageBytes = await photo.readAsBytes();   // JPEG/PNG handled automatically
await chat.addQueryChunk(Message.withImage(               // SINGULAR withImage, ONE Uint8List (no withImages/list in 0.13.6)
  text: 'Extract the lost-person card from this photo. Reply ONLY with JSON.',
  imageBytes: imageBytes, isUser: true,
));
final r = await chat.generateChatResponse();
if (r is TextResponse) parseCard(r.token);
// Message.imageOnly(imageBytes: ..., isUser: true) also exists. message.hasImage to check.
```
`supportImage: true` needed at BOTH `getActiveModel()` AND `createChat()`. README: vision models want 8GB+ RAM devices; no other size guidance given — pre-shrink camera output anyway.

## 4. Function calling / JSON output / thinking toggle
```dart
final chat = await model.createChat(
  tools: [ const Tool(name: 'save_card', description: 'Save an extracted lost-person card',
      parameters: {'type':'object','properties':{'age_range':{'type':'string'},'clothing_top':{'type':'string'}},
                   'required':['age_range']}) ],
  supportsFunctionCalls: true,              // REQUIRED alongside tools
  toolChoice: ToolChoice.auto,              // auto | required | none
  // maxFunctionBufferLength: 2048,         // new in 0.13.6 — raise if long function args get truncated
);
final resp = await chat.generateChatResponse();
if (resp is FunctionCallResponse) {
  handle(resp.name, resp.args);             // args: Map<String, dynamic>
  await chat.addQueryChunk(Message.toolResponse(toolName: resp.name, response: {'status': 'ok'}));
} else if (resp is ParallelFunctionCallResponse) { for (final c in resp.calls) handle(c.name, c.args); }
```
**Demo-safer fallback (our default): NO tools.** systemInstruction = "Respond ONLY with JSON matching {schema}", then `jsonDecode` in try/catch, strip ```json fences, one retry on failure. Deterministic Dart owns the flow either way.
**Thinking mode (Gemma 4, since 0.13.1):** `createChat(isThinking: true, modelType: ModelType.gemmaIt)` → `ThinkingResponse` chunks (`.content`) in the async stream; `<|think|>` auto-injected. **For speed leave `isThinking: false` (the default)** — no thinking tokens generated/parsed.

## 5. Platform config (exactly what the 0.13.6 README prescribes)
**iOS** — `ios/Podfile`: `platform :ios, '16.0'` + `use_frameworks! :linkage => :static`. `Info.plist`: `UIFileSharingEnabled=true` (sideload via Finder), `NSLocalNetworkUsageDescription` (needed for our LAN hub anyway), optional `CADisableMinimumFrameDurationOnPhone=true`. `Runner.entitlements` (large models — REQUIRED or jetsam kills mid-generation): `com.apple.developer.kernel.extended-virtual-addressing`, `com.apple.developer.kernel.increased-memory-limit`, `com.apple.developer.kernel.increased-debugging-memory-limit` all `<true/>`. CHANGELOG 0.13.4: arm64 **excluded from simulator archs** (Apple-Silicon sim builds compile but = CPU sim only) — test on the real iPhone. 0.13.3 fixed `pod install` hanging — don't downgrade below it.
**Android** — plugin ships minSdk 24 / compileSdk 36. GPU needs OpenCL lines in `AndroidManifest.xml` **inside `<application>`** (skip only if CPU-only):
```xml
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-car.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-pixel.so" android:required="false"/>
```
Release builds: ProGuard rules auto-included (keep `com.google.mediapipe.**` / `com.google.protobuf.**` if you see `UnsatisfiedLinkError`). No abiFilters required by the README.

## 6. Formats & our model
| Format | Android | iOS | Web | Desktop |
|---|:--:|:--:|:--:|:--:|
| `.task` | ✅ | ✅ | ✅ | ❌ |
| `.litertlm` | ✅ | ⚠️ **text only — no vision/audio** | ❌ | ✅ |
| `-web.task` | ❌ | ❌ | ✅ | ❌ |
| `.bin` | ✅ | ✅ | ✅ | ❌ |

**Gemma 4 E2B** = 2.4GB, vision ✅ (Android), audio ✅ (Android/Desktop), function calling ✅, thinking ✅, multilingual, 128K-class context. Repo ungated (no HF token):
`https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`

## GOTCHAS (demo killers)
1. **iOS + `.litertlm` = TEXT ONLY.** Vision on iPhone silently isn't a thing in 0.13.6. Photo→card demos run on the Androids; iPhone 16 does Hindi-text→card only.
2. **Download the model NOW, before the venue.** No internet there. `/resolve/main/` URLs, never `/blob/main/` (HTML, not the file). HF CDN does NOT support resume — interrupted download restarts from 0. Android >500MB downloads auto-use a foreground service (notification appears — normal).
3. **`maxTokens` is the ENTIRE context window** (prompt + image tokens + reply). There is **no `maxOutputTokens` in 0.13.6** — cap verbosity via the system instruction. Check budget with `session.sizeInTokens(text)`.
4. **`generateChatResponse()` returns `ModelResponse`, not `String`.** Always `if (response is TextResponse) response.token` — pattern-match or you get nothing.
5. `getActiveModel()` throws `StateError('No active inference model set…')` if `installModel()` never ran — gate app start on `isModelInstalled`. First `getActiveModel()` does the slow weight load: once, behind splash, then keep warm.
6. CHANGELOG traps fixed in 0.13.3–0.13.6 (stay pinned, don't downgrade): iOS pod install hang (0.13.3), iOS XNNPack compile error + arm64 simulator (0.13.4), Qwen3 think-tag leakage (0.13.5). Gemma 4 thinking mode only works since 0.13.1 (and not on Web).
7. Model files are 2.4GB — **never commit** (already gitignored). Sideload per phone via `adb push` / Files, then `.fromFile()`.
