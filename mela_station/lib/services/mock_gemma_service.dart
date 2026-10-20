import 'dart:typed_data';

import 'gemma_service.dart';

/// Keyword-rule stand-in for Gemma so the ENTIRE demo path runs before the
/// real model is wired in (and on macOS where flutter_gemma has no model).
/// Handles Devanagari (hi-IN STT output) + Latin transliteration (typed
/// fallback). Just enough vocabulary for the rehearsal phrases — this is
/// scaffolding, not a product.
class MockGemmaService implements GemmaService {
  bool _ready = false;

  @override
  Future<void> init() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _ready = true;
  }

  @override
  bool get isReady => _ready;

  @override
  Future<Map<String, String>> extractFromText(String text,
      {Map<String, String>? existing}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900)); // feel real
    final t = text.toLowerCase();

    // ---- scripted demo lines (typed verbatim) get perfect cards ----
    if (t.contains('chotu') && (t.contains('kurta') || t.contains('कुर्ता'))) {
      // A: "mera beta 6 saal ka hai, lal kurta, naam Chotu, Ram Ghat pe kho gaya"
      return {
        'age_range': '5-7', 'gender': 'male', 'name_response': 'Chotu',
        'clothing_top': 'red kurta', 'clothing_bottom': 'unknown',
        'glasses': 'unknown', 'hair': 'black', 'marks': 'unknown',
        'last_seen': 'Ram Ghat',
      };
    }
    if (existing != null &&
        (t.contains('kaala chashma') ||
            t.contains('kala chashma') ||
            t.contains('काला चश्मा'))) {
      // A follow-up answer: "haan, kaala chashma"
      return {...existing, 'glasses': 'black frame'};
    }
    if ((t.contains('mila') || t.contains('मिला')) &&
        (t.contains('chashma') || t.contains('चश्मा'))) {
      // B: "ladka mila hai, lal kurta, kaala chashma, umar 5-6 saal"
      return {
        'age_range': '5-6', 'gender': 'male', 'name_response': 'unknown',
        'clothing_top': 'red kurta', 'clothing_bottom': 'unknown',
        'glasses': 'black frame', 'hair': 'black', 'marks': 'unknown',
        'last_seen': 'unknown',
      };
    }
    // ---- generic keyword rules below (any other input) ----
    final out = Map<String, String>.of(existing ?? const {});

    void fill(String key, String value) {
      final cur = out[key];
      if (cur == null || cur.isEmpty || cur == 'unknown') out[key] = value;
    }

    // gender
    if (_any(t, ['ladka', 'beta', 'boy', 'लड़का', 'बेटा'])) fill('gender', 'male');
    if (_any(t, ['ladki', 'beti', 'girl', 'लड़की', 'बेटी'])) {
      fill('gender', 'female');
    }

    // age: digits ("6 saal") or Hindi number words
    final digits = RegExp(r'(\d{1,2})\s*(saal|sal|years?|साल|वर्ष)').firstMatch(t);
    if (digits != null) {
      final n = int.parse(digits.group(1)!);
      fill('age_range', '${n - 1}-${n + 1}');
    } else {
      const numbers = {
        'paanch': 5, 'पांच': 5, 'पाँच': 5,
        'chhe': 6, 'che': 6, 'छह': 6, 'छे': 6,
        'saat': 7, 'सात': 7,
        'aath': 8, 'आठ': 8,
      };
      for (final e in numbers.entries) {
        if (t.contains(e.key)) {
          fill('age_range', '${e.value - 1}-${e.value + 1}');
          break;
        }
      }
    }

    // clothing_top: color + garment
    const colors = {
      'lal': 'red', 'laal': 'red', 'red': 'red', 'लाल': 'red',
      'nila': 'blue', 'neela': 'blue', 'blue': 'blue', 'नीला': 'blue',
      'hara': 'green', 'green': 'green', 'हरा': 'green',
      'pila': 'yellow', 'peela': 'yellow', 'yellow': 'yellow', 'पीला': 'yellow',
    };
    const garments = {
      'kurta': 'kurta', 'कुर्ता': 'kurta',
      'shirt': 'shirt', 'शर्ट': 'shirt', 'kameez': 'shirt', 'कमीज': 'shirt',
      'frock': 'frock', 'फ्रॉक': 'frock',
      'saree': 'saree', 'साड़ी': 'saree', 'sari': 'saree',
    };
    String? color, garment;
    for (final e in colors.entries) {
      if (t.contains(e.key)) { color = e.value; break; }
    }
    for (final e in garments.entries) {
      if (t.contains(e.key)) { garment = e.value; break; }
    }
    if (garment != null) {
      fill('clothing_top', color != null ? '$color $garment' : garment);
    }

    // glasses — only when actually mentioned; "nahi/no" near chashma => none
    if (_any(t, ['chashma', 'chasma', 'glasses', 'चश्मा'])) {
      if (_any(t, ['nahi', 'nahin', 'no ', 'नहीं'])) {
        out['glasses'] = 'none';
      } else if (_any(t, ['kaala', 'kala', 'black', 'काला'])) {
        out['glasses'] = 'black frame';
      } else {
        out['glasses'] = 'yes';
      }
    }

    // follow-up "haan"/"yes" answers arrive with existing card context;
    // if the answer is just an affirmation about glasses, mark it.
    if (existing != null &&
        (existing['glasses'] == null || existing['glasses'] == 'unknown') &&
        _any(t, ['haan', 'han ', 'yes', 'हां', 'हाँ']) &&
        !t.contains('kurta')) {
      if (_any(t, ['kaala', 'kala', 'black', 'काला'])) {
        out['glasses'] = 'black frame';
      } else {
        out['glasses'] = 'yes';
      }
    }

    // name: "naam X hai" / "answers to X" / "naam X"
    final name = RegExp(r'(?:naam|नाम)\s+([a-zA-Zऀ-ॿ]+)')
        .firstMatch(text.toLowerCase());
    if (name != null && name.group(1) != 'kya') {
      final n = name.group(1)!;
      fill('name_response', n[0].toUpperCase() + n.substring(1));
    }

    // last_seen: known demo landmarks, else "<word> ghat/gate/mandir"
    if (_any(t, ['ram ghat', 'राम घाट', 'ramghat'])) {
      fill('last_seen', 'Ram Ghat');
    } else {
      final place = RegExp(r'([a-zऀ-ॿ]+)\s*(ghat|घाट|gate|गेट|mandir|मंदिर)')
          .firstMatch(t);
      if (place != null) fill('last_seen', place.group(0)!);
    }

    for (final k in MelaCardKeys.all) {
      out.putIfAbsent(k, () => 'unknown');
    }
    return out;
  }

  @override
  Future<Map<String, String>> extractFromImage(Uint8List imageBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // Canned "found child" matching the rehearsal lost-card. MOCK ONLY.
    return {
      'age_range': '5-7',
      'gender': 'male',
      'name_response': 'unknown',
      'clothing_top': 'red kurta',
      'clothing_bottom': 'unknown',
      'glasses': 'black frame',
      'hair': 'black',
      'marks': 'unknown',
      'last_seen': 'unknown',
    };
  }

  bool _any(String t, List<String> keys) => keys.any(t.contains);
}

/// Attribute keys, duplicated here to keep the service layer free of a
/// model-class import cycle. Must equal MelaCard.attributeKeys.
class MelaCardKeys {
  static const all = [
    'age_range', 'gender', 'name_response', 'clothing_top',
    'clothing_bottom', 'glasses', 'hair', 'marks', 'last_seen',
  ];
}
