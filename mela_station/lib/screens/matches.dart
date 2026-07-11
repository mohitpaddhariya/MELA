import 'package:flutter/material.dart';

import '../services/card_store.dart';
import '../services/matcher.dart';
import '../services/sync_service.dart';

/// The human gate. Explainable ✓/✗/unknown table per candidate pair —
/// a volunteer confirms or rejects. NOTHING is ever automatic.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.store, required this.sync});

  final CardStore store;
  final SyncService sync;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _rejected = <String>{}; // "lostId|foundId" pairs dismissed this run

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final all = widget.store.all;
        final founds =
            all.where((c) => c.kind == 'found' && c.status != 'resolved');
        final pairs = <MatchResult>[];
        for (final f in founds) {
          for (final r in rankCandidates(f, all)) {
            if (!_rejected.contains('${r.lost.id}|${r.found.id}')) {
              pairs.add(r);
            }
          }
        }
        if (pairs.isEmpty) {
          return const Center(
              child: Text('कोई candidate match नहीं।\n'
                  'Found card file hone par yahan table dikhega.',
                  textAlign: TextAlign.center));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pairs.length,
          itemBuilder: (context, i) => _MatchCard(
            result: pairs[i],
            onConfirm: () async {
              await widget.sync
                  .publishMatchCandidate(pairs[i].lost, pairs[i].fieldsForWire);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Candidate confirmed → station ${pairs[i].lost.station} '
                        'ko Hindi mein sunaya jayega')));
              }
            },
            onReject: () => setState(() =>
                _rejected.add('${pairs[i].lost.id}|${pairs[i].found.id}')),
            onResolve: () => widget.sync.publishResolve(pairs[i].lost),
          ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard(
      {required this.result,
      required this.onConfirm,
      required this.onReject,
      required this.onResolve});

  final MatchResult result;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final lost = result.lost, found = result.found;
    final isCandidate = lost.status == 'candidate';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${lost.id} (lost, ${lost.station})  ↔  '
              '${found.id} (found, ${found.station})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: IntrinsicColumnWidth(),
            },
            children: [
              const TableRow(children: [
                Text('Field', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Lost report',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Found (photo)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(''),
              ]),
              for (final r in result.rows.where((r) =>
                  r.verdict != FieldVerdict.unknown ||
                  !_bothUnknown(r)))
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(r.field),
                  ),
                  Text(r.lostValue),
                  Text(r.foundValue),
                  Text(switch (r.verdict) {
                    FieldVerdict.match => '✓',
                    FieldVerdict.mismatch => '✗',
                    FieldVerdict.unknown => '?',
                  }),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (!isCandidate) ...[
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check),
                label: const Text('Confirm candidate'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onReject, child: const Text('Reject')),
            ] else ...[
              const Chip(
                  label: Text('CANDIDATE — family verify karo'),
                  backgroundColor: Colors.orange),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.family_restroom),
                label: const Text('Reunited ✓'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  bool _bothUnknown(MatchRow r) =>
      r.lostValue == 'unknown' && r.foundValue == 'unknown';
}
