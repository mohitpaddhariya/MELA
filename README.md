# MELA 🪔 — Offline-First Lost & Found for India's Mega-Gatherings

> *"Intelligence is always local. Connectivity is opportunistic."*

Built at the **Google DeepMind Bangalore Hackathon · July 11, 2026** — the commit history is the build log.

---

## The Problem

At Maha Kumbh 2025, **~54,000 people** — mostly women and elderly — were separated from their families. On the busiest bathing day alone, **8,725** people were reported missing. Cell networks collapse from congestion precisely on those peak days.

The Bhule-Bhatke camp has reunited lost pilgrims with the same loudspeaker since **1946** (~15 lakh reunited, including 21,000+ children). MELA gives that loudspeaker a brain — one that fits in a volunteer's pocket.

---

## What MELA Does

MELA turns any volunteer's phone into a fully functional lost-and-found station — **no internet required**.

1. 🎙️ **Lost-report intake** — A panicked parent speaks in Hindi. Gemma 4 E2B (running entirely on-device) converts unstructured speech into a structured card: age, clothing, name, last-seen location.
2. 🤖 **Agentic slot-filling** — If a field is missing, the app asks exactly **one follow-up question** aloud in Hindi: *"Kya usne chashma pehna tha?"* → card updates. Sense → decide → act → check: the model extracts, deterministic code decides what to ask.
3. 💾 **Restart-safe storage** — Cards, sync queue, and station identity are persisted locally (Hive). The app survives being killed or the phone rebooting mid-demo.
4. 📷 **Found-person intake** — A volunteer takes one consented photo at another station; Gemma vision extracts the same attributes on that device. The volunteer can also just *describe* the person by voice — same pipeline. **Photos and audio never leave the phone** — only small JSON cards travel.
5. ✅ **Explainable match table** — Deterministic Dart code (never the model) compares fields and renders a human-readable ✓ / ✗ / unknown table. No fake confidence percentages — ever.
6. 👤 **Human gate** — The app surfaces a *candidate*; a human volunteer verifies and confirms. Nothing is ever automatic.
7. 📡 **Opportunistic sync** — Stations sync over a local hotspot LAN via a lightweight WebSocket hub. Internet is optional, not required.

---

## Why Not Face Recognition?

The majority of lost persons at melas are **elderly women with no recent photo anywhere**. A spoken description is the only universal input. MELA uses attribute matching only — no biometric database, full consent, fully explainable.

Kumbh 2025's government system used 10 centralized AI face-recognition centres requiring servers, connectivity, and a photo database. MELA removes all three.

---

## Architecture

```
mela_station/ (Flutter — Android is the full station; iOS/macOS run the text path)
│
├── Gemma 4 E2B on-device (flutter_gemma 1.2.0 + LiteRT-LM engine, .litertlm)
│     ├── Hindi text  → structured card JSON (schema-prompted extraction)
│     └── photo       → structured card JSON (vision — Android GPU)
│
├── Deterministic Dart matcher (field-by-field ✓/✗/unknown table)
├── Hive persistence (cards, outbox, settings — restart-safe)
├── speech_to_text hi-IN (offline-first, self-healing) + flutter_tts Hindi
└── WebSocket client → persistent outbox queue → background sync
      └── brain badge on the Board: MOCK / GEMMA 4 loading… / GEMMA 4 on-device

mela_hub/ (Node.js — ~100 lines, runs on a laptop)
│
└── Dumb WebSocket relay. No AI, no authority.
      HELLO → SNAPSHOT (full state, enables kill-and-revive)
      CARD_UPSERT → broadcast (keep newer updated_at, idempotent)
      MATCH_CANDIDATE → broadcast
      RESOLVE → broadcast
```

Network topology: phone hotspot, mobile data OFF. `google.com` fails; MELA works anyway.

---

## Card Schema

```json
{
  "id": "A-114",
  "station": "vol1-iphone",
  "updated_at": 1752212345,
  "kind": "lost | found",
  "status": "open | candidate | resolved",
  "age_range": "5-7",
  "gender": "male",
  "name_response": "Chotu",
  "clothing_top": "red kurta",
  "clothing_bottom": "unknown",
  "glasses": "black frame | none | unknown",
  "hair": "unknown",
  "marks": "unknown",
  "last_seen": "Ram Ghat",
  "notes": ""
}
```

All fields are strings. Missing = `"unknown"`. Schema is frozen — the hub and all stations share it.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter ≥ 3.44 (Dart ≥ 3.12), single codebase |
| On-device LLM | Gemma 4 E2B via `flutter_gemma 1.2.0` + `flutter_gemma_litertlm` (2.4GB `.litertlm`, GPU) |
| Speech input | `speech_to_text` hi-IN — offline-first, auto-falls back online if the Hindi pack is missing |
| Speech output | `flutter_tts` (Hindi) |
| Local storage | Hive (no codegen, no build_runner) |
| Sync relay | Node.js `ws` WebSocket hub |
| Network | Local hotspot LAN — no internet |

---

## Running Locally

### 1. Hub (laptop)
```bash
cd mela_hub
npm install
node server.js
# Listening on ws://0.0.0.0:8765 — LAN IP: ipconfig getifaddr en0
```

### 2. Model (2.4GB, Apache-2.0, **ungated — no token needed**)
```bash
curl -LO https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
```

### 3. App
```bash
cd mela_station
flutter pub get
flutter run          # pick your Android device
```

### 4. Sideload the model (after the app's first launch)
```bash
adb push gemma-4-E2B-it.litertlm /sdcard/Android/data/com.mela.mela_station/files/
```
Restart the app — it auto-detects the model and switches from the mock brain to real Gemma (watch the Board badge). Model loads once at startup (~10–20s) and stays warm.

**Per-station setup:** Board → ⚙️ → Station ID (A/B/…) + Hub URL. For fully-offline Hindi speech: Settings → System → Languages → On-device speech recognition → install Hindi (once per phone).

---

## Battle Scars (all from build day — see `Docs/flutter_gemma.md`)

- **Gemma 4 vision needs the 1.x runtime.** flutter_gemma 0.13.x rejects its vision encoder ("must have exactly one signature but got 3") on every platform. Mid-hackathon Flutter upgrade to Dart 3.12 unlocked it.
- **Backend ladder:** GPU+vision → CPU+vision → text-only → mock. A flaky GPU driver degrades the brain, never crashes the app.
- **Scoped storage:** the model must live in the **app-created** external-files dir; a shell-created dir is invisible to the app (FUSE ownership).
- **Sync never lies:** write-local-first + persistent outbox, flushed only after the WebSocket handshake provably completes (`web_socket_channel` silently discards writes on dead sockets).
- **No NTP on a hotspot:** per-card monotonic `updated_at` stamps so a slow phone clock can't un-confirm a volunteer's tap.

---

## Design Principles

- **Working > elegant.** Demo path ships; gold-plating doesn't.
- **Model extracts. Code decides.** Gemma converts speech/photos to structured data. Plain Dart does field comparison. The model never matches, never scores, never controls flow.
- **Local write first, network second.** Every card is written to Hive before touching the WebSocket. Outbox queue with retry — nothing ever blocks on the network.
- **Human always confirms.** Candidates are surfaced, never acted upon automatically. The agent defers — that's the design, not a limitation.
- **Privacy by architecture.** Photos and audio live only on the phone that captured them. Only small JSON cards travel over the wire.

---

## Live Demo Scenario

> 2:40 PM, Ujjain Simhastha. Sunita Devi loses 6-year-old Chotu near Ram Ghat; full bars, nothing loads. A volunteer's phone — airplane mode — listens to her panicked Hindi and builds card #A-114 (male ~6, red kurta, answers to "Chotu"). Gemma asks aloud: *"Kya usne chashma pehna tha?"* — *"Haan, kaala chashma."* Card queues for sync.
>
> 3:05 PM, 800m away: a tea seller brings a crying boy in a red kurta to Station 3. One consented photo → attributes extracted on-device → match table: kurta ✓ glasses ✓ age ✓. The volunteer says "Chotu?" — the boy looks up. She taps **Confirm candidate**. Station 1 chirps in Hindi: *"Sambhavit milaan — Station 3."*
>
> **Network used: zero. Data sent to any cloud: zero. Time: 22 minutes instead of 9 hours.**

---

## Repo Layout

```
MELA/
├── mela_station/   Flutter app (Android full station; iOS/macOS text path)
├── mela_hub/       Node.js WebSocket relay (server.js, ~100 lines)
├── Docs/           Context, idea, tasklist + API cheat sheets earned today
├── models/         Model file lives here locally (gitignored)
└── CLAUDE.md       Build guardrails (read before touching anything)
```

---

## Rules Compliance

- Public repo — all work done on the day is provable via commit history.
- Not a RAG app, dashboard, image analyzer, or education chatbot — this is an agent loop with a human gate.
- No medical advice. No biometric database. Consented single photo only.
- AI-generated content labeled where applicable.

---

## Team

Built at WeWork Marathahalli by Mohit Paddhariya, Amitesh & team — with Claude Code pair-driving the build.

*Built in one day. The loudspeaker just got a brain.*
