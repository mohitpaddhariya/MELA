# MELA — EXECUTION TASKLIST
**Clock: started 11:32 AM · demo-ready 3:00 PM · submission 5:00 PM**
Team: **Mohit (code)** · **Coder-friend (code)** · **R1 "Pitch Lead"** · **R2 "Producer"**

---

## ⏱ 11:32–11:50 — SETUP SPRINT (everyone, parallel, RIGHT NOW)

- [ ] **Mohit:** create public GitHub repo `mela`, first commit NOW (rule: public repo + proves work done today). `flutter create mela_station`, add `flutter_gemma`, `speech_to_text`, `flutter_tts`, `web_socket_channel`, `hive` (or sqflite).
- [ ] **Coder:** HuggingFace token → start **Gemma 4 E2B `.litertlm` download on BOTH dev phones NOW** (~1.5–2GB, slowest thing today). Also grab it in AI Edge Gallery on Mohit's iPhone (fallback proof).
- [ ] **Mohit:** check **Xcode opens + iPhone connects + free-signing works** with a hello-world run to device. ⚠️ If signing fights you > 20 min → **iOS is CUT**: demo on 2 Androids, iPhone becomes the "google.com fails" prop + camera. Decide by 12:00, no sentiment.
- [ ] **R2:** Android #2 hotspot (data OFF) up, laptop joined, note hub IP. Charge everything; collect cables/stands.
- [ ] **R1:** read IDEA.md fully (it has stats, prior art, Q&A ammo — your raw material).

## ⏱ 11:50–12:30 — SPIKE (kill-or-keep, timeboxed HARD)

- [ ] **Coder:** flutter_gemma on Android: (1) E2B loads + text generation ✅? (2) **image → attribute JSON** ✅? — vision is the only make-or-break. (3) Function calling works? If fiddly → fallback: "reply ONLY with JSON" prompt + **code** checks missing fields and asks the follow-up (still honest, still the agent loop, code-orchestrated).
- [ ] **Decision at 12:30:** vision works → GREEN, continue. Vision dead on both platforms → 🔴 pivot call (Filmy) — but expect green; the runtime is 3 months mature.
- [ ] **Audio decision made NOW, not later:** default = `speech_to_text` package (on-device, supports hi-IN) → Gemma structures the TEXT. Gemma-native audio-in = stretch goal ONLY if ahead at 2 PM.
- [ ] **Mohit (parallel):** app skeleton — 4 screens (Lost Intake / Found Intake / Matches / Board), Card model + Hive persistence, `mela_hub` relay (~100-line Node/Python: HELLO→snapshot, CARD_UPSERT/MATCH_CANDIDATE/RESOLVE broadcast, upsert by `updated_at`).

## ⏱ 12:30–14:00 — CORE BUILD (parallel, interfaces frozen)

**Frozen contract between you two (agree in 5 min, never reopen):** Card JSON schema + the 3 sync message types.

- [ ] **Coder — the AI pipeline:** mic → STT (hi-IN) → Gemma extraction prompt → card JSON; missing-field check → follow-up question (TTS out in Hindi) → card complete. Camera photo → Gemma vision → same attribute JSON. Prompt-tune on real test data from R2.
- [ ] **Mohit — everything around it:** deterministic matcher (field-by-field compare → ✓/✗/unknown table UI), confirm/reject buttons + human-gate flow, outbox queue + WebSocket client + reconnect-snapshot, reunion chirp (TTS), station ID via QR/config. Deploy loop to iPhone as you go (if iOS alive).
- [ ] Commit + push every ~30 min (both).

## ⏱ 14:00–14:30 — INTEGRATION on the real hotspot

- [ ] Full loop: Hindi intake on Station A → card hops → photo on Station B → match table → confirm → chirp on A. Fix ONLY demo-path bugs.
- [ ] Kill-and-revive test: restart app (state survives?) + kill hub (queues? resyncs?).

## ⏱ 14:30–15:00 — REHEARSE ×2, full script, roles locked

Then FREEZE the code. Nothing merges after 15:00 except the video.

---

## 🎤 R1 — PITCH LEAD (11:50 → 15:00)

- [ ] **3-minute script** from IDEA.md §6: hook (Bhule-Bhatke 1946 loudspeaker + 54,000 stat) → live demo beats → close ("intelligence is always local"). Time it with a stopwatch; cut until 2:45.
- [ ] **Q&A drill sheet** (from IDEA.md §8) — especially: "Kumbh 2025 already had AI centres" rebuttal, "why not internet" 4-counter, "what if model hallucinates a match" (deterministic matcher + human gate), "how does it scale" (camps are choke points).
- [ ] **Verify every stat + source link** you'll say aloud; drop anything unsourced. Date discipline: Gemma 4 released April 2; tech report July 7.
- [ ] Rehearse the TEAM at 14:30: who speaks (one voice, R1 or Mohit), who plays the panicked mother (in Hindi — practice the lines!), who runs Station B, who hands the judge the phone.
- [ ] Prep the **judge-participation move**: invite the judge to describe the "lost" teammate themselves / toggle airplane mode with their own hands.

## 🎬 R2 — PRODUCER (11:50 → submission)

- [ ] **Test data:** 5 photos of a teammate in distinctive clothes (red/bright kurta if anyone has one — go buy/borrow!), varied angles/lighting, for Coder's prompt tuning.
- [ ] **Props:** "CAMP A" / "CAMP B" table cards, phone stands, QR code of hub IP, charged power banks.
- [ ] **README.md** for the repo: what it is, the stats table (copy from IDEA.md §1), architecture diagram, what was built TODAY (rules require it), how to run.
- [ ] **14:45–15:15: shoot the 1-minute demo video** (on Mohit's iPhone): google.com fails → Hindi intake → card hops → match table → chirp. One take is fine; real > polished.
- [ ] **15:15: SUBMIT** at cerebralvalley.ai submission page — video uploaded, repo public (double-check in incognito!), demo link if any, **ALL 4 teammates added**. Do not wait until 16:45.
- [ ] Monitor Discord #announcements + #rules for judging-room assignment.

---

## ✂️ CUT LADDER (if behind at 13:30, cut top-down, no debate)
1. Gemma-native audio-in (already defaulted out — STT is fine)
2. Wallboard page (judges can look at the two phones)
3. iOS build (2 Androids demo; iPhone = prop) — cut earlier if signing fought you
4. Thinking-mode/reasoning display
5. Found-intake **camera** → fallback: photo picked from gallery (still Gemma vision!)

## 🔒 NEVER CUT (this IS the project)
Speech→card extraction on-device · follow-up question · ✓/✗ explainable match table · human confirm gate · restart-safe storage · cards syncing between 2 stations · the no-internet proof.

## ⚠️ Standing landmines
- Demo on OWN hotspot only; never venue WiFi.
- Load model ONCE at app start (10–20s), keep session warm.
- Phones plugged in all day; screen-lock off on demo devices.
- If a judge asks anything you didn't build: say so plainly — honesty scored better than bluff all year.
