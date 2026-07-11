import 'package:flutter/material.dart';

import '../config.dart';
import '../models/mela_card.dart';
import '../services/card_store.dart';
import '../services/sync_service.dart';

/// Card board + sync status + demo-day config (station id, hub IP).
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.store, required this.sync});

  final CardStore store;
  final SyncService sync;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Station config'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: station,
              decoration: const InputDecoration(labelText: 'Station ID')),
          TextField(
              controller: hub,
              decoration:
                  const InputDecoration(labelText: 'Hub URL (ws://ip:8765)')),
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
    );
    if (ok == true) {
      MelaConfig.station = station.text.trim();
      MelaConfig.hubUrl = hub.text.trim();
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
