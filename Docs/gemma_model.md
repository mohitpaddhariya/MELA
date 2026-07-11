⚠ Our app pins flutter_gemma 0.13.6 — on iOS, .litertlm models are TEXT-ONLY (no vision). Vision demo runs on Android. See flutter_gemma.md.

# MELA Cheat Sheet — Gemma 4 E2B on-device (.litertlm) via flutter_gemma
Verified live 2026-07-11. **Planning-doc assumption "Gemma 4 E2B, released April 2, 2026" is CORRECT** — Gemma 4 (E2B/E4B/26B MoE/31B) shipped Apr 2, 2026, Apache-2.0 (12B Unified added Jun 3, 2026). Gemma 3n still exists but Gemma 4 E2B supersedes it (smaller file, faster, native vision+audio, function calling).

## 1. Model download (do this NOW, on venue-free internet)
- **Repo:** `litert-community/gemma-4-E2B-it-litert-lm` — **NOT gated, no HF token, no license click** (Apache-2.0). (The `google/gemma-3n-*` repos ARE gated + need HF token — avoid.)
- **File for Android + iPhone 16:** `gemma-4-E2B-it.litertlm` — **2.59 GB**
- Direct URL (curl/browser/phone works, no auth):
  `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`
- Do NOT grab: `-web.litertlm`/`-web.task` (browser builds, text-only), `_Google_Tensor_G5` / `_qualcomm_sm8750` / `_intel_*` (NPU-specific builds).
- Context: up to **32k** on-device (bench at 2048); quantization mixed 2/4/8-bit.

## 2. Flutter install (flutter_gemma v1.2.2, published 2026-07-07)
```yaml
dependencies:
  flutter_gemma: ^1.2.2
  flutter_gemma_litertlm: ^1.0.2   # REQUIRED engine pkg for .litertlm (FFI)
```

## 3. Demo-path code
```dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

// REQUIRED once in main() — core registers no engine on its own;
// without this, getActiveModel() throws "add the engine package".
FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

// One-time install (token param optional — repo is ungated)
await FlutterGemma.installModel(modelType: ModelType.gemma4)   // gemma4, NOT gemmaIt!
  .fromNetwork('https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm')
  .withProgress((p) => print('Downloading: $p%'))
  .install();
// (bundle-in-app alternative: .fromAsset('gemma-4-E2B-it.litertlm'))

final model = await FlutterGemma.getActiveModel(
  maxTokens: 2048,                    // CONTEXT window (KV cache), min 1024
  preferredBackend: PreferredBackend.gpu,
  supportImage: true,                 // needed here AND on createChat
);

final chat = await model.createChat(
  temperature: 0.1, topK: 1,          // defaults: temp .8/topK 1 — force low for JSON
  supportImage: true,
  maxOutputTokens: 512,               // reply cap (separate from maxTokens)
  systemInstruction: 'You extract lost-item data. Output ONLY valid JSON matching the schema. No markdown, no prose.',
);

// Text (Hindi) extraction:
await chat.addQueryChunk(Message.text(text: hindiText + jsonSchemaPrompt, isUser: true));
final resp = await chat.generateChatResponse();

// Photo extraction (image BEFORE text — Gemma 4 official guidance):
await chat.addQueryChunk(Message.withImages(
  text: jsonSchemaPrompt, imageBytes: [jpegBytes], isUser: true));

await model.close();
```

## 4. Platform config
**Android** `AndroidManifest.xml` (inside `<application>`, needed for GPU backend):
```xml
<uses-native-library android:name="libvndksupport.so" android:required="false"/>
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-car.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-pixel.so" android:required="false"/>
```
Plus `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>` (auto foreground service for >500MB downloads).
**iOS** `Podfile`: `platform :ios, '16.0'` and `use_frameworks! :linkage => :static` (no post_install needed).
`Info.plist`: `UIFileSharingEnabled=true`; `NSLocalNetworkUsageDescription` (dev).
`Runner.entitlements` (mandatory for a 2.6GB model): `com.apple.developer.kernel.increased-memory-limit=true`, `com.apple.developer.kernel.extended-virtual-addressing=true`.

## 5. Perf / RAM (official LiteRT-LM benchmarks, E2B)
- Peak CPU memory 607–3505 MB depending on device/backend; **use 6–8GB+ RAM phones**; text-only path can be as low as ~0.8 GB weights in memory.
- Decode: ~**52 tok/s Android GPU**, ~25 tok/s iPhone CPU / ~57 tok/s iPhone GPU (bench device: iPhone 17 Pro; iPhone 16 not benchmarked); prefill up to ~3800 tok/s GPU. Budget 5–15 s per JSON card in the demo.

## 6. Prompting for JSON (Gemma cookbook patterns)
- **Temperature 0.0–0.3, topK 1** for schema compliance; put the **full JSON schema with field descriptions IN the prompt** ("Respond with ONLY this JSON, no other text: {\"item\":\"...\",\"color\":\"...\",...}").
- Gemma 4 uses a **NEW chat template** (`<|turn>user ... <turn|>`, `<|image|>`, `<|think|>` thinking token) — NOT Gemma 3's `<start_of_turn>`. flutter_gemma applies it automatically when `ModelType.gemma4` is set; never hand-write turn tokens or add stop tokens yourself.
- Post-process defensively: strip ```json fences, take substring first `{` → last `}`, `jsonDecode` in try/catch, one retry with "Your last output was invalid JSON, output only JSON".
- Vision: variable aspect-ratio/resolution input, visual budget 70–1120 tokens/img — just pass camera JPEG bytes; one image per message is the safe demo path (`maxNumImages` exists on getActiveModel).
- **Hindi: in Gemma 4's 35+ out-of-the-box languages** (140+ pretrained; exact language list not published — ⚠ unverified). Reading Hindi text is fine; for maximum JSON reliability keep schema/keys in English, values may be Devanagari.

## 7. Backup PoC: Google AI Edge Gallery
- Official app on **Google Play (`com.google.ai.edge.gallery`) AND Apple App Store** (iOS 17+; Android 12+ ⚠ unverified); downloads Gemma 4 E2B in-app from HF and runs chat + image + audio fully offline. Perfect judge-facing fallback if the Flutter build breaks.

## Sources
- https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm (files/sizes/bench)
- https://developers.google.com/edge/litert-lm/models/gemma-4 · https://ai.google.dev/gemma/docs/core/model_card_4
- https://pub.dev/packages/flutter_gemma · https://github.com/DenisovAV/flutter_gemma (README, `flutter_gemma_interface.dart`)
- https://github.com/google-gemma/cookbook · https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
- https://play.google.com/store/apps/details?id=com.google.ai.edge.gallery
