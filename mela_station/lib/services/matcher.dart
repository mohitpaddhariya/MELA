import '../models/mela_card.dart';

/// THE MATCHER IS PLAIN DART, NOT THE MODEL (frozen design, see CLAUDE.md).
/// Field-by-field compare -> explainable ✓/✗/unknown rows. No percentages,
/// no scores shown to users — the tally only orders candidates internally.
enum FieldVerdict { match, mismatch, unknown }

class MatchRow {
  final String field;
  final String lostValue;
  final String foundValue;
  final FieldVerdict verdict;
  const MatchRow(this.field, this.lostValue, this.foundValue, this.verdict);
}

class MatchResult {
  final MelaCard lost;
  final MelaCard found;
  final List<MatchRow> rows;
  const MatchResult(this.lost, this.found, this.rows);

  int get matches => rows.where((r) => r.verdict == FieldVerdict.match).length;
  int get mismatches =>
      rows.where((r) => r.verdict == FieldVerdict.mismatch).length;

  /// Internal ordering only — never displayed.
  int get tally => matches * 2 - mismatches;

  /// Wire form for MATCH_CANDIDATE {fields:{"clothing_top":"match",...}}.
  Map<String, String> get fieldsForWire => {
        for (final r in rows) r.field: r.verdict.name,
      };
}

bool _isUnknown(String v) => v.isEmpty || v == 'unknown';

String _norm(String v) => v.toLowerCase().trim();

Set<String> _tokens(String v) =>
    _norm(v).split(RegExp(r'[\s,/-]+')).where((t) => t.isNotEmpty).toSet();

/// (min,max) from "5-7", "6", "~6" — null when unparseable.
(int, int)? _ageBounds(String v) {
  final nums = RegExp(r'\d{1,2}')
      .allMatches(v)
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (nums.isEmpty) return null;
  nums.sort();
  return (nums.first, nums.last);
}

FieldVerdict _compareField(String field, String lost, String found) {
  if (_isUnknown(lost) || _isUnknown(found)) return FieldVerdict.unknown;
  final l = _norm(lost), f = _norm(found);
  if (l == f) return FieldVerdict.match;

  switch (field) {
    case 'age_range':
      final a = _ageBounds(l), b = _ageBounds(f);
      if (a == null || b == null) return FieldVerdict.unknown;
      return (a.$1 <= b.$2 && b.$1 <= a.$2)
          ? FieldVerdict.match
          : FieldVerdict.mismatch;
    case 'glasses':
      // "none" only matches "none"; any two non-none descriptions agree
      // ("yes" vs "black frame") unless tokens actively conflict.
      final lNone = l == 'none' || l == 'no';
      final fNone = f == 'none' || f == 'no';
      if (lNone != fNone) return FieldVerdict.mismatch;
      if (lNone && fNone) return FieldVerdict.match;
      if (l == 'yes' || f == 'yes') return FieldVerdict.match;
      return _tokens(l).intersection(_tokens(f)).isNotEmpty
          ? FieldVerdict.match
          : FieldVerdict.mismatch;
    default:
      // token overlap = fuzzy match ("red kurta" vs "kurta, red colour")
      return _tokens(l).intersection(_tokens(f)).isNotEmpty
          ? FieldVerdict.match
          : FieldVerdict.mismatch;
  }
}

MatchResult matchCards(MelaCard lost, MelaCard found) {
  final la = lost.attributes, fa = found.attributes;
  final rows = <MatchRow>[];
  for (final field in MelaCard.attributeKeys) {
    if (field == 'last_seen') continue; // location isn't an identity attribute
    final l = la[field] ?? 'unknown', f = fa[field] ?? 'unknown';
    rows.add(MatchRow(field, l, f, _compareField(field, l, f)));
  }
  return MatchResult(lost, found, rows);
}

/// All open lost cards ranked against one found card. Candidates with any
/// hard mismatch sink; ties break by most confirmed fields.
List<MatchResult> rankCandidates(MelaCard found, List<MelaCard> allCards) {
  final results = allCards
      .where((c) => c.kind == 'lost' && c.status != 'resolved')
      .map((lost) => matchCards(lost, found))
      .where((r) => r.matches > 0)
      .toList();
  results.sort((a, b) => b.tally.compareTo(a.tally));
  return results;
}
