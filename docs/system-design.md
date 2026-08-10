# System Design — Cultural Heritage Quest (iOS)

**Scope:** v1 architecture in full, with the seams that let v2 (accounts + sync) and v3 (CMS) arrive without a rewrite.
**Source of requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`. Requirement IDs referenced inline.
**Companion:** [`schema.md`](schema.md) — content and persistence schemas.

---

## 1. Correction to the PRD: v1 is not backend-free

The PRD says v1 has no backend. That is nearly true and worth stating precisely, because two obligations do require a server:

| Need | Requirement | Shape |
|---|---|---|
| Site kill-switch | AD-5, NFR-GOV-04 | A static JSON file on a CDN. No compute. |
| Recall survey + analytics ingest | FR-SURV-03, NFR-OBS-01/02 | One write-only HTTPS endpoint. No reads, no auth, no user records. |

Without the second, v1 produces no verdict on its own hypothesis — the entire purpose of the release. So v1 has **infrastructure**, not a backend: no database of users, no content API, no login. Both pieces are optional at runtime: the app functions completely when neither is reachable.

Call this tier **Edge Services**. It stays tiny through v2 and is replaced, not extended, by the v3 content platform.

---

## 2. Architecture at a glance

```
┌─────────────────────────────────────────────────────────────┐
│  Presentation — SwiftUI views + @Observable view models      │
│  Discovery · Preview · Arrival · Lore · Task · Summary       │
└───────────────────────────┬─────────────────────────────────┘
                            │  (view models depend on protocols only)
┌───────────────────────────▼─────────────────────────────────┐
│  Application — use cases                                     │
│  StartRun · RecordArrival · CompleteTask · CompleteRun       │
│  ComposeShareCard · SubmitSurvey · EvaluateProximity         │
└──────┬──────────────────────────────────┬───────────────────┘
       │                                  │
┌──────▼──────────────────┐   ┌───────────▼────────────────────┐
│ ContentRepository       │   │ Domain stores (read-write)     │
│ (read-only, protocol)   │   │ RunStore · AwardStore          │
│                         │   │ TelemetryQueue · PhotoStore    │
│ v1: BundledContentRepo  │   │                                │
│ v3: CachedRemoteRepo    │   │ SwiftData + file system        │
└─────────────────────────┘   └────────────────────────────────┘
       │                                  │
┌──────▼──────────────────────────────────▼───────────────────┐
│  Platform services                                           │
│  LocationService · ProximityService · NotificationService    │
│  KillSwitchService · TelemetryFlusher · ShareComposer        │
└──────────────────────────────────────────────────────────────┘
                            │  (opportunistic, never in a user path)
┌───────────────────────────▼─────────────────────────────────┐
│  Edge Services (optional at runtime)                         │
│  suppressions.json (CDN)  ·  POST /ingest                    │
└──────────────────────────────────────────────────────────────┘
```

Two rules hold this together:

1. **Nothing above the platform layer knows whether the network exists.** There is no reachability check in any use case (AD-3).
2. **Content and user data live in separate stores, linked by string IDs, never by object references.** Section 4 explains why this is the load-bearing decision.

---

## 3. Module inventory

| Module | Responsibility | Key requirements |
|---|---|---|
| `ContentKit` | Load, validate, and serve quests and places. Protocol-fronted. | FR-OFF-01, FR-OFF-04, NFR-MAINT-01 |
| `RunEngine` | Run lifecycle, ordering rules, arrival acceptance, awards. | FR-CP-01, FR-RUN-*, FR-DONE-* |
| `LocationKit` | Foreground arrival sampling; accuracy tiering. | FR-ARR-*, NFR-BAT-02/03/04 |
| `ProximityKit` | Region registration and lifecycle; local notifications. | FR-PROX-*, NFR-BAT-05/06 |
| `MediaKit` | Photo capture/import, on-disk storage, share card composition. | FR-TASK-03/04, FR-SHARE-*, NFR-REL-05 |
| `TelemetryKit` | Durable event and survey queue; opportunistic flush. | FR-SURV-03, NFR-OBS-* |
| `GovernanceKit` | Kill-switch fetch, validation, caching, application. | AD-5, NFR-SEC-01/02, FR-ERR-09 |
| `DesignSystem` | Typography, colour, Dynamic Type, contrast-verified theme. | NFR-A11Y-01/03/05 |

`ContentKit` and `RunEngine` have no UIKit, SwiftUI, or CoreLocation imports. They are testable without a device or a simulator, which matters because the ordering and award rules are where correctness bugs hide.

---

## 4. The load-bearing decision: two stores, ID-linked

Content and user data have opposite lifecycles.

- Content is **replaced wholesale** — by an app update in v1, by a CMS fetch in v3.
- User data must **survive every replacement, forever** (FR-DONE-05).

If a `Run` held a SwiftData relationship to a `Quest` object, replacing content would orphan or cascade-delete a user's completed walks. So:

- **Content store** — read-only. Loaded from the bundle, keyed by string IDs (`quest.jejak-terakhir-badung`, `place.puri-agung-pemecutan`).
- **User store** — SwiftData, writable. References content by `questID: String` and `checkpointID: String` plus the pinned `contentVersion`.

### 4.1 Snapshot-on-complete

ID references alone are not enough. AD-4 pins a Run to a content version, and FR-DONE-04 requires the summary to render that pinned version — but v1 ships only one content version per app build, so an old Run's original text would be gone after an update.

Rather than archiving every historical content version on device or on a server, **the Run denormalizes what it needs at the moment each checkpoint completes**: the rendered lore segment, the Place's official name, the accuracy labels, and the source citations are copied into `CheckpointResult`.

This one choice satisfies four requirements at once:

| | |
|---|---|
| FR-DONE-04 | The summary is literally the text the user read. |
| FR-DONE-05 | It renders forever, offline, with no content lookup. |
| FR-RUN-06 | A suppressed Place cannot erase a completed walk. |
| AD-4 | Version pinning needs no version archive. |

Cost is a few kilobytes per Run. It is the cheapest correctness this design buys.

### 4.2 What stays a live lookup

Route geometry, map pins, and preview metadata are read live from content — they are not part of the user's record of what happened, and a corrected distance figure *should* update everywhere.

---

## 5. Content pipeline

```
authoring (JSON + assets)
        │
        ▼
build-time validator ──► fails the build on:
        │                  missing consent reference   (NFR-GOV-01)
        │                  missing source citation     (NFR-CONT-02)
        │                  missing accuracy label      (NFR-CONT-01)
        │                  ID/EN parity gap            (NFR-I18N-02)
        │                  photo task at a prohibited place (FR-TASK-06)
        │                  game mechanic at is_sacred place (FR-TASK-05)
        │                  proximity_radius ≤ arrival_radius (FR-PROX-11)
        │                  blocks_progression == true  (AD-2)
        ▼
app bundle ──► BundledContentRepository ──► ContentRepository (protocol)
```

The validator is the mechanism that turns cultural governance from a promise into a build failure. `NFR-GOV-01` is not enforceable by review discipline at scale; it is enforceable by a script that refuses to produce an `.ipa`.

**v3 swap.** `CachedRemoteContentRepository` implements the same protocol: read from a local cache directory, refresh opportunistically in the background, never block a read. No use case changes. This is the concrete safeguard against the risk *"offline-first lost during the v3 CMS migration."*

---

## 6. Location design

Two behaviors, deliberately separated (AD-1).

### 6.1 Arrival — foreground only

```
ArrivalView appears
   └─ LocationService.start(target: checkpoint)
        ├─ authorization: When In Use
        ├─ distance > 300 m  → desiredAccuracy = .hundredMeters   (NFR-BAT-03)
        ├─ distance ≤ 300 m  → desiredAccuracy = .nearestTenMeters
        ├─ fix within radius AND horizontalAccuracy ≤ radius → ARRIVED  (FR-ARR-01)
        └─ 60 s elapsed, no arrival → reveal manual override        (FR-ARR-03)
ArrivalView disappears
   └─ LocationService.stop()                                        (NFR-BAT-04)
```

`horizontalAccuracy ≤ radius` is the guard that prevents a 500 m-accuracy cell-tower fix from unlocking a 75 m checkpoint. It is also why the manual override is mandatory rather than a nicety (FR-START-10): inside Pasar Badung the accuracy test will fail legitimately and often.

The override at the *start* checkpoint additionally requires a named confirmation (FR-START-09). Everywhere else it is one tap, unpenalized (FR-ARR-04).

### 6.2 Proximity — background regions

```
registerRegions() triggered by: launch · setting toggled on ·
                                Run completed · kill-switch update
   └─ candidate quests = not completed, not suppressed
   └─ v1: all (2 regions)     v3: nearest 20 by coarse location  (FR-PROX-14)
   └─ CLLocationManager.startMonitoring(CLCircularRegion(
          center: quest.startPlace.coordinate,
          radius: quest.proximityRadiusM))

didEnterRegion  (app not running — iOS relaunches into background)
   └─ guard: no active Run                       (FR-PROX-08)
   └─ guard: 07:00 ≤ localTime < 22:00           (FR-PROX-10)
   └─ guard: quest not alerted in last 24 h, < 3 alerts today  (FR-PROX-09)
   └─ schedule UNNotificationRequest (immediate)  (FR-PROX-06)
   └─ write one row: (questID, shownAt)           (NFR-PRIV-09)
   └─ return. No network, no analytics, no other work.  (NFR-BAT-06)
```

The handler must complete in milliseconds. iOS gives a background relaunch a short budget, and everything it could do beyond posting a notification is forbidden by NFR-BAT-06 anyway.

**Apple Watch requires no code.** A local notification on a locked iPhone is forwarded to a worn, unlocked Watch by the system, producing the haptic. There is no watchOS target in v1 (NFR-PLAT-05) and no guarantee to make beyond those conditions (NFR-PLAT-06).

**Authorization reality.** Requesting `Always` on iOS typically yields `When In Use` first, with the system upgrading later or never. `ProximityKit` must treat `Always` as a capability it may not have, disable itself plainly when absent, and leave every other feature untouched (FR-PROX-05).

---

## 7. Core flows

### 7.1 Start a Run

```
tap Start
  └─ content.quest(id) ─► startCheckpoint
  └─ LocationService.awaitArrival(startCheckpoint)
        ├─ arrived (gps)    ─┐
        └─ manual override  ─┤ requires named confirmation (FR-START-09)
                             ▼
     RunEngine.start(questID:, contentVersion:, language:)
        ├─ reject if an active Run exists for this quest → offer resume/restart
        ├─ persist Run(state: .active, currentIndex: 0)      < 500 ms (FR-RUN-01)
        ├─ record CheckpointResult for index 0 + snapshot    (§4.1)
        ├─ award stamp                                       (FR-CP-07)
        └─ enqueue quest_started
```

There is no path from outside the radius (FR-START-08). Preview remains fully available there (FR-DISC-01).

### 7.2 Checkpoint arrival

```
arrival accepted
  └─ persist CheckpointResult + content snapshot
  └─ award stamp                       (independent of tasks, FR-CP-07)
  └─ present lore ─► tasks ─► clue     (ordered, FR-CP-02)
        └─ each task result persisted individually; skip is a first-class outcome
  └─ advance currentIndex
  └─ if last index → CompleteRun
```

Out-of-sequence arrival is rejected with a message naming the expected checkpoint; it never advances state (FR-ARR-06).

### 7.3 Completion

```
CompleteRun
  ├─ Run.state = .completed, completedAt = now
  ├─ award quest badge                       (FR-DONE-02)
  ├─ deregister that quest's proximity region (FR-PROX-08)
  ├─ present recall survey → persist locally BEFORE any send  (FR-SURV-03)
  ├─ present summary from snapshots           (FR-DONE-03/04)
  └─ offer share (optional, never a precondition — FR-SHARE-07)
```

Survey precedes share so that abandoning the share sheet cannot cost the measurement (FR-SURV-04).

---

## 8. State machines

**Run**

```
        ┌──────────┐  start  ┌────────┐  final arrival  ┌───────────┐
        │notStarted├────────►│ active ├────────────────►│ completed │
        └──────────┘         └───┬────┘                 └───────────┘
                                 │ user abandons  ·  place suppressed
                                 ▼
                           ┌───────────┐
                           │ abandoned │
                           └───────────┘
```

`active` persists indefinitely as a draft — no expiry in v1 (FR-RUN-05). `completed` and `abandoned` are terminal; both retain their summary.

**Checkpoint within a Run**

```
locked ──► awaitingArrival ──► arrived ──► loreRead ──► tasksResolved ──► done
                                  │
                       (stamp awarded here, not later)
```

`tasksResolved` is reached by completing *or skipping* every task. Both are resolutions (AD-2).

---

## 9. Concurrency and persistence

Swift 6 strict concurrency.

| Component | Isolation |
|---|---|
| View models | `@MainActor`, `@Observable` |
| `RunEngine` writes | `@ModelActor` — background context, `save()` per transition |
| `LocationService` | actor wrapping `CLLocationManager`, delegate callbacks hopped in |
| `ProximityService` | actor; the region handler avoids the main actor entirely |
| `TelemetryQueue` | actor; append is fire-and-forget from callers |
| Photo writes | detached task with file coordination |

`RunEngine` persists on every transition rather than batching, because NFR-REL-01 admits no lost action and the write volume is trivial — tens of writes per walk.

---

## 10. Telemetry and Edge Services

```
event/survey ─► TelemetryQueue (SwiftData, durable)
                     │
                     │ opportunistic: app foreground, connectivity present
                     ▼
              POST /ingest  (batch, no auth, no user identity)
                     │
              200 ─► mark sent, prune
              else ─► leave queued, retry with backoff
```

Bounds (NFR-OBS-03): 30 days or 10,000 rows. Overflow drops **oldest analytics events first**. Survey responses and any user-authored content are never dropped (FR-ERR-10).

**Privacy shape of an event.** Checkpoint arrival is reported as `{checkpoint_id, arrival_method, accuracy_bucket}` — never coordinates (NFR-PRIV-02). Runs carry an anonymous Run UUID; there is no device, user, or advertising identifier (NFR-PRIV-03/05).

**Kill-switch**

```
launch ─► GET suppressions.json (TLS, schema-validated)
              ├─ valid   ─► cache durably, apply
              ├─ invalid ─► discard, keep last good      (NFR-SEC-02)
              └─ failure ─► keep last good, silent       (FR-ERR-09)
```

Applying a suppression removes the quest from discovery, deregisters its region, and ends any active Run gracefully while preserving the summary (FR-DISC-08, FR-PROX-12, FR-RUN-06). It never blocks launch and never delays a start.

---

## 11. Map rendering

`FR-MAP-01` forbids depending on live tiles, because MapKit has no public offline tile cache and the checkpoints sit exactly where signal fails.

**Recommendation — no basemap during a Run.** Draw the route polyline, checkpoint pins, and the user's position on a plain canvas, with a bearing indicator and remaining straight-line distance (FR-MAP-02). Rendered from route geometry that already ships with the content. Fully offline by construction, and it suits the aged-paper visual direction better than a modern basemap would.

For preview, a pre-rendered static route image per quest, produced at content build time and shipped as an asset.

MapLibre with cached vector tiles remains the only full-fidelity offline option, and it is the fallback if field testing shows users cannot orient without streets. It is a heavier integration and should not be paid for speculatively.

---

## 12. Security and privacy posture

| Surface | Position |
|---|---|
| Data leaving the device (v1) | Only anonymous telemetry and survey text. No photos, no coordinates, no identifiers. |
| Data at rest | Default file protection. Photos in the app container, excluded from iCloud backup only if the user opts out — otherwise backed up as user content. |
| Kill-switch | TLS, schema-validated, hostile responses discarded (NFR-SEC-01/02). |
| Ingest endpoint | Write-only, unauthenticated by design, rate-limited server-side, stores no identity. Accepting junk is preferable to shipping credentials in a bundle (NFR-SEC-03). |
| Photo paths | Stored **relative** to the container. Absolute paths break after a device restore — a classic and silent iOS data-loss bug. |
| Permissions | `When In Use` at first start attempt; `Always` only when the user turns proximity alerts on. Purpose strings describe the single real use (NFR-PRIV-10). |

---

## 13. Platform decision — `NFR-PLAT-01`

**Recommendation: iOS 17.0 minimum, SwiftData.**

iOS 17 is three major versions behind current and carries SwiftData, which removes a large amount of Core Data boilerplate for a schema this small. The counter-argument is reach among domestic travelers on older hardware, which should be checked against current adoption figures before locking — the recommendation is sound but the number is not something to assert without data.

If reach demands iOS 15/16, use Core Data. The schema in `schema.md` maps to either; nothing in this design depends on SwiftData specifically. `RunEngine` talks to a `RunStore` protocol precisely so this stays a swappable decision.

Consider iOS 17.4+ as the floor rather than 17.0 — early SwiftData releases had migration rough edges that are not worth debugging on a first product.

---

## 14. Testing strategy

| Layer | Approach |
|---|---|
| `RunEngine`, `ContentKit` | Pure unit tests. Ordering, award, snapshot, and suppression rules — no device needed. |
| Content | Build-time validation (§5) runs in CI on every content change. |
| Location | `LocationProviding` protocol with a scripted-fix fake: arrival, poor accuracy, timeout, out-of-sequence, permission revoked mid-Run. |
| Persistence | In-memory store; force-quit simulated by discarding the context after each transition and asserting recovery (NFR-REL-01). |
| Offline | Full core loop in airplane mode **on a physical device** — a release gate, not a suite item (NFR-REL-03). |
| Accessibility | Full loop under VoiceOver at largest Dynamic Type; contrast measured on the final theme (NFR-A11Y-01/02/03). |
| Proximity | Field-verified: real radius, app closed, phone locked, Watch worn (acceptance criterion 11). Simulator location injection covers the guard logic only. |
| Battery | 24 h standby measurement, monitoring on versus off (NFR-BAT-05). |

The two items that cannot be faked — airplane-mode traversal and field proximity — are exactly the two most likely to be skipped under deadline. They are listed as release gates in the PRD for that reason.

---

## 15. Evolution seams

| Change | Seam already in place | Work required |
|---|---|---|
| v2 accounts | User rows already carry device UUIDs and timestamps (NFR-MAINT-04) | Add `syncState` and remote ID columns. No identity migration. |
| v2 sync | All writes already go to the local store (AD-3) | Add a reconciliation worker. No use case changes. |
| v2 History Alert | `ProximityKit` region lifecycle exists | Add Place regions and a separate opt-in. Consent is not inherited. |
| v2 Watch app | Notification path exists | Add a watchOS target for in-Run arrival haptics (FR-WATCH-03). |
| v3 CMS | `ContentRepository` protocol | New implementation only. Presentation and application layers untouched. |
| v3 >20 quests | Region registration is already centralized | Add nearest-N selection by coarse location (FR-PROX-14). |

---

## 16. Open items blocking implementation

- **`NFR-PLAT-01`** — iOS floor, which decides SwiftData versus Core Data. Blocks the persistence module.
- **`FR-MAP-01`** — confirm the no-basemap canvas is navigable in the field before committing. Blocks the map module.
- **`proximity_radius_m`** — 200 m is a placeholder; the real value comes from walking each approach. Blocks content, not code.
- **Edge Services ownership** — who hosts `suppressions.json` and `/ingest`, and what uptime is expected. Blocks AD-5 sign-off. Both fit comfortably in a static host plus one serverless function.
- **Survey coding rubric** — needed before launch, not after; it decides whether the free-text field is analyzable at all.

---

*Companion document: [`schema.md`](schema.md).*
