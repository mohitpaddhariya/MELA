import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/mela_card.dart';
import '../services/card_store.dart';
import '../services/gemma_service.dart';
import '../services/sync_service.dart';

/// Card board + sync status + demo-day config (station id, hub IP).
class BoardScreen extends StatefulWidget {
  const BoardScreen(
      {super.key,
      required this.store,
      required this.sync,
      required this.gemma});

  final CardStore store;
  final SyncService sync;
  final GemmaService gemma;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  Timer? _brainPoll;

  @override
  void initState() {
    super.initState();
    // The brain badge must flip green the moment the model finishes loading.
    _brainPoll = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) return t.cancel();
      if (widget.gemma.isReady) t.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _brainPoll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final cards = widget.store.all;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(children: [
              ValueListenableBuilder<SyncStatus>(
                valueListenable: widget.sync.status,
                builder: (_, s, __) => Chip(
                  avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: switch (s) {
                        SyncStatus.online => Colors.green,
                        SyncStatus.connecting => Colors.orange,
                        SyncStatus.offline => Colors.red,
                      }),
                  label: Text('Station ${MelaConfig.station} · ${s.name} · '
                      'queue ${widget.store.pendingCount}'),
                ),
              ),
              const SizedBox(width: 6),
              // Which brain is running — judges (and we) must never wonder.
              Chip(
                avatar: Icon(
                    MelaConfig.useMockAi ? Icons.smart_toy : Icons.memory,
                    size: 16),
                backgroundColor: MelaConfig.useMockAi
                    ? Colors.grey.shade300
                    : (widget.gemma.isReady
                        ? Colors.green.shade100
                        : Colors.amber.shade100),
                label: Text(MelaConfig.useMockAi
                    ? 'MOCK brain'
                    : (widget.gemma.isReady
                        ? 'GEMMA 4 E2B on-device'
                        : 'GEMMA 4 loading…')),
              ),
              const Spacer(),
              IconButton(
                  onPressed: () => _editConfig(context),
                  icon: const Icon(Icons.settings)),
            ]),
            const SizedBox(height: 8),
            if (cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('अभी कोई card नहीं')),
              ),
            for (final c in cards) _CardTile(card: c),
          ],
        );
      },
    );
  }

  Future<void> _editConfig(BuildContext context) async {
    final station = TextEditingController(text: MelaConfig.station);
    final hub = TextEditingController(text: MelaConfig.hubUrl);
    var realAi = !MelaConfig.useMockAi;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Station config'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: station,
                decoration: const InputDecoration(labelText: 'Station ID')),
            TextField(
                controller: hub,
                decoration:
                    const InputDecoration(labelText: 'Hub URL (ws://ip:8765)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Real Gemma (restart app)'),
              subtitle: const Text('Off = mock brain for UI testing'),
              value: realAi,
              onChanged: (v) => setDialog(() => realAi = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save + reconnect')),
          ],
        ),
      ),
    );
    if (ok == true) {
      MelaConfig.station = station.text.trim();
      MelaConfig.hubUrl = hub.text.trim();
      // Persist — the kill+restart demo beat must come back as itself.
      await widget.store.setSetting('station', MelaConfig.station);
      await widget.store.setSetting('hubUrl', MelaConfig.hubUrl);
      await widget.store.setSetting('useMockAi', realAi ? 'false' : 'true');
      widget.sync.stop();
      widget.sync.start();
      setState(() {});
    }
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});
  final MelaCard card;

  @override
  Widget build(BuildContext context) {
    final color = switch (card.status) {
      'resolved' => Colors.green.shade50,
      'candidate' => Colors.orange.shade50,
      _ => null,
    };
    final a = card.attributes.entries
        .where((e) => e.value != 'unknown')
        .map((e) => e.value)
        .join(' · ');
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(card.kind == 'lost' ? Icons.person_search : Icons.face,
            color: card.kind == 'lost' ? Colors.red : Colors.blue),
        title: Text('${card.id} — ${card.kind} (${card.status})'),
        subtitle: Text(a.isEmpty ? '—' : a),
        trailing: Text(card.station,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}
