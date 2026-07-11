# MELA — Offline-first Lost & Found for India's mega-gatherings
### Gemma 4 on-device · Google DeepMind Bangalore Hackathon · July 11, 2026

**One-liner:** The Bhule-Bhatke camp has reunited lost pilgrims with the same loudspeaker since 1946. MELA puts that entire lost-and-found centre — intake, matching, reunion — into a volunteer's pocket, running on Gemma 4 **entirely on-device**, no network required.

**Tagline:** *Intelligence is always local. Connectivity is opportunistic.*

---

## 1. The problem — verified numbers (the "survey")

| Stat | Number | Source |
|---|---|---|
| People separated from families at Maha Kumbh 2025 (45 days) | **~50,000–54,000** | [ETV Bharat](https://www.etvbharat.com/en/!state/uttar-pradesh-prayagraj-mahakumbh-2025-missing-persons-reunited-enn25030203144), [OpIndia](https://www.opindia.com/2025/03/over-54000-separated-individuals-were-reunited-with-families-at-maha-kumbh-in-prayagraj/) |
| Lost & reunited on Mauni Amavasya — ONE day | **8,725** | [Business Standard](https://www.business-standard.com/india-news/maha-kumbh-20k-missing-reunite-with-kin-via-digital-lost-and-found-centres-125021500993_1.html) |
| Reunited via the 10 digital centres (full event) | **35,083** | Business Standard (above) |
| Reunited by Bhule-Bhatke / Bharat Seva Kendra camp alone, 2025 | **19,274** (incl. all 18 lost children returned) | search coverage of 2025 event |
| People reunited by the Bhule-Bhatke camp since 1946 | **~15 lakh, incl. 21,000+ children** | [The Better India](https://thebetterindia.com/173394/india-kumbh-mela-lost-children-rescue-help/), [PIB](https://pibindia.wordpress.com/2021/11/23/iffi-52-celebrates-the-humanitarian-spirit-of-raja-ram-tiwari-bhule-bhatke-walon-ka-baba-who-helped-reunite-lakhs-of-lost-pilgrims-with-their-loved-ones/) |
| Camp's daily average / peak-day reunions | **250 / 1,700** | The Better India (above) |
| Who gets lost | **Mostly women & elderly** — least likely to carry smartphones or have recent photos of themselves | ETV Bharat (above) |

Context: Kumbh 2025 drew **~660 million attendees**; cell networks congest/collapse on peak bathing days. The same lost-person problem recurs at Simhastha (Ujjain 2028), Rath Yatra (Puri), Ganesh Visarjan (Mumbai), Sabarimala, and thousands of district-level melas that get zero technology budget.

---

## 2. Prior art — disclose it, then beat it

**Kumbh 2025 already deployed 10 "digital Khoya-Paya Kendras" with AI facial recognition, ML, and multilingual support** ([kumbh.gov.in/en/lostandfound](https://kumbh.gov.in/en/lostandfound)). Never claim "first AI lost-and-found." Claim the gap:

| Kumbh 2025 government system | MELA |
|---|---|
| 10 centralized centres on a 4,000-hectare site | Any volunteer phone is a station — hundreds of intake points |
| Cloud/server face recognition; needs connectivity that collapses at peak snans | Inference runs on the device — airplane mode is the demo |
| Face-matching needs a photo of the lost person; rural families often have none (esp. for elderly women — the majority of cases) | Spoken Hindi description → structured card; works with zero photos |
| Biometric face database of pilgrims | Consented single photo, attribute matching only — explainable, no biometrics stored |
| Bespoke government budget, one mega-event | Commodity Android phones; deployable at any mela by any NGO |

**Killer positioning line:** *"The government validated this problem in 2025 — 54,000 reunions through ten AI centres. We removed the servers, the network, and the face database, and put the whole centre in a volunteer's pocket."*

**Uniqueness, calibrated honestly:** "AI lost-and-found at melas" — not new. **"Offline, on-device, description-based, consent-first, explainable lost-person matching on any volunteer's phone"** — no prior art found anywhere, and it was technically impossible until multimodal models fit on phones — i.e., this year. (Date discipline: **Gemma 4 released April 2, 2026**; the arXiv technical report is July 7. Say "the tech report is a week old", NOT "the model is 4 days old" — a judge will correct you.)

---

## 3. What we build (final shape — post-feedback, honest version)

1. **Lost-report intake:** parent speaks in Hindi (panicked, unstructured) → Gemma 4 on-device converts to a structured search card (age, clothing, name, last-seen).
2. **Agentic slot-filling:** if a field is missing, Gemma asks ONE follow-up out loud: *"Kya usne chashma pehna tha?"* → card updates. (This loop is our special-prize qualification — sense→decide→act→check, not a straight arrow.)
3. **Card stored locally**; survives app close/reopen.
4. **Found-person intake at another station:** volunteer takes ONE consented photo → Gemma extracts the same attributes on-device. Photo never leaves the phone.
5. **Explainable match table** — never a fake confidence %:
   `Red kurta ✓ · Glasses (black) ✓ · Age ~6 ✓ · Trousers ~not in report · ASK: answers to "Chotu"?`
6. **Human gate:** app flags a *candidate*; a volunteer verifies the family before any reunion. No automatic notification, ever.
7. **Opportunistic sync:** stations sync over whatever exists — hotspot LAN, Nearby Connections (only if an Android-native dev is on the team), or internet later. Internet is optional, not forbidden.

**Explicitly NOT building (bluff-free):** crowd-watching cameras · city-scale mesh claims · face recognition · maps · simulated features.

---

## 4. One scenario (use this in the pitch)

2:40 PM, Ujjain Simhastha. Sunita Devi loses 6-year-old Chotu near Ram Ghat; the network shows full bars, nothing loads. At the Bhule-Bhatke camp a volunteer's tablet — airplane mode — listens to her panicked Hindi and builds card #A-114 (male ~6, red kurta, answers to "Chotu"). Gemma asks aloud: "Kya usne chashma pehna tha?" — "Haan, kaala chashma." Card updates and queues for sync. 3:05 PM, 800m away: a tea seller brings a crying boy in a red kurta to Station 3. One consented photo → attributes extracted on-device → match table lights up against #A-114 (kurta ✓ glasses ✓ age ✓). The volunteer says "Chotu?" — the boy looks up. She taps *Confirm candidate*. Station 1 chirps in Hindi: *"Sambhavit milaan — Station 3."* A human makes the final match, like this camp has done since 1946 — in 22 minutes instead of 9 hours. Network used: zero. Data sent to any cloud: zero.

---

## 5. Why it wins

**Rubric math (R1: Creativity 35 / India 25 / Demo 25 / Depth 15):**
- **Creativity 35%:** nobody has pointed on-device multimodal agents at the Bhule-Bhatke camp; the offline/consent/explainable combination has no prior art.
- **India 25%:** 54,000 families per Kumbh; works for every mela that will never get a government AI budget; Hindi-first; elderly-women-without-photos is the exact unserved case.
- **Demo 25%:** airplane mode toggled on stage; Hindi voice → card in seconds; explainable match table; Hindi reunion chirp; optional kill-and-revive a station to show state resync.
- **Depth 15% (our weakest line — buy it back visibly):** on-device audio+vision on a 4-day-old model, agentic follow-up loop, restart-safe state, offline sync. Show the Android phone running Gemma 4 E2B on stage.

**Gemma 4 Special Prize ($2000) — near checklist fit:** state held across a task (synced cards) ✓ · recovery when the plan breaks (station dies → resyncs) ✓ · clear human-deferral boundaries (volunteer gate) ✓ · not a single straight arrow (follow-up question loop) ✓ · offline-first for connectivity-dead contexts ✓. Most teams will chase cloud APIs; the Gemma field will be thin. **We compete in BOTH prize pools.**

**Zeitgeist:** HN's current obsession is exactly this — local, private AI (GLM-on-a-slow-computer at 819 pts, Mac Mini on-device demand, Cactus v2's local-first pattern). We're among the first builds anywhere on Gemma 4.

**Vs. the other ideas we considered:**
- *Raksha (video-call scam guardian):* hottest news hook but crowded theme risk + Truecaller/Pixel/Savi incumbents + fragile live staging.
- *Filmy (cast judges in a live AI movie):* maximum spectacle, but hostage to Omni Flash latency and thin on India impact. **Remains our pivot if the Gemma spike fails.**
- *Street-vendor storefront (NB2 Lite):* joyful, but it's literally the sample use case in the problem statement.
- *Contour-style 3D terrain:* already won 2nd at this same hackathon tour — seen by these judges; DQ-adjacent.
- *Insurance referee / dark-pattern auditor:* enterprise-tool energy; live APAC events this year were won by human moments.

---

## 6. 3-minute demo script

1. **0:00** — "660 million people. The network collapses daily. This camp has used the same loudspeaker since 1946." *Toggle airplane mode on every device, on camera.*
2. **0:30** — Teammate-as-mother speaks panicked Hindi → card materializes → Gemma asks the glasses question aloud → card completes.
3. **1:15** — "Found child" brought to station 2 → one consented photo → **explainable match table** on screen. "The system explains itself. It never auto-decides."
4. **2:00** — Volunteer confirms → station 1 chirps in Hindi. Optional: kill station 2's power, revive, show resync.
5. **2:30** — Close: *"Intelligence is always local. Connectivity is opportunistic. The loudspeaker just got a brain — and it fits in a pocket."* Hold up the phone running Gemma 4 E2B.

---

## 7. Build architecture & plan (10:30 → 17:00)

### Architecture — ONE Flutter app on all phones (the "not a toy" version)
- **`mela_station` (Flutter, single codebase → Mohit's iPhone 16 + friends' Androids):**
  - [flutter_gemma](https://pub.dev/packages/flutter_gemma) runs **Gemma 4 E2B on-device** (vision + audio + function calling + thinking mode; Metal GPU on iPhone, `.litertlm` format). See [Android vs iOS reality check](https://dev.to/devpicon/gemma-4-e2b-on-mobile-android-vs-ios-reality-1-38lm) for gotchas.
  - Screens: Lost Intake (mic → card) · Found Intake (consented camera photo → attributes) · Matches (explainable ✓/✗ table, confirm/reject) · Card Board.
  - **Agent loop via real function calling:** model calls `create_card({...})` / `ask_followup("...")` until the card is complete — this is the Gemma-prize qualification, implemented as tool calls.
  - **Matching = deterministic Dart code, NOT the model.** Gemma extracts attributes; code compares field-by-field into the ✓/✗ table; humans confirm. (Q&A answer for "what if the model hallucinates a match?")
  - Audio ladder: Gemma 4 audio-in for Hindi → if flaky, platform offline ASR → Gemma structures text. Both fully local.
  - SQLite/Hive persistence — restart-safe (demo beat).
- **`mela_hub` (~100-line Node/Python on a laptop):** WebSocket relay over the hotspot — `CARD_UPSERT / MATCH_CANDIDATE / RESOLVE`, full-state snapshot on reconnect (kill-and-revive beat), + read-only **wallboard page** so judges watch cards hop between phones. Optionally Ollama [`gemma4:e4b`](https://ollama.com/library/gemma4:e4b) (9.6GB, ~4.5GB RAM) as a "camp desk" station.
- **Android #2:** hotspot, mobile data OFF = the offline LAN. Staging: skip airplane-mode gymnastics — show google.com failing on the iPhone, then the system working anyway.

### Team split (4)
- **Mohit (Mac + iPhone):** Flutter scaffold, screens, iOS signing/deploy (**check Xcode is installed FIRST — giant download, #1 silent killer**; free Apple ID signing = 7 days). Owns the demo.
- **Friend A (best Android):** flutter_gemma integration — model manager, E2B load, vision, function calling, Hindi extraction prompts.
- **Friend B:** hub + sync protocol + persistence + wallboard.
- **Friend C:** offline Hindi TTS, test data (photos of teammate in red kurta), README, submission video, props.

### Timeline
- **Pre-kickoff (doors 9:00):** Xcode check · `ollama pull gemma4:e4b` · Gemma 4 E2B into AI Edge Gallery on BOTH phones (backup proof) · `flutter create` + flutter_gemma hello-world · HuggingFace token + `.litertlm` E2B download.
- **10:30–11:30 GO/NO-GO spike:** E2B text → vision → audio, on both platforms. Cut in reverse order (audio first). Vision dead on BOTH platforms → pivot to Filmy.
- **11:30–14:00:** parallel build per split. **14:00–15:00:** integrate + full rehearsal.
- **15:00 hard stop:** 1-min video, repo public, all teammates added ([submit](https://cerebralvalley.ai/e/google-deepmind-bangalore-hackathon/hackathon/submit)).
- **Cut order if behind:** audio-in → thinking-mode display → wallboard → E4B camp-desk. NEVER cut: function-calling loop, match table, human gate, restart persistence.

### Judge staging (Round 1 — they come to your table)
iPhone on stand = "Camp A", Android = "Camp B", wallboard laptop between, hotspot data off. google.com fails on camera → teammate speaks panicked Hindi → card hops → consented photo → ✓/✗ table → Hindi reunion chirp. Then the winner move: **hand the judge the phone and let them describe the "lost" teammate themselves.**

## 8. Q&A ammo

- *"Kumbh 2025 already had AI lost-and-found?"* — Yes, 10 centralized face-rec centres needing servers + connectivity + a photo database. We remove all three; see §2 table.
- *"Why not face recognition?"* — Majority of lost persons are elderly women with no recent photo anywhere; descriptions are the only universal input. Also: consent, explainability, no biometric database to leak.
- *"How does it scale beyond your stations?"* — It doesn't need to blanket the mela; lost people already converge at camps and police booths. We multiply intake points from 10 to every volunteer's phone.
- *"What if Gemma extracts wrong attributes?"* — Every match is a candidate with visible reasoning; a human confirms. The agent defers — that's the design, not a limitation.
- *"Why now?"* — Multimodal models that fit on phones. Gemma 4's report is four days old. This project was impossible last week.

## 9. Rules compliance

- Public repo from first commit · demo only what we built today · not a RAG app / dashboard / image analyzer / education chatbot (it's an agent loop with a human gate) · no medical advice · AI-generated content labeled where applicable.
