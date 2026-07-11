# flutter_gemma Cheat Sheet — verified live 2026-07-11 (MELA demo path)

## 1. Install (API changed at 1.0 — modular split; old tutorials are stale)
```yaml
dependencies:
  flutter_gemma: ^1.2.2              # core (published 2026-07-08) — NO engine by itself
  flutter_gemma_litertlm: ^1.0.2     # runs .litertlm (FFI; Android/iOS/desktop, web preview)
  flutter_gemma_mediapipe: ^1.0.4    # runs .task (MediaPipe; Android/iOS/web)
```
Add at least one engine package. For the demo, `flutter_gemma_mediapipe` + a `.task` model OR `flutter_gemma_litertlm` + `.litertlm` both work on Android+iOS.

## 2. Initialize once in main() (MANDATORY — otherwise `getActiveModel()` throws "add the engine package")
```dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterGemma.initialize(
    inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
  );
  runApp(MyApp());
}
```

## 3. Install model (one time, persisted; sets it "active")
```dart
// From network (gemma-licensed HF repos need token — incl. litert-community Gemma repos; gemma-4 repo is Apache-2.0, no token)
await FlutterGemma.installModel(modelType: ModelType.gemma4)   // gemmaIt for Gemma 3n/3
  .fromNetwork('https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      token: 'hf_...')
  .withProgress((p) => print('$p%')).install();
// Other sources: .fromAsset('assets/models/x.litertlm')  .fromFile('/abs/path/x.litertlm')  .fromBundled('x.litertlm')
```
`.fromFile()` is your offline friend: sideload via USB/adb/AirDrop-to-Files, then register. iOS: `UIFileSharingEnabled` lets you drop the file via Finder into the app's Documents.
ModelType: `gemma4` (Gemma 4 E2B/E4B), `gemmaIt` (Gemma 3n / Gemma 3), `general`, etc.

## 4. Create model + chat — LOAD ONCE at startup, keep warm
```dart
late final InferenceModel model;   // app-lifetime singleton
model = await FlutterGemma.getActiveModel(
  maxTokens: 2048,                 // CONTEXT WINDOW (input+output), .litertlm min 1024
  preferredBackend: PreferredBackend.gpu,   // or PreferredBackend.cpu
  supportImage: true,              // REQUIRED for vision
  maxNumImages: 1,
);
final chat = await model.createChat(
  temperature: 0.8, topK: 1, // topP:, randomSeed: also available
  supportImage: true,              // must ALSO be true here
  systemInstruction: 'You are a lost-and-found matcher. Reply only in JSON.',
  maxOutputTokens: 256,            // reply cap (.litertlm only; .task ignores it)
  tokenBuffer: 256,
);
await chat.addQueryChunk(Message.text(text: 'hello', isUser: true));
final reply = await chat.generateChatResponse();          // or generateChatResponseAsync() stream
// Keep `model` and `chat` alive between requests; model.close() only on app exit.
// Fresh context per item: final c = await model.openChat();  (weights shared, history separate)
```

## 5. Multimodal (image) — Gemma 4 E2B/E4B, Gemma 3n E2B/E4B (also FastVLM)
```dart
final msg = Message.withImages(
  text: 'Describe this item for a lost-and-found listing.',
  imageBytes: [jpegOrPngBytes],    // List<Uint8List>; JPEG/PNG auto-handled
  isUser: true,
);
await chat.addQueryChunk(msg);
final desc = await chat.generateChatResponse();
```
Resize photos to ~512-768px before passing (faster prefill, less RAM). Docs recommend 8GB+ RAM devices for vision models.

## 6. Function calling (supported: Gemma 4, Gemma 3n, Gemma 3 1B, Qwen, Phi-4)
```dart
final chat = await model.createChat(tools: [
  Tool(name: 'report_match', description: 'Report a matching found item',
       parameters: {'type':'object','properties':{'item_id':{'type':'string'},'confidence':{'type':'number'}}}),
]); // toolChoice: ToolChoice.auto / required / none
chat.generateChatResponseAsync().listen((r) {
  if (r is TextResponse) append(r.token);
  if (r is FunctionCallResponse) { handle(r.name, r.args);
    chat.addQueryChunk(Message.toolResponse(toolName: r.name, response: {'status':'ok'})); }
});
```
Fallback (safer for a demo): skip tools; system-prompt "Respond ONLY with JSON matching {...}" + `jsonDecode` with try/catch + one retry.

## 7. iOS (iPhone 16 = 8GB RAM, fine)
- `ios/Podfile`: `platform :ios, '16.0'` and `use_frameworks! :linkage => :static`. No post_install needed.
- `Runner.entitlements` (create + attach in Xcode Signing&Capabilities): `com.apple.developer.kernel.increased-memory-limit` = true, `com.apple.developer.kernel.extended-virtual-addressing` = true (+ `increased-debugging-memory-limit` for debug runs).
- `Info.plist`: `UIFileSharingEnabled` = true (sideload models via Finder); `NSLocalNetworkUsageDescription` string (you need this anyway for your hotspot LAN); optional `CADisableMinimumFrameDurationOnPhone` = true.
- Physical device only for GPU; Simulator = CPU-only (Metal sim 256MB cap ⚠ unverified).

## 8. Android
- minSdk 24, compileSdk 36 (plugin uses `com.google.mediapipe:tasks-genai:0.10.33`).
- `.litertlm` runs on **arm64-v8a ONLY**; add `ndk { abiFilters 'arm64-v8a' }` in app build.gradle defaultConfig. (`.task` text also works on x86_64/armeabi-v7a.)
- GPU: add inside `<application>` in AndroidManifest.xml:
```xml
<uses-native-library android:name="libvndksupport.so" android:required="false"/>
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-car.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-pixel.so" android:required="false"/>
```
- No largeHeap needed (native memory). Models stored in app documents dir.

## 9. Models + exact file names (verified on HF today)
| Model | File | Size | Vision | Tools |
|---|---|---|---|---|
| Gemma 4 E2B (best pick) | `litert-community/gemma-4-E2B-it-litert-lm` → `gemma-4-E2B-it.litertlm` (Apache-2.0, NOT gated) | 2.4GB | Y | Y |
| Gemma 3n E2B (.task) | `google/gemma-3n-E2B-it-litert-preview` → `gemma-3n-E2B-it-int4.task` (gated, needs HF token) | 3.1GB | Y | Y |
| Gemma 3n E2B (.litertlm) | `google/gemma-3n-E2B-it-litert-lm` → `gemma-3n-E2B-it-int4.litertlm` (gated) | 3.7GB | Y | Y |
| Gemma 3 1B (text-only fallback) | `litert-community/Gemma3-1B-IT` → `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm` (gated) | 0.6GB | N | Y |

## GOTCHAS (demo killers)
1. **The API you may remember is deprecated.** `FlutterGemmaPlugin.instance.modelManager` / `installModelFromAsset` / `downloadModelFromNetworkWithProgress` are legacy. Modern path = `FlutterGemma.initialize(...)` + `installModel(...)` + `getActiveModel(...)`. Forgetting `initialize()` with engine instances throws at runtime.
2. **DOWNLOAD MODELS NOW, before you're offline.** Venue has no internet. Pre-download to each phone (or bundle) and use `.fromFile()`/`.fromAsset()`. All gemma-licensed repos are gated (accepted license + `hf_` token) — that includes `google/gemma-3n-*` AND `litert-community/Gemma3-1B-IT`; only `litert-community/gemma-4-E2B-it-litert-lm` (Apache-2.0) is ungated. Use `/resolve/main/` URLs, never `/blob/main/` (404).
3. **`maxTokens` ≠ reply length.** It's the whole KV-cache/context window; `.litertlm` requires ≥1024 (also the default) — too-small values crashed with `DYNAMIC_UPDATE_SLICE` errors (see issue #318; ⚠ "now auto-clamped" unverified). Cap replies with `maxOutputTokens` on `createChat` — and note `.task`/MediaPipe **ignores** `maxOutputTokens`.
4. **`supportImage: true` must be set in BOTH `getActiveModel()` and `createChat()`** or images silently degrade/fail.
5. **Mali GPUs (Pixel 7a-class, many mid-range Androids) hard-froze on the vision encoder** — issue #324 (WebGPU/Vulkan fallback path on Mali-G710) is still OPEN as of 1.2.2; keep the manifest lines above anyway. If a demo phone freezes on GPU, retry with `PreferredBackend.cpu` — keep a CPU toggle in your debug UI.
6. **iOS without the `increased-memory-limit` entitlement = jetsam kill mid-generation** on 2-3GB models. Also `.litertlm` on arm64-only: ship `abiFilters 'arm64-v8a'` on Android or old test phones get a broken native load.
7. First `getActiveModel()` after install does the heavy weight load (10-60s). Do it behind a splash screen once; generation is serialized (one session generates at a time) — queue requests, don't parallelize.

## Sources
- https://pub.dev/packages/flutter_gemma (1.2.2, 2026-07-08) + /changelog
- https://github.com/DenisovAV/flutter_gemma (README at packages/flutter_gemma/README.md; signatures verified in lib/flutter_gemma_interface.dart, lib/core/api/flutter_gemma.dart, lib/core/tool.dart)
- https://fluttergemma.dev/docs/multimodal , /docs/function-calling
- HF file listings: google/gemma-3n-E2B-it-litert-preview, google/gemma-3n-E2B-it-litert-lm, litert-community/gemma-4-E2B-it-litert-lm
- Issues: #318 (DYNAMIC_UPDATE_SLICE crash), #324 (Mali freeze), #226 (shared session), #214 (GPU garbage output)
