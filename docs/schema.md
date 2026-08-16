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
├── sidequests/
│   └── sq-catur-muka.json                    # schema 2 (§A.10)
├── collections/
│   └── bali-the-explorer.json                # schema 2 (§A.11)
├── consent/
│   └── puri-agung-pemecutan.json        # not shipped; validated at build
└── assets/
    ├── places/{place_id}/hero.heic
    ├── quests/{quest_id}/route-preview.png
    ├── quests/{quest_id}/route.geojson
    ├── quests/{quest_id}/hero.png            # discovery card image
    ├── sidequests/{side_quest_id}/hero.jpg   # optional notice-card image
    ├── maps/{region}.png                     # illustrated region map (manifest.regionMap)
    └── badges/{badge_id}.png
```

A sidequest's place is an ordinary `Place` in `places/`, with an ordinary consent record in
`consent/`. That is the main reason a sidequest points at a Place rather than carrying its own
coordinate and hours: V2, V4, V5, V13 and V15 cover it with no new rule.

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
  "schemaVersion": 2,
  "contentBundleVersion": "2026.09.0",
  "languages": ["id", "en"],
  "places": ["puri-agung-pemecutan", "pura-maospahit-gerenceng", "…"],
  "quests": ["jejak-terakhir-badung", "siklus-ubud"],
  "sideQuests": ["sq-catur-muka", "…"],
  "collections": ["bali-the-explorer"],
  "regionMap": { "asset": "maps/bali-illustrated.png", "aspectRatio": 0.4626 }
}
```

`contentBundleVersion` is what a Run pins (AD-4). Any change to any content file **must** bump it.

`schemaVersion` is **2**. `sideQuests` and `collections` (§A.10, §A.11) both decode with a default of
`[]`, so a bundle authored against schema 1 still loads and simply has no sidequests — which is what
a content rollback has to be able to do. Manifest order decides list order here as it already does
for quests: directory enumeration order is a filesystem detail and would reshuffle a collection
between machines.

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
  "bonusPrompts": [
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

**BonusPrompt** — the `bonusPrompts[]` entries above. Optional suggestions, decoded and tracked by
nothing (FR-TASK-08/09). The key read `sideQuests[]` and the type was `ContentKit.SideQuest` until
the FR-SIDE amendment (PRD §5.15) claimed that word for the entity in §A.10; the concept and its
requirement IDs are unchanged, only the name moved, so that *sidequest* names one thing. Renaming a
content key bumps `contentBundleVersion`.

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
  "schemaVersion": 2,
  "updatedAt": "2026-08-15T09:00:00Z",
  "suppressedPlaceIds": [],
  "suppressedQuestIds": [],
  "suppressedSideQuestIds": []
}
```

Schema-validated before use; anything malformed is discarded in favour of the last cached copy (NFR-SEC-02).

**`suppressedSideQuestIds` and the bump to schema 2.** The kill-switch has authority over sidequests as well (`FR-SIDE-14`, sidequest plan `s3` §7): a withdrawn sidequest leaves every surface and its region is deregistered on next launch, while **the letter it already awarded is retained** — the record is a snapshot and the walk happened.

Two rules on the new array, and the second is the one that bites:

- Suppressing a **place** already suppresses the sidequests standing at it: `ContentRepository.sideQuests(suppressingSideQuestIDs:suppressingPlaceIDs:)` filters on either set. The new array is for withdrawing one story while the place itself stays walkable, which is the likelier request.
- **Decode it as `decodeIfPresent … ?? []`.** A validator that rejects a schema-1 document sends the app to its last good copy (NFR-SEC-02, FR-ERR-09), and the failure mode is a withdrawal that silently stops applying — the exact thing AD-5 exists to prevent. A schema-1 file must keep validating and simply carry no sidequests, the same way `manifest.json` already tolerates a bundle authored before its own two new arrays existed (§A.3).

The server side of this document is `docs/backend-supabase.md` §6.1, where `ops.suppressions.entity_type` gains `'sidequest'` alongside `'place'` and `'quest'`.

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
| V19 | Every `SideQuest.placeId` resolves, and that Place is listed in `manifest.places` | FR-SIDE-02, NFR-GOV-01 |
| V20 | `triggerRadiusM` within 30–250; `noticeRadiusM > triggerRadiusM` | FR-ARR-07, FR-PROX-11 |
| V21 | Every sidequest `LoreBlock` has `accuracy` and resolvable `sourceRefs` | NFR-CONT-01, FR-SIDE-04 |
| V22 | A quiz has 2–4 distinct `options` and a `correctIndex` inside that range | FR-SIDE-06 |
| V23 | No photo challenge at a Place with `photoPolicy.level == "prohibited"` | FR-TASK-06, FR-SIDE-13 |
| V24 | Every sidequest fills exactly one slot, in exactly one collection | FR-SIDE-05 |
| V25 | `slots.count` equals `phrase` with spaces removed, and each slot's `letter` matches the phrase at its position | FR-SIDE-08 |
| V26 | Slot indices contiguous from 0; each `sideQuestId` resolves and appears once | FR-SIDE-08 |
| V27 | A collection has at most 20 sidequests | FR-PROX-14, FR-SIDE-16 |
| V28 | Every sidequest asset path referenced exists | — |

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

**V24 is bidirectional and that is the point.** A sidequest with no slot is a place the walker can
complete for no letter; a slot with no sidequest is a letter nobody can earn. Both are silent in the
app and loud in the validator.

**V27 is a hardware limit dressed as a content rule.** iOS monitors 20 regions per app, and quest
start regions share that budget, so the real ceiling is lower than 20 and this rule is a backstop
rather than a guarantee. Without it, the twenty-first place simply never notifies — indistinguishable,
in the field, from a GPS problem. The runtime half is nearest-N selection (FR-SIDE-16).

### A.10 SideQuest — schema 2

A single-place activity outside any quest: one story, one challenge, one letter (PRD §5.15). It is
never part of a Run and never blocks one (FR-SIDE-01).

```json
{
  "id": "sq-catur-muka",
  "placeId": "catur-muka",
  "title": { "id": "Catur Muka", "en": "Catur Muka" },
  "synopsis": { "id": "Arca berwajah empat di persimpangan kota.",
                "en": "A four-faced statue at the city crossroads." },
  "lore": [
    { "text": { "id": "Arca ini berdiri di catus patha.", "en": "The statue stands on the catus patha." },
      "accuracy": "documented", "sourceRefs": [0] }
  ],
  "challenge": {
    "type": "quiz",
    "question": { "id": "Berapa wajah yang dimiliki arca ini?", "en": "How many faces does this statue have?" },
    "options": [ { "id": "Dua", "en": "Two" }, { "id": "Tiga", "en": "Three" }, { "id": "Empat", "en": "Four" } ],
    "correctIndex": 2,
    "explanation": { "id": "Empat wajah menghadap empat penjuru catus patha.",
                     "en": "The four faces look out along the catus patha crossroads." }
  },
  "triggerRadiusM": 75,
  "noticeRadiusM": 250
}
```

The photo variant, for a Place where photography is not prohibited (V23):

```json
{ "type": "photo",
  "prompt": { "id": "Foto gerbang bata merahnya.", "en": "Photograph the red brick gateway." } }
```

`challenge` is a closed enum with a `type` discriminator, so an unknown mechanic is a decode failure
rather than a silently ignored challenge. `TaskType` is **not** reused: it belongs to checkpoint
tasks, whose `blocksProgression` rule (AD-2, V8) must keep meaning exactly what it means today, and
hanging a second concept off it would make V8 ambiguous. FR-TASK-05's limit at sacred places is met
by construction — quiz is the single light question, photo is photo, and nothing else is
representable.

`triggerRadiusM` is the arrival gate, applied by the same `ArrivalEvaluator` and the same two
conditions as a checkpoint (FR-ARR-01, FR-SIDE-02). `noticeRadiusM` is the monitored region and must
be larger: the alert warns on approach, it does not confirm arrival.

There is deliberately **no `contentVersion`**. A Quest carries one because a Run pins it at start; a
sidequest record pins `manifest.contentBundleVersion` at discovery (FR-SIDE-10), which is the same
fact without a second place to keep it. `heroImageAsset` is optional.

### A.11 LetterCollection — schema 2

```json
{
  "id": "bali-the-explorer",
  "region": "Bali",
  "phrase": "BALI THE EXPLORER",
  "title":   { "id": "Bali the Explorer", "en": "Bali the Explorer" },
  "caption": { "id": "Kumpulkan satu huruf di setiap tempat.",
               "en": "Collect one letter at each place." },
  "badgeId": "badge-bali-the-explorer",
  "slots": [
    { "index": 0, "letter": "B", "sideQuestId": "sq-puri-agung-pemecutan" },
    { "index": 1, "letter": "A", "sideQuestId": "sq-pura-maospahit" }
  ]
}
```

`phrase` is a plain `String` and **not** a `LocalizedText`. That is a product constraint, accepted
2026-08-15 (PRD §5.15, decision 2): translating it changes the letter count, which changes the number
of places, which forks the content tree per language. `caption` beside it is localized, so
NFR-I18N-01 still holds for every sentence the user reads.

Spaces in `phrase` are display only and get no slot: `BALI THE EXPLORER` is 15 letters and therefore
15 slots and 15 places — each with its own consent record and its own citations. `letter` is a
`String` rather than a `Character` because `Character` has no stable JSON representation; V25 compares
it against the phrase position by position, so a phrase needing a digraph would need V25 revisited.

FR-SIDE-08 governs how a slot renders, not how it is authored: an unearned slot shows a blank and
names the place that fills it, never the letter.

---

## Part B — Local persistence schema

SwiftData models. Every user record carries a device-generated UUID and timestamps from v1, so v2 sync needs no identity migration (NFR-MAINT-04).

### B.1 Entity map

```
RunRecord ──1:N──► CheckpointResultRecord ──1:N──► TaskResultRecord
    │
    ├──1:N──► AwardRecord
    └──0:1──► SurveyResponseRecord

SideQuestRecord ──0:1──► SideQuestChallengeResult   (PRD §5.15)
    └──1:N──► AwardRecord

TelemetryEventRecord      (standalone)
ProximityAlertRecord      (standalone)
AppStateRecord            (singleton)
```

No relationships cross into content. Content is referenced by `String` id plus `contentVersion`.

`SideQuestRecord` has **no** edge to `RunRecord`, and that absence is the whole of `FR-SIDE-01`: a sidequest that could reach a Run is a sidequest that can change one. It is a separate aggregate with a separate store, for the reasons in `.claude/plans/sidequest/s0-scope-and-decisions.plan.md` D1.

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
    var typeRaw: String                // stamp | badge | letter
    var sourceID: String               // stampId, badgeId, or a slot's sideQuestId
    var snapshotName: String           // survives content changes
    var awardedAt: Date
}
```

Cross-quest badges (v2, e.g. the Lempad link) are awarded with `run == nil` and a `sourceID` naming the achievement.

`letter` arrived with PRD §5.15 (`FR-SIDE-05`) and is held by a `SideQuestRecord`, never by a Run. Adding a case to a raw-`String` enum is safe for stored data; adding one to a raw-`Int` enum is not, which is why the Appendix requires string raws in the first place.

A **collection badge** (`FR-SIDE-09`) is the exception that proves the rule: it is not stored at all. It is derived from the records that fill the collection's slots, with a deterministic id, so "awarded once" is true by construction rather than by a guard — see `RunEngine.LetterCollectionProgress`.

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

**Sidequests — PRD §5.15, proposed with the `FR-SIDE` block.** The sidequest feature adds six screens and a second engagement loop, and specifies no telemetry at all. That is a gap rather than a decision: NFR-OBS-01 is explicit that an uninstrumented metric is not a metric, and every row above exists because a quest metric would otherwise be unmeasurable. `TelemetryEventRecord` needs no change — `paramsJSON` absorbs these — so this is a catalogue addition and a `schemaVersion` bump on the envelope.

| Event | Params | Serves |
|---|---|---|
| `sidequest_alert_shown` \| `sidequest_alert_opened` | sideQuestID | whether the notification is worth the `Always` permission it costs |
| `sidequest_discovered` | sideQuestID, arrivalMethod, accuracyBucket | how often the FR-ARR-01 gate fails in the field, and whether it fails differently than at a checkpoint |
| `sidequest_quiz_resolved` | sideQuestID, attempts, wasRevealed | which questions are badly written. `SideQuestChallengeResult` keeps `attempts` for exactly this (§B.13) and nothing carries it off the device today |
| `sidequest_completed` | sideQuestID, collectionID | letter conversion — how many people who open a story finish one |
| `collection_completed` | collectionID, durationDays | whether a collection is finishable at all |

Three constraints these inherit:

- **No Run key.** `docs/backend-supabase.md` §2.4 gives each Run a pseudonymous `run_key` so the funnel stays analysable without a join back to a person. A sidequest has no Run, and minting a second key to correlate one walker's sidequests across a region would rebuild precisely what that decision prevents. These events are single-shot; there is no funnel to reconstruct.
- `accuracyBucket` stays a band, as above (NFR-PRIV-02).
- They are **analytics, not survey data**, so they prune with everything else at 30 days. FR-ERR-10's never-drop protection covers `SurveyResponseRecord` only.

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

Reused as authored for sidequests (PRD §5.15, `FR-SIDE-11`). `questID` becomes a target id in one namespace shared with sidequests — the daily cap in `FR-PROX-09` is a cap on *interruptions*, and the walker does not care which feature produced one. `RunEngine.ProximityAlert` is the value form of this row, and `RunEngine.ProximityGate` is the rule that reads it; both are pure so quiet hours and rate limits are testable without a device (`s0` D10).

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
| Sidequest notice / story | one `SideQuestRecord` by `sideQuestID`; **no content access** for anything already snapshotted |
| Collection screen | `SideQuestRecord` where `collectionID == X`, sorted `slotIndex`, joined to the content collection's slots |

Indexes on `RunRecord.questID`, `RunRecord.stateRaw`, `RunRecord.updatedAt`, `TelemetryEventRecord.createdAt`, `TelemetryEventRecord.syncStateRaw`. At v1 volumes — tens of runs, thousands of events — these are precautionary rather than necessary, and cost nothing to add now.

### B.11 Retention

| Data | v1 policy |
|---|---|
| Active drafts | never expire (FR-RUN-05) |
| Completed runs, photos, awards | never deleted except by the user (FR-SET-02) |
| Sidequest records and earned letters | never expire; deleted only by the user (FR-SET-02) or, in part, by content withdrawal never touching them at all (FR-SIDE-14) |
| Telemetry events | 30 days or 10,000 rows |
| Proximity alert log | 7 days |
| Suppression cache | replaced on successful fetch; otherwise kept indefinitely |

`FR-SET-02` deletion must remove SwiftData rows **and** the photo directory. Deleting the store alone leaves orphaned image files on disk — a privacy failure that passes every database test. From PRD §5.15 it must also remove `SideQuestRecord`s: erasure that leaves the letters behind is a lie told by a confirmation dialog.

### B.12 `SideQuestRecord` — PRD §5.15

```swift
@Model
final class SideQuestRecord {
    #Index<SideQuestRecord>([\.sideQuestID], [\.collectionID], [\.updatedAt])

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var sideQuestID: String   // at most one record per sidequest
    var placeID: String
    var collectionID: String
    var slotIndex: Int
    var letter: String                 // the letter, copied (FR-SIDE-10)

    var languageRaw: String
    var contentVersion: String         // manifest.contentBundleVersion, pinned at discovery

    var discoveredAt: Date
    var arrivalMethodRaw: String       // gps | manual
    var gpsAccuracyM: Double?

    // Content snapshot, captured at discovery
    var snapshotPlaceName: String
    var snapshotTitle: String
    var snapshotSynopsis: String
    var snapshotLoreJSON: Data         // [LoreBlockSnapshot]

    var stateRaw: String               // discovered | completed
    var loreFirstOpenedAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var challenge: SideQuestChallengeResult?
    @Relationship(deleteRule: .cascade) var awards: [AwardRecord]
}
```

**`sideQuestID` is unique, and that is `FR-SIDE-05` expressed in the schema rather than in a guard somebody can forget to write.** A walker who passes a place twice on the same afternoon must not get two rows, and re-entering a completed sidequest must find the existing record rather than mint a second letter.

The snapshot is the same denormalization `CheckpointResultRecord` makes and for the same reason (§4.1, `AD-4`): the letter especially has to survive the content that described the place, because a collection is a record of where somebody has been (`FR-SIDE-10`, `FR-SIDE-14`).

Collection progress (`FR-SIDE-08`) is **not** a model. It is computed from the content collection plus these records on every read; storing it would create a second source of truth for "how far am I", and the two would drift the first time a record was deleted by erasure.

v1 ships this as one JSON document per record under `Application Support/Kultara/sidequests` (`RunEngine.FileSideQuestStore`), mirroring `FileRunStore` — SwiftData is a swap behind `SideQuestStore`, never a call in front of it.

### B.13 `SideQuestChallengeResult` — PRD §5.15

```swift
@Model
final class SideQuestChallengeResult {
    @Attribute(.unique) var id: UUID
    var kindRaw: String                // quiz | photo
    var promptSnapshot: String         // the question as it was asked
    var attempts: Int                  // every attempt, right or wrong
    var chosenOptionSnapshot: String?
    var isCorrect: Bool?
    var wasRevealed: Bool              // shown after three attempts (FR-SIDE-06)
    var photoRelativePath: String?     // relative to the app container (NFR-REL-05, FR-SIDE-13)
    var answeredAt: Date
}
```

`attempts` is kept deliberately: a question everyone gets wrong three times is a badly written question, and this row is the only place that would show it. It is never read to reduce a reward — `FR-SIDE-06` awards the letter on a revealed answer exactly as on a found one.

`TaskResultRecord` is **not** reused. It belongs to checkpoint tasks, whose `blocksProgression` rule (`AD-2`, V8) must keep meaning exactly what it means today; hanging a second concept off it would make V8 ambiguous.

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
