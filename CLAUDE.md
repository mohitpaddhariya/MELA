# MELA — hackathon build (July 11, 2026). GUARDRAILS — READ FIRST.

**All architecture decisions are FINAL. Do not relitigate, do not suggest pivots, do not gold-plate. Build the demo path.** Full context: `Docs/CONTEXT.md` (decisions) · `Docs/IDEA.md` (pitch/stats) · `Docs/TASKLIST.md` (timeline). Package/API cheat sheets researched from live docs today: `Docs/*.md`.

## What this is
Offline-first lost-and-found for Indian mega-gatherings. Gemma E2B runs ON the phone (flutter_gemma, .litertlm), spoken Hindi → structured card, one follow-up question, deterministic Dart matcher → explainable ✓/✗/unknown table, human always confirms, cards sync over hotspot LAN via a dumb WebSocket hub. Photos/audio NEVER leave the device — only small JSON cards travel.

## Repo layout
- `mela_station/` — the ONE Flutter app (iOS + Android + macOS-for-local-testing).
- `mela_hub/` — ~100-line Node `ws` relay on the laptop (`node server.js`, port 8765). No AI, no authority.
- `Docs/` — all documentation. Never put docs anywhere else.

## Hard clock
Demo-ready **15:00**. 14:00→ integration/rehearsal fixes ONLY. **15:00 code freeze.** Commit + push every ~30 min (repo must stay public — proves work done today).

## FROZEN contracts (never reopen)
Card schema (all fields strings; missing = "unknown"):
```json
{ "id": "A-114", "station": "vol1-iphone", "updated_at": 1752212345,
  "kind": "lost | found", "status": "open | candidate | resolved",
  "age_range": "5-7", "gender": "male", "name_response": "Chotu",
  "clothing_top": "red kurta", "clothing_bottom": "unknown",
  "glasses": "black frame | none | unknown", "hair": "unknown",
  "marks": "unknown", "last_seen": "Ram Ghat", "notes": "" }
```
Sync protocol: `HELLO {station}` → hub replies `SNAPSHOT {cards}`; `CARD_UPSERT {card}`, `MATCH_CANDIDATE {card_id, found_at, fields}`, `RESOLVE {card_id, by}` → hub broadcasts to all. Conflict rule everywhere: keep newer `updated_at` (idempotent). Client rule: **local Hive write first → outbox queue → background flush with retry. Nothing ever blocks on the network.**

## Division of intelligence (the honest agent design)
- Model (Gemma E2B via `GemmaService`): ONLY `text → card JSON` and `image → card JSON`. Never matches, never scores, never controls flow.
- Code (plain Dart): picks the missing field, asks the ONE templated Hindi follow-up, merges the answer, matches field-by-field (✓/✗/unknown — no percentages, ever), and gates everything behind a human Confirm tap.

## Engineering rules
- Working > elegant. Hardcode what won't be seen (station IDs, hub IP fallback) with an override field.
- Load the model ONCE at app start; keep the session warm. E2B only on phones (E4B = laptop/Ollama only).
- No codegen/build_runner (cards = JSON strings in Hive). No state-management framework (setState/ValueNotifier). No new packages beyond pubspec unless something is broken.
- Every AI call has a non-AI fallback on screen: text field beside the mic, gallery pick beside the camera.
- Something fails → documented fallback before debugging >15 min. Do NOT upgrade Flutter/Xcode/packages today.
- Demo on OWN hotspot only (data OFF), never venue WiFi. Phones plugged in, screen-lock off.

## Cut ladder (if behind at 13:30 — cut top-down, no debate)
1. Gemma-native audio-in (already out) → 2. wallboard → 3. iOS build (demo on 2 Androids) → 4. thinking-mode display → 5. live camera (gallery pick still counts).

## NEVER cut (this IS the project)
Speech→card on-device · one follow-up question · explainable ✓/✗ match table · human confirm gate · restart-safe storage · 2 stations syncing · no-internet proof.
