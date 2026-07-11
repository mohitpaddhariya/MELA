import 'dart:convert';

import 'mela_card.dart';

/// The FROZEN wire protocol (see CLAUDE.md). Flat JSON with a "type"
/// discriminator — same shape the Node hub speaks.
///
///   HELLO           {type, station}
///   SNAPSHOT        {type, cards: [card...]}          (hub -> client)
///   CARD_UPSERT     {type, card}
///   MATCH_CANDIDATE {type, card_id, found_at, fields} (fields: {"clothing_top":"match",...})
///   RESOLVE         {type, card_id, by}
class SyncMessage {
  static const hello = 'HELLO';
  static const snapshot = 'SNAPSHOT';
  static const cardUpsert = 'CARD_UPSERT';
  static const matchCandidate = 'MATCH_CANDIDATE';
  static const resolve = 'RESOLVE';

  final String type;
  final Map<String, dynamic> data;

  const SyncMessage(this.type, this.data);

  static String encodeHello(String station) =>
      jsonEncode({'type': hello, 'station': station});

  static String encodeCardUpsert(MelaCard card) =>
      jsonEncode({'type': cardUpsert, 'card': card.toJson()});

  static String encodeMatchCandidate(
          String cardId, String foundAt, Map<String, String> fields) =>
      jsonEncode({
        'type': matchCandidate,
        'card_id': cardId,
        'found_at': foundAt,
        'fields': fields,
      });

  static String encodeResolve(String cardId, String by) =>
      jsonEncode({'type': resolve, 'card_id': cardId, 'by': by});

  /// Returns null on garbage input — sync must never crash the app.
  static SyncMessage? decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return null;
      final t = j['type'];
      if (t is! String) return null;
      return SyncMessage(t, j);
    } catch (_) {
      return null;
    }
  }

  MelaCard? get card {
    final c = data['card'];
    return c is Map<String, dynamic> ? MelaCard.fromJson(c) : null;
  }

  List<MelaCard> get cards {
    final list = data['cards'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(MelaCard.fromJson)
        .toList();
  }
}
