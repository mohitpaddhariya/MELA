/// The agent loop's decision step — plain code, NOT the model (see CLAUDE.md).
/// Scans a card's attributes for "unknown" in priority order and returns the
/// ONE follow-up question to ask aloud in Hindi.
///
/// Priority is tuned to the demo script: the rehearsed mother-statement
/// covers clothing/gender/age/name/last-seen but not glasses, so the
/// glasses question ("Kya usne chashma pehna tha?") is the one that fires.
class FollowUp {
  final String field;
  final String questionHindi;
  const FollowUp(this.field, this.questionHindi);
}

const _priority = <FollowUp>[
  FollowUp('clothing_top', 'Usne upar kya pehna tha?'),
  FollowUp('gender', 'Ladka tha ya ladki?'),
  FollowUp('age_range', 'Uski umar kitni hai?'),
  FollowUp('glasses', 'Kya usne chashma pehna tha?'),
  FollowUp('name_response', 'Uska naam kya hai?'),
  FollowUp('last_seen', 'Aakhri baar kahan dekha tha?'),
];

/// Returns the single highest-value gap, or null when the card is good
/// enough to file. ONE question per case — never interrogate a panicked
/// parent (and the spec says one).
FollowUp? nextFollowUp(Map<String, String> attrs, {Set<String>? alreadyAsked}) {
  for (final f in _priority) {
    if (alreadyAsked != null && alreadyAsked.contains(f.field)) continue;
    final v = attrs[f.field];
    if (v == null || v.isEmpty || v == 'unknown') return f;
  }
  return null;
}
