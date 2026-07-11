import 'dart:convert';

/// The FROZEN card schema (see CLAUDE.md). All fields are strings;
/// anything unknown is the literal string "unknown". Do not extend.
class MelaCard {
  final String id; // "A-114"
  final String station; // "vol1-iphone"
  final int updatedAt; // epoch seconds
  final String kind; // "lost" | "found"
  final String status; // "open" | "candidate" | "resolved"
  final String ageRange; // "5-7"
  final String gender;
  final String nameResponse;
  final String clothingTop;
  final String clothingBottom;
  final String glasses; // "black frame" | "none" | "unknown"
  final String hair;
  final String marks;
  final String lastSeen;
  final String notes;

  const MelaCard({
    required this.id,
    required this.station,
    required this.updatedAt,
    required this.kind,
    this.status = 'open',
    this.ageRange = 'unknown',
    this.gender = 'unknown',
    this.nameResponse = 'unknown',
    this.clothingTop = 'unknown',
    this.clothingBottom = 'unknown',
    this.glasses = 'unknown',
    this.hair = 'unknown',
    this.marks = 'unknown',
    this.lastSeen = 'unknown',
    this.notes = '',
  });

  /// The attribute keys the model extracts and the matcher compares.
  /// Order matters: it is the matcher's display order.
  static const attributeKeys = [
    'age_range', 'gender', 'name_response', 'clothing_top',
    'clothing_bottom', 'glasses', 'hair', 'marks', 'last_seen',
  ];

  Map<String, String> get attributes => {
        'age_range': ageRange,
        'gender': gender,
        'name_response': nameResponse,
        'clothing_top': clothingTop,
        'clothing_bottom': clothingBottom,
        'glasses': glasses,
        'hair': hair,
        'marks': marks,
        'last_seen': lastSeen,
      };

  MelaCard copyWith({
    String? status,
    String? notes,
    int? updatedAt,
    Map<String, String>? attrs,
  }) {
    final a = attrs ?? const {};
    String pick(String key, String current) {
      final v = a[key];
      return (v == null || v.isEmpty || v == 'unknown') ? current : v;
    }

    return MelaCard(
      id: id,
      station: station,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: kind,
      status: status ?? this.status,
      ageRange: pick('age_range', ageRange),
      gender: pick('gender', gender),
      nameResponse: pick('name_response', nameResponse),
      clothingTop: pick('clothing_top', clothingTop),
      clothingBottom: pick('clothing_bottom', clothingBottom),
      glasses: pick('glasses', glasses),
      hair: pick('hair', hair),
      marks: pick('marks', marks),
      lastSeen: pick('last_seen', lastSeen),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station': station,
        'updated_at': updatedAt,
        'kind': kind,
        'status': status,
        'age_range': ageRange,
        'gender': gender,
        'name_response': nameResponse,
        'clothing_top': clothingTop,
        'clothing_bottom': clothingBottom,
        'glasses': glasses,
        'hair': hair,
        'marks': marks,
        'last_seen': lastSeen,
        'notes': notes,
      };

  factory MelaCard.fromJson(Map<String, dynamic> j) {
    String s(String key, [String fallback = 'unknown']) {
      final v = j[key];
      return (v is String && v.isNotEmpty) ? v : fallback;
    }

    return MelaCard(
      id: s('id', ''),
      station: s('station', ''),
      updatedAt: (j['updated_at'] is int)
          ? j['updated_at'] as int
          : int.tryParse('${j['updated_at']}') ?? 0,
      kind: s('kind', 'lost'),
      status: s('status', 'open'),
      ageRange: s('age_range'),
      gender: s('gender'),
      nameResponse: s('name_response'),
      clothingTop: s('clothing_top'),
      clothingBottom: s('clothing_bottom'),
      glasses: s('glasses'),
      hair: s('hair'),
      marks: s('marks'),
      lastSeen: s('last_seen'),
      notes: s('notes', ''),
    );
  }

  String encode() => jsonEncode(toJson());
  factory MelaCard.decode(String raw) =>
      MelaCard.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Conflict rule (FROZEN): newer updated_at wins. Idempotent.
  static MelaCard newer(MelaCard a, MelaCard b) =>
      b.updatedAt > a.updatedAt ? b : a;
}
