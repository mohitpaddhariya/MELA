import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/mela_card.dart';
import 'gemma_service.dart';
import 'mock_gemma_service.dart';

/// The REAL on-device brain: Gemma 4 E2B (.litertlm) via flutter_gemma 1.x
/// + LiteRtLmEngine (registered in main.dart). The 1.x runtime parses the
/// Gemma 4 vision encoder — 0.13.6 could not ("3 signatures" error).
/// One-shot sessions per extraction = fresh context per case.
class FlutterGemmaService implements GemmaService {
  static const modelFile = 'gemma-4-E2B-it.litertlm';
  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm'
      '/resolve/main/gemma-4-E2B-it.litertlm'; // ungated, 2.4GB — download BEFORE the venue

  /// Android external-files dir path, resolved by main() via path_provider
  /// so the APP creates/owns the dir (a shell-created dir is invisible to
  /// the app through FUSE). adb push the model here AFTER first app run.
  static String? androidExternalModelPath;

  static const _staticSideloadPaths = [
    '/sdcard/Download/gemma-4-E2B-it.litertlm',
    '/Users/mohitpaddhariya/Library/Containers/com.mela.melaStation/Data/'
        'Documents/gemma-4-E2B-it.litertlm',
    '/Users/mohitpaddhariya/flagship-projects/MELA/models/gemma-4-E2B-it.litertlm',
  ];

  static List<String> get sideloadPaths => [
        if (androidExternalModelPath != null) androidExternalModelPath!,
        ..._staticSideloadPaths,
      ];

  InferenceModel? _model;
  bool _ready = false;

  /// If real inference can't come up, extraction degrades to the mock so
  /// the app never breaks. Set only after all engine attempts fail.
  MockGemmaService? _fallback;
  bool get usingFallback => _fallback != null;

  /// Download progress 0-100 while installing (UI can watch this).
  final downloadProgress = ValueNotifier<int?>(null);

  /// Whether the engine that actually came up supports images.
  bool _visionActive = false;
  bool get visionActive => _visionActive;

  bool get _visionOk => Platform.isAndroid; // demo plan: vision on Androids

  @override
  bool get isReady => _ready;

  Future<void> _ensureInstalled() async {
    final installer = FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    );
    String? local;
    for (final p in sideloadPaths) {
      if (File(p).existsSync()) {
        local = p;
        break;
      }
    }
    if (local != null) {
      await installer.fromFile(local).install();
    } else {
      await installer
          .fromNetwork(modelUrl)
          .withProgress((p) => downloadProgress.value = p)
          .install();
      downloadProgress.value = null;
    }
  }

  /// Load ladder: GPU+vision -> CPU+vision -> GPU text -> CPU text -> mock.
  @override
  Future<void> init() async {
    try {
      // Engine registration happens in main(); here we only install + load.
      if (!await FlutterGemma.isModelInstalled(modelFile)) {
        await _ensureInstalled();
      }
      final attempts = <(PreferredBackend, bool)>[
        if (_visionOk) (PreferredBackend.gpu, true),
        if (_visionOk) (PreferredBackend.cpu, true),
        (PreferredBackend.gpu, false),
        (PreferredBackend.cpu, false),
      ];
      for (var round = 0; round < 2; round++) {
        for (final (backend, vision) in attempts) {
          try {
            await _model?.close();
            _model = await FlutterGemma.getActiveModel(
              maxTokens: 4096,
              preferredBackend: backend,
              supportImage: vision,
            );
            _visionActive = vision;
            debugPrint('gemma engine UP: backend=${backend.name} '
                'vision=$vision (round $round)');
            _ready = true;
            return;
          } catch (e) {
            debugPrint(
                'gemma attempt ${backend.name}/vision=$vision failed: $e');
          }
        }
        // Whole ladder failed — maybe stale registration; reinstall once.
        if (round == 0) await _ensureInstalled();
      }
      throw StateError('all engine attempts failed');
    } catch (e) {
      debugPrint('FlutterGemmaService init failed ($e) — using mock fallback');
      _fallback = MockGemmaService();
      await _fallback!.init();
      _ready = true;
    }
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
    if (_fallback != null) {
      return _fallback!.extractFromText(text, existing: existing);
    }
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
    if (_fallback != null) return _fallback!.extractFromImage(imageBytes);
    if (!_visionActive) {
      // Engine came up text-only: found intake falls back to description.
      return {for (final k in MelaCard.attributeKeys) k: 'unknown'};
    }
    final raw = await _generate(
      _schemaPrompt('Describe the person in this photo as a found-person '
          'card. Only physical appearance and clothing you can actually see.'),
      image: imageBytes,
    );
    return _parseAttrs(raw);
  }

  /// One-shot session per request (fresh context, weights stay warm).
  Future<String> _generate(String prompt, {Uint8List? image}) async {
    final model = _model;
    if (model == null) throw StateError('Gemma not initialized');
    final session = await model.createSession(
      enableVisionModality: image != null && _visionActive,
      temperature: 0.2, // extraction wants determinism, not creativity
      topK: 40,
    );
    try {
      await session.addQueryChunk(image == null
          ? Message.text(text: prompt, isUser: true)
          : Message.withImages(
              text: prompt, imageBytes: [image], isUser: true));
      return await session.getResponse();
    } finally {
      await session.close();
    }
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
