# Cultural Heritage Quest — Story-Led Walking Quests for Travelers

*Working title. Platform: native iOS (Swift). Status: DRAFT — requirements only.*

---

## Problem

First-time travelers stand in front of genuinely significant heritage sites and feel nothing, because nobody tells them what happened there. Plaques are sparse, online sources are generic and untrusted, and human guides are either unavailable or incompatible with travelers who prefer to explore on their own. The visit collapses into a photo checklist.

The cost of leaving this unsolved: heritage sites keep being consumed as backdrops rather than places, travelers leave with photos and no memory, and the intangible context that gives these sites meaning — the stories, the lineages, the events — stays locked in local knowledge that never reaches the visitor.

## Evidence

- Design-thinking research: interviews with domestic + international tourists, plus a storyteller from Kultara (Sanur) and a guided cultural tour.
- Two problems recurred consistently across interviews:
  1. "I know it's historic, but I don't know the story" — visits feel flat.
  2. Information is fragmented and low-trust — sparse plaques, generic web sources, guides not always available or wanted.
- Route feasibility for the Denpasar candidate is validated by real-world precedent: the same checkpoint sequence was walked by a local cultural-tour community (B-PART, 2025).
- **Assumption — needs validation via prototype:** that a *connected* narrative across checkpoints produces better recall and completion than the same lore delivered as standalone site entries. This is the core product bet and is currently untested.

## Users

**Primary — The Cultural Explorer.** A traveler (domestic or international) visiting an area for the first time, with active interest in culture and history, comfortable exploring independently with a phone rather than depending on a human guide. Triggered when they have a free half-day and are physically in or near the heritage district.

**Not for:**
- Package-tour participants with a guide already assigned (need is already met)
- Transit travelers with under one day in the area (no time for a 1.5–2 hour walk)
- Local residents (different motivation — this is a first-visit product)
- Travelers with limited mobility, for the 2–3 km walking format (see Accessibility in Risks)
- Casual tourists with no interest in history — heritage exposure is incidental for them, and the product's cost is attention

## Hypothesis

We believe **a linear, story-connected walking quest — where each checkpoint is a layer of time leading to one historical climax** — will make first-time visitors **finish the visit and remember what happened there**, for **culturally curious independent travelers**.

We'll know we're right when **at least 40% of started quests reach the final checkpoint, and at least 70% of finishers can retell the quest's narrative arc unprompted in a one-question post-quest survey.**

The second number is the one that actually tests the differentiation. Completion alone can be bought with gamification; recall cannot.

## Success Metrics

| Metric | Target (v1) | How measured |
|---|---|---|
| **Quest completion rate** (start → final checkpoint) | ≥ 40% | In-app event: quest_started → quest_completed |
| **Narrative recall** (primary hypothesis test) | ≥ 70% of finishers give a coherent retelling | 1-question free-text survey on completion screen, manually coded |
| Checkpoint drop-off | No single checkpoint loses > 25% of arrivals | Per-checkpoint arrival vs departure events |
| Median time-on-checkpoint | ≥ 90 seconds | Lore screen dwell time (proxy for "actually read it") |
| Share rate | ≥ 25% of completions | share_sheet_presented / quest_completed |
| GPS-gate failure rate | ≤ 10% of checkpoint arrivals require manual override | manual_override_used / checkpoint_arrival |
| Draft resume rate | ≥ 30% of abandoned quests resumed within 7 days | quest_resumed / quest_abandoned |

All targets are first-guess baselines, not commitments. Their purpose is to force a verdict at end of v1, not to be hit exactly.

---

## Principles

Durable constraints that outlive any single release. A later milestone may not quietly violate these.

**Offline-first, permanently.** The device is the source of truth. Every core experience — browsing, previewing, starting, walking, completing, and summarizing a quest — must work with the radio off. Network is an enhancement that adds sync, fresh content, and sharing; it is never a precondition for the walk.

In v1 this is trivially true, because there is no backend at all: content is bundled, storage is local, there is no account. The principle exists for what comes after:

- **v2 (accounts + sync)**: writes land locally first and reconcile later. A journal entry written in a dead zone is not "pending" — it is saved. Sync is a background reconciliation, and conflicts resolve in favor of the device that wrote the content.
- **v3 (CMS / content API)**: this is where offline-first is most likely to be lost by accident. Fetched quest content must be durably cached and versioned, usable while stale, and refreshed opportunistically. A quest the user has downloaded stays playable forever, regardless of backend availability. **Never block a quest start on a network call.**

There is no branch on connectivity. The app does not ask whether it is online and then choose a path — it always writes locally, and a separate opportunistic process syncs when it can. Reachability is unreliable (captive portals report success, one bar reports connected), and a connectivity branch means two code paths where the offline one is the less-tested one.

**Content version is pinned at quest start.** An in-progress quest keeps the content snapshot it began with. If the content team corrects a lore passage while a user is standing at checkpoint 3, the story must not change underneath them, and the final recap must match what they actually read. Content updates take effect on the next quest, never the current one.

Two consequences that are easy to miss:

- **Telemetry queues locally.** Analytics events and the post-quest recall survey are captured on-device and flushed when connectivity returns. The recall survey is answered at the final checkpoint — often the worst-signal moment of the whole quest — and it is the primary instrument for the core hypothesis. Losing it to a failed POST would silently destroy the thing v1 exists to measure.
- **Share cards compose on-device.** The summary image is generated locally from local photos, and is savable to Photos with no network. Only the act of posting requires connectivity, and that is the OS share sheet's concern.

**Sacred sites are not content.** Consent from the managing community is a precondition for shipping a site, not a courtesy. Mechanics inside active places of worship stay quiet and contemplative. This constraint outranks engagement metrics.

**Claims carry their epistemic status.** Documented history and oral tradition are both worth telling and are never presented as the same kind of thing.

---

## Scope

### MVP (v1) — the minimum to test the hypothesis

**Content**
- **2 quest routes**, both fully field-validated and community-consented. Specific routes TBD — the Denpasar ("Jejak Terakhir Badung") and Ubud ("Siklus Ubud") drafts are the leading candidates but are not locked.
- Each quest: 5 checkpoints, 2–3 km, 1 start / 3 middle / 1 finish.
- **Bilingual (Indonesian + English)** — the primary persona explicitly includes international travelers; a Bali heritage app without English fails half its users. Adds ~30% to content production time; accepted.
- Every lore claim carries an accuracy label: `[Tercatat]` (documented) vs `[Babad/Cerita rakyat]` (legend/oral tradition), with visible source attribution.

**Core loop**
- Quest browsing and full preview **from anywhere** — including from a hotel room, before travel. Location is a gate on *starting*, never on *discovering*.
- Quest preview shows: opening lore hook, route map with checkpoint pins, total distance, pure walking time, realistic total duration, **estimated out-of-pocket cost** (entry tickets, etc.), terrain/steps note, recommended start-time window, and a pedestrian-safety notice.
- **Start gate**: a quest can only be started from inside the start radius. Everywhere else, preview is the only available action. GPS radius on checkpoint 1, with a **manual "I'm here" override** available after a 60-second timeout, flagged as low-confidence and requiring the user to confirm which place they are standing at.
- **Quest proximity alert** — opt-in, default off. Background region monitoring on quest start points only; walking into one produces a local notification, which the system forwards to a paired Apple Watch as a haptic. This is the discovery path for travelers who did not plan the walk: phone stays pocketed, wrist buzzes, they look. No watchOS app required, and the product is complete without a watch.
- **Offline prefetch on Start**: all lore text and images are resident on device before the quest begins. Heritage districts have unreliable signal — this is a requirement, not an option. See the open question on map rendering: MapKit exposes no public offline tile cache, so the route display cannot depend on live tiles.
- **Checkpoint loop**: arrive → GPS confirm (with manual fallback) → lore reveal → task → clue to the next checkpoint. Fixed order, no skipping.
- **Tasks are keepsakes, not proof.** The GPS radius is the gate; the photo is a souvenir. Every photo task is **skippable** without penalty — some checkpoints prohibit photography, and the user may have a dead battery, rain, or a crowd.
- Progress tracking, save-as-draft, and resume.
- Side quests appear as optional suggestions (text only, no state tracked in v1).

**Completion**
- 5 checkpoint stamps + 1 combined quest badge.
- Trip summary: linear story recap + the user's photos, in checkpoint order.
- One personal reflection field, prompted by the final checkpoint task.
- Auto-composed share card + native share sheet.
- Post-quest recall survey (1 question) — this is the measurement instrument for the core hypothesis, not a nice-to-have.

**Platform**
- **No account in v1.** Everything is stored locally on device. Login/register is removed from the flow entirely — a traveler downloading the app on the street with 30% battery should never hit an auth wall. Accounts arrive in v2, when cross-device sync is the actual need.
- SwiftUI, MVVM, CoreLocation (foreground only), MapKit, local persistence.
- Quest content bundled with the app in v1. A CMS is v3 — with only two quests, shipping a backend first is premature.

**Explicitly required non-features**
- Community consent obtained in writing from the pengempon/managing body of every sacred site before that site ships.
- Attribution to community sources (Kultara, B-PART, juru kunci, pemangku) visible in-app.
- Pedestrian safety pattern: clues and lore are revealed **at rest at a checkpoint**, never as turn-by-turn prompts while walking.

### Out of scope for MVP

| Item | Why deferred |
|---|---|
| **History Alert / ambient heritage notifications** | Distinct from the quest proximity alert, which does ship in v1. History Alert fires unsolicited about places the user never asked about, across many sites — a harder App Review case and a much easier feature to make annoying. It shares infrastructure with proximity alerts from v2 onward, but shares neither its consent nor its justification. |
| **User accounts, login, register** | No cross-device need with local-only data. Pure friction at the worst possible moment. |
| **CMS / content backend** | Two bundled quests do not justify a backend. Build it when content velocity is the bottleneck, not before. |
| **Full Map Area with badge collection view** | v1 needs a route map, not a collectibles map. |
| **Journal browsing, visited-places history** | With two quests there is nothing to browse. |
| **Cross-quest achievements** (e.g. the Lempad "Karya Sang Maestro" link) | Only meaningful once a user has finished multiple quests. |
| **Side quest state tracking and bonus rewards** | Optional suggestions cost nothing; tracking them costs a lot. |
| **Audio narration** | High content cost. Strong candidate for v3 — it directly solves the phone-while-walking safety problem. |
| **Monetization** | Free in v1. Pricing decisions need completion and retention data first. |
| **Additional languages beyond ID/EN** | v3, once the localization pipeline exists. |

---

## Roadmap

Each release is gated on the previous one's evidence. If a gate fails, the next release is re-planned, not started.

### v1 — MVP: prove the story loop
*Goal: does a linear, story-connected walking quest make people finish and remember?*

As scoped above. Two routes, bilingual, offline-capable, no account, no backend. The only notification is the opt-in quest proximity alert, and the only background work is region monitoring for it.

**Gate to v2:** completion ≥ 40% AND recall ≥ 70%. If recall fails but completion passes, the differentiation claim is wrong — rework the narrative model before adding surface area. If completion fails, fix the drop-off checkpoint first.

### v1.1 — Fast follow (2–6 weeks post-launch, data-driven)
*Goal: fix what the data exposes. No new pillars.*

- Retune GPS radius per checkpoint using real override rates
- Rewrite clues and tasks at the worst drop-off checkpoint
- Adjust duration and difficulty estimates against observed reality
- Copy and pacing fixes on lore that shows low dwell time
- Add a third route **only if** content production time per quest turned out lower than estimated

### v2 — Ambient discovery and memory
*Goal: bring users back between quests, and let stories find them.*

- **History Alert** — background geofence notifications when passing a heritage site outside an active quest. Opt-in, **default off**, with a clear value explanation before the permission prompt. Rate-limited (max 1–2 per day) and only active in cities where the user has opened the app.
- **Standalone Place pages** — the `Place` entity finally used outside a quest. This is where the "standalone by default" half of the content model becomes real.
- **Journal** — browse past trips, visited places, edit reflections, share history.
- **Full Map Area** — earned badges surfaced on the map, area overview, recommendations along the route.
- **Accounts (Sign in with Apple) + cloud sync** — introduced now, when there is finally a reason: not losing a journal when changing phones.
- **Cross-quest achievements** — e.g. finishing both a Denpasar and an Ubud quest unlocks the I Gusti Nyoman Lempad link (Catur Muka 1973 / Pura Taman Saraswati 1951–52).
- **Side quest tracking** with bonus stamps.

**Gate to v3:** 7-day return rate and second-quest start rate justify investing in content volume. If users finish one quest and never come back, more quests is the wrong answer.

### v3 — Content scale
*Goal: make new quests cheap enough to ship continuously.*

- **CMS / content backend** — quest data fetched from an API; content team ships new quests and corrections without an App Store release.
- **Content production pipeline tooling** — real walking-directions validation (not haversine + buffer), a field-validation checklist per checkpoint, and a **community consent tracker** per site as a hard gate before publish.
- **Temporal gating** — piodalan/ceremony calendar, site closing hours, market-hours awareness. A quest starting at 16:00 must not send someone to a site that closes at 18:00.
- **Multi-city expansion** beyond the first two districts — Singaraja, Klungkung/Semarapura, Karangasem, then off-island.
- **Content versioning and hotfix** — correcting a historical claim should take hours, not a release cycle.
- **Localization pipeline** — Japanese, Mandarin, Korean (largest Bali inbound markets after domestic).
- **Audio narration** — pulled here from the long horizon because it directly fixes the walking-while-reading safety problem, not just as a premium feature.

### v4 — Community and social
*Goal: let the people who own these stories tell them, and get paid for it.*

- **Storyteller partnership program** — Kultara, B-PART, juru kunci, pemangku as credited contributors, with a defined attribution and revenue-share model.
- **Community-contributed quests** — moderated submission flow with the same consent and accuracy gates as first-party content.
- **Group quest** — walk together, synced progress across a small party. Deliberately *not* a leaderboard: competitive ranking on sacred sites is the wrong incentive.
- **Public web preview for shared quests** — a shared card should open something, not nothing.
- **Moderated user photo galleries** per place, with explicit rules against disrespectful framing of sacred sites.

### v5 and beyond — long horizon
*Only pursued if earlier bets pay off. Listed for direction, not commitment.*

- **Monetization** — premium quests, city passes, tourism-board or heritage-body sponsorship, licensing to regional governments. Any paid model must preserve free access to at least one quest per city.
- **AR at checkpoints** — reconstructed Puri Pemecutan as it stood before 20 September 1906, viewed from the spot where it fell.
- **B2B / white-label** — museums, heritage bodies, regional tourism offices running their own quests on the platform.
- **Accessibility route variants** — shorter, step-free, or vehicle-assisted versions of existing quests.
- **Apple Watch companion** — checkpoint arrival and clue delivery on the wrist, keeping the phone in the pocket.
- **Full offline map packs** for low-connectivity regions.

---

## Delivery Milestones

Business outcomes, not engineering tasks. `/plan` turns each into an implementation plan.

| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Content model locked | `Place` (standalone lore) and `Quest` (ordered reference to Places) defined as distinct entities; accuracy-label convention fixed | in-progress | `.claude/plans/cultural-heritage-quest.plan.md` |
| 2 | Community consent secured | Written permission from the managing body of every site in both v1 routes; sites without consent are cut | pending | — |
| 3 | Routes field-validated | Both routes walked end to end; real walking distances, timings, opening hours, photo rules, and costs recorded | pending | — |
| 4 | Quest content written | Both quests written and reviewed in Indonesian and English, every claim labeled and sourced | pending | — |
| 5 | Discovery and preview | A user anywhere in the world can browse both quests and see route, duration, cost, terrain, and timing | pending | — |
| 6 | Quest execution loop | A user on-site can start, progress through 5 checkpoints, skip a photo, lose signal, abandon, and resume | pending | — |
| 7 | Completion and share | Badges, trip summary, reflection, share card, and the recall survey | pending | — |
| 8 | Instrumentation | Every metric in the Success Metrics table is actually being collected | pending | — |
| 9 | v1 verdict | Enough runs to accept or reject the hypothesis and decide whether v2 proceeds as scoped | pending | — |

Milestones 1–4 are content and relationship work, not engineering, and they are the critical path. Milestone 2 in particular can invalidate a route entirely.

---

## Open Questions

- [ ] **Which two routes ship in v1?** Denpasar and Ubud are the candidates; the decision depends on the outcome of milestone 2 (consent) and 3 (field validation), not on narrative quality.
- [ ] **App name and branding.** Only quest names exist so far ("Bandana Negara", "Puputan: Kisah Terakhir Sang Raja", "Dari Puri ke Catur Muka"). Needed before App Store submission.
- [ ] **How many hours does one quest actually cost to produce** (research + field validation + consent + bilingual writing + photography)? Estimated 30–50 hours. This number determines whether v3's content-scale bet is viable at all, and it can only be answered by producing the first two.
- [ ] **Who owns content production long-term?** Internal writer, contracted local historians, or the community partnership model that v4 formalizes?
- [ ] **How is the recall survey coded?** Manual coding does not scale past a few hundred responses; needs a rubric before launch.
- [ ] **Differentiation against Questo specifically.** Questo is a direct competitor running the same location-based story-walk model globally. "Better than a tourist map" is not a positioning statement when Questo exists. The likely answer is depth of local sourcing, community consent, and narrative craft — but it has to be stated and defended.
- [ ] **How is the route map rendered offline?** MapKit has no public offline tile API, so a live MapKit view goes blank exactly where the product needs it most — inside Pasar Badung, in narrow alleys, under the Monkey Forest canopy. Three candidates: (a) pre-rendered static route images for preview, (b) a custom canvas drawing the route line and checkpoint pins with no basemap, (c) MapLibre with cached vector tiles. Leading recommendation: (b) during an active quest and (a) for preview — a detailed basemap is not what the user needs mid-walk, direction and remaining distance are. Option (c) is the only true full-fidelity offline map and costs the most to integrate.
- [ ] **What is the draft expiry policy?** How long does an abandoned quest hold its photos and progress, and what happens to the data at expiry?
- [ ] **Minimum iOS version and device floor** — affects CoreLocation and SwiftData choices.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Sacred site objects to being gamified** — a pemangku or desa adat publicly opposes the app | Medium | Critical | Written consent as a hard publish gate (milestone 2); contemplative, non-game mechanics inside active places of worship; a rapid takedown path for any site whose community withdraws consent |
| **Historical claim disputed by academics or cultural figures** | Medium | High | Mandatory `[Tercatat]` / `[Babad]` labeling; visible sources; content versioning so a correction ships in hours (v3), with a manual patch process until then |
| **GPS unreliable at real checkpoints** — indoor markets, narrow alleys, dense canopy | High | High | Manual "I'm here" override after 60s, flagged low-confidence; per-checkpoint radius tuning in v1.1; radius sized generously by default |
| **The connected-narrative bet is simply wrong** — users like the walk but recall no better than a standalone guide would produce | Medium | Critical | The recall survey is built into v1 specifically to detect this early, before content volume is scaled |
| **Content production is too slow to sustain a catalogue** | High | High | Measure honestly on the first two quests; if the number is bad, v3's expansion strategy changes to partnership-first rather than in-house |
| **Pedestrian injury** — user hit by traffic while reading the app on Jalan Gajah Mada or Jalan Monkey Forest | Low | Critical | No turn-by-turn prompts while walking; content revealed at rest at checkpoints; explicit safety notice pre-start; checkpoints positioned at safe standing spots during field validation |
| **User arrives at a closed or ceremony-occupied site mid-quest** | High | Medium | Recommended start window and closing hours surfaced in preview (v1); calendar-aware gating (v3); graceful "site unavailable, here's the story anyway" fallback |
| **Map goes blank offline** — MapKit provides no offline tile cache, so route display fails in exactly the low-signal places the quests visit | High | High | Do not depend on live tiles: static pre-rendered route images for preview, custom route-and-pin canvas during an active quest (see open question) |
| **Offline-first lost during the v3 CMS migration** — quest data moves behind an API and the app silently becomes network-dependent | Medium | High | Offline-first written as a durable principle, not a v1 property; durable versioned content cache; a downloaded quest stays playable regardless of backend state; quest start never blocks on a network call |
| **Recall survey lost to bad signal** — the primary hypothesis instrument fails to submit at the final checkpoint | High | High | Survey responses and analytics events persist locally and flush on reconnect; never gate submission on a live request |
| **App Store rejection over background location** (v2) | Medium | Medium | Opt-in, default off, clear pre-permission value explanation, and a feature that degrades gracefully when denied |
| **Accessibility exclusion** — 2–3 km walking format excludes users with limited mobility | High | Medium | Honest terrain, distance, and step disclosure in v1; route variants in v5; never present the format as universally accessible |
| **Unexpected out-of-pocket cost frustrates users** — e.g. Monkey Forest and Museum Puri Lukisan entry fees on the Ubud route | High | Medium | `estimated_cost` as a required quest metadata field, shown in preview before start |

---

*Status: DRAFT — requirements only. Implementation planning pending via `/plan`.*
