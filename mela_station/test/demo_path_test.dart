import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mela_station/models/mela_card.dart';
import 'package:mela_station/services/followup.dart';
import 'package:mela_station/services/matcher.dart';
import 'package:mela_station/services/mock_gemma_service.dart';

// The rehearsal demo path, minus UI and network. If this passes, the brain
// of the demo works; screens and sync are proven separately.
void main() {
  test('demo path: Hindi statement -> card -> glasses follow-up -> match',
      () async {
    final gemma = MockGemmaService();
    await gemma.init();

    // 1. Mother's rehearsed statement (no glasses mentioned).
    final attrs = await gemma.extractFromText(
        'मेरा बेटा छह साल का है, लाल कुर्ता पहना है, नाम चोटू, राम घाट पर खोया');
    expect(attrs['gender'], 'male');
    expect(attrs['age_range'], '5-7');
    expect(attrs['clothing_top'], 'red kurta');
    expect(attrs['last_seen'], isNot('unknown'));
    expect(attrs['glasses'], 'unknown');

    // 2. Code (not model) picks the ONE follow-up: the glasses question.
    final fu = nextFollowUp(attrs);
    expect(fu, isNotNull);
    expect(fu!.field, 'glasses');
    expect(fu.questionHindi, 'Kya usne chashma pehna tha?');

    // 3. Mother answers; merge fills ONLY the gap.
    final merged =
        await gemma.extractFromText('हाँ, काला चश्मा', existing: attrs);
    expect(merged['glasses'], 'black frame');
    expect(merged['clothing_top'], 'red kurta'); // untouched
    expect(nextFollowUp(merged), isNull); // one question, then done

    // 4. Found intake at Station B (canned mock vision).
    final foundAttrs = await gemma.extractFromImage(Uint8List(0));

    final lost = MelaCard(
            id: 'A-101', station: 'A', updatedAt: 100, kind: 'lost')
        .copyWith(attrs: merged);
    final found = MelaCard(
            id: 'B-101', station: 'B', updatedAt: 101, kind: 'found')
        .copyWith(attrs: foundAttrs);

    // 5. Deterministic matcher: the ✓/✗ table, no scores.
    final result = matchCards(lost, found);
    final verdicts = {for (final r in result.rows) r.field: r.verdict};
    expect(verdicts['clothing_top'], FieldVerdict.match);
    expect(verdicts['glasses'], FieldVerdict.match);
    expect(verdicts['age_range'], FieldVerdict.match);
    expect(verdicts['gender'], FieldVerdict.match);
    expect(result.mismatches, 0);

    // 6. Ranking puts this pair on top and wire fields serialize.
    final ranked = rankCandidates(found, [lost]);
    expect(ranked, hasLength(1));
    expect(ranked.first.fieldsForWire['clothing_top'], 'match');

    // 7. Card JSON round-trip (what actually travels).
    final wire = MelaCard.decode(lost.encode());
    expect(wire.attributes, lost.attributes);
    expect(MelaCard.newer(lost, found).id, 'B-101');
  });

  test('typed Hinglish fallback works the same', () async {
    final gemma = MockGemmaService();
    await gemma.init();
    final attrs = await gemma.extractFromText(
        'mera beta 6 saal ka hai, lal kurta, naam Chotu, Ram Ghat pe khoya');
    expect(attrs['gender'], 'male');
    expect(attrs['age_range'], '5-7');
    expect(attrs['clothing_top'], 'red kurta');
    expect(attrs['name_response'], 'Chotu');
    expect(attrs['last_seen'], 'Ram Ghat');
    expect(nextFollowUp(attrs)!.field, 'glasses');
  });
}
