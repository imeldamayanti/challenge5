# Field verification checklist — `badung-empat-wajah`

**Produced 2026-08-16 as desk work from
`.claude/plans/Content/c1-badung-single-quest-content.plan.md` §11.0.** Nothing here is verified and
nothing here invents a value. This is the list of what a person walking the route has to capture,
in the order they will meet it.

**Rule for using it:** a value is written back only when it was read off the thing itself or off a
source that can be reopened. A remembered value is not a verified value. Anything not captured stays
exactly as it ships — a wrong-looking placeholder that is honestly labelled is better than a
plausible invention.

Every write-back is to `challange-5/Packages/Kultara/Sources/ContentKit/Content/`, and **every
change to any content file must bump `contentBundleVersion` in `manifest.json`** (`CLAUDE.md`).

---

## 0. Before leaving

| # | Item | Why |
|---|---|---|
| 0.1 | A GPS app that shows **horizontal accuracy in metres**, not just a blue dot | `FR-ARR-01` is two conditions and the accuracy one is load-bearing. A coordinate captured at 40 m accuracy is not a verified coordinate |
| 0.2 | The current `arrivalRadiusM` for each stop, below | A coordinate 40 m off inside a 60 m radius is a checkpoint that never unlocks |
| 0.3 | A debug build with **Settings → Developer tools → Simulate arrival anywhere** *off* | The point of the walk is to exercise the real gate |
| 0.4 | This checklist on paper or offline | The app works in airplane mode; the checklist should too |

## 1. Route-level, captured across the whole walk

These are the three values the plan singles out as claiming a provenance they do not have.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 1.1 | `route.totalDistanceM` | `2000` — estimated from unwalked seed coordinates | Actual walked distance, metres, from the recorded track | `quests/badung-empat-wajah.json` → `route.totalDistanceM` |
| 1.2 | `route.walkingTimeMin` | `30` — estimated | Actual walking time excluding stops | same → `route.walkingTimeMin` |
| 1.3 | `route.totalDurationMin` | `105` — estimated | Walking time plus realistic time at each stop | same → `route.totalDurationMin` |
| 1.4 | `route.geometryAsset` (`route.geojson`) | Drawn between seed points with approximated street vertices | The recorded track, simplified to street vertices | `assets/…/route.geojson` |

> **`distanceSource` already claims `walking-directions`.** Validator rule V11 forbids `haversine`,
> so the JSON asserts a provenance the shipped number does not have — stated in plan §11.0 rather
> than hidden. Capturing 1.1–1.3 is what makes that assertion true. Until then it is the one place
> in the content where the schema and the truth disagree by design, and it is not fixable by editing
> the JSON.

> **`hardLatestStart` is derived, not captured.** V16 binds it to the earliest closing time on the
> route minus `totalDurationMin`. It is recomputed *after* 1.3 and all the closing times below are
> in — never captured directly, and never left stale when any of its inputs move.

---

## 2. Stop 1 — Puri Agung Pemecutan (`badung-puri-agung-pemecutan`)

Ships with `arrivalRadiusM: 75`, coordinate `-8.6595, 115.2077`.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 2.1 | `coordinate` | `-8.6595, 115.2077` — **unverified seed** | Lat/lon at the point a walker actually stands, with accuracy ≤ 20 m | `places/badung-puri-agung-pemecutan.json` → `coordinate` |
| 2.2 | Radius sanity | `75` | Whether 75 m from 2.1 covers the approach without reaching the next street | same → `arrivalRadiusM` |
| 2.3 | `visitingHours.weekly` | 7 × `08:00–17:00` — **unverified** | Posted hours, per weekday. Note days it is closed to visitors entirely | same → `visitingHours` |
| 2.4 | `dressCode` | authored conservatively — **unverified** | What is actually required or asked of a visitor, in ID and EN | same → `dressCode` |
| 2.5 | `photoPolicy.level` | `restricted` — **unverified** | `allowed` / `restricted` / `prohibited`, plus the notes that explain it | same → `photoPolicy` |
| 2.6 | `entryCost` | `0` — **unverified** | Any donation expected or fee charged, in IDR minor units | same → `entryCost` |
| 2.7 | `accessibility.stepCount` | `hasSteps: true`, `stepCount: null` — **unverified** | Actual number of steps at the entrance, and the surface | same → `accessibility` |
| 2.8 | **`sources[0]`** | `BELUM DIVERIFIKASI — Sejarah dan kedudukan Puri Agung Pemecutan` | An openable source for the puri's history and standing | same → `sources[0].citation`, `.url`, `.kind` |
| 2.9 | **`sources[1]`** | `BELUM DIVERIFIKASI — Konsep catus patha dan tata ruang inti kota lama Badung` | An openable source for the catus patha concept and the old town's layout | same → `sources[1]` |

> 2.8 and 2.9 are the two heaviest items on this list. Every quest-level `hookLore` block resolves
> against this Place, so **all three hook blocks cite an unverified source** — the first thing a
> reader sees in the whole app rests on them. Checkpoint 1's lore currently says little more than
> that the walk starts here and the history is missing: honest, and not content.
>
> If the source arrives verbally from the custodians, it is an `oral` lore block and needs its own
> consent trail (plan D2) — see `docs/consent-request-pack.md` §3.1, which warns against collapsing
> the permission ask and the history ask into one conversation.

---

## 3. Stop 2 — Pura Maospahit / Grenceng (`badung-pura-maospahit`)

Ships with `arrivalRadiusM: 60` — the tightest on the route — coordinate `-8.6570, 115.2085`.
`isSacred: true`.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 3.1 | `coordinate` | **unverified seed** | Lat/lon where a walker stands, accuracy ≤ 20 m. **60 m radius leaves the least room of any stop** | `places/badung-pura-maospahit.json` → `coordinate` |
| 3.2 | `visitingHours.weekly` | 7 × `08:00–17:00` — **unverified** | Posted or custodian-stated hours. Note ceremony days, which close it without notice | same → `visitingHours` |
| 3.3 | `dressCode` | **unverified** | The real requirement — kain and selendang, and whether they are lent at the gate | same → `dressCode` |
| 3.4 | `photoPolicy` | `restricted` — **unverified** | What may and may not be photographed, and where the line is | same → `photoPolicy` |
| 3.5 | `entryCost` | `0` — **unverified** | Donation or fee | same → `entryCost` |
| 3.6 | `accessibility.stepCount` | `hasSteps: true`, `stepCount: null` — **unverified** | Steps at the gate, surface inside | same → `accessibility` |

Verified already and **not** to be re-captured or edited without cause: the address and the
architecture description, each with an openable citation.

---

## 4. Stop 3 — Pasar Kumbasari (`badung-pasar-kumbasari`)

Ships with `arrivalRadiusM: 100`, coordinate `-8.6540, 115.2115`.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 4.1 | `coordinate` | **unverified seed** | Lat/lon at the entrance a walker uses | `places/badung-pasar-kumbasari.json` → `coordinate` |
| 4.2 | **Accuracy behaviour inside the market** | not a content field | Observe what `horizontalAccuracy` actually does under the roof, and whether the manual override is reachable and usable there | Nothing. Record in the plan's execution notes |
| 4.3 | `visitingHours.weekly` | 7 × `08:00–18:00` — **unverified** | Posted trading hours; note that the night market differs | same → `visitingHours` |
| 4.4 | `photoPolicy` | `restricted` — **unverified** | Whether traders object; the market's own rule if it has one | same → `photoPolicy` |
| 4.5 | `entryCost` | `0` — **unverified** | Any entry or parking charge | same → `entryCost` |
| 4.6 | `dressCode` | **unverified** | Whether there is one at all | same → `dressCode` |

4.2 is the one item on this list that is not a content value. Plan §11 item 3 predicts that
`FR-ARR-01`'s accuracy condition fails legitimately here, which is exactly why `FR-START-10` makes
the manual override mandatory. **Test that path at this checkpoint specifically**, not the happy one.

Verified already: the address, the four-storey layout, the 1977 founding, and the market rules —
each with an openable citation. The step count follows from the four storeys and is the one verified
accessibility figure on the route.

---

## 5. Stop 4 — Catur Muka (`badung-catur-muka`)

Ships with `arrivalRadiusM: 120` — the widest — coordinate `-8.6535, 115.2160`.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 5.1 | **`coordinate`** | `-8.6535, 115.2160` — **unverified, and known to be in the wrong quadrant** | Lat/lon at the monument | `places/badung-catur-muka.json` → `coordinate` |
| 5.2 | `visitingHours.weekly` | 7 × `00:00–23:59` — **unverified** but plausible for a public junction | Confirm it is genuinely always accessible | same → `visitingHours` |
| 5.3 | `photoPolicy` | `allowed` | Confirm — this is the one place with a photo task, and `docs/consent-request-pack.md` §3.4 asks the city about it | same → `photoPolicy` |
| 5.4 | `entryCost` | `0` | Confirm (expected correct for a public monument) | same → `entryCost` |
| 5.5 | **`sources[1]`** | `BELUM DIVERIFIKASI — Ikonografi dan sejarah pendirian patung Catur Muka` | An openable source for the statue's iconography and founding | same → `sources[1]` |

> **5.1 has a failed sanity check on record and it is the most specific error on this list.** The
> Jaya Sabha anchor (8.65549°S, 115.21775°E) sits north-east of the catus patha, so Catur Muka must
> be **south-west** of it. The shipped seed is roughly 220 m north and 190 m west — that is
> north-*west*, about 293 m away. Right neighbourhood, wrong quadrant. It shipped unchanged rather
> than being silently "corrected" to an invented value, which is the correct call and is also why
> this is the highest-priority coordinate to capture.
>
> The 120 m radius may be masking it: 293 m of error is well outside even that, so the checkpoint
> as authored probably does not unlock at all. Capture the coordinate before assuming the radius is
> the problem.

Verified already: the monument's position relative to the catus patha, with an openable citation.
`sources[0]` (Wikipedia EN, "Jaya Sabha Complex") is flagged in the content as a tertiary source —
worth replacing with a primary one, but it is not a `BELUM DIVERIFIKASI` entry.

---

## 6. Stop 5 — Museum Bali (`badung-museum-bali`)

Ships with `arrivalRadiusM: 80`, coordinate `-8.6560, 115.2172`. **The only site whose hours are
verified**, and V16 binds the quest's `hardLatestStart` to them.

| # | Field | Ships as | Capture | Write back to |
|---|---|---|---|---|
| 6.1 | `coordinate` | **unverified seed** | Lat/lon at the entrance | `places/badung-museum-bali.json` → `coordinate` |
| 6.2 | **`entryCost`** | `0` — **known wrong** | The actual ticket price, per category if it varies (domestic/foreign, adult/child), in IDR minor units | same → `entryCost`, **and** `quests/badung-empat-wajah.json` → `estimatedCost.amount` + `estimatedCost.breakdown` |
| 6.3 | `photoPolicy` | `restricted` — **unverified** | The museum's actual rule, including whether it differs by gallery | same → `photoPolicy` |
| 6.4 | `dressCode` | **unverified** | Whether there is one | same → `dressCode` |
| 6.5 | `accessibility.stepCount` | `hasSteps: true`, `stepCount: null` — **unverified** | Steps at the entrance and between pavilions | same → `accessibility` |
| 6.6 | `visitingHours` | **verified** — 6 days, `08:00–15:00` | Do **not** change without a new citation. If it has changed, recompute `hardLatestStart` | same |

> **6.2 is the highest-value single item on this checklist.** `entryCost: 0` renders as "Gratis" /
> "Free" on the discovery card (`ContentFormatter.cost` returns the free string for zero), so the
> app currently tells a walker that a ticketed museum is free. `estimatedCost.breakdown` is empty
> for the same reason, so `FR-DISC-05`'s cost total and its breakdown are both a placeholder.
>
> Capturing it also restores test coverage the content deletion removed: plan §11.0b item 1 records
> that no priced quest ships, so the paid discovery-card state was exercised by nothing until
> `challange-5Tests/ContentFixtures.swift` gave that guard a fixture of its own (m7, group A). The
> fixture makes the *requirement* tested; a real price makes the *product* correct. They are not
> substitutes.

Verified already: address and hours, with openable citations.

---

## 7. After the walk — what has to be redone, in order

1. Write back every captured value, per the tables above.
2. **Recompute `hardLatestStart`** from the new earliest closing time minus the new
   `totalDurationMin`. V16 checks it; getting it wrong is a `FR-DISC-06` warning that fires at the
   wrong hour.
3. Re-measure the route and replace `route.geojson`, `totalDistanceM`, `walkingTimeMin`,
   `totalDurationMin` together — they are one measurement, not four.
4. Rewrite `estimatedCost.amount` and `estimatedCost.breakdown` from the captured entry costs. The
   breakdown must sum to the total (`QuestPreviewTests.theCostBreakdownSumsToTheTotal`).
5. Replace each resolved `BELUM DIVERIFIKASI` citation, and rewrite the lore blocks that cite it —
   checkpoint 1's lore in particular exists in its current thin form *because* the source is missing.
6. Re-run the gate:
   ```bash
   swift run content-validator Sources/ContentKit/Content
   ```
7. **Bump `contentBundleVersion` in `manifest.json`.**
8. Re-run `swift test` and the unit suite. The discovery guards now read
   `challange-5Tests/ContentFixtures.swift` rather than the shipped tree, so they will *not* go red
   when this content changes — which is the point of that change and also means they will not catch
   a content mistake. `content-validator` and step 6 are what catch those.

## 8. What this checklist does not cover

- **Consent.** Separate document, separate failure mode: `docs/consent-request-pack.md`. An
  unverified opening time makes the app wrong; a missing consent record makes the project's claim to
  be a heritage project untrue.
- **`Support/UIStrings.swift:338`**, which still tells the user the content is "data contoh dengan
  tempat fiktif". That is now false — the places are real and the facts about them are partly
  unverified. Rewriting user-facing copy is a product decision, and it is listed in plan §11.0c and
  in `CLAUDE.md`'s Known state rather than here.
- **The `oral` accuracy label.** No `oral` lore block ships (plan §11.0b item 2), so a broken oral
  label would not be caught by shipped content. It returns with the first interview, which needs its
  own consent trail.
