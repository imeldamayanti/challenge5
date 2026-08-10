# Cultural Heritage Quest — Full Product Requirements

**Document type:** Full PRD — functional and non-functional requirements
**Platform:** native iOS (Swift / SwiftUI)
**Status:** DRAFT
**Supersedes:** nothing. Companion to `cultural-heritage-quest.prd.md`, which holds the problem framing, hypothesis, metrics, and roadmap. This document does not restate them — it turns them into requirements.

**How to read this document.** Requirements use RFC 2119 keywords: **MUST** (mandatory), **SHOULD** (strong default, deviation needs a written reason), **MAY** (optional). Each requirement carries an ID, a priority (P0 = MVP blocker, P1 = MVP but degradable, P2 = post-MVP), and a target release. IDs are stable — never renumber, mark withdrawn requirements as `WITHDRAWN` and keep the ID.

---

## 1. Glossary

Precise names matter here because the same word means different things to design, content, and engineering.

| Term | Meaning |
|---|---|
| **Place** | A real-world heritage site with its own standalone lore. Exists independently of any quest. Has coordinates, a radius, visiting rules, and a consent record. |
| **Quest** | An ordered sequence of Checkpoints forming one narrative arc. References Places; does not own them. |
| **Checkpoint** | One position in a Quest's ordered sequence, bound to exactly one Place, carrying its own lore segment, clue, and tasks. The same Place may appear in multiple Quests with different lore segments. |
| **Run** | One user's attempt at one Quest. The unit of progress, drafting, and completion. A user MAY have at most one active Run per Quest. |
| **Task** | An activity offered at a Checkpoint — photo, reflection, or question. Never gates progression. |
| **Side quest** | An optional suggestion at a Checkpoint. Not tracked in v1. |
| **Stamp** | Award for reaching one Checkpoint. |
| **Badge** | Award for completing a whole Quest, or for a cross-Quest achievement (v2). |
| **Arrival** | The system's confirmation that the user is physically at a Checkpoint. Either GPS-confirmed or manually asserted. |
| **Content version** | An immutable version identifier for a Quest's text, media, and route. Pinned to a Run at start. |
| **Consent record** | Documented permission from a Place's managing community to include it in a Quest. |

---

## 2. Scope of this release

| | v1 (MVP) | v1.1 | v2 | v3 |
|---|---|---|---|---|
| Quests shipped | 2 | +1 conditional | — | many |
| Content delivery | bundled in app | bundled | bundled | CMS/API |
| Accounts | none | none | Sign in with Apple | — |
| Network required | never | never | sync only | content refresh only |
| Notifications | quest proximity (opt-in, off) | — | + History Alert (opt-in, off) | — |
| Background location | region monitoring only | — | + History Alert regions | — |
| Apple Watch | forwarded haptic only | — | arrival haptic during a Run | — |
| Languages | ID + EN | ID + EN | ID + EN | +JA/ZH/KO |

---

## 3. Key architectural decisions

Decisions that constrain many requirements below. Each has a rationale because each will be questioned later.

### AD-1 — Location use is split by purpose

Two location behaviors with different permissions, different costs, and different justifications. They must not be conflated.

**Arrival detection, during a Run — foreground only.** Sampling runs while the app is open, at the checkpoint screen. The product must not encourage walking while staring at a screen, so continuous tracking during the walk has no user-facing purpose: the clue tells the user where to go, they pocket the phone, they walk, they open the app on arrival. This keeps the walking experience safe and costs nothing between checkpoints.

**Quest proximity alert, outside a Run — background region monitoring, opt-in, default off.** The app monitors the start radius of quests the user has not completed, and alerts when the user walks into one, so that a traveler who happens to pass Puri Agung Pemecutan learns that a quest begins there. On a paired Apple Watch this surfaces as a haptic. See `FR-PROX`.

*Rationale for accepting background location in v1.* The expensive, scrutinized pattern is continuous background location updates. Region monitoring is not that — it runs on coarse radios with hardware assistance and has negligible standby cost. The App Review justification is narrow and legible: *tell the user when they are standing near the start of a walking tour they can take right now.* That is a far easier case than ambient History Alert, which fires unsolicited about places the user never asked about.

*Consequence for History Alert (v2).* It now inherits working infrastructure, but it remains a separate feature with its own opt-in and its own permission conversation. Sharing a mechanism is not sharing consent.

*Consequence for the walking model.* The user experience is still "pocket the phone, walk, open on arrival" during a Run. This must be taught in onboarding and in the pre-start safety notice, not left to be discovered.

### AD-2 — Arrival is gated by position; tasks are never gates

Progression requires Arrival only. Every Task is skippable with no penalty and no altered reward.

*Rationale.* The app cannot verify photo content, so a photo is not evidence — it is a souvenir. Treating it as a gate creates a failure the app cannot resolve: photography is prohibited in parts of active temples, and the PRD's own field-validation list flags photo permission as unresolved per site.

### AD-3 — Local store is authoritative; no connectivity branching

All reads and writes go to the local store. There is no `if online` branch anywhere in the core loop. Sync (v2) and content refresh (v3) are separate opportunistic processes that never sit in a user-facing path.

### AD-4 — Content version pinned per Run

A Run keeps the content snapshot it started with, for its entire life including its summary.

*Rationale.* A content hotfix must never rewrite the story under a user standing at Checkpoint 3, and the recap must match what they actually read.

### AD-5 — One justified network dependency: the site kill-switch

v1 content is bundled, so a site whose community withdraws consent cannot be removed without an App Store release (24–48h review, plus user update lag — realistically days). This is unacceptable for the one risk rated Critical.

Therefore the app **MUST** fetch a small remote suppression list on launch when connectivity is available, cache the result durably, and apply it to all subsequent launches. It **MUST** fail to the last cached state, never block launch, and never delay quest start.

*This is the only place where the network touches the core product, and it exists to honor a promise to the communities whose sites we ship.*

---

## 4. Data model

Field lists are requirements, not schema. Types are indicative.

### 4.1 Content entities (authored, read-only on device)

**Place**
| Field | Notes |
|---|---|
| `id` | stable, never reused |
| `name_official` | localized; the form used by the managing body |
| `name_variants[]` | alternate spellings encountered in sources (e.g. Maospahit / Maospait) |
| `coordinate` | lat/lon, validated in the field, not from a map search |
| `arrival_radius_m` | per-place, tuned; default 75 m |
| `type` | puri / pura / pasar / monumen / museum / ruang publik |
| `is_sacred` | drives mechanic restrictions — see FR-TASK-05 |
| `visiting_hours` | including known seasonal closure patterns |
| `dress_code` | free text, localized |
| `photo_policy` | allowed / restricted-areas / prohibited, plus notes |
| `entry_cost` | amount + currency, or free |
| `accessibility_notes` | steps, surface, width |
| `lore_standalone` | localized; used by History Alert in v2, authored in v1 |
| `sources[]` | citation + type (documented / oral / interview) |
| `consent_record_id` | required non-null to publish |

**Quest**
| Field | Notes |
|---|---|
| `id`, `slug` | |
| `content_version` | immutable per published revision |
| `title`, `hook_lore`, `description` | localized |
| `region`, `city` | |
| `checkpoints[]` | ordered, 1..n |
| `total_distance_m` | from real walking directions, not haversine |
| `walking_time_min`, `total_duration_min` | separate figures; both shown |
| `estimated_cost` | sum of Place entry costs + notes |
| `terrain_summary` | derived from Places, editable |
| `proximity_radius_m` | radius for the pre-arrival alert (FR-PROX); larger than the start checkpoint's `arrival_radius_m`, default 200 m |
| `recommended_start_window` | e.g. 08:00–14:00 local |
| `hard_latest_start` | derived from earliest Place closing time minus duration |
| `safety_notes` | localized |
| `languages[]` | |
| `badge_id` | |

**Checkpoint**
| Field | Notes |
|---|---|
| `id`, `quest_id`, `order_index` | |
| `place_id` | |
| `role` | start / middle / finish |
| `lore_segment` | localized, with per-claim accuracy labels |
| `clue_to_next` | localized; null for the final checkpoint |
| `tasks[]` | |
| `side_quests[]` | |
| `stamp_id` | |

**Task**
| Field | Notes |
|---|---|
| `id`, `checkpoint_id`, `type` | photo / reflection / question |
| `prompt` | localized |
| `blocks_progression` | **MUST be false for all v1 content**; field exists to make the rule explicit and auditable |

**ConsentRecord**
| Field | Notes |
|---|---|
| `place_id`, `granting_body`, `granted_by_name`, `granted_by_role` | |
| `granted_at`, `expires_at` | |
| `scope[]` | inclusion / photography / naming / imagery |
| `document_ref` | pointer to the signed artifact |
| `status` | granted / withdrawn / expired |

### 4.2 User entities (device-authored, sync-bound in v2)

All user records **MUST** carry a device-generated UUID, `created_at`, and `updated_at` from v1 onward, even though nothing syncs in v1. Retrofitting identity onto existing rows after launch is materially harder than carrying it from the start.

**Run** — `id`, `quest_id`, `content_version`, `language`, `state`, `started_at`, `updated_at`, `completed_at`, `abandoned_at`, `current_checkpoint_index`

**CheckpointResult** — `run_id`, `checkpoint_id`, `arrived_at`, `arrival_method` (gps / manual), `gps_accuracy_m`, `lore_first_opened_at`, `lore_dwell_ms`, `stamp_awarded_at`

**TaskResult** — `checkpoint_result_id`, `task_id`, `type`, `photo_local_id` | `text`, `skipped`, `completed_at`

**Award** — `type` (stamp / badge), `source_id`, `run_id`, `awarded_at`

**SurveyResponse** — `run_id`, `question_id`, `text`, `created_at`, `sync_state`

**AnalyticsEvent** — `id`, `name`, `params`, `created_at`, `sync_state`

---

## 5. Functional requirements

### 5.1 Onboarding and first run — `FR-ONB`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ONB-01 | The app **MUST** be fully usable on first launch with no account, no sign-in, and no email. | P0 | v1 |
| FR-ONB-02 | Onboarding **MUST** be at most 4 screens and **MUST** be skippable from the first screen. | P0 | v1 |
| FR-ONB-03 | Onboarding **MUST** explain the pocket-the-phone walking model (AD-1): the app is opened at checkpoints, not carried open while walking. | P0 | v1 |
| FR-ONB-04 | The app **MUST NOT** request location permission during onboarding. It **MUST** be requested in context, at the first quest start attempt, with a preceding explanation screen. | P0 | v1 |
| FR-ONB-05 | Language **MUST** default to the device language when it is Indonesian or English, and to English otherwise, and **MUST** be changeable in Settings. | P0 | v1 |
| FR-ONB-06 | The app **MUST NOT** display an App Tracking Transparency prompt, because it **MUST NOT** collect data used for tracking. | P0 | v1 |

### 5.2 Discovery and preview — `FR-DISC`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-DISC-01 | Quest browsing and full preview **MUST** work at any location on earth, with no network, and with location permission denied. | P0 | v1 |
| FR-DISC-02 | The quest list **MUST** show, per quest: title, region, distance, walking time, total duration, and estimated cost. | P0 | v1 |
| FR-DISC-03 | Quest preview **MUST** show all of: opening lore hook, description, ordered checkpoint list with Place names, route map (see FR-MAP), total distance, walking time, total duration, estimated out-of-pocket cost with breakdown, terrain and steps summary, recommended start window, and the safety notice. | P0 | v1 |
| FR-DISC-04 | Preview **MUST NOT** reveal checkpoint lore segments or clues. Place names and the map are shown; the story is not. | P0 | v1 |
| FR-DISC-05 | When a quest is estimated to cost money, the total **MUST** be visible on the quest card in the list, not only inside preview. | P0 | v1 |
| FR-DISC-06 | If the current local time is later than `hard_latest_start`, preview **MUST** show a non-blocking warning naming the site that closes and its closing time. | P1 | v1 |
| FR-DISC-07 | Quest preview **MUST** be reachable in one tap from the quest list. | P1 | v1 |
| FR-DISC-08 | Quests suppressed by the kill-switch (AD-5) **MUST NOT** appear in the list, and an in-progress Run of a suppressed quest **MUST** be closed gracefully with an explanation. | P0 | v1 |

### 5.3 Prefetch and offline readiness — `FR-OFF`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-OFF-01 | In v1 all quest content **MUST** ship inside the app bundle. No download is required to start a quest. | P0 | v1 |
| FR-OFF-02 | Every core flow — browse, preview, start, progress, complete, summarize, compose share card, save to Photos — **MUST** function with the device in airplane mode. This is a release gate, tested as such. | P0 | v1 |
| FR-OFF-03 | The route map **MUST** render offline. See FR-MAP-01. | P0 | v1 |
| FR-OFF-04 | From v3, fetched content **MUST** be cached durably and versioned, remain usable while stale, and refresh opportunistically. Quest start **MUST NOT** await any network call. | P0 | v3 |
| FR-OFF-05 | From v3, a quest already resident on device **MUST** remain playable indefinitely regardless of backend availability. | P0 | v3 |

### 5.4 Route map — `FR-MAP`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-MAP-01 | The route display **MUST NOT** depend on live map tiles. MapKit exposes no public offline tile cache, so a live MapKit view is not an acceptable implementation for in-quest use. | P0 | v1 |
| FR-MAP-02 | During an active Run the map **MUST** show, at minimum: the ordered checkpoint sequence, the user's position relative to the next checkpoint, and the straight-line distance remaining. | P0 | v1 |
| FR-MAP-03 | The map **MUST NOT** provide turn-by-turn navigation. | P0 | v1 |
| FR-MAP-04 | The app **MAY** offer a one-tap handoff to Apple Maps walking directions, presented as leaving the app, for users who want navigation. | P2 | v1.1 |
| FR-MAP-05 | Earned badges displayed on a regional map is a v2 feature and **MUST NOT** be built into the v1 map. | P2 | v2 |

### 5.5 Starting a Run — `FR-START`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-START-01 | Starting a Run **MUST** require Arrival at the first checkpoint, established per FR-ARR. | P0 | v1 |
| FR-START-02 | Before the location permission prompt, the app **MUST** show a plain-language explanation of why location is needed and that it is used only while the app is open. | P0 | v1 |
| FR-START-03 | If location permission is denied, quest preview **MUST** remain fully available and the start control **MUST** explain what is blocked and offer a path to Settings. | P0 | v1 |
| FR-START-04 | The user **MUST** acknowledge the safety notice before the first Run of a quest. | P0 | v1 |
| FR-START-05 | Starting a Run **MUST** pin `content_version` and `language` to the Run. | P0 | v1 |
| FR-START-06 | At most one Run per quest **MAY** be active. Starting a quest with an existing draft **MUST** offer resume or restart, and restart **MUST** warn that existing photos and reflections for that Run will be discarded. | P0 | v1 |
| FR-START-07 | Multiple Runs of *different* quests **MAY** be in draft simultaneously. | P1 | v1 |
| FR-START-08 | A quest **MUST NOT** be startable from outside the start radius by any path. When arrival cannot be confirmed, the only available action is preview. | P0 | v1 |
| FR-START-09 | Manual override at the *start* checkpoint **MUST** require an explicit confirmation that names the Place — for example, "Are you standing at the main gate of Puri Agung Pemecutan?" — before the Run begins. Override exists for GPS failure, not for remote starting, and the wording must make that plain without accusing the user. | P0 | v1 |
| FR-START-10 | Manual override **MUST** remain available at the start checkpoint. Removing it would make the entire product unusable wherever GPS fails at the first gate, which is precisely where dense urban sites are worst. | P0 | v1 |

### 5.6 Arrival detection — `FR-ARR`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ARR-01 | Arrival is established when a location fix places the user within the checkpoint's `arrival_radius_m` with horizontal accuracy no worse than the radius. | P0 | v1 |
| FR-ARR-02 | Location sampling **MUST** run only while the app is foregrounded. | P0 | v1 |
| FR-ARR-03 | A manual override control **MUST** appear after 60 seconds of unsuccessful detection while the arrival screen is open. Using it **MUST** record `arrival_method = manual` and the last known accuracy. | P0 | v1 |
| FR-ARR-04 | Manual override **MUST NOT** reduce any reward, mark the Run as lesser, or be visually penalized. It is a legitimate path, not a cheat. | P0 | v1 |
| FR-ARR-05 | The arrival screen **MUST** show live feedback — approximate distance remaining and whether a usable fix exists — rather than an indefinite spinner. | P0 | v1 |
| FR-ARR-06 | Arrival at a checkpoint out of sequence **MUST NOT** advance the Run. The app **MUST** state which checkpoint is expected. | P0 | v1 |
| FR-ARR-07 | `arrival_radius_m` **MUST** be adjustable per checkpoint through content, not code. | P0 | v1 |

### 5.7 Checkpoint progression and lore — `FR-CP`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-CP-01 | Checkpoints **MUST** be completed in `order_index` order. Skipping ahead **MUST NOT** be possible. | P0 | v1 |
| FR-CP-02 | On Arrival the app **MUST** present, in order: the checkpoint's lore segment, its tasks, then the clue to the next checkpoint. | P0 | v1 |
| FR-CP-03 | The clue to the next checkpoint **MUST** be re-readable at any later time during the Run without re-triggering arrival. | P0 | v1 |
| FR-CP-04 | Lore already read **MUST** remain accessible for the remainder of the Run and in the summary. | P0 | v1 |
| FR-CP-05 | Every factual claim in lore **MUST** be rendered with its accuracy label — documented versus oral tradition — using a consistent, legible visual convention. The label **MUST NOT** be hidden behind a tap. | P0 | v1 |
| FR-CP-06 | Sources for a checkpoint's lore **MUST** be reachable within one tap from the lore screen. | P0 | v1 |
| FR-CP-07 | A stamp **MUST** be awarded on Arrival, independent of task completion. | P0 | v1 |
| FR-CP-08 | The app **MUST** show progress through the quest as a count of checkpoints reached out of total. Distance-based progress **MUST NOT** be used, because real walking distance is not measured. | P1 | v1 |

### 5.8 Tasks — `FR-TASK`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-TASK-01 | No task **MUST** block progression, reward, or completion. | P0 | v1 |
| FR-TASK-02 | Every task **MUST** offer an explicit, non-apologetic skip control. | P0 | v1 |
| FR-TASK-03 | Photo tasks **MUST** support both capturing a new photo and choosing an existing one. | P0 | v1 |
| FR-TASK-04 | Photos captured for a task **MUST** be stored in app-local storage and **MUST NOT** be uploaded anywhere in v1. | P0 | v1 |
| FR-TASK-05 | At a Place with `is_sacred = true`, the app **MUST** display the Place's dress code and photo policy before offering any task, and **MUST NOT** offer puzzle, scavenger, or timed mechanics. Permitted mechanics are limited to photo, reading, reflection, and a single light question. | P0 | v1 |
| FR-TASK-06 | At a Place with `photo_policy = prohibited`, a photo task **MUST NOT** be offered at all. | P0 | v1 |
| FR-TASK-07 | The final checkpoint's task **MUST** include a free-text reflection prompt, and its answer **MUST** flow into the trip summary. | P0 | v1 |
| FR-TASK-08 | Side quests **MUST** be presented as clearly optional and **MUST NOT** be tracked, scored, or rewarded in v1. | P1 | v1 |
| FR-TASK-09 | Side quest tracking with bonus stamps. | P2 | v2 |

### 5.9 Run state, drafts, interruption — `FR-RUN`

Run states: `not_started → active → (completed | abandoned)`, with `active` persisting indefinitely as a draft.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-RUN-01 | Every state transition and every task result **MUST** be persisted durably within 500 ms of the user action. | P0 | v1 |
| FR-RUN-02 | A Run **MUST** survive app backgrounding, force-quit, iOS termination, and device restart with no loss of arrivals, photos, or text. | P0 | v1 |
| FR-RUN-03 | An active Run **MUST** be resumable from the home screen with a visible entry point showing quest name and progress. | P0 | v1 |
| FR-RUN-04 | The user **MUST** be able to abandon a Run explicitly, with a confirmation that names what will be kept and what will be lost. | P0 | v1 |
| FR-RUN-05 | Draft Runs **MUST NOT** expire automatically in v1. Retention policy is an open question; until it is answered, nothing is deleted. | P0 | v1 |
| FR-RUN-06 | If a checkpoint's Place becomes suppressed (AD-5) mid-Run, the Run **MUST** end gracefully with the summary preserved for checkpoints already reached. | P0 | v1 |

### 5.10 Completion, awards, summary — `FR-DONE`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-DONE-01 | A Run completes on Arrival at the final checkpoint, independent of task completion. | P0 | v1 |
| FR-DONE-02 | On completion the app **MUST** award all checkpoint stamps earned plus the quest badge. | P0 | v1 |
| FR-DONE-03 | The trip summary **MUST** present the checkpoints in narrative order, each with its lore segment recap, the user's photo if any, and the user's reflection. | P0 | v1 |
| FR-DONE-04 | The summary **MUST** be generated from the Run's pinned `content_version`, never from current content. | P0 | v1 |
| FR-DONE-05 | The summary **MUST** be viewable offline, forever, after completion. | P0 | v1 |
| FR-DONE-06 | Summaries of completed Runs **MUST** be listed and re-openable from the home screen in v1, even before the full Journal exists. | P1 | v1 |
| FR-DONE-07 | Full Journal — browse all trips, visited Places, edit reflections, share history. | P2 | v2 |

### 5.11 Share — `FR-SHARE`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SHARE-01 | The share card **MUST** be composed entirely on-device from local assets. | P0 | v1 |
| FR-SHARE-02 | The share card **MUST** be savable to Photos with no network. | P0 | v1 |
| FR-SHARE-03 | Sharing **MUST** use the system share sheet. | P0 | v1 |
| FR-SHARE-04 | The user **MUST** be able to exclude individual photos from the share card before sharing. | P0 | v1 |
| FR-SHARE-05 | For sacred Places, the share card **MUST** carry the Place's official name and **MUST NOT** apply humorous framing, stickers, or overlays. | P0 | v1 |
| FR-SHARE-06 | The share card **MUST NOT** embed precise coordinates, and any location metadata in included photos **MUST** be stripped from the composed image. | P0 | v1 |
| FR-SHARE-07 | Sharing **MUST** be entirely optional and **MUST NOT** be a precondition for any award. | P0 | v1 |

### 5.12 Recall survey — `FR-SURV`

This is the measuring instrument for the product's core hypothesis. It is not a nice-to-have.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SURV-01 | On completion the app **MUST** present a single free-text question asking the user to retell the quest's story in their own words. | P0 | v1 |
| FR-SURV-02 | The survey **MUST** be skippable. | P0 | v1 |
| FR-SURV-03 | The response **MUST** be persisted locally before any transmission is attempted, and **MUST** be queued for later delivery if offline. | P0 | v1 |
| FR-SURV-04 | The survey **MUST** be presented before the share step, so that share abandonment does not lose the response. | P1 | v1 |
| FR-SURV-05 | The user **MUST** be told what the response is used for and that it is anonymous. | P0 | v1 |

### 5.13 Settings — `FR-SET`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SET-01 | Settings **MUST** expose: language, location permission status with a link to system settings, storage used, and a control to delete all local data. | P0 | v1 |
| FR-SET-02 | Deleting all local data **MUST** remove Runs, photos, reflections, awards, and queued telemetry, and **MUST** require confirmation. | P0 | v1 |
| FR-SET-03 | Settings **MUST** show attribution to community sources and content contributors. | P0 | v1 |
| FR-SET-04 | Settings **MUST** expose a way to report a factual error or a concern about a Place. | P0 | v1 |

### 5.14 Quest proximity alert and Apple Watch — `FR-PROX`, `FR-WATCH`

The user walks past Puri Agung Pemecutan without knowing a quest starts there. The phone stays in the pocket; the watch buzzes; they look and find out. This is the discovery path for travelers who did not plan the walk in advance — the opposite of the preview-from-the-hotel path, and it reaches people the quest list never would.

Scoped in v1 to **quest start points only**, not intermediate checkpoints. During an active Run the user is already engaged and opens the app at each checkpoint by design (AD-1).

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-PROX-01 | The app **MUST** alert the user when they enter the `proximity_radius_m` of the start point of a quest they have not completed, while the app is not open. | P0 | v1 |
| FR-PROX-02 | Proximity monitoring **MUST** cover quest start points only. Intermediate checkpoints **MUST NOT** be monitored in v1. | P0 | v1 |
| FR-PROX-03 | The feature **MUST** be opt-in with a default of off, and **MUST** present a plain-language explanation of what it does and what permission it needs before any system prompt. | P0 | v1 |
| FR-PROX-04 | Implementation **MUST** use region monitoring. Continuous background location updates **MUST NOT** be used. | P0 | v1 |
| FR-PROX-05 | If iOS grants only `When In Use` rather than `Always`, the feature **MUST** disable itself, say so plainly, and offer a path to Settings. Every other feature **MUST** be unaffected. | P0 | v1 |
| FR-PROX-06 | The alert **MUST** be delivered as a local notification, so that the system forwards it to a paired Apple Watch as a haptic. It **MUST NOT** require a watch app to be installed, running, or reachable. | P0 | v1 |
| FR-PROX-07 | The notification **MUST** name the quest and the Place, and tapping it **MUST** open that quest's preview. | P0 | v1 |
| FR-PROX-08 | Proximity alerts **MUST NOT** fire for a quest the user has completed, and **MUST NOT** fire at all while any Run is active. | P0 | v1 |
| FR-PROX-09 | Alerts **MUST** be rate-limited: at most once per quest per 24 hours, and at most 3 in total per day. | P0 | v1 |
| FR-PROX-10 | Alerts **MUST NOT** fire between 22:00 and 07:00 local time. | P0 | v1 |
| FR-PROX-11 | `proximity_radius_m` **MUST** be larger than the start checkpoint's `arrival_radius_m` — the point is a warning on approach, not a confirmation at the gate — and **MUST** be tunable per quest through content. | P0 | v1 |
| FR-PROX-12 | Regions for a suppressed quest (AD-5) **MUST** be deregistered on the next launch. | P0 | v1 |
| FR-PROX-13 | Turning the feature off **MUST** deregister all monitored regions immediately. | P0 | v1 |
| FR-PROX-14 | iOS limits an app to 20 monitored regions. From the release where quest count could exceed that, the app **MUST** register only the nearest regions, recomputed from coarse location, rather than failing silently at the cap. | P0 | v3 |
| FR-PROX-15 | Region entry **MUST** be handled entirely on-device. Proximity alerts **MUST NOT** be triggered by a server or delivered as remote push. | P0 | v1 |
| FR-WATCH-01 | Watch support in v1 **MUST** be limited to receiving forwarded notifications and their haptic. A standalone watchOS app **MUST NOT** be required. | P0 | v1 |
| FR-WATCH-02 | The app **MUST** be fully functional for users with no Apple Watch. The watch is an enhancement, never a dependency. | P0 | v1 |
| FR-WATCH-03 | A watchOS companion delivering checkpoint arrival haptics during an active Run, so the phone can stay pocketed for the whole walk. | P2 | v2 |

### 5.15 Post-MVP functional areas

Stated at requirement level so v1 does not foreclose them, not specified in full.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ALERT-01 | History Alert **MUST** be opt-in with a default of off, and **MUST** present its value before any permission prompt. | P0 | v2 |
| FR-ALERT-02 | History Alert **MUST** be rate-limited to at most 2 notifications per day and **MUST NOT** fire during an active Run. | P0 | v2 |
| FR-ALERT-03 | History Alert **MUST** function only in regions where the user has opened the app. | P0 | v2 |
| FR-ALERT-04 | Denying background location **MUST NOT** degrade any other feature. | P0 | v2 |
| FR-ACC-01 | Sign in with Apple **MUST** be optional; the app **MUST** remain fully functional without an account. | P0 | v2 |
| FR-SYNC-01 | Sync **MUST** be a background reconciliation over the local store, never a user-facing save action. | P0 | v2 |
| FR-SYNC-02 | Conflicts **MUST** resolve in favor of the device that authored the content. | P0 | v2 |
| FR-SYNC-03 | Whether photos sync, and over which network types, **MUST** be an explicit user choice, defaulting to Wi-Fi only. | P0 | v2 |
| FR-CMS-01 | Publishing a Place **MUST** be blocked by the CMS unless a ConsentRecord with `status = granted` and an unexpired `expires_at` exists. | P0 | v3 |
| FR-CMS-02 | Publishing a Quest **MUST** be blocked unless total distance was derived from real walking directions and a field-validation checklist is complete. | P0 | v3 |
| FR-CMS-03 | Content **MUST** be versioned such that a correction can be published and reach devices without an app release. | P0 | v3 |

---

## 6. Error, edge, and failure behavior

The original flow board covers only the happy path. These are requirements, not suggestions.

| ID | Condition | Required behavior | Pri |
|---|---|---|---|
| FR-ERR-01 | No usable GPS fix at a checkpoint | Live status plus manual override after 60 s (FR-ARR-03). Never an indefinite spinner. | P0 |
| FR-ERR-02 | Location permission denied mid-Run | Explain, offer Settings, and allow the Run to continue via manual override. The Run **MUST NOT** be destroyed. | P0 |
| FR-ERR-03 | Camera permission denied | Task falls back to photo-library selection, then to skip. | P0 |
| FR-ERR-04 | Storage full while saving a photo | Save the arrival and text first, report the photo failure specifically, keep the Run intact. | P0 |
| FR-ERR-05 | Device battery critical | No special handling required, because state is persisted continuously (FR-RUN-01). | P1 |
| FR-ERR-06 | Site closed or occupied by a ceremony on arrival | The app cannot detect this. It **MUST** provide a "site unavailable" path that awards the stamp, shows the lore, skips place-dependent tasks, and continues the Run. | P0 |
| FR-ERR-07 | User arrives out of sequence | State which checkpoint is expected; do not advance (FR-ARR-06). | P0 |
| FR-ERR-08 | User starts a quest far from its region | Preview remains available; start remains gated by arrival. No special error. | P1 |
| FR-ERR-09 | Kill-switch fetch fails | Silently retain the last cached state. Never block launch. | P0 |
| FR-ERR-10 | Telemetry queue exceeds limits | Drop oldest analytics events first; survey responses and user content **MUST** never be dropped. | P0 |

---

## 7. Non-functional requirements

### 7.1 Performance — `NFR-PERF`

Baseline device for all targets: iPhone 12, iOS at the minimum supported version, cold state.

| ID | Requirement | Pri |
|---|---|---|
| NFR-PERF-01 | Cold launch to an interactive quest list **MUST** complete in ≤ 2.0 s. | P0 |
| NFR-PERF-02 | Quest preview **MUST** render in ≤ 500 ms from tap. | P0 |
| NFR-PERF-03 | A lore screen **MUST** render in ≤ 300 ms. | P0 |
| NFR-PERF-04 | Arrival **MUST** be detected within 15 s of entering the radius with the arrival screen open and a clear sky view. | P1 |
| NFR-PERF-05 | Share card composition **MUST** complete in ≤ 3 s for a 5-photo card. | P1 |
| NFR-PERF-06 | Scrolling in lore and summary **MUST** hold 60 fps on the baseline device. | P1 |
| NFR-PERF-07 | Installed size with 2 bundled quests **MUST** be ≤ 250 MB. Content beyond that budget **MUST** be compressed or cut, not shipped. | P0 |

### 7.2 Reliability and data integrity — `NFR-REL`

| ID | Requirement | Pri |
|---|---|---|
| NFR-REL-01 | Zero data loss on force-quit or crash for any action the user has completed. | P0 |
| NFR-REL-02 | Crash-free session rate **MUST** be ≥ 99.5% before launch is considered acceptable. | P0 |
| NFR-REL-03 | Airplane-mode traversal of the entire core loop **MUST** be part of the release test suite, executed on a physical device. | P0 |
| NFR-REL-04 | A corrupted or partially written local record **MUST NOT** prevent app launch; the app **MUST** isolate and report it while remaining usable. | P1 |
| NFR-REL-05 | Photos **MUST** be stored outside the app's database and referenced, so that a database migration failure cannot destroy user photographs. | P0 |

### 7.3 Battery and resource use — `NFR-BAT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-BAT-01 | The app **MUST NOT** use continuous background location updates in any release. Background location is limited to region monitoring for `FR-PROX`. | P0 |
| NFR-BAT-05 | Region monitoring **MUST NOT** produce a measurable increase in standby battery drain. This **MUST** be verified by measurement over a 24-hour idle period before launch, not assumed. | P0 |
| NFR-BAT-06 | The app **MUST NOT** perform background CPU or network work on region entry beyond scheduling the local notification. | P0 |
| NFR-BAT-02 | During an active Run with the app foregrounded, battery drain **MUST** be ≤ 12% per hour on the baseline device. | P1 |
| NFR-BAT-03 | Location accuracy **MUST** be reduced when the user is more than 300 m from the next checkpoint, and raised on approach. | P1 |
| NFR-BAT-04 | Location sampling **MUST** stop entirely when the arrival screen is not visible. | P0 |

### 7.4 Privacy and data protection — `NFR-PRIV`

The applicable regimes are Indonesia's UU PDP No. 27/2022 and, for EU visitors, GDPR. v1's local-only posture keeps exposure minimal; v2 changes this materially and requires its own review.

| ID | Requirement | Pri |
|---|---|---|
| NFR-PRIV-01 | In v1 the app **MUST NOT** transmit location data, photographs, or reflection text off the device. | P0 |
| NFR-PRIV-02 | Analytics **MUST NOT** include raw coordinates. Checkpoint arrival is reported as a checkpoint identifier, never a position. | P0 |
| NFR-PRIV-03 | The app **MUST NOT** use advertising identifiers, cross-app tracking, or any SDK that performs them. | P0 |
| NFR-PRIV-04 | The app **MUST NOT** collect names, email addresses, phone numbers, or contacts in v1. | P0 |
| NFR-PRIV-05 | Survey responses **MUST** be anonymous and **MUST NOT** be linkable to a person, only to an anonymous Run. | P0 |
| NFR-PRIV-06 | A single control **MUST** delete all local user data (FR-SET-02). | P0 |
| NFR-PRIV-07 | The privacy policy and App Store privacy labels **MUST** accurately reflect the above, and **MUST** be re-reviewed at v2 when accounts and sync are introduced. | P0 |
| NFR-PRIV-09 | Region monitoring **MUST** remain entirely on-device. Region entries **MUST NOT** be logged with coordinates, transmitted, or used to build a movement history. The only permitted record is that a proximity alert for a given quest was shown. | P0 |
| NFR-PRIV-10 | The `Always` authorization purpose string **MUST** describe the single actual use — alerting the user near a quest start — and **MUST NOT** claim broader purposes. | P0 |
| NFR-PRIV-08 | From v2, transmitted user data **MUST** be encrypted in transit, and account deletion **MUST** delete server-side data within 30 days. | P0 |

### 7.5 Security — `NFR-SEC`

| ID | Requirement | Pri |
|---|---|---|
| NFR-SEC-01 | The kill-switch endpoint (AD-5) **MUST** be fetched over TLS and its response **MUST** be schema-validated before use. | P0 |
| NFR-SEC-02 | A malformed or hostile kill-switch response **MUST** be discarded in favor of the last known good state. | P0 |
| NFR-SEC-03 | The app **MUST NOT** ship secrets, API keys, or credentials in the bundle. | P0 |
| NFR-SEC-04 | From v2, authentication **MUST** use Sign in with Apple; the app **MUST NOT** handle passwords. | P0 |

### 7.6 Accessibility — `NFR-A11Y`

| ID | Requirement | Pri |
|---|---|---|
| NFR-A11Y-01 | All text **MUST** support Dynamic Type through the largest accessibility size without truncation or overlap. Lore is long-form reading; this is not optional. | P0 |
| NFR-A11Y-02 | All interactive elements **MUST** carry VoiceOver labels, and the full core loop **MUST** be completable with VoiceOver. | P0 |
| NFR-A11Y-03 | Body text **MUST** meet a contrast ratio of at least 4.5:1, and large text at least 3:1. **The "royal letter" aged-paper visual direction is at direct risk here** — sepia text on sepia parchment routinely fails. The theme **MUST** be adapted to meet contrast, not the other way round. | P0 |
| NFR-A11Y-04 | Reduce Motion **MUST** be honored; no essential information may be conveyed by animation alone. | P0 |
| NFR-A11Y-05 | Colour **MUST NOT** be the sole carrier of meaning, including for accuracy labels (FR-CP-05). | P0 |
| NFR-A11Y-06 | Tap targets **MUST** be at least 44×44 pt. | P0 |
| NFR-A11Y-07 | Quest preview **MUST** disclose distance, terrain, steps, and surface honestly enough for a user with mobility limitations to self-assess. The product **MUST NOT** be presented as universally accessible. | P0 |
| NFR-A11Y-08 | Shorter or step-free route variants. | P2 (v5) |

### 7.7 Localization — `NFR-I18N`

| ID | Requirement | Pri |
|---|---|---|
| NFR-I18N-01 | All user-facing strings **MUST** be externalized; none hardcoded. | P0 |
| NFR-I18N-02 | Indonesian and English **MUST** be at full parity. A quest **MUST NOT** ship with one language complete and the other partial. | P0 |
| NFR-I18N-03 | The app **MUST NOT** mix languages within a single lore passage under any fallback condition. | P0 |
| NFR-I18N-04 | Place names **MUST** always render in their official local form regardless of interface language. Translation applies to narration, never to the name of a place. | P0 |
| NFR-I18N-05 | Distances **MUST** use metric units. Times **MUST** use the device's 12/24-hour convention. | P1 |
| NFR-I18N-06 | Content and UI strings **MUST** be versioned together, so a content update cannot desynchronize from its interface. | P1 |

### 7.8 Content and editorial standards — `NFR-CONT`

These are product requirements because violating them damages the product's central claim: that its information can be trusted.

| ID | Requirement | Pri |
|---|---|---|
| NFR-CONT-01 | Every factual claim **MUST** be classified as documented history or oral tradition, and rendered with that classification visible (FR-CP-05). | P0 |
| NFR-CONT-02 | Every checkpoint's lore **MUST** cite at least one source, reachable in-app. | P0 |
| NFR-CONT-03 | Claims requiring field verification — opening hours, dress codes, photography rules, specific architectural details used in tasks, official spellings — **MUST NOT** ship until verified on site. Desk research alone is insufficient. | P0 |
| NFR-CONT-04 | Where sources disagree on a name's spelling, the form used by the managing body **MUST** be authoritative; variants **MAY** be noted. | P1 |
| NFR-CONT-05 | Route distances **MUST** be derived from real walking directions, not haversine with a buffer. | P0 |
| NFR-CONT-06 | Duration estimates **MUST** state walking time and total quest time as separate figures. | P0 |
| NFR-CONT-07 | A factual-correction process **MUST** exist before launch, with a defined owner and a target turnaround. In v1 this necessarily involves an app release; the target **MUST** be stated honestly to users who report errors. | P0 |

### 7.9 Cultural governance — `NFR-GOV`

The highest-impact risk in this product is not technical.

| ID | Requirement | Pri |
|---|---|---|
| NFR-GOV-01 | No Place **MUST** ship in any Quest without a ConsentRecord with `status = granted`. | P0 |
| NFR-GOV-02 | The ConsentRecord **MUST** name the granting body, the individual granting it, their role, the date, and the scope of what was permitted. | P0 |
| NFR-GOV-03 | Consent **MUST** be re-confirmed at least annually, and expiry **MUST** be tracked. | P0 |
| NFR-GOV-04 | Withdrawal of consent **MUST** be actionable within 24 hours through the kill-switch (AD-5), without an app release. | P0 |
| NFR-GOV-05 | Community sources — organizations, juru kunci, pemangku, storytellers — **MUST** be credited in-app. | P0 |
| NFR-GOV-06 | At Places with `is_sacred = true`, game-like mechanics **MUST NOT** be used (FR-TASK-05). This constraint outranks engagement metrics and **MUST NOT** be relaxed on the basis of A/B results. | P0 |
| NFR-GOV-07 | A named individual **MUST** own the community relationship for each region, and this ownership **MUST** be documented rather than implicit. | P0 |
| NFR-GOV-08 | From v4, contributed content **MUST** pass the same consent and accuracy gates as first-party content. | P0 (v4) |

### 7.10 Physical safety — `NFR-SAFE`

| ID | Requirement | Pri |
|---|---|---|
| NFR-SAFE-01 | The app **MUST NOT** deliver turn-by-turn prompts while the user is walking (FR-MAP-03). | P0 |
| NFR-SAFE-02 | Clues **MUST** be written to be read once, at rest, and remembered — short enough to follow without re-reading mid-street. | P0 |
| NFR-SAFE-03 | A safety notice **MUST** be acknowledged before the first Run of each quest, covering traffic, narrow pavements, and the pocket-the-phone model. | P0 |
| NFR-SAFE-04 | Checkpoint positions **MUST** be chosen during field validation as places where a person can safely stand still and read. | P0 |
| NFR-SAFE-05 | No task **MUST** require the user to stand in a roadway, obstruct a walkway, or enter a restricted area. | P0 |

### 7.11 Observability — `NFR-OBS`

| ID | Requirement | Pri |
|---|---|---|
| NFR-OBS-01 | Every metric in the Success Metrics table **MUST** have a corresponding instrumented event before launch. An uninstrumented metric is not a metric. | P0 |
| NFR-OBS-02 | Events **MUST** be persisted locally and flushed opportunistically; no event may be lost to a failed request. | P0 |
| NFR-OBS-03 | The local queue **MUST** be bounded — 30 days or 10,000 events — dropping oldest analytics first and never dropping survey responses or user content. | P0 |
| NFR-OBS-04 | The event schema **MUST** be versioned. | P1 |
| NFR-OBS-05 | Crash reports **MUST** be captured offline and delivered later. | P0 |
| NFR-OBS-06 | Per-checkpoint arrival, departure, dwell time, and manual-override use **MUST** be instrumented, because checkpoint-level drop-off is how v1 is diagnosed. | P0 |

### 7.12 Platform and compatibility — `NFR-PLAT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-PLAT-01 | Minimum iOS version — **TBD, needs decision.** Driven by SwiftData availability (iOS 17+) versus reach. | P0 |
| NFR-PLAT-02 | The app **MUST** support iPhone in portrait. iPad and landscape are not required in v1. | P0 |
| NFR-PLAT-03 | The app **MUST** function on the smallest supported screen without truncation. | P0 |
| NFR-PLAT-04 | Dark mode **MUST** be supported, including the aged-paper theme, without violating NFR-A11Y-03. | P1 |
| NFR-PLAT-05 | Apple Watch support in v1 requires no watchOS target — notification forwarding is a system behavior. A minimum watchOS version therefore **MUST NOT** be declared in v1. | P0 |
| NFR-PLAT-06 | Notification forwarding to the watch only occurs when the iPhone is locked and the watch is worn and unlocked. The feature **MUST** be described to users in those terms, not as a guarantee. | P0 |

### 7.13 Maintainability and content operations — `NFR-MAINT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-MAINT-01 | Adding a quest **MUST NOT** require code changes. Content is data from v1, even while bundled. | P0 |
| NFR-MAINT-02 | Content **MUST** be validated at build time against a schema, and the build **MUST** fail on missing consent references, missing sources, missing accuracy labels, or language gaps. | P0 |
| NFR-MAINT-03 | Actual production hours per quest **MUST** be recorded, because that number determines whether the v3 content-scale strategy is viable. | P0 |
| NFR-MAINT-04 | The v1 local schema **MUST** carry device-generated UUIDs and timestamps on all user records, so that v2 sync does not require a migration of identity. | P0 |

---

## 8. Release acceptance criteria

v1 is not shippable until all of the following hold. These are gates, not aspirations.

1. Both quests have a complete ConsentRecord for every Place, with named grantors. *(NFR-GOV-01, 02)*
2. Both routes have been walked end to end, with distances from real walking directions and all field-verifiable claims confirmed on site. *(NFR-CONT-03, 05)*
3. Content passes build-time schema validation with zero missing sources, accuracy labels, or translations. *(NFR-MAINT-02, NFR-I18N-02)*
4. The complete core loop has been traversed in airplane mode on a physical device. *(NFR-REL-03)*
5. The complete core loop has been traversed with VoiceOver and at the largest Dynamic Type size. *(NFR-A11Y-01, 02)*
6. Contrast has been measured on the final visual theme and meets 4.5:1 for body text. *(NFR-A11Y-03)*
7. Every Success Metric has a firing, verified event. *(NFR-OBS-01)*
8. The kill-switch has been tested end to end: suppress a Place, confirm removal on next launch, confirm graceful failure when the endpoint is unreachable. *(AD-5, FR-ERR-09)*
9. Force-quit during every state transition loses nothing. *(NFR-REL-01)*
10. Privacy labels and policy match actual behavior. *(NFR-PRIV-07, NFR-PRIV-10)*
11. Proximity alert verified in the field: fires on entering a real quest start radius with the app closed and the phone locked, produces a haptic on a paired watch, opens the correct preview on tap, respects quiet hours and rate limits, disables itself cleanly when `Always` is refused, and deregisters every region when switched off. *(FR-PROX-01…13)*
12. Standby battery measured over 24 hours with proximity monitoring on shows no meaningful regression against monitoring off. *(NFR-BAT-05)*
13. Starting a quest from outside the start radius is impossible by every path tested, including the manual override, which requires presence confirmation. *(FR-START-08, 09)*

---

## 9. Traceability

Every P0 functional area exists to serve the hypothesis or to protect against a named risk. Requirements that serve neither are candidates for cutting.

| Requirement group | Serves |
|---|---|
| FR-DISC, FR-CP, FR-TASK, FR-DONE | Core hypothesis: does connected narrative produce completion and recall |
| FR-PROX, FR-WATCH | Discovery for travelers who did not plan the walk — reaches users the quest list never would, and keeps the phone pocketed while doing it |
| FR-SURV, NFR-OBS | Measuring the hypothesis — without these, v1 produces no verdict |
| FR-ARR, FR-ERR, FR-MAP, FR-OFF | Risk: GPS unreliable, map blank offline, signal absent at real checkpoints |
| FR-RUN, NFR-REL | Risk: losing a user's walk to a crash or a dead battery |
| NFR-GOV, FR-TASK-05, FR-SHARE-05, AD-5 | Risk: sacred site objects to being gamified — rated Critical |
| NFR-CONT, FR-CP-05, FR-CP-06 | Risk: historical claim disputed; and the product's own claim to be trustworthy |
| NFR-SAFE, AD-1, FR-MAP-03 | Risk: pedestrian injury — rated Critical |
| NFR-A11Y | Risk: accessibility exclusion |
| FR-DISC-05, FR-DISC-06, FR-ERR-06 | Risk: unexpected cost, closed site mid-quest |
| AD-3, AD-4, NFR-MAINT-04, FR-OFF-04 | Risk: offline-first lost during the v3 CMS migration |

---

## 10. Open questions carried into implementation

Unchanged from the lean PRD unless noted. These block specific requirements rather than the document as a whole.

- Which two routes ship — blocks NFR-GOV-01 sign-off and all content work.
- Minimum iOS version — blocks NFR-PLAT-01 and the SwiftData decision.
- Offline map rendering approach — blocks FR-MAP-01. Candidates: pre-rendered static route images for preview, a custom route-and-pin canvas during a Run, or MapLibre with cached vector tiles.
- Draft retention policy — blocks FR-RUN-05, currently resolved conservatively as "never delete".
- Recall survey coding rubric — blocks the analysis half of FR-SURV, needed before launch rather than after.
- Kill-switch hosting and ownership — blocks AD-5. It is small, but it needs an owner and an uptime expectation.
- `proximity_radius_m` default — blocks FR-PROX-11. 200 m is a placeholder. The right value depends on how the approach actually feels on the ground at each start point, and on how far a walking traveler wants warning; it must come out of field validation, not a spreadsheet.
- Whether a proximity alert should fire for a quest the user has already previewed but not started, more prominently than for one they have never seen — blocks nothing, but it is the difference between a reminder and a discovery.
- App name and branding — blocks submission.
- Actual production hours per quest — blocks the v3 decision, answerable only by producing the first two.

---

*Status: DRAFT. Functional and non-functional requirements only. Implementation planning proceeds via `/plan`.*
