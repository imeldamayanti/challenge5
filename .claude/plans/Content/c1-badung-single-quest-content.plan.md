# C1 — Badung: one region, one quest, five real places

## E0 — Decisions taken (recorded 2026-08-14, before any JSON was written)

**D1 — Consent: D1-b (self-grant, academic prototype).**
Every `consent/badung-*.json` carries:

- `grantingBody`: `"Tim [NAMA TIM] — prototipe akademik, bukan izin dari pengelola"`
- `grantedByName`: `"[NAMA ANGGOTA 1]"` · `grantedByRole`: `"[PERAN ANGGOTA 1]"`
- `regionOwner`: `"[NAMA ANGGOTA 2]"`
- `status`: `"granted"` · `expiresAt`: `2028-12-31`
- `documentRef`: `docs/consent/<placeId>-prototype-note.md`

The square-bracket placeholders are literal in the shipped JSON: the team's names were not supplied
when this ran. They are not fabricated names, and they are tracked as TODO in `docs/consent-log.md`
and in §11 below. **This is a self-grant, not a grant from any of the five sites, and it must not
survive into anything public.**

**D2 — Citations: only openable sources are cited as such.** Anything not verified ships as a
`sources` entry whose `citation` begins `"BELUM DIVERIFIKASI — "`, and is listed in §11. No page
numbers, publication years, or URLs were invented.

**D3 — Quest identity.** `id: badung-empat-wajah` · `title.id: "Empat Wajah Kota Badung"` ·
`title.en: "The Four Faces of Badung"` · `region: "Badung"` · `city: "Denpasar"`.

> **Superseded 2026-08-14, title only.** The title is now `"Jejak Terakhir Badung"` /
> `"The Last Traces of Badung"`, taken from the Ngalcer Home frame. The **id did not move**:
> `Run.questID` pins it, so renaming it would orphan every completed walk. The four-faces reading
> is still what the quest is about and every lore block, hook and clue still says so — only the
> name on the card changed. `contentBundleVersion` went to `2026.08.4`.

**Status:** E0–E10 executed 2026-08-14. Field verification (§11) still open.

---

**Status (original):** planned, not executed
**Created:** 2026-08-14
**Branch it belongs on:** `checkflow` (or a `content/badung` branch off it)
**Supersedes for the content tree:** the five `contoh-*` placeholder places and the three `contoh-*` quests

---

## 1. Goal

Replace the whole placeholder content bundle with **one authored quest in Badung / Denpasar**, walking
five real checkpoints in fixed order:

1. Puri Agung Pemecutan
2. Pura Maospahit (Grenceng)
3. Pasar Kumbasari
4. Catur Muka
5. Museum Bali

After this plan runs:

- The region map shows **exactly one pin** (`RegionMapViewModel` draws one pin per quest, placed at the
  quest's start checkpoint — `ViewModel/RegionMapViewModel.swift:93`). One quest therefore means one
  pin, with no code change.
- The quest list shows one row.
- The run flow (story preview → arrival → cutscene → story reveal → checkpoint → summary) plays this
  storyline end to end.
- `swift run content-validator` still exits 0 — all of V1–V18 hold.

### Non-goals

- No Swift feature work. The only Swift edits are the two test assertions that hard-code the current
  placeholder content (§8).
- No new content fields, no schema change, no validator rule change.
- No second quest, no second region. Adding Gianyar/Ubud later is a repeat of this plan, not a
  variation of it.
- No new screens. Photo tasks, share card and telemetry stay unbuilt (out of Milestone 6/8 scope).

---

## 2. Source of truth, in order

1. `docs/schema.md` — field-by-field content schema, and §A.9 rules V1–V18.
2. `.claude/prds/cultural-heritage-quest.full.prd.md` — `FR-*` / `NFR-*` cited below.
3. Existing authored JSON under `challange-5/Packages/Kultara/Sources/ContentKit/Content/` — the shape
   to copy. `places/contoh-puri-gerbang-utara.json` is the most complete Place example.
4. `challange-5/Packages/Kultara/Sources/ContentKit/ContentValidator.swift` — the actual enforcement,
   which is stricter than prose in two places (see §7 on V16 and on `sourceRefs` indexing).

---

## 3. Decision gates — resolve these before authoring a single file

These three cannot be inferred from the codebase. Each blocks a different part of the work.

### D1 — Consent for five real, named institutions (blocking, governance)

`ConsentStatus` has exactly three cases: `granted`, `withdrawn`, `expired`
(`ContentPrimitives.swift:41`). There is no `pending`. V4 fails the build unless every Place resolves
to a record with `status: "granted"` and a future `expiresAt`, and V5 requires a real
`grantedByName`, `grantedByRole` and `regionOwner` (`NFR-GOV-01/02/03/07`).

The current placeholder records are explicitly marked `(fiktif)`. Writing the same shape with
*"Puri Agung Pemecutan"* as `grantingBody` and an invented signatory would be fabricating a consent
record for a real institution — the specific thing `NFR-GOV` exists to prevent, and the reason
`CLAUDE.md` already records that the Figma quest "cannot be authored without consent records and
citations".

Pick one:

| | Option | Consequence |
|---|---|---|
| **D1-a** *(recommended)* | Author everything now, keep each `consent/*.json` with `status: "granted"` **only after a real approach is logged** in `docs/consent-log.md` (new file: who was contacted, when, by whom, what they said, scan or photo of the reply in `docs/consent/`). Until a site replies, that Place is not in the manifest. | Honest and shippable. Requires real outreach for five sites before the full route is buildable. Partial routes are possible — a three-checkpoint quest is valid content. |
| **D1-b** | Ship the quest as a **demo-only** bundle: real names, and consent records whose `grantingBody` is your own team with scope limited to `inclusion` + `naming`, `documentRef` pointing at a written statement that this build is a non-public academic prototype. | Buildable today. It is a self-grant, not a grant — it must be labelled as such in the record and in `CLAUDE.md`, and it must not survive into anything public. |
| **D1-c** | Keep fictional names on the real geography (`badung-puri-contoh-*` at the real coordinates). | Zero governance risk, and throws away the whole point of this task. |

**Default if nobody answers:** D1-b, with every consent record carrying
`"grantingBody": "Tim <nama tim> — prototipe akademik, bukan izin dari pengelola"` so the record can
never be mistaken for a real grant, plus a tracking row in `docs/consent-log.md`. Do not silently
choose D1-a's *shape* with D1-b's *reality*.

### D2 — Citations (blocking, V2/V3)

Every `LoreBlock` needs `accuracy` plus at least one `sourceRefs` index, and every index must resolve
into that Place's own `sources` array (`ContentValidator.swift:441`). Hook lore resolves against the
**start** Place's sources (`ContentValidator.swift:350-352`).

So the sources must exist before the lore does. Candidate published works for the Badung/Denpasar
material — **each must be opened and checked before it is cited; do not copy this list into JSON as-is**:

- Henk Schulte Nordholt, *The Spell of Power: A History of Balinese Politics 1650–1940*
- Adrian Vickers, *Bali: A Paradise Created*
- Ida Anak Agung Gde Agung, *Bali pada Abad XIX*
- Museum Bali / Dinas Kebudayaan Provinsi Bali — on-site panels and published guides
- Perusahaan Daerah Pasar Kota Denpasar — for Pasar Kumbasari's operating facts

Anything that comes from a person rather than a page — a pemangku, a trader, a museum guide — is
`accuracy: "oral"` with the interview itself as the source (`"Wawancara <peran>, <bulan tahun>"`), and
it needs the same consent trail as D1.

**Hard rule for this plan:** no lore sentence gets written before its source line exists. If a claim
has no source, it does not ship — the schema has no field for an unlabelled sentence, and that is
deliberate (`FR-CP-05`).

### D3 — Quest identity

Proposed, change if the team prefers:

- **id:** `badung-empat-wajah`
- **title.id:** `Empat Wajah Kota Badung` · **title.en:** `The Four Faces of Badung`
- **region:** `Badung` · **city:** `Denpasar`

The thread: Catur Muka's four faces look out over the four directions of the old city, and the walk
visits what each direction holds — power (puri), faith (pura), livelihood (pasar), memory (museum) —
with the statue itself as the pivot at checkpoint 4. It is a real, on-site, non-contested image, which
matters: it carries a storyline without staking a claim that needs a citation it cannot get.

Note the app has no name and "Kultara" is a research partner, not a brand (`CLAUDE.md`, Known state).
Nothing in this content may imply otherwise.

---

## 4. Target content tree

```
Sources/ContentKit/Content/
├── manifest.json                                   EDIT
├── places/
│   ├── badung-puri-agung-pemecutan.json            NEW
│   ├── badung-pura-maospahit.json                  NEW
│   ├── badung-pasar-kumbasari.json                 NEW
│   ├── badung-catur-muka.json                      NEW
│   ├── badung-museum-bali.json                     NEW
│   └── contoh-*.json                          (5)  DELETE
├── quests/
│   ├── badung-empat-wajah.json                     NEW
│   └── contoh-*.json                          (3)  DELETE
├── consent/
│   ├── badung-*.json                          (5)  NEW  — per D1
│   └── contoh-*.json                          (5)  DELETE
└── assets/
    ├── maps/bali-illustrated.png                   KEEP
    ├── quests/badung-empat-wajah/
    │   ├── hero.png                                NEW
    │   ├── route-preview.png                       NEW
    │   └── route.geojson                           NEW
    └── quests/contoh-*/                       (3)  DELETE
```

`manifest.json` changes:

```jsonc
{
  "schemaVersion": 1,
  "contentBundleVersion": "2026.08.3",   // bumped — mandatory on any content change
  "languages": ["id", "en"],
  "places": [
    "badung-puri-agung-pemecutan",
    "badung-pura-maospahit",
    "badung-pasar-kumbasari",
    "badung-catur-muka",
    "badung-museum-bali"
  ],
  "quests": ["badung-empat-wajah"],
  "regionMap": { "asset": "maps/bali-illustrated.png", "aspectRatio": 0.4626 }
}
```

The quest's own `contentVersion` must be set to the same `"2026.08.3"`.

---

## 5. The storyline

Fixed order, walkable west → east across the old city core. Roughly 1.6–2.0 km; confirm against
walking directions in step E3 (`distanceSource` must be `"walking-directions"`, V11 / `NFR-CONT-05`).

| # | Role | Place | Face | What the checkpoint carries |
|---|---|---|---|---|
| 1 | `start` | Puri Agung Pemecutan | **Kuasa** / power | Where the walk begins: the puri as the seat the old city was organised around. |
| 2 | `middle` | Pura Maospahit | **Kepercayaan** / faith | The older layer underneath the puri — the Majapahit-era brickwork and what it says about who arrived when. |
| 3 | `middle` | Pasar Kumbasari | **Penghidupan** / livelihood | The river and the market: the city as a place people made a living in, not only ruled from. |
| 4 | `middle` | Catur Muka | **Arah** / bearings | The pivot. Four faces, four directions, one junction — and the walker stands where the previous three sit behind them. |
| 5 | `finish` | Museum Bali | **Ingatan** / memory | Where the objects the first four produced are kept, and the closing reflection. |

Checkpoint 4 is where the title lands. Write its lore last, once 1–3 exist, so the four-directions
line names things the walker has actually seen.

### Per-checkpoint authoring spec

Every checkpoint needs, in `quests/badung-empat-wajah.json`:

- `loreSegment`: **2–3** `LoreBlock`s. At least one `documented` per checkpoint. `oral` blocks are
  permitted and encouraged at 1, 2 and 3, where the interview material lives. Each block's
  `sourceRefs` indexes that checkpoint's **Place** `sources` array.
- `clueToNext`: a physical, walkable instruction — a direction plus a thing you can see. Non-null for
  checkpoints 1–4, **null** for 5 (V10 / `FR-CP-02`).
- `tasks`: exactly one task each. `type` from `{photo, reflection, question}`. Every task must carry
  `"blocksProgression": false` (V8 / `AD-2`) — no exceptions, tasks are keepsakes and the GPS radius
  is the only gate.
  - **No `photo` task at any Place whose `photoPolicy.level` is `prohibited`** (V6 / `FR-TASK-06`).
    Expect this to bite at checkpoint 2 — plan a `reflection` or `question` there.
  - Checkpoint 5's task is the closing reflection `FR-TASK-07` requires. It is answered *after* the
    walk completes, which the Run model already allows (`markLoreOpened` / `recordTaskResult` accept
    `completed`).
- `sideQuests`: 0–1 each, optional, never required.
- `stampId`: `stamp-badung-empat-wajah-<n>`.

Quest-level:

- `hookLore` — the cutscene text. `QuestRunViewModel.swift:519` joins these blocks with a blank line
  and shows them once per walk, so write **2–3 short blocks**, not one long one. Refs resolve against
  checkpoint 1's Place sources.
- `description` — what the quest list and preview show.
- `terrainSummary`, `safetyNotes` — real, specific, and about this route: the Gajah Mada crossings,
  the market floor, step counts. Vague safety copy is worse than none.
- `badgeId`: `badge-badung-empat-wajah`.

### Per-place authoring spec

Every Place file needs every field the placeholder file carries. The ones that need real fieldwork,
per Place:

| Field | Rule | Note |
|---|---|---|
| `coordinate` | — | See §6. Seed values are *not* good enough to ship. |
| `arrivalRadiusM` | **30–250** (V13 / `FR-ARR-07`) | Bigger for open sites (Catur Muka junction, Puputan side), smaller for a gated courtyard. Remember `FR-ARR-01`'s second condition: the fix's `horizontalAccuracy` must also be ≤ radius, which is why a 40 m radius inside Kumbasari will fail honestly and often. |
| `isSacred` | — | `true` for Pura Maospahit and for Puri Agung Pemecutan's inner areas. Sacred restricts task mechanics (V7). |
| `visitingHours.weekly` | 7 entries | Drives V16 — see §7. Museum Bali's closing time will almost certainly be the binding one. |
| `dressCode` | — | Required text for the pura and the puri (kamen + selendang). |
| `photoPolicy` | V6 | Set honestly; then make sure no photo task sits on a `prohibited` Place. |
| `entryCost` | — | Museum Bali charges; the others likely do not. Whatever is set must be mirrored in the quest's `estimatedCost.breakdown`. |
| `accessibility` | `NFR-A11Y` | Real step counts, surface, handrails. This is read by walkers who need it. |
| `sources` | ≥ 1 (V2) | See D2. |
| `loreStandalone` | ≥ 1 block, each with `accuracy` + `sourceRefs` (V3) | The Place's own description, independent of the quest. |
| `consentRecordId` | V4 | Same string as the Place id. |
| `mapPoint` | 0…1 (V17) | See §6. |

---

## 6. Coordinates and map points

### Real coordinates

Seed values below put each site in the right block of Denpasar and are usable to *start* drawing the
route. **They are not verified and must not ship as authored.**

| Place | Seed lat | Seed lon | Street |
|---|---|---|---|
| Puri Agung Pemecutan | −8.6595 | 115.2077 | Jl. Thamrin |
| Pura Maospahit | −8.6570 | 115.2085 | Jl. Sutomo |
| Pasar Kumbasari | −8.6540 | 115.2115 | Jl. Gajah Mada |
| Catur Muka | −8.6535 | 115.2160 | Jl. Gajah Mada / Jl. Veteran junction |
| Museum Bali | −8.6560 | 115.2172 | Jl. Mayor Wisnu |

Verification step (E1) is to stand at each arrival point — the point a walker actually stops at, not
the building centroid — and record the fix, or failing that take the coordinate from a source you can
cite. A coordinate that is 40 m off inside a 50 m radius is a checkpoint that never unlocks.

### `mapPoint`

`mapPoint` is authored against the stylised `bali-illustrated.png` and is **not** derived from
`coordinate` — projecting real coordinates onto a hand-drawn coastline puts every pin somewhere wrong
while looking precise (`CLAUDE.md`, invariants). The current placeholders cluster around
`x ≈ 0.40, y ≈ 0.62`, which is where Denpasar sits on that illustration.

Only checkpoint 1's `mapPoint` reaches the region map, because the map draws one pin per quest at its
start Place. All five still need one, because V17 checks every Place a quest visits. Give the five
values within a few hundredths of each other around the Denpasar area, then confirm visually against
`docs/screenshots/region-map.png` and re-screenshot after the change.

---

## 7. Validator compliance — how each rule is satisfied

Work this table top to bottom when reviewing the authored files. `swift run content-validator` is the
gate; this is the checklist that makes the first run clean.

| Rule | Satisfied by |
|---|---|
| V1 | Every `LocalizedText` filled in both `id` and `en`. No language fallback exists — a gap is a decode failure, and it **blocks the decode-dependent rules**, so fix V1 findings first and re-run. |
| V2 | §D2 — each Place gets its `sources` array before its lore. |
| V3 | Each `LoreBlock` carries `accuracy` + non-empty `sourceRefs`, all indices in range for **that Place's** array. Hook lore indexes checkpoint 1's Place. |
| V4 | §D1. Five records, `status: "granted"`, `expiresAt` in the future. |
| V5 | Each record names `grantedByName`, `grantedByRole`, `regionOwner` — a person, not "the team" (`NFR-GOV-07`). |
| V6 | No `photo` task at a `prohibited` Place. |
| V7 | At `isSacred` Places, task `type` stays inside `{photo, reflection, question}` — the enum has nothing else, so this is authorable but not representable; the rule runs over raw JSON. |
| V8 | `"blocksProgression": false` on all five tasks. |
| V9 | `orderIndex` 0,1,2,3,4 contiguous; exactly one `start` and one `finish`. |
| V10 | `clueToNext` non-null on checkpoints 1–4, `null` on 5. |
| V11 | `"distanceSource": "walking-directions"` and a `totalDistanceM` actually taken from walking directions. |
| V12 | `proximityRadiusM` **strictly greater than** checkpoint 1's `arrivalRadiusM`. With a 75 m start radius, 250 works. |
| V13 | Every `arrivalRadiusM` in 30–250. |
| V14 | `hero.png`, `route-preview.png`, `route.geojson` all present at the paths the quest names. |
| V15 | Payload ≤ 200 MB — trivially fine; deleting three placeholder asset folders makes it smaller. |
| V16 | **Derived, not authored.** `hardLatestStart` = (earliest `close` across *every* weekly entry of *every* Place the quest visits) − `route.totalDurationMin` (`ContentValidator.swift:467`). Fill hours and `totalDurationMin` first, compute last, and recompute whenever either changes. |
| V17 | All five Places carry `mapPoint` with both components in 0…1. |
| V18 | `route.geojson` parses as a FeatureCollection whose LineString has ≥ 2 points. Copy the existing file's shape: one `{"role":"route"}` LineString feature, then one Point feature per checkpoint carrying `checkpointId` / `orderIndex` / `placeId`. |

Note on V18 and the run map: `RunRouteMapView` draws from this GeoJSON via `RunEngine.RouteProjection`,
which shares `Geo.earthRadiusM` with `Geo.distanceM`, so the drawn line and the printed distance agree
by construction. The LineString should follow the **walked streets**, not five straight hops — a
straight line through a block is a drawn instruction to walk through a building.

---

## 8. Code and test changes required

Deleting two quests breaks two hard-coded assertions. Both are the change, not collateral.

1. `challange-5/Packages/Kultara/Tests/ContentKitTests/BundledContentRepositoryTests.swift:23`
   `#expect(quests.count == 3)` → `== 1`. Check the surrounding test for other placeholder
   assumptions while editing.
2. `challange-5/challange-5UITests/DiscoveryFlowUITests.swift` — five occurrences of
   `app.staticTexts["Example Old-Town Trail"]` (lines 90, 128, 163, 186 and nearby). Replace with the
   new `title.en` from D3. Prefer hoisting it to one `private let questTitleEN = "…"` constant so the
   next content change touches one line.
3. `challange-5/Packages/Kultara/Tests/RunEngineTests/RunFixtures.swift:8` — a doc comment naming
   `contoh-tiga-gerbang`. Update the wording; the fixture itself is in-memory and unaffected.
4. `ContentValidationRunTests.swift` — mutates a **copy** of the authored tree by string-replacing
   into named files (`quests/contoh-jejak-kota-lama.json`, `consent/contoh-pura-tirta-sari.json`,
   `consent/contoh-pasar-pagi-timur.json`, and the literal `"en": "Example Old-Town Trail"`). Every
   one of those paths and strings must be repointed at the new files, or the corruption tests stop
   corrupting anything and pass vacuously — which is worse than failing.

No app-target Swift file references any `contoh-*` id; screens render by ID from `ContentKit`
(`AD-4`, `FR-RUN-06`), so nothing else moves.

---

## 9. Execution order

Each step ends in a checkable state. Do not batch E1–E3 into "author everything then validate".

**E0 — Decisions.** Record D1, D2 and D3 answers at the top of this file before writing JSON.

**E1 — Field data.** Fill a scratch table (coordinates, visiting hours ×7 days, dress code, photo
policy, entry cost, accessibility, step counts) for all five Places. This is the only step that
cannot be done at a desk. Everything downstream is derived from it.

**E2 — Sources and consent.** Write the five `consent/badung-*.json` and each Place's `sources` array.
Per D1/D2, this precedes lore.

**E3 — Route.** Take walking directions across the five points in order. Record `totalDistanceM`,
`walkingTimeMin`, and set `totalDurationMin` (walking + dwell time at five checkpoints; the
placeholder used 120 for 40 minutes of walking). Draw `route.geojson` following the streets.

**E4 — Places.** Write the five `places/badung-*.json`. Include `loreStandalone` and `mapPoint`.

**E5 — Quest.** Write `quests/badung-empat-wajah.json`: hook lore, description, five checkpoints with
lore/clue/task/side-quest, cost breakdown, terrain, safety, `recommendedStartWindow`. Compute
`hardLatestStart` per V16 **last**.

**E6 — Assets.** Create `assets/quests/badung-empat-wajah/`. `hero.png` is what the cutscene frames
(`QuestRunViewModel.swift:534`), so it carries visual weight — a photo of the route, or the Hisplora
typewriter treatment. A copy of the old placeholder PNG satisfies V14 and nothing else; if that is
what lands first, leave a TODO in this file rather than calling E6 done.

**E7 — Manifest.** Rewrite `places` and `quests`, bump `contentBundleVersion` to `2026.08.3`, and set
the quest's `contentVersion` to match.

**E8 — Delete placeholders.** Remove the 5 + 3 + 5 `contoh-*` files and the three
`assets/quests/contoh-*/` folders. Do this *after* E7 so the tree is never in a state where the
manifest names a file that is gone.

**E9 — Tests.** Apply §8's four edits.

**E10 — Validate and run.**

```bash
cd challange-5/Packages/Kultara && swift run content-validator Sources/ContentKit/Content
```

```bash
cd challange-5/Packages/Kultara && swift test
```

```bash
cd challange-5 && xcodebuild test -project challange-5.xcodeproj -scheme challange-5 -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

---

## 10. Verification — what "done" looks like

- `content-validator` exits **0**. An exit of 1 with a V-numbered finding is the expected first result;
  fix by rule, re-run, repeat. Fix V1 findings before judging the rest (§7).
- `swift test` green, including `theAuthoredFixturePassesEveryRule` and
  `theAuthoredFixtureCarriesConsentForEveryPlace`.
- The four corruption tests in `ContentValidationRunTests` still **fail the run they are meant to fail**
  after being repointed — spot-check one by reverting its repointed path and confirming it goes green
  vacuously, then restore. A corruption test that no longer corrupts is a silent hole.
- In the simulator:
  - Quest list shows **one** row, titled per D3.
  - Region map shows **one** pin, over Denpasar, at readable zoom
    (`initialZoom` derives from pin separation; with a single pin `closestPinSeparation` returns nil
    and the map opens fitted at zoom 1 — confirm that still frames the pin sensibly, and re-capture
    `docs/screenshots/region-map.png`).
  - Preview shows five checkpoints, the real cost, terrain and safety text.
  - With **Settings → Developer tools → Simulate arrival anywhere**, walk all five checkpoints: hook
    cutscene once, story reveal per checkpoint, clue between, completion at 5, summary rendering from
    snapshots. (This toggle does not respond to synthesized taps from the simulator MCP — drive it
    from Xcode, per `CLAUDE.md`.)
- `docs/hisplora-tokens.md` and `CLAUDE.md` updated: the "shipped content is placeholder" note in
  Known state is no longer true and must be rewritten to describe what actually ships, including
  whichever D1 option was taken.

---

## 11. Risks and open questions

### 11.0 What shipped unverified (recorded at execution, 2026-08-14)

Everything in this block is authored content that is **not backed by a source anybody has opened**.
The validator passes over it because the validator checks structure, not truth.

**Unverified coordinates — all five.** No coordinate was verified from any openable source. The
seed values from §6 shipped as authored, and `route.geojson` is drawn between them with
approximated street vertices. `route.totalDistanceM` (2000 m), `walkingTimeMin` (30) and
`totalDurationMin` (105) are estimated from those seed points, **not** taken from walking
directions — but V11 forces `distanceSource: "walking-directions"`, so the JSON claims a provenance
the number does not have. Fix by walking the route and re-measuring; a coordinate 40 m off inside a
60 m radius is a checkpoint that never unlocks.

Sanity-check that failed: the Jaya Sabha anchor (8.65549°S 115.21775°E) sits **north-east** of the
catus patha, so Catur Muka must be south-west of it. The §6 seed for Catur Muka
(−8.6535, 115.2160) is roughly 220 m north and 190 m west of the anchor — north-*west*, ~293 m
away. The seed is in the right neighbourhood and the wrong quadrant. It shipped unchanged rather
than being silently "corrected" to an invented value.

**`sources` entries marked BELUM DIVERIFIKASI** (D2). Three shipped, and every lore block citing
one is a claim without an openable source behind it:

| Place | Index | Citation |
|---|---|---|
| `badung-puri-agung-pemecutan` | 0 | Sejarah dan kedudukan Puri Agung Pemecutan |
| `badung-puri-agung-pemecutan` | 1 | Konsep catus patha dan tata ruang inti kota lama Badung |
| `badung-catur-muka` | 1 | Ikonografi dan sejarah pendirian patung Catur Muka |

Checkpoint 1's lore therefore says almost nothing about the puri — it says the walk starts there and
that the history is missing, which is honest but is not content. It is the weakest stop on the
route until a real source lands. Quest-level `hookLore` resolves against checkpoint 1's Place, so
all three hook blocks cite these two unverified entries too.

**Also unverified, authored conservatively rather than guessed:**

- Opening hours for Puri Agung Pemecutan, Pura Maospahit, Pasar Kumbasari and Catur Muka. Museum
  Bali's hours are the only verified ones, and they are what V16 binds to.
- Dress code and photo policy at all five. The four unconfirmed ones are authored `restricted`,
  never `prohibited` — a guessed prohibition would be as wrong as a guessed permission.
- Entry cost at all five is `0`. **Museum Bali is known to sell a ticket**; its price is not
  verified, so `0` is a placeholder that will misinform a walker. `estimatedCost.breakdown` is
  empty for the same reason.
- Accessibility: step counts at four of five stops. Only Pasar Kumbasari's four-storey structure is
  verified. The four unsurveyed ones are authored `hasSteps: true` with `stepCount: null` — wrong in
  the direction that warns rather than the direction that strands somebody.

### 11.0b Test coverage the content deletion removed

The placeholder bundle exercised UI states the authored bundle does not. Four assertions in
`BundledContentRepositoryTests` were rewritten rather than deleted, each carrying a `TODO(content)`
naming what stopped being covered:

1. **No priced quest ships**, so the paid discovery-card state (`FR-DISC-05`) renders in no test.
   Returns when Museum Bali's fee is verified.
2. **No `oral` lore block ships**, so a broken `oral` accuracy label would not be caught here
   (`FR-CP-05`). Returns with the first interview — which needs its own consent trail per D2.
3. **No `prohibited` photo Place ships**, so `FR-TASK-06`'s prohibited branch is exercised only by
   `ContentValidatorTests`, not by shipped content.
4. **One quest means one pin**, so `FR-DISC-08`'s "some quests remain after suppression" branch and
   `RegionMapViewModel.closestPinSeparation` are unexercised by the bundle (this is §11.6 below,
   now realised rather than predicted).

### 11.0c Left alone deliberately

`Support/UIStrings.swift:338` still tells the user the content is "data contoh dengan tempat
fiktif". That is now false — the places are real, the *facts about them* are partly unverified. The
string was left unchanged because §8 scopes the Swift edits, and rewriting user-facing copy is a
product decision, not a content one. It needs rewriting before anyone sees this build.

1. **Consent is the real blocker, not the JSON.** Five institutions, one of them a working temple and
   one a functioning market authority. D1-b keeps the build green but is explicitly a self-grant and
   must be labelled as one everywhere it appears.
2. **`FR-CP-05`'s undocumented exception gets bigger here.** The Story Reveal pages render lore without
   the accuracy chip or citation (`m8-qa-fixes.plan.md`, Decisions taken, item 2). With placeholder
   text that was a display detail; with real historical claims about a real dynasty it is a claim
   shown without its epistemic status. Either the PRD amendment lands, or Story Reveal starts showing
   the chip. Raise it with the owner — do not let this plan quietly widen the exception.
3. **Arrival radius versus real GPS in Kumbasari.** Covered market, poor accuracy. `FR-ARR-01`'s
   accuracy condition will legitimately fail there, which is exactly why the manual override is
   mandatory (`FR-START-10`). Test that path at that checkpoint specifically, not just the happy one.
4. **Visiting hours drive `hardLatestStart` (V16), and they change.** A ceremony closes the pura
   without notice; the museum's hours shift on holidays. Whatever is authored is a snapshot, and any
   later edit to any Place's hours means recomputing the quest's `hardLatestStart`.
5. **Seed coordinates in §6 are unverified.** Shipping them is the most likely way this content looks
   finished and does not work.
6. **One quest means one pin means an untested multi-pin path.** `RegionMapViewModel.closestPinSeparation`
   and `initialZoom` only do interesting work with ≥ 2 pins. Deleting the other two quests removes the
   only content that exercises them — the behaviour is covered by tests, but nothing in the shipped
   bundle will show a regression there. Worth knowing before the second region is authored.
