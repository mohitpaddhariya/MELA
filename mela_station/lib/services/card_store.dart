import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config.dart';
import '../models/mela_card.dart';

/// Restart-safe local truth. Cards live in Hive as JSON strings (no codegen).
/// Every mutation notifies listeners so screens rebuild.
class CardStore extends ChangeNotifier {
  late Box<String> _cards; // id -> card json
  late Box<String> _outbox; // seq -> raw wire message json
  late Box<String> _settings; // station, hubUrl, per-station id seq

  Future<void> init() async {
    await Hive.initFlutter();
    _cards = await Hive.openBox<String>('cards');
    _outbox = await Hive.openBox<String>('outbox');
    _settings = await Hive.openBox<String>('settings');
  }

  // --- settings (kill+restart must NOT forget who this station is) ---

  String? getSetting(String key) => _settings.get(key);

  Future<void> setSetting(String key, String value) async {
    await _settings.put(key, value);
  }

  /// Persisted per-station counter — a revived station must never re-mint
  /// an id it already used (newer-updated_at-wins would eat the original).
  String nextCardId() {
    final key = 'seq_${MelaConfig.station}';
    final next = (int.tryParse(_settings.get(key) ?? '') ?? 100) + 1;
    _settings.put(key, '$next');
    return '${MelaConfig.station}-$next';
  }

  List<MelaCard> get all {
    final list = _cards.values.map(MelaCard.decode).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  MelaCard? byId(String id) {
    final raw = _cards.get(id);
    return raw == null ? null : MelaCard.decode(raw);
  }

  /// Newer-updated_at-wins merge (FROZEN rule). Returns the winning card,
  /// or null when the incoming card was stale (no change, no notify).
  Future<MelaCard?> merge(MelaCard incoming) async {
    final existing = byId(incoming.id);
    if (existing != null && existing.updatedAt > incoming.updatedAt) {
      return null;
    }
    await _cards.put(incoming.id, incoming.encode());
    notifyListeners();
    return incoming;
  }

  // --- outbox (also restart-safe) ---

  Future<void> enqueue(String rawMessage) async {
    await _outbox.add(rawMessage);
  }

  /// Oldest-first pending wire messages, paired with their box keys.
  List<MapEntry<dynamic, String>> pending() =>
      _outbox.toMap().entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));

  Future<void> markSent(dynamic key) async {
    await _outbox.delete(key);
  }

  int get pendingCount => _outbox.length;
}
