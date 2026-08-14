# Schema — Cultural Heritage Quest

**Two schemas, deliberately separate.** Content is authored, read-only, and replaceable. User data is device-authored, writable, and permanent. They are linked by string IDs, never by object references — see [`system-design.md`](system-design.md) §4 for why this is the load-bearing decision.

| | Content | User data |
|---|---|---|
| Authored by | content team | the device |
| Lifecycle | replaced wholesale on app update (v1) or CMS fetch (v3) | never destroyed |
| Storage | JSON + assets in the app bundle | SwiftData store + file system |
| Mutability | read-only at runtime | read-write |
| Identity | human-readable slugs | UUID v4 generated on device |

---

## Part A — Content schema

### A.1 Layout

```
Content/
├── manifest.json
├── places/
│   ├── puri-agung-pemecutan.json
│   └── …
├── quests/
│   ├── jejak-terakhir-badung.json
│   └── …
├── consent/
│   └── puri-agung-pemecutan.json        # not shipped; validated at build
└── assets/
    ├── places/{place_id}/hero.heic
    ├── quests/{quest_id}/route-preview.png
    ├── quests/{quest_id}/route.geojson
    ├── quests/{quest_id}/hero.png            # discovery card image
    ├── maps/{region}.png                     # illustrated region map (manifest.regionMap)
    └── badges/{badge_id}.png
```

`consent/` is a build input, not a runtime resource. It exists so the validator can refuse to build content whose consent is missing or expired (NFR-GOV-01). Shipping it would put named individuals' details in every user's app for no purpose.

### A.2 Localized text

Every user-facing string is an object, never a bare string. This makes an ID/EN parity gap a structural error the validator can see rather than a runtime surprise.

```json
{ "id": "Gerbang tua Puri Agung Pemecutan.", "en": "The old gate of Puri Agung Pemecutan." }
```

```swift
struct LocalizedText: Codable, Sendable {
    let id: String   // Bahasa Indonesia
    let en: String
    func value(for language: ContentLanguage) -> String { … }  // no fallback — see NFR-I18N-03
}
```

There is deliberately **no fallback**. A missing translation fails the build; it never degrades into a mixed-language lore passage at runtime.

### A.3 `manifest.json`

```json
{
  "schemaVersion": 1,
  "contentBundleVersion": "2026.08.1",
  "languages": ["id", "en"],
  "places": ["puri-agung-pemecutan", "pura-maospahit-gerenceng", "…"],
  "quests": ["jejak-terakhir-badung", "siklus-ubud"],
  "regionMap": { "asset": "maps/bali-illustrated.png", "aspectRatio": 0.4626 }
}
```

`contentBundleVersion` is what a Run pins (AD-4). Any change to any content file **must** bump it.

`regionMap` is optional. When present, the discovery screen offers a map surface drawn from that
shipped illustration — no live tiles, so it works offline by construction (FR-MAP-01, FR-OFF-03).
When absent, the map surface is not offered at all rather than shown empty.

### A.4 Place

```json
{
  "id": "puri-agung-pemecutan",
  "nameOfficial": { "id": "Puri Agung Pemecutan", "en": "Puri Agung Pemecutan" },
  "nameVariants": ["Puri Pemecutan"],
  "type": "puri",
  "isSacred": true,
  "coordinate": { "lat": -8.6584, "lon": 115.2091 },
  "arrivalRadiusM": 75,
  "address": { "id": "Jl. Thamrin No.2, Denpasar Barat", "en": "Jl. Thamrin No.2, West Denpasar" },

  "visitingHours": {
    "notes": { "id": "Cek ulang saat piodalan.", "en": "Re-check during piodalan ceremonies." },
    "weekly": [{ "weekday": 1, "open": "08:00", "close": "17:00" }]
  },
  "dressCode": { "id": "Kamen dan selendang wajib.", "en": "Sarong and sash required." },
  "photoPolicy": { "level": "restricted", "notes": { "id": "…", "en": "…" } },
  "entryCost": { "amount": 0, "currency": "IDR" },
  "accessibility": {
    "hasSteps": true, "stepCount": 6,
    "surface": "paving", "notes": { "id": "…", "en": "…" }
  },

  "loreStandalone": [ /* LoreBlock[] — see A.6 */ ],
  "sources": [
    { "kind": "documented", "citation": "Pemkot Denpasar, profil sejarah", "url": "https://…" },
    { "kind": "oral", "citation": "Wawancara pemangku, media lokal 2023", "url": null }
  ],
  "consentRecordId": "puri-agung-pemecutan"
}
```

| Field | Constraint |
|---|---|
| `id` | `^[a-z0-9-]+$`, permanent, never reused |
| `type` | `puri \| pura \| pasar \| monumen \| museum \| ruang-publik` |
| `isSacred` | drives FR-TASK-05 and FR-SHARE-05 enforcement |
| `arrivalRadiusM` | 30–250; tunable per place without a code change (FR-ARR-07) |
| `photoPolicy.level` | `allowed \| restricted \| prohibited` — `prohibited` bans photo tasks outright (FR-TASK-06) |
| `sources` | ≥ 1 required (NFR-CONT-02) |
| `consentRecordId` | must resolve to a `granted`, unexpired record (NFR-GOV-01) |
| `mapPoint` | `{ x, y }`, each within 0…1 — position on `manifest.regionMap`, required for every Place a quest visits when a region map ships (V17) |

**`mapPoint` is authored, not derived from `coordinate`.** The region map is an illustration:
hand-drawn, taller than the island is, with a stylised coastline. Projecting a real coordinate onto
it would put every pin somewhere wrong while looking precise. A drawing's pin positions are a
drawing decision, so the validator checks the range and not the geography.

### A.5 Quest

```json
{
  "id": "jejak-terakhir-badung",
  "contentVersion": "2026.08.1",
  "title": { "id": "Jejak Terakhir Badung", "en": "Badung's Last Trail" },
  "region": "Denpasar",
  "hookLore": [ /* LoreBlock[] */ ],
  "description": { "id": "…", "en": "…" },

  "route": {
    "totalDistanceM": 2200,
    "distanceSource": "walking-directions",
    "walkingTimeMin": 35,
    "totalDurationMin": 105,
    "geometryAsset": "quests/jejak-terakhir-badung/route.geojson",
    "previewImageAsset": "quests/jejak-terakhir-badung/route-preview.png"
  },

  "estimatedCost": { "amount": 0, "currency": "IDR",
                     "breakdown": [{ "placeId": "…", "amount": 0 }] },
  "terrainSummary": { "id": "…", "en": "…" },
  "recommendedStartWindow": { "from": "08:00", "to": "14:00" },
  "hardLatestStart": "16:15",
  "proximityRadiusM": 200,
  "safetyNotes": { "id": "…", "en": "…" },
  "badgeId": "penjaga-ingatan-badung",
  "heroImageAsset": "quests/jejak-terakhir-badung/hero.jpg",

  "checkpoints": [ /* Checkpoint[] — ordered */ ]
}
```

| Field | Constraint |
|---|---|
| `distanceSource` | must be `walking-directions`; `haversine` fails the build (NFR-CONT-05) |
| `walkingTimeMin` / `totalDurationMin` | both required, must differ (NFR-CONT-06) |
| `hardLatestStart` | derived: earliest checkpoint closing time − `totalDurationMin`; validator recomputes and rejects a stale value |
| `proximityRadiusM` | **must exceed** the start checkpoint's `arrivalRadiusM` (FR-PROX-11) |
| `heroImageAsset` | optional; the photograph the discovery card is built around. A quest without one lists as type on paper rather than as a gap |

### A.6 Checkpoint, LoreBlock, Task

```json
{
  "id": "jtb-cp1",
  "orderIndex": 0,
  "placeId": "puri-agung-pemecutan",
  "role": "start",
  "loreSegment": [
    {
      "text": { "id": "Sekitar tahun 1660, Kyai Gede Raka mendirikan Puri Agung Pemecutan.",
                "en": "Around 1660, Kyai Gede Raka founded Puri Agung Pemecutan." },
      "accuracy": "documented",
      "sourceRefs": [0]
    },
    {
      "text": { "id": "Konon Bhatari Danu memberinya restu kejayaan untuk tanah Badung.",
                "en": "Legend holds that Bhatari Danu granted him a blessing of prosperity." },
      "accuracy": "oral",
      "sourceRefs": [1]
    }
  ],
  "clueToNext": { "id": "Susuri Jalan Sutomo ke utara, cari gerbang yang terbelah dua.",
                  "en": "Follow Jalan Sutomo north; look for the gate split in two." },
  "tasks": [
    { "id": "jtb-cp1-t1", "type": "photo",
      "prompt": { "id": "Foto gerbang utama.", "en": "Photograph the main gate." },
      "blocksProgression": false }
  ],
  "sideQuests": [
    { "id": "jtb-cp1-s1",
      "prompt": { "id": "Cari tahu siapa raja terakhir sebelum 1906.",
                  "en": "Find out who the last king was before 1906." } }
  ],
  "stampId": "stamp-jtb-1"
}
```

**LoreBlock** is the unit that carries epistemic status. Lore is an *array of labelled blocks*, not a paragraph of prose, because FR-CP-05 requires the label to be visible per claim and never hidden behind a tap. A writer cannot produce an unlabelled sentence — there is no field for one.

| `accuracy` | Rendering |
|---|---|
| `documented` | `[Tercatat]` / `[Documented]` |
| `oral` | `[Babad/Cerita rakyat]` / `[Oral tradition]` |

Both labels must be distinguishable without colour (NFR-A11Y-05).

**Task** — `type` is `photo \| reflection \| question`. `blocksProgression` must be `false` for every task in v1; the field exists so AD-2 is auditable by a script rather than by memory.

### A.7 ConsentRecord — build input only

```json
{
  "placeId": "puri-agung-pemecutan",
  "grantingBody": "Puri Agung Pemecutan",
  "grantedByName": "…",
  "grantedByRole": "…",
  "grantedAt": "2026-07-14",
  "expiresAt": "2027-07-14",
  "scope": ["inclusion", "photography", "naming"],
  "documentRef": "consent/2026/puri-agung-pemecutan-signed.pdf",
  "status": "granted",
  "regionOwner": "…"
}
```

`regionOwner` is the named individual accountable for the relationship (NFR-GOV-07). A record without one fails validation, because "the team" owning a relationship means nobody does.

### A.8 Suppression list — the only runtime remote document

Served as a static file (AD-5).

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-08-10T09:00:00Z",
  "suppressedPlaceIds": [],
  "suppressedQuestIds": []
}
```

Schema-validated before use; anything malformed is discarded in favour of the last cached copy (NFR-SEC-02).

### A.9 Build-time validation rules

CI fails on any of these. This is the enforcement mechanism for requirements that review discipline cannot hold at scale.

| # | Rule | Requirement |
|---|---|---|
| V1 | Every `LocalizedText` has non-empty `id` and `en` | NFR-I18N-02 |
| V2 | Every `Place.sources` has ≥ 1 entry | NFR-CONT-02 |
| V3 | Every `LoreBlock` has `accuracy` and ≥ 1 `sourceRefs` | NFR-CONT-01 |
| V4 | Every `Place.consentRecordId` resolves; status `granted`; `expiresAt` in the future | NFR-GOV-01/03 |
| V5 | Every ConsentRecord has `grantedByName`, `grantedByRole`, `regionOwner` | NFR-GOV-02/07 |
| V6 | No photo task at a Place with `photoPolicy.level == "prohibited"` | FR-TASK-06 |
| V7 | No task type outside {photo, reflection, question} at `isSacred` Place | FR-TASK-05 |
| V8 | Every `blocksProgression == false` | AD-2 |
| V9 | `checkpoints` `orderIndex` contiguous from 0; exactly one `start`, one `finish` | FR-CP-01 |
| V10 | `clueToNext` non-null for all but the final checkpoint; null for the final | FR-CP-02 |
| V11 | `distanceSource == "walking-directions"` | NFR-CONT-05 |
| V12 | `proximityRadiusM > startCheckpoint.place.arrivalRadiusM` | FR-PROX-11 |
| V13 | `arrivalRadiusM` within 30–250 | FR-ARR-07 |
| V14 | Every asset path referenced exists | — |
| V15 | Total content payload ≤ 200 MB (leaves headroom under the 250 MB app budget) | NFR-PERF-07 |
| V16 | `hardLatestStart` matches recomputation from visiting hours | FR-DISC-06 |
| V17 | When `manifest.regionMap` is present, every Place a quest visits has a `mapPoint` within 0…1 | FR-DISC-02/03 |
| V18 | `route.geometryAsset` parses as a GeoJSON FeatureCollection carrying a LineString of ≥ 2 points | FR-MAP-02 |

**V18 exists because V14 stops at the filename.** The run map draws the route from
`route.geometryAsset`, so a file that is present but is not a route — a placeholder, a bare geometry
object, a line of one vertex — degrades to a blank canvas at the one moment the walker is standing in
a street looking for a gate. The rule reads the bytes, which is why `AssetInventory` has `data(_:)`
alongside `exists(_:)`; an inventory that cannot supply bytes simply does not run the rule.

**Two rules cannot run against decoded content**, because the type system makes their violations
unrepresentable: `LocalizedText` refuses to decode with a gap (V1) and `TaskType` has only the three
mechanics FR-TASK-05 permits (V7). Both remain perfectly *authorable*, so both run over the raw JSON
instead — otherwise a translation gap surfaces as an opaque `keyNotFound` naming no requirement, and
a puzzle task at a temple as an unreadable enum error. A consequence worth knowing: a V1 gap blocks
the decode-dependent rules rather than merely adding a finding, so content with several faults may
need fixing in two passes.

---

## Part B — Local persistence schema

SwiftData models. Every user record carries a device-generated UUID and timestamps from v1, so v2 sync needs no identity migration (NFR-MAINT-04).

### B.1 Entity map

```
RunRecord ──1:N──► CheckpointResultRecord ──1:N──► TaskResultRecord
    │
    ├──1:N──► AwardRecord
    └──0:1──► SurveyResponseRecord

TelemetryEventRecord      (standalone)
ProximityAlertRecord      (standalone)
AppStateRecord            (singleton)
```

No relationships cross into content. Content is referenced by `String` id plus `contentVersion`.

### B.2 `RunRecord`

```swift
@Model
final class RunRecord {
    #Index<RunRecord>([\.questID], [\.stateRaw], [\.updatedAt])

    @Attribute(.unique) var id: UUID
    var questID: String            // content reference — not a relationship
    var contentVersion: String     // pinned at start (AD-4)
    var languageRaw: String        // pinned at start
    var stateRaw: String           // notStarted | active | completed | abandoned
    var currentCheckpointIndex: Int

    var startedAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var abandonedAt: Date?
    var abandonReasonRaw: String?  // userChoice | placeSuppressed

    // v2 additions — absent in v1, no migration of identity needed
    // var syncState: String
    // var remoteID: String?

    @Relationship(deleteRule: .cascade, inverse: \CheckpointResultRecord.run)
    var checkpointResults: [CheckpointResultRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \AwardRecord.run)
    var awards: [AwardRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \SurveyResponseRecord.run)
    var survey: SurveyResponseRecord?
}
```

**Invariant:** at most one `RunRecord` per `questID` with `state == .active` (FR-START-06). Enforced in `RunEngine`, not by a unique constraint, because SwiftData cannot express a partial unique index.

### B.3 `CheckpointResultRecord` — where the snapshot lives

```swift
@Model
final class CheckpointResultRecord {
    @Attribute(.unique) var id: UUID
    var run: RunRecord?
    var checkpointID: String
    var orderIndex: Int

    var arrivedAt: Date
    var arrivalMethodRaw: String       // gps | manual
    var gpsAccuracyM: Double?          // last known accuracy, incl. for manual
    var loreFirstOpenedAt: Date?
    var loreDwellMs: Int?
    var stampAwardedAt: Date?

    // ── Content snapshot, captured at arrival (system-design §4.1) ──
    var snapshotPlaceName: String
    var snapshotLoreJSON: Data         // [LoreBlockSnapshot] in the Run's language
    var snapshotSourcesJSON: Data
    var snapshotContentVersion: String

    @Relationship(deleteRule: .cascade, inverse: \TaskResultRecord.checkpointResult)
    var taskResults: [TaskResultRecord] = []
}
```

```swift
struct LoreBlockSnapshot: Codable, Sendable {
    let text: String          // already resolved to the Run's language
    let accuracy: String      // documented | oral
    let sourceCitations: [String]
}
```

The snapshot is the reason a completed walk renders identically forever — after a content correction, after a Place is suppressed, with no network and no content lookup. It satisfies FR-DONE-04, FR-DONE-05, and FR-RUN-06 together.

### B.4 `TaskResultRecord`

```swift
@Model
final class TaskResultRecord {
    @Attribute(.unique) var id: UUID
    var checkpointResult: CheckpointResultRecord?
    var taskID: String
    var typeRaw: String                // photo | reflection | question
    var skipped: Bool                  // a first-class outcome, not a failure (AD-2)
    var completedAt: Date

    var photoRelativePath: String?     // RELATIVE to the container — never absolute
    var text: String?                  // reflection or question answer
}
```

> **Photo paths must be relative.** Container paths change on restore from backup and between installs. An absolute path silently resolves to nothing after a user restores their phone, and their photographs appear to have vanished. Store `photos/{runID}/{checkpointID}.heic` and resolve it against the container at read time (NFR-REL-05).

### B.5 `AwardRecord`

```swift
@Model
final class AwardRecord {
    @Attribute(.unique) var id: UUID
    var run: RunRecord?
    var typeRaw: String                // stamp | badge
    var sourceID: String               // stampId or badgeId from content
    var snapshotName: String           // survives content changes
    var awardedAt: Date
}
```

Cross-quest badges (v2, e.g. the Lempad link) are awarded with `run == nil` and a `sourceID` naming the achievement.

### B.6 `SurveyResponseRecord`

```swift
@Model
final class SurveyResponseRecord {
    @Attribute(.unique) var id: UUID
    var run: RunRecord?
    var questionID: String
    var text: String
    var createdAt: Date
    var syncStateRaw: String           // pending | sent
}
```

Persisted before any transmission is attempted (FR-SURV-03), and never dropped by queue pruning (FR-ERR-10). This row is the entire measurement apparatus for the product's core hypothesis.

### B.7 `TelemetryEventRecord`

```swift
@Model
final class TelemetryEventRecord {
    #Index<TelemetryEventRecord>([\.createdAt], [\.syncStateRaw])

    @Attribute(.unique) var id: UUID
    var name: String
    var paramsJSON: Data
    var createdAt: Date
    var syncStateRaw: String           // pending | sent
    var schemaVersion: Int
}
```

Bounded at 30 days or 10,000 rows; prune drops the **oldest `pending` analytics events first** and never touches `SurveyResponseRecord` (NFR-OBS-03).

**Event catalogue** — one per Success Metric, because an uninstrumented metric is not a metric (NFR-OBS-01):

| Event | Params | Serves |
|---|---|---|
| `quest_started` | questID, contentVersion, language | completion rate denominator |
| `checkpoint_arrived` | checkpointID, orderIndex, arrivalMethod, accuracyBucket | drop-off, GPS failure rate |
| `checkpoint_departed` | checkpointID, dwellMs | median time-on-checkpoint |
| `task_resolved` | taskID, type, skipped | task friction |
| `quest_completed` | questID, durationMin, manualOverrideCount | completion rate numerator |
| `quest_abandoned` | questID, lastOrderIndex, reason | drop-off diagnosis |
| `quest_resumed` | questID, daysSinceAbandon | draft resume rate |
| `share_sheet_presented` | questID | share rate |
| `survey_submitted` \| `survey_skipped` | questID | recall response rate |
| `proximity_alert_shown` \| `proximity_alert_opened` | questID | proximity value |

`accuracyBucket` is a band (`<20m`, `20–75m`, `>75m`), never a coordinate (NFR-PRIV-02).

### B.8 `ProximityAlertRecord`

```swift
@Model
final class ProximityAlertRecord {
    @Attribute(.unique) var id: UUID
    var questID: String
    var shownAt: Date
}
```

The **only** record of a region entry. No coordinates, no dwell, no trajectory — a movement history is exactly what NFR-PRIV-09 forbids. Rows older than 7 days are pruned; they exist solely to enforce the rate limits in FR-PROX-09.

### B.9 `AppStateRecord`

```swift
@Model
final class AppStateRecord {
    @Attribute(.unique) var id: String = "singleton"
    var preferredLanguageRaw: String?
    var proximityAlertsEnabled: Bool = false      // default off (FR-PROX-03)
    var onboardingCompletedAt: Date?
    var safetyNoticeAckedQuestIDs: [String] = []  // FR-START-04
    var cachedSuppressionJSON: Data?              // last good (FR-ERR-09)
    var cachedSuppressionFetchedAt: Date?
    var installedContentVersion: String?
}
```

### B.10 Query paths

| Screen | Query |
|---|---|
| Home — resume banner | `RunRecord` where `stateRaw == "active"`, sort `updatedAt` desc, limit 1 |
| Home — completed list | `RunRecord` where `stateRaw == "completed"`, sort `completedAt` desc |
| Summary | one `RunRecord` by id + cascaded children; **no content access** — snapshots only |
| Telemetry flush | `TelemetryEventRecord` where `syncStateRaw == "pending"`, sort `createdAt`, limit 200 |
| Proximity rate check | `ProximityAlertRecord` where `questID == X` and `shownAt > now-24h`; plus count where `shownAt > startOfDay` |

Indexes on `RunRecord.questID`, `RunRecord.stateRaw`, `RunRecord.updatedAt`, `TelemetryEventRecord.createdAt`, `TelemetryEventRecord.syncStateRaw`. At v1 volumes — tens of runs, thousands of events — these are precautionary rather than necessary, and cost nothing to add now.

### B.11 Retention

| Data | v1 policy |
|---|---|
| Active drafts | never expire (FR-RUN-05) |
| Completed runs, photos, awards | never deleted except by the user (FR-SET-02) |
| Telemetry events | 30 days or 10,000 rows |
| Proximity alert log | 7 days |
| Suppression cache | replaced on successful fetch; otherwise kept indefinitely |

`FR-SET-02` deletion must remove SwiftData rows **and** the photo directory. Deleting the store alone leaves orphaned image files on disk — a privacy failure that passes every database test.

---

## Part C — Migration

### C.1 v1 → v2 (accounts and sync)

Additive only.

```swift
// RunRecord, CheckpointResultRecord, TaskResultRecord, AwardRecord, SurveyResponseRecord
var syncState: String = "local"     // local | pending | synced
var remoteID: String?
var lastSyncedAt: Date?
```

No identity migration is needed because UUIDs and timestamps already exist (NFR-MAINT-04). This is the entire payoff of that requirement: a schema change instead of a data rewrite.

Conflict rule: the device that authored the content wins (FR-SYNC-02). With one account per person the case is rare; the rule exists so it is decided in advance rather than during an incident.

### C.2 v2 → v3 (CMS)

The user schema does not change. Content moves from the bundle to a cache directory with a version manifest, behind the same `ContentRepository` protocol.

Because Runs snapshot their content (§B.3), a Run started under bundled content and finished after a CMS migration still renders correctly. The migration cannot corrupt history — it was designed out.

### C.3 Rules for every future change

1. **Never** add a SwiftData relationship from a user record to a content entity.
2. **Never** widen a snapshot field's meaning after release — add a new field.
3. **Never** delete an entity type; mark it withdrawn and stop writing to it.
4. Every new user record carries `id: UUID`, `createdAt`, `updatedAt` on day one.
5. Every migration ships with a test that loads a v1-era store and asserts a completed Run still renders.

---

## Appendix — Type reference

```swift
enum ContentLanguage: String, Codable, Sendable { case id, en }
enum PlaceType: String, Codable, Sendable { case puri, pura, pasar, monumen, museum, ruangPublik }
enum PhotoPolicyLevel: String, Codable, Sendable { case allowed, restricted, prohibited }
enum AccuracyLabel: String, Codable, Sendable { case documented, oral }
enum CheckpointRole: String, Codable, Sendable { case start, middle, finish }
enum TaskType: String, Codable, Sendable { case photo, reflection, question }

enum RunState: String, Codable, Sendable { case notStarted, active, completed, abandoned }
enum AbandonReason: String, Codable, Sendable { case userChoice, placeSuppressed }
enum ArrivalMethod: String, Codable, Sendable { case gps, manual }
enum AwardType: String, Codable, Sendable { case stamp, badge }
enum SyncState: String, Codable, Sendable { case pending, sent }
```

Enums are stored as raw `String`, not `Int`. A persisted integer becomes unreadable the moment someone reorders a case; a string survives it.

---

*Companion document: [`system-design.md`](system-design.md).*
