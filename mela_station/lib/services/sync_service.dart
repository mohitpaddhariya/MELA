import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/mela_card.dart';
import '../models/sync_messages.dart';
import 'card_store.dart';

enum SyncStatus { offline, connecting, online }

/// WebSocket client to mela_hub. FROZEN client rule: write local first,
/// then outbox, background flush with retry. Nothing blocks on the network;
/// nothing here ever throws into the UI.
class SyncService {
  SyncService(this.store);

  final CardStore store;
  final status = ValueNotifier<SyncStatus>(SyncStatus.offline);

  /// Fired when another station confirms a candidate for OUR lost card —
  /// Stage 3 wires the Hindi TTS chirp here.
  void Function(String cardId, String foundAt)? onMatchCandidate;
  void Function(String cardId)? onResolve;

  WebSocketChannel? _ch;
  Timer? _retry;
  bool _stopped = false;

  void start() {
    _stopped = false;
    _connect();
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _ch?.sink.close();
    status.value = SyncStatus.offline;
  }

  // --- public API used by screens ---

  /// Local truth first, then queue for the world.
  Future<void> publishCard(MelaCard card) async {
    await store.merge(card);
    await store.enqueue(SyncMessage.encodeCardUpsert(card));
    _flush();
  }

  Future<void> publishMatchCandidate(
      MelaCard card, Map<String, String> fields) async {
    final updated = card.copyWith(
        status: 'candidate',
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await store.merge(updated);
    await store.enqueue(SyncMessage.encodeCardUpsert(updated));
    await store.enqueue(SyncMessage.encodeMatchCandidate(
        card.id, MelaConfig.station, fields));
    _flush();
  }

  Future<void> publishResolve(MelaCard card) async {
    final updated = card.copyWith(
        status: 'resolved',
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await store.merge(updated);
    await store.enqueue(SyncMessage.encodeCardUpsert(updated));
    await store.enqueue(SyncMessage.encodeResolve(card.id, MelaConfig.station));
    _flush();
  }

  // --- connection machinery ---

  void _connect() {
    if (_stopped) return;
    status.value = SyncStatus.connecting;
    try {
      _ch = WebSocketChannel.connect(Uri.parse(MelaConfig.hubUrl));
      _ch!.stream.listen(_onMessage, onDone: _onDrop, onError: (_) => _onDrop());
      _ch!.sink.add(SyncMessage.encodeHello(MelaConfig.station));
      status.value = SyncStatus.online;
      _flush();
    } catch (_) {
      _onDrop();
    }
  }

  void _onDrop() {
    if (_stopped) return;
    status.value = SyncStatus.offline;
    _ch = null;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), _connect); // simple, relentless
  }

  Future<void> _flush() async {
    final ch = _ch;
    if (ch == null || status.value != SyncStatus.online) return;
    for (final entry in store.pending()) {
      try {
        ch.sink.add(entry.value);
        await store.markSent(entry.key);
      } catch (_) {
        return; // connection died mid-flush; retry loop will resume
      }
    }
  }

  Future<void> _onMessage(dynamic raw) async {
    final msg = SyncMessage.decode('$raw');
    if (msg == null) return;
    switch (msg.type) {
      case SyncMessage.snapshot:
        for (final card in msg.cards) {
          await store.merge(card);
        }
        _flush(); // push anything we created while dead (kill-and-revive beat)
        break;
      case SyncMessage.cardUpsert:
        final card = msg.card;
        if (card != null) await store.merge(card);
        break;
      case SyncMessage.matchCandidate:
        final id = msg.data['card_id'];
        final at = msg.data['found_at'];
        final mine = id is String ? store.byId(id) : null;
        if (mine != null && mine.station == MelaConfig.station) {
          onMatchCandidate?.call(mine.id, at is String ? at : '?');
        }
        break;
      case SyncMessage.resolve:
        final id = msg.data['card_id'];
        if (id is String) {
          final c = store.byId(id);
          if (c != null && c.status != 'resolved') {
            await store.merge(c.copyWith(
                status: 'resolved',
                updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000));
          }
          onResolve?.call(id);
        }
        break;
    }
  }
}
