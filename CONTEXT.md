# CONTEXT.md — MELA build handoff
**READ THIS FIRST. You are Claude Code helping build a hackathon project under extreme time pressure. All decisions below are FINAL — do not relitigate them, do not suggest pivots, do not gold-plate. Build the demo path.**

> Tip: copy this file into the repo root as `CLAUDE.md` so it auto-loads every session.

## Situation
- **Event:** Google DeepMind Bangalore Hackathon (Cerebral Valley), TODAY July 11 2026, WeWork Marathahalli.
- **Clock:** coding started ~11:45 AM. Demo-ready **3:00 PM**. Video + submission by ~15:15. Absolute submission deadline 5:00 PM.
- **Team:** Mohit + 1 coder (this laptop pair-codes with you). 2 non-coding friends handle pitch/props/video/submission.
- **Judging:** Creativity 35% · Impact in India 25% · Live Demo 25% · Technical Depth 15%. Also targeting the **"Best Use of Gemma 4 — Local-First Agents" special prize ($2000)**: requires on-device inference, state across a task, error recovery, explicit human-deferral boundaries, "not a single straight arrow input→output".
- **Rules:** repo must be PUBLIC (commit early/often — proves work done today). Banned: RAG apps, dashboards-as-main-feature, image analyzers, Streamlit, education/medical-advice chatbots. We comply: this is an agent loop with a human gate.

## The project: MELA — offline-first lost-and-found for Indian mega-gatherings
At Kumbh 2025, ~54,000 people (mostly women/elderly) were separated from families; 8,725 on one peak day; cell networks collapse from congestion exactly on those days. The Bhule-Bhatke camp has done this job with a loudspeaker since 1946 (~15 lakh reunited). Kumbh 2025's govt fix = 10 centralized AI face-recognition centres needing servers + connectivity. **MELA puts the whole lost-and-found centre on volunteers' phones: Gemma 4 E2B runs ON the phone, works with zero internet, matches by spoken description (not biometrics), and a human always confirms.**

Tagline: **"Intelligence is always local. Connectivity is opportunistic."**

### The flow (one case)
1. Panicked parent speaks Hindi at Station A → on-device STT → **Gemma 4 E2B (on-device) extracts a structured card**.
2. Missing field → app asks ONE follow-up aloud in Hindi ("Kya usne chashma pehna tha?") → card completes. *(This loop = special-prize qualification.)*
3. Card saved locally (restart-safe), queued, synced to other stations via hub.
4. Found child brought to Station B → volunteer takes ONE consented photo → **Gemma vision extracts the same attributes on that phone**. Photo/audio NEVER leave the device — only the small JSON card travels.
5. **Deterministic Dart code** (NOT the model) compares fields → explainable ✓/✗/unknown match table. No fake confidence %.
6. Volunteer taps confirm (human gate — nothing is ever automatic) → Station A plays Hindi TTS: "Sambhavit milaan — Station B."

## Architecture (FINAL)
- **`mela_station`** — ONE Flutter app, deployed to Mohit's iPhone 16 + friends' Androids.
  - On-device LLM: **`flutter_gemma` package + Gemma 4 E2B `.litertlm`** (supports vision, function calling, thinking mode; Metal GPU on iOS, GPU/NPU on Android). Load model ONCE at app start (~10–20s), keep session warm forever.
  - Speech: **`speech_to_text` package, locale hi-IN, on-device** → Gemma structures the TEXT. (Gemma-native audio-in = stretch goal ONLY if ahead of schedule.) TTS out: `flutter_tts` Hindi.
  - Persistence: Hive (or sqflite) — must survive app kill/restart.
  - Screens: Lost Intake · Found Intake · Matches (✓/✗ table + Confirm/Reject) · Card Board (+ sync status indicator).
- **`mela_hub`** — ~100-line Node or Python WebSocket relay on a laptop. No AI, no authority — a message passer with a log + optional read-only wallboard HTML page.
- **Network:** Android phone's hotspot, mobile data OFF (= LAN with no internet). Hub IP shared via QR. Demo beat: google.com fails on camera, system works anyway.

## Card schema (FROZEN — do not extend)
```json
{ "id": "A-114", "station": "vol1-iphone", "updated_at": 1752212345,
  "kind": "lost | found", "status": "open | candidate | resolved",
  "age_range": "5-7", "gender": "male", "name_response": "Chotu",
  "clothing_top": "red kurta", "clothing_bottom": "unknown",
  "glasses": "black frame | none | unknown", "hair": "unknown",
  "marks": "unknown", "last_seen": "Ram Ghat", "notes": "" }
```

## Sync protocol (FROZEN)
- `HELLO {station}` → hub replies `SNAPSHOT {cards: [...]}` (full state — this is how dead stations recover).
- `CARD_UPSERT {card}` → hub broadcasts to all. Receivers keep whichever version has newer `updated_at` (idempotent — safe to receive twice/out of order).
- `MATCH_CANDIDATE {card_id, found_at, fields:{kurta:"match",...}}` → broadcast.
- `RESOLVE {card_id, by}` → broadcast.
- Client rule: **write to local DB first, then outbox queue, background flush with retry.** Nothing ever blocks on the network.

## Gemma usage
- Extraction prompt: "You are helping at a lost-and-found camp. From this parent's statement, return ONLY JSON matching this schema... unknown fields = 'unknown'." Try flutter_gemma function calling first; if fiddly, JSON-only prompt + code-side parsing is the approved fallback.
- Follow-up loop: CODE finds the highest-value "unknown" field → asks one templated Hindi question → re-extract. (Model extracts; code orchestrates; that's the honest agent design.)
- Vision prompt: same schema from a photo. Test with team-provided photos (teammate in bright kurta).
- **Matcher is plain Dart:** field-by-field equal/fuzzy/unknown → table rows. The model NEVER decides a match.

## Cut ladder (if behind at 13:30, cut top-down, no debate)
1. Gemma-native audio-in (already out) → 2. wallboard → 3. iOS build (demo on 2 Androids; iPhone becomes no-internet prop — cut iOS EARLY if free-signing fights >20 min) → 4. thinking-mode display → 5. live camera (gallery-picked photo still counts, still Gemma vision).

## NEVER cut (this IS the project)
Speech→card on-device · one follow-up question · explainable ✓/✗ match table · human confirm gate · restart-safe storage · 2 stations syncing · no-internet proof.

## Landmines
- Load `.litertlm` once; never per-request. E2B only on phones (E4B needs Pro-Max-class).
- Own hotspot ONLY, never venue WiFi. Phones plugged in, screen-lock off.
- iOS: free Apple-ID signing (7-day cert) via Xcode; if it fights, invoke cut ladder #3.
- Commit + push every ~30 min. Repo public from first commit.
- Date discipline for pitch: Gemma 4 released Apr 2 2026; tech report Jul 7. Kumbh 2025 already had 10 AI face-rec centres — our wedge is on-device/offline/description-based/consent-first (never claim "first AI lost-and-found").

## How to help (you, Claude Code)
- Bias to WORKING over elegant. Demo path first. Hardcode what won't be seen (station IDs, hub IP fallback).
- Small steps, runnable after each. No new packages beyond listed unless something is broken.
- When something fails, try the documented fallback before debugging >15 min.
- At 14:00 the only acceptable activity is integration + rehearsal fixes; at 15:00 code freeze.
- Demo script beats (for testing end-to-end): google.com fails → Hindi intake on A → follow-up question → card hops to B → photo → ✓/✗ table → confirm → Hindi chirp on A → kill & revive a station to show resync.
