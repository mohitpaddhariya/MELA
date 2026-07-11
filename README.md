# MELA 🪔 — Offline-First Lost & Found for India's Mega-Gatherings

> *"Intelligence is always local. Connectivity is opportunistic."*

Built at the **Google DeepMind Bangalore Hackathon · July 11, 2026**

---

## The Problem

At Maha Kumbh 2025, **~54,000 people** — mostly women and elderly — were separated from their families. On the busiest bathing day alone, **8,725** people were reported missing. Cell networks collapse from congestion precisely on those peak days.

The Bhule-Bhatke camp has reunited lost pilgrims with the same loudspeaker since **1946** (~15 lakh reunited, including 21,000+ children). MELA gives that loudspeaker a brain — one that fits in a volunteer's pocket.

---

## What MELA Does

MELA turns any volunteer's phone into a fully functional lost-and-found station — **no internet required**.

1. 🎙️ **Lost-report intake** — A panicked parent speaks in Hindi. Gemma 4 E2B (running entirely on-device) converts unstructured speech into a structured card: age, clothing, name, last-seen location.
2. 🤖 **Agentic slot-filling** — If a field is missing, the app asks exactly **one follow-up question** aloud in Hindi: *"Kya usne chashma pehna tha?"* → card updates. This loop is genuine agentic behaviour: sense → decide → act → check.
3. 💾 **Restart-safe storage** — Cards are persisted locally (Hive). The app survives being killed or the phone rebooting mid-demo.
4. 📷 **Found-person intake** — A volunteer takes one consented photo at another station. Gemma vision extracts the same attributes on that device. **Photos and audio never leave the phone** — only small JSON cards travel.
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
mela_station/ (Flutter — iOS + Android)
│
├── Gemma 4 E2B on-device (flutter_gemma, .litertlm)
│     ├── text → structured card JSON (function calling)
│     └── image → structured card JSON (vision)
│
├── Deterministic Dart matcher (field-by-field ✓/✗ table)
├── Hive persistence (restart-safe)
├── speech_to_text hi-IN + flutter_tts Hindi
└── WebSocket client → outbox queue → background sync

mela_hub/ (Node.js — ~100 lines, runs on a laptop)
│
└── Dumb WebSocket relay. No AI, no authority.
      HELLO → SNAPSHOT (full state, enables kill-and-revive)
      CARD_UPSERT → broadcast (keep newer updated_at)
      MATCH_CANDIDATE → broadcast
      RESOLVE → broadcast
```

Network topology: Android hotspot, mobile data OFF. Hub IP shared via QR. `google.com` fails; MELA works anyway.

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
| Mobile app | Flutter (iOS + Android, single codebase) |
| On-device LLM | Gemma 4 E2B via `flutter_gemma` (`.litertlm`, Metal/GPU) |
| Speech input | `speech_to_text` (hi-IN, fully offline) |
| Speech output | `flutter_tts` (Hindi) |
| Local storage | Hive (no codegen, no build_runner) |
| Sync relay | Node.js `ws` WebSocket hub |
| Network | Local hotspot LAN — no internet |

---

## Running Locally

### Hub (laptop)
```bash
cd mela_hub
npm install
node server.js
# Listening on ws://0.0.0.0:8765
# LAN IP: ipconfig getifaddr en0
```

### Flutter App
```bash
cd mela_station
# Place Gemma 4 E2B .litertlm model in the correct path (see download_model.sh)
bash ../download_model.sh
flutter run
```

Set the hub IP in the app's settings screen (or edit the fallback constant before building).

---

## Model Download

```bash
bash download_model.sh
```

Requires a HuggingFace token with access to the Gemma 4 E2B model. The `.litertlm` file is loaded once at app start (~10–20 s warm-up) and kept in session for the duration.

---

## Repo Layout

```
MELA/
├── mela_station/   Flutter app (iOS + Android + macOS for local testing)
├── mela_hub/       Node.js WebSocket relay (server.js, ~100 lines)
├── Docs/           All documentation — context, idea, tasklist, API notes
├── download_model.sh
└── CLAUDE.md       Build guardrails (read before touching anything)
```

---

## Design Principles

- **Working > elegant.** Demo path ships; gold-plating doesn't.
- **Model extracts. Code decides.** Gemma converts speech/photos to structured data. Plain Dart does field comparison. The model never matches, never scores, never controls flow.
- **Local write first, network second.** Every card is written to Hive before touching the WebSocket. Outbox queue with retry — nothing ever blocks on the network.
- **Human always confirms.** Candidates are surfaced, never acted upon automatically. The agent defers — that's the design, not a limitation.
- **Privacy by architecture.** Photos and audio live only on the phone that captured them. Only small JSON cards travel over the wire.

---

## Live Demo Scenario

> 2:40 PM, Ujjain Simhastha. Sunita Devi loses 6-year-old Chotu near Ram Ghat; full bars, nothing loads. A volunteer's tablet — airplane mode — listens to her panicked Hindi and builds card #A-114 (male ~6, red kurta, answers to "Chotu"). Gemma asks aloud: *"Kya usne chashma pehna tha?"* — *"Haan, kaala chashma."* Card queues for sync.
>
> 3:05 PM, 800m away: a tea seller brings a crying boy in a red kurta to Station 3. One consented photo → attributes extracted on-device → match table: kurta ✓ glasses ✓ age ✓. The volunteer says "Chotu?" — the boy looks up. She taps **Confirm candidate**. Station 1 chirps in Hindi: *"Sambhavit milaan — Station 3."*
>
> **Network used: zero. Data sent to any cloud: zero. Time: 22 minutes instead of 9 hours.**

---

## Rules Compliance

- Repo public from first commit — all work done on the day is provable.
- Not a RAG app, dashboard, image analyzer, or education chatbot — this is an agent loop with a human gate.
- No medical advice. No biometric database. Consented single photo only.
- AI-generated content labeled where applicable.

---

*Built in one day. The loudspeaker just got a brain.*
