# S1 — Content schema and validation

Phase A. Package: `Packages/Kultara/Sources/ContentKit`. Foundation only — no SwiftUI, no
CoreLocation; `ImportBoundaryTests` holds that line.

## 1. Directory layout

```
Sources/ContentKit/Content/
├── manifest.json                       + sideQuests[], collections[]
├── places/<id>.json                    unchanged type; new files for new places
├── quests/<id>.json                    unchanged apart from the D2 key rename
├── sidequests/<id>.json                NEW
├── collections/<id>.json               NEW
├── consent/<place-id>.json             build input; one per new place too
└── assets/sidequests/<id>/hero.jpg     NEW, optional per sidequest
```

`consent/` stays excluded from package resources — it is a build input the validator reads, not
something to ship in every user's app (`schema.md` §A.1). New places change nothing about that.

## 2. `manifest.json`

```json
{
  "schemaVersion": 2,
  "contentBundleVersion": "2026.09.0",
  "languages": ["id", "en"],
  "places": ["badung-puri-agung-pemecutan", "…"],
  "quests": ["badung-empat-wajah"],
  "sideQuests": ["sq-badung-catur-muka", "…"],
  "collections": ["bali-the-explorer"],
  "regionMap": { "asset": "maps/bali.png", "aspectRatio": 0.72 }
}
```

`schemaVersion` goes to 2. Both new arrays decode with `decodeIfPresent … ?? []`, so a bundle
authored against schema 1 still loads and simply has no sidequests — which is what a content
rollback has to be able to do.

Manifest order decides list order, as it already does for quests: directory enumeration order is a
filesystem detail and would reshuffle the collection between machines.

## 3. `SideQuest`

`ContentEntities.swift`, or a new `SideQuestEntities.swift` in the same target.

```swift
public struct SideQuest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// The Place this sits at. A string id — never an object (`system-design.md` §4).
    public let placeId: String
    public let title: LocalizedText
    /// What the notification and the notice card say. Deliberately short: it is read on a lock
    /// screen by someone walking (`FR-SIDE-11`).
    public let synopsis: LocalizedText
    /// The history, as labelled claims. Same rule as `Checkpoint.loreSegment`: there is no field
    /// for an unlabelled sentence (`FR-CP-05`).
    public let lore: [LoreBlock]
    public let challenge: SideQuestChallenge
    /// Inside this radius, and with a fix at least this good, the sidequest opens (`FR-ARR-01`
    /// reused). 30–250 m, rule V20.
    public let triggerRadiusM: Int
    /// The monitored region. Larger than `triggerRadiusM` — the alert warns on approach, it does
    /// not confirm arrival (the `FR-PROX-11` argument, rule V20).
    public let noticeRadiusM: Int
    public let heroImageAsset: String?
}
```

There is no `contentVersion` on a sidequest. A `Quest` carries one because a Run pins it at start;
a sidequest record pins `manifest.contentBundleVersion` at the moment it is discovered, which is the
same fact without a second place to keep it.

## 4. `SideQuestChallenge`

A closed enum with a `type` discriminator, so an unknown mechanic is a decode failure rather than a
silently ignored challenge.

```json
{ "type": "quiz",
  "question": { "id": "…", "en": "…" },
  "options": [ { "id": "…", "en": "…" }, … ],
  "correctIndex": 2,
  "explanation": { "id": "…", "en": "…" } }
```

```json
{ "type": "photo",
  "prompt": { "id": "Foto gerbang bata merahnya.", "en": "Photograph the red brick gateway." } }
```

```swift
public enum SideQuestChallenge: Codable, Sendable, Equatable {
    case quiz(QuizChallenge)
    case photo(PhotoChallenge)
}

public struct QuizChallenge: Codable, Sendable, Equatable {
    public let question: LocalizedText
    /// 2–4, distinct (V22). Four is the ceiling because these are read one-handed in daylight.
    public let options: [LocalizedText]
    public let correctIndex: Int
    /// Shown after the answer, right or wrong. It is the point of the question — the fact the
    /// walker leaves with — so it is required, not optional.
    public let explanation: LocalizedText
}

public struct PhotoChallenge: Codable, Sendable, Equatable {
    public let prompt: LocalizedText
}
```

`TaskType` (`photo | reflection | question`) is **not** reused. It belongs to checkpoint tasks, whose
`blocksProgression` rule (V8) must keep meaning exactly what it means today; hanging a second concept
off it would make V8 ambiguous. `FR-TASK-05`'s constraint at sacred places is satisfied by
construction: quiz is the "single light question" and photo is photo; nothing else is representable.

## 5. `LetterCollection`

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
    { "index": 0, "letter": "B", "sideQuestId": "sq-badung-puri-agung-pemecutan" },
    { "index": 1, "letter": "A", "sideQuestId": "sq-badung-pura-maospahit" }
  ]
}
```

```swift
public struct LetterSlot: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { index }
    public let index: Int
    /// One character. Stored as `String` rather than `Character` because `Character` has no
    /// stable JSON representation and because a future phrase may need a digraph.
    public let letter: String
    public let sideQuestId: String
}

public struct LetterCollection: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let region: String
    /// Not a `LocalizedText`, and that is a product decision, not an oversight — see `s0` D7.
    public let phrase: String
    public let title: LocalizedText
    public let caption: LocalizedText
    public let badgeId: String
    public let slots: [LetterSlot]
}
```

Spaces in `phrase` are display only; they get no slot. `BALI THE EXPLORER` is 15 letters and
therefore 15 slots and 15 places.

## 6. `ContentRepository` additions

```swift
public protocol ContentRepository: Sendable {
    // … existing …
    func sideQuests() throws -> [SideQuest]
    func sideQuest(id: String) throws -> SideQuest?
    func sideQuests(atPlaceID: String) throws -> [SideQuest]
    func collections() throws -> [LetterCollection]
    func collection(id: String) throws -> LetterCollection?
    /// The discovery set minus anything withdrawn (`AD-5`). Suppressed sets are passed in, never
    /// fetched here — whoever owns the kill-switch owns the fetch.
    func sideQuests(suppressingSideQuestIDs: Set<String>,
                    suppressingPlaceIDs: Set<String>) throws -> [SideQuest]
}
```

Still no notion of loading, refreshing, connectivity or freshness. Adding one here is the specific
mistake `AD-3` exists to prevent, and a sidequest is exactly the kind of feature that invites a
"check for new places nearby" call. There is none.

`ContentDirectoryLoader` decodes `sidequests/<id>.json` and `collections/<id>.json` from the manifest
lists, and `ContentBundle` gains `sideQuest(id:)` / `collection(id:)` lookups next to the existing
ones.

## 7. Validator rules — V19 to V28

`ContentValidator.swift` plus `ValidationRule` cases. Every rule gets a test that proves violating
content is **rejected**; a test that only confirms valid content passes proves nothing.

| Rule | Title | Requirement |
|---|---|---|
| V19 | Every sidequest's `placeId` resolves, and that Place is listed in the manifest | `FR-SIDE-02`, `NFR-GOV-01` |
| V20 | `triggerRadiusM` is 30–250 m, and `noticeRadiusM` exceeds it | `FR-ARR-07`, `FR-PROX-11` |
| V21 | Every sidequest lore block has an accuracy label and resolvable `sourceRefs` | `NFR-CONT-01` |
| V22 | A quiz has 2–4 distinct options and a `correctIndex` inside that range | `FR-SIDE-06` |
| V23 | No photo challenge at a Place where photography is prohibited | `FR-TASK-06` |
| V24 | Every sidequest fills exactly one slot, in exactly one collection | `FR-SIDE-05` |
| V25 | `slots.count` equals the letters of `phrase` with spaces removed, and each slot's letter matches the phrase at its index | `FR-SIDE-08` |
| V26 | Slot indices are contiguous from 0 and each `sideQuestId` resolves and appears once | `FR-SIDE-08` |
| V27 | A collection has at most 20 sidequests | `FR-PROX-14` |
| V28 | Every sidequest asset path exists | — |

Notes on two of them:

**V24 is bidirectional and that is the point.** A sidequest with no slot is a place the walker can
complete for no letter; a slot with no sidequest is a letter nobody can earn. Both are silent in the
app and loud in the validator.

**V27 is a hardware limit dressed as a content rule.** iOS monitors 20 regions per app. Twenty-one
sidequests in one collection cannot all be watched, and the failure mode without this rule is that
some places simply never notify — indistinguishable, in the field, from a GPS problem. The nearest-N
selection in `s2` §6 is the runtime half; this is the authoring half, which fails the build instead
of failing quietly. Note that quest start regions share the same 20-region budget, so the real
ceiling is lower than 20 and the rule is a backstop, not a guarantee.

V2, V4, V5, V13, V15 already cover the new **places** and their consent records with no change, because
a sidequest place is an ordinary `Place`. That is the main reason a sidequest points at a `Place`
rather than carrying its own coordinate and hours.

## 8. The D2 rename, concretely

1. `ContentKit.SideQuest` → `BonusPrompt`; `Checkpoint.sideQuests: [SideQuest]` →
   `bonusPrompts: [BonusPrompt]`; the `decodeIfPresent` key follows.
2. `badung-empat-wajah.json`: `"sideQuests"` → `"bonusPrompts"` at five checkpoints.
3. `docs/schema.md` §A.6 example and prose.
4. `contentBundleVersion` bump — any change to any content file requires it.
5. `.claude/plans/Content/c1-badung-single-quest-content.plan.md` line about `sideQuests: 0–1 each`.

Nothing in `ViewModel/` or `View/` references the field today, so there is no presentation change.

## 9. Files touched

| File | Change |
|---|---|
| `Sources/ContentKit/SideQuestEntities.swift` | new — `SideQuest`, `SideQuestChallenge`, `QuizChallenge`, `PhotoChallenge`, `LetterCollection`, `LetterSlot` |
| `Sources/ContentKit/ContentEntities.swift` | `BonusPrompt` rename |
| `Sources/ContentKit/ContentBundle.swift` | hold and index the two new arrays |
| `Sources/ContentKit/ContentRepository.swift` | protocol additions, loader, `BundledContentRepository` |
| `Sources/ContentKit/ContentValidator.swift` | V19–V28 |
| `Sources/ContentKit/Content/**` | manifest, new documents, rename |
| `Tests/ContentKitTests/ContentValidatorTests.swift` | ten rejection tests |
| `Tests/ContentKitTests/ContentFactory.swift` | fixtures for sidequests and collections |
| `Tests/ContentKitTests/ContentModelTests.swift` | decode round-trips, unknown-challenge-type failure |
| `docs/schema.md` | new §A.10 sidequest, §A.11 collection; §A.9 rules table |
