import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../models/mela_card.dart';
import '../services/gemma_service.dart';
import '../services/speech_service.dart';
import '../services/sync_service.dart';

/// Found-person intake: ONE consented photo (Gemma vision) AND/OR a spoken
/// description by the volunteer — both feed the same schema, and the
/// description fills whatever the photo couldn't. Photo NEVER leaves the
/// phone — only the JSON card syncs.
class FoundIntakeScreen extends StatefulWidget {
  const FoundIntakeScreen(
      {super.key,
      required this.gemma,
      required this.speech,
      required this.sync,
      this.onFiled});

  final GemmaService gemma;
  final SpeechService speech;
  final SyncService sync;
  final VoidCallback? onFiled; // jump to Matches tab

  @override
  State<FoundIntakeScreen> createState() => _FoundIntakeScreenState();
}

class _FoundIntakeScreenState extends State<FoundIntakeScreen> {
  final _picker = ImagePicker();
  final _desc = TextEditingController();
  Uint8List? _photo;
  Map<String, String>? _attrs;
  bool _busy = false;
  String? _savedId;

  /// Volunteer's spoken/typed description -> same extraction pipeline;
  /// merges into photo attrs when both exist.
  Future<void> _describeExtract() async {
    final text = _desc.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final attrs =
          await widget.gemma.extractFromText(text, existing: _attrs);
      if (!mounted) return;
      setState(() => _attrs = attrs);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Model abhi ready nahi — 10s baad phir try karo')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 768, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _attrs = null;
        _busy = true;
      });
      final attrs = await widget.gemma.extractFromImage(bytes);
      if (!mounted) return;
      setState(() => _attrs = attrs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().contains('camera')
                ? 'Camera is device par nahi hai — Gallery use karo'
                : 'Model abhi ready nahi — 10s baad phir try karo')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final attrs = _attrs;
    if (attrs == null) return;
    final card = MelaCard(
      id: widget.sync.store.nextCardId(),
      station: MelaConfig.station,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      kind: 'found',
    ).copyWith(attrs: attrs);
    await widget.sync.publishCard(card);
    setState(() {
      _savedId = card.id;
      _photo = null;
      _attrs = null;
      _desc.clear();
    });
    widget.onFiled?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('मिला हुआ व्यक्ति — Found person',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'सहमति से एक फोटो। Photo phone se bahar kabhi nahi jaata — sirf '
            'attribute card sync hota hai.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        if (!Platform.isAndroid)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('📷 Photo → card (Gemma vision) sirf ANDROID '
                  'station par chalta hai. Yahan sirf lost-intake test karo.'),
            ),
          )
        else
          Row(children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Photo lo'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ]),
        if (_photo != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_photo!, height: 220, fit: BoxFit.cover),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _desc,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'जो दिख रहा है बोलिए/लिखिए (volunteer description)',
            hintText: 'लड़का, लाल कुर्ता, काला चश्मा, करीब छह साल…',
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          ValueListenableBuilder<bool>(
            valueListenable: widget.speech.listening,
            builder: (_, on, __) => OutlinedButton.icon(
              onPressed: widget.speech.sttAvailable
                  ? () => on
                      ? widget.speech.stopListening()
                      : widget.speech
                          .listen((t) => setState(() => _desc.text = t))
                  : null,
              icon: Icon(on ? Icons.stop : Icons.mic),
              label: Text(on ? 'सुन रहा है…' : 'बोलिए'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _describeExtract,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Card banao'),
          ),
        ]),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Gemma photo padh raha hai… (on-device)'),
            ])),
          ),
        if (_attrs != null) ...[
          const Divider(height: 32),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in MelaCard.attributeKeys)
              Chip(
                label: Text('$k: ${_attrs![k] ?? "unknown"}'),
                backgroundColor: (_attrs![k] ?? 'unknown') == 'unknown'
                    ? Colors.grey.shade200
                    : Colors.lightGreen.shade100,
              ),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Found card file karo'),
          ),
        ],
        if (_savedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('✅ Card $_savedId filed — matches dekho',
                style: const TextStyle(color: Colors.green)),
          ),
      ],
    );
  }
}
