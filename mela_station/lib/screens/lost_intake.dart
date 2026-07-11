import 'package:flutter/material.dart';

import '../config.dart';
import '../models/mela_card.dart';
import '../services/followup.dart';
import '../services/gemma_service.dart';
import '../services/speech_service.dart';
import '../services/sync_service.dart';

/// Lost-report intake: panicked Hindi -> Gemma card -> ONE follow-up -> file.
/// The mic is primary; the text field is the always-there fallback (STT
/// produces text anyway, so typing is the same pipeline).
class LostIntakeScreen extends StatefulWidget {
  const LostIntakeScreen(
      {super.key,
      required this.gemma,
      required this.speech,
      required this.sync});

  final GemmaService gemma;
  final SpeechService speech;
  final SyncService sync;

  @override
  State<LostIntakeScreen> createState() => _LostIntakeScreenState();
}

class _LostIntakeScreenState extends State<LostIntakeScreen> {
  final _text = TextEditingController();
  final _answer = TextEditingController();

  Map<String, String>? _attrs;
  FollowUp? _followUp;
  bool _followUpDone = false;
  bool _busy = false;
  String? _savedId;

  Future<void> _extract() async {
    final input = _text.text.trim();
    if (input.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final attrs = await widget.gemma.extractFromText(input);
      final fu = nextFollowUp(attrs);
      if (!mounted) return;
      setState(() {
        _attrs = attrs;
        _followUp = fu;
      });
      if (fu != null) {
        await widget.speech.speak(fu.questionHindi); // the agent asks ALOUD
      }
    } catch (_) {
      _toast('Model abhi ready nahi — 10s baad phir try karo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergeAnswer() async {
    final ans = _answer.text.trim();
    if (ans.isEmpty || _attrs == null || _busy) return;
    setState(() => _busy = true);
    try {
      final merged = await widget.gemma.extractFromText(ans, existing: _attrs);
      if (!mounted) return;
      setState(() {
        _attrs = merged;
        _followUpDone = true; // ONE question only — never interrogate
        _followUp = null;
      });
    } catch (_) {
      _toast('Model abhi ready nahi — 10s baad phir try karo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final attrs = _attrs;
    if (attrs == null) return;
    final card = MelaCard(
      id: widget.sync.store.nextCardId(),
      station: MelaConfig.station,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      kind: 'lost',
    ).copyWith(attrs: attrs);
    await widget.sync.publishCard(card);
    setState(() {
      _savedId = card.id;
      _attrs = null;
      _followUp = null;
      _followUpDone = false;
      _text.clear();
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('गुमशुदा रिपोर्ट — Lost report',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'क्या हुआ? बोलिए या लिखिए (Hindi)',
            hintText: 'मेरा बेटा छह साल का, लाल कुर्ता, राम घाट पर...',
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          ValueListenableBuilder<bool>(
            valueListenable: widget.speech.listening,
            builder: (_, on, __) => FilledButton.icon(
              onPressed: () => on
                  ? widget.speech.stopListening()
                  : widget.speech
                      .listen((t) => setState(() => _text.text = t)),
              icon: Icon(on ? Icons.stop : Icons.mic),
              label: Text(on ? 'सुन रहा है…' : 'बोलिए'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _extract,
            icon: _busy
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Card banao'),
          ),
        ]),
        if (_attrs != null) ...[
          const Divider(height: 32),
          _AttrPreview(attrs: _attrs!),
          if (_followUp != null && !_followUpDone) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('❓ ${_followUp!.questionHindi}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _answer,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'जवाब (बोलिए या लिखिए)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.speech.listening,
                          builder: (_, on, __) => OutlinedButton.icon(
                            onPressed: () => on
                                ? widget.speech.stopListening()
                                : widget.speech.listen((t) =>
                                    setState(() => _answer.text = t)),
                            icon: Icon(on ? Icons.stop : Icons.mic),
                            label: const Text('बोलिए'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _busy ? null : _mergeAnswer,
                          child: const Text('जवाब जोड़ो'),
                        ),
                      ]),
                    ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Card save + sync karo'),
          ),
        ],
        if (_savedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('✅ Card $_savedId saved — sync queue mein',
                style: const TextStyle(color: Colors.green)),
          ),
      ],
    );
  }
}

class _AttrPreview extends StatelessWidget {
  const _AttrPreview({required this.attrs});
  final Map<String, String> attrs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in MelaCard.attributeKeys)
          Chip(
            label: Text('$k: ${attrs[k] ?? "unknown"}'),
            backgroundColor: (attrs[k] ?? 'unknown') == 'unknown'
                ? Colors.grey.shade200
                : Colors.lightGreen.shade100,
          ),
      ],
    );
  }
}
