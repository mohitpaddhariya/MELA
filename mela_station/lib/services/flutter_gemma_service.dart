import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/mela_card.dart';
import 'gemma_service.dart';

/// The REAL on-device brain: Gemma 4 E2B (.litertlm) via flutter_gemma 0.13.6.
/// See Docs/flutter_gemma.md — 0.13.6 API, NOT the pub.dev 1.x docs.
/// iOS .litertlm = text only; vision runs on the Androids (frozen demo plan).
class FlutterGemmaService implements GemmaService {
  static const modelFile = 'gemma-4-E2B-it.litertlm';
  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm'
      '/resolve/main/gemma-4-E2B-it.litertlm'; // ungated, 2.4GB — download BEFORE the venue

  InferenceModel? _model;
  bool _ready = false;

  /// Download progress 0-100 while installing (UI can watch this).
  final downloadProgress = ValueNotifier<int?>(null);

  bool get _visionOk => !Platform.isIOS; // .litertlm vision: Android/desktop only

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    await FlutterGemma.initialize();
    if (!await FlutterGemma.isModelInstalled(modelFile)) {
      // On-site the file is sideloaded (adb push / Files) and installed via
      // .fromFile by the setup step; network install is the pre-venue path.
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(modelUrl)
          .withProgress((p) => downloadProgress.value = p)
          .install();
      downloadProgress.value = null;
    }
    // The slow weight load — ONCE, then warm forever (CLAUDE.md landmine).
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      preferredBackend: PreferredBackend.gpu,
      supportImage: _visionOk,
      maxNumImages: 1,
    );
    _ready = true;
  }

  String _schemaPrompt(String task) =>
      'You are helping at a lost-and-found camp at an Indian mela. $task\n'
      'Return ONLY a JSON object with exactly these keys: '
      '${MelaCard.attributeKeys.join(", ")}.\n'
      'Rules: values are short simple English phrases (example: "red kurta", '
      '"5-7", "male", "black frame"); use "unknown" for anything not stated; '
      'age_range is a range like "5-7"; no explanations, no markdown, JSON only.';

  @override
  Future<Map<String, String>> extractFromText(String text,
      {Map<String, String>? existing}) async {
    final task = existing == null
        ? 'Extract the lost-person card from this parent\'s statement '
            '(may be Hindi): "$text"'
        : 'Current card: ${jsonEncode(existing)}. The parent added: "$text". '
            'Update the card — change only fields this answer supports, keep '
            'everything else exactly as it was.';
    final raw = await _generate(_schemaPrompt(task));
    return _parseAttrs(raw, fallback: existing);
  }

  @override
  Future<Map<String, String>> extractFromImage(Uint8List imageBytes) async {
    if (!_visionOk) {
      // Frozen plan: photos are taken on Android stations. Never crash.
      return {for (final k in MelaCard.attributeKeys) k: 'unknown'};
    }
    final raw = await _generate(
      _schemaPrompt('Describe the person in this photo as a found-person '
          'card. Only physical appearance and clothing you can actually see.'),
      image: imageBytes,
    );
    return _parseAttrs(raw);
  }

  /// Fresh chat per request — no cross-case contamination; weights stay warm.
  Future<String> _generate(String prompt, {Uint8List? image}) async {
    final model = _model;
    if (model == null) throw StateError('Gemma not initialized');
    final chat = await model.createChat(
      temperature: 0.2, // extraction wants determinism, not creativity
      topK: 40,
      supportImage: image != null && _visionOk,
      isThinking: false, // speed (cut ladder already dropped thinking display)
    );
    await chat.addQueryChunk(image == null
        ? Message.text(text: prompt, isUser: true)
        : Message.withImage(text: prompt, imageBytes: image, isUser: true));
    final response = await chat.generateChatResponse();
    return response is TextResponse ? response.token : '';
  }

  /// Model output -> schema-clamped attribute map. Tolerates ```json fences
  /// and stray text; never throws — worst case everything is "unknown".
  Map<String, String> _parseAttrs(String raw, {Map<String, String>? fallback}) {
    final out = <String, String>{
      for (final k in MelaCard.attributeKeys) k: fallback?[k] ?? 'unknown',
    };
    try {
      var s = raw.trim();
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start == -1 || end <= start) return out;
      final j = jsonDecode(s.substring(start, end + 1));
      if (j is! Map) return out;
      for (final k in MelaCard.attributeKeys) {
        final v = j[k];
        if (v is String && v.trim().isNotEmpty) {
          out[k] = v.trim().toLowerCase() == 'unknown' ? 'unknown' : v.trim();
        }
      }
    } catch (_) {
      // keep fallback/unknowns — deterministic code owns the flow
    }
    return out;
  }
}
