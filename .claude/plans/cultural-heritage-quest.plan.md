# Plan: Cultural Heritage Quest — Content Model Locked

**Source PRD**: `.claude/prds/cultural-heritage-quest.prd.md`
**Selected Milestone**: 1 — Content model locked
**Complexity**: Medium

## Summary

Define `Place` (standalone lore) and `Quest` (an ordered reference to Places) as distinct entities, fix the accuracy-label convention, and specify the content-version pinning rules — before any content is written or any screen is built. This milestone produces a schema and a written specification, not an app. It is the critical dependency for milestones 3 and 4 (field validation and bilingual writing), which cannot start until the content team knows what fields they must fill.

Scope note from the requester: this plan is the deliverable. No scaffolding, no Xcode project, no implementation code is to be written under it.

Persistence decision from the requester: **no CloudKit**. Cross-device sync in v2 will be a custom backend, so the v1 model does not lean on any Apple sync primitive. The schema is nonetheless designed sync-ready (stable UUIDs, UTC timestamps, soft delete, schema version) so that v2 does not require a migration of user data.

## Patterns to Mirror

| Category | Source | Pattern |
|---|---|---|
| Naming | `kultara-stitch-prompts.md`, `kultara-wireframe.html` | Domain vocabulary already in use: place, quest, stop/checkpoint, story card, stamp, journal. Model names should not invent a third vocabulary. |
| Accuracy labels | PRD "Principles" and MVP content section | `[Tercatat]` (documented) vs `[Babad/Cerita rakyat]` (oral tradition), with visible source attribution — already fixed as product language, the model encodes it rather than redesigns it. |
| Bilingual content | PRD MVP scope | Indonesian is the authoring language, English is a required peer — not a fallback. |
| Errors | — | No existing code in this repository. No error-handling pattern to mirror; the plan states one below rather than inventing a precedent. |
| Logging | — | No existing code. Not applicable at this milestone. |
| Data access | — | No existing code. Not applicable at this milestone. |
| Tests | — | No test harness exists. Validation at this milestone is schema validation over authored JSON, defined below. |

**Two pre-existing artifacts contradict the PRD** and should not be treated as a pattern source for the model:

- `kultara-stitch-prompts.md` and `kultara-wireframe.html` both include Login, Register, "Continue with Google", audio narration, notifications, and a Level/XP profile. All of these are explicitly out of scope for v1 in the PRD (no account, no audio, no background notifications). They predate the PRD. Use them for visual and naming vocabulary only.
- The wireframe states "Account is required only at first quest start." The PRD directly overrides this: no auth wall at any point in v1.

## Files to Change

| File | Action | Why |
|---|---|---|
| `docs/content-model.md` | CREATE | The normative specification: entity definitions, field semantics, accuracy-label rules, versioning and pinning rules. The document milestones 3–4 are authored against. |
| `content/schema/place.schema.json` | CREATE | JSON Schema for a Place record — machine-checkable so a malformed place fails before it reaches an engineer. |
| `content/schema/quest.schema.json` | CREATE | JSON Schema for a Quest record, including the ordered checkpoint list and its reference to Place IDs. |
| `content/schema/content-bundle.schema.json` | CREATE | Wraps the set of places + quests shipped together, carrying `schemaVersion` and `contentVersion`. |
| `content/quests/_template.quest.json` | CREATE | A filled-in dummy quest showing every required field, so the content team copies rather than interprets. |
| `content/places/_template.place.json` | CREATE | Same, for a Place. |
| `docs/field-validation-checklist.md` | CREATE | The per-checkpoint list of facts that must be captured on the walk (milestone 3), derived directly from the required fields in the schema — prevents a second field trip. |
| `.claude/prds/cultural-heritage-quest.prd.md` | UPDATE | Milestone 1 row set to `in-progress` with this plan linked. |

## Tasks

### Task 1: Separate `Place` from `Quest` and name the join

- **Action**: Define three entities, not two.
  - `Place` — a heritage site that stands alone. Owns: stable ID, bilingual name, bilingual standalone lore, coordinates, address/district, opening hours, entry cost, photography rules, `isSacred` flag, managing-body/consent reference, accessibility and terrain notes, source attributions. A Place is meaningful with no quest attached — this is what makes v2's standalone Place pages a data-free change.
  - `Quest` — an ordered narrative over Places. Owns: stable ID, bilingual title, opening hook, narrative arc metadata, total distance, walking time, realistic duration, `estimatedCost`, terrain summary, recommended start window, safety notice, difficulty, and an ordered list of checkpoints.
  - `QuestCheckpoint` — the join, and the reason two entities are not enough. Owns: `order` (1…5), `placeID`, the **quest-specific** lore for this stop (distinct from the Place's standalone lore), the clue to the next checkpoint, the task, the GPS radius override, and the checkpoint role (`start` / `middle` / `finish`).
- **Why the join carries its own lore**: the same Place can appear in a future quest telling a different story. If lore lives only on the Place, the second quest overwrites the first. If it lives only on the checkpoint, v2's standalone Place pages have nothing to show. Both are needed and they are not the same text.
- **Mirror**: The wireframe's "stop" vocabulary; the PRD's "1 start / 3 middle / 1 finish" structure.
- **Validate**: The template quest references template places by ID; schema validation fails if a `placeID` has no matching Place in the bundle, if `order` is not a contiguous 1..n, or if roles are not exactly one `start`, one `finish`.

### Task 2: Fix the accuracy-label convention as a structural requirement

- **Action**: Lore is not a free string. Define `LoreBlock { text: LocalizedText, accuracy: "tercatat" | "babad", sources: [Source] }`, where a quest's or place's lore is an ordered array of blocks. `Source` carries a citation string, an optional URL, and an attribution type (`archival`, `academic`, `oral_community`, `partner`).
- **Rationale**: a per-passage label makes it impossible to write a paragraph that silently mixes documented history and oral tradition — the failure mode the risk table calls "Historical claim disputed." A label on the whole screen would not catch it.
- **Rule to state in the spec**: `sources` must be non-empty for `tercatat`. For `babad`, the source names the community, teller, or text it came from — an unsourced legend is not shippable either.
- **Mirror**: PRD Principles, "Claims carry their epistemic status."
- **Validate**: Schema requires `accuracy` and `minItems: 1` on `sources` for every block. No lore field anywhere accepts a bare string.

### Task 3: Make every user-facing string bilingual by construction

- **Action**: Define `LocalizedText { id: string, en: string }` — both required, no optionals, no fallback chain. Every displayable string on Place, Quest, Checkpoint, task, clue, and lore uses this type.
- **Rationale**: the PRD accepts a ~30% content-production cost for bilingual. Making `en` optional would let that cost be silently deferred until an English-speaking user hits a blank screen mid-walk.
- **Validate**: Schema rejects a `LocalizedText` missing either key or with an empty string. A "translation pending" placeholder is not a valid value — an unfinished quest simply does not pass validation and does not ship.

### Task 4: Specify content versioning and the pin-at-start rule

- **Action**: Define two version numbers with different jobs.
  - `schemaVersion` (on the bundle) — the shape of the data. Changed by engineers. Drives migration.
  - `contentVersion` (on the bundle, and a per-quest `questContentVersion`) — the text and facts. Changed by the content team. Never triggers a migration.
- **Pinning rule to state normatively**: a `QuestRun` records `questID` + `questContentVersion` at the moment of start, and reads its lore from that snapshot for the whole run. A content update that lands mid-walk applies to the *next* run. The completion recap renders from the pinned version, so the recap matches what the user actually read.
- **v3 consequence to write into the spec now**: the CMS may only ever *add* a new `questContentVersion`; it may not mutate a version already published. This is the one rule that keeps offline-first honest when content moves behind an API — a device holding version 4 is never wrong, only old.
- **Mirror**: PRD Principles, "Content version is pinned at quest start"; the risk row "Offline-first lost during the v3 CMS migration."
- **Validate**: Spec review. There is no code to test at this milestone; the check is that the rule is stated unambiguously enough that a v3 CMS design cannot pass review while violating it.

### Task 5: Draw the line between bundled content and user state

- **Action**: State in the spec that the model has two halves with different lifecycles and different storage:
  - **Content** (`Place`, `Quest`, `QuestCheckpoint`, `LoreBlock`) — immutable, read-only, shipped as JSON in the app bundle in v1, fetched-and-cached in v3. Never written by the app.
  - **User state** (`QuestRun`, `CheckpointProgress`, `CapturedPhoto`, `Reflection`, `SurveyResponse`, `Stamp`, `Badge`) — written locally, always, with no connectivity branch.
- **Rationale**: this split is what makes version pinning cheap (user state holds a version pointer, not a copy of the story) and what keeps the v3 CMS migration to a single layer. It also means the content team's JSON never needs a database migration.
- **Sync-ready fields on every user-state entity** (defined now, unused in v1): `id: UUID` client-generated, `createdAt` / `updatedAt` as UTC instants, `deletedAt` for soft delete, `lastModifiedBy` device identifier. No server-assigned integer IDs anywhere. **No CloudKit** — v2 sync is a custom backend, and these fields exist so v2 does not have to migrate v1 users' journals.
- **Validate**: Spec review against the PRD's offline-first principle: every entity in the user-state list must be writable and readable with the radio off, and none of them may have a required field that only a server can supply.

### Task 6: Define the fields the field validation walk must produce

- **Action**: Derive `docs/field-validation-checklist.md` mechanically from the required Place and Checkpoint fields — GPS coordinate at the safe standing spot, proposed radius, observed signal quality, opening hours as posted on site, entry cost as charged, photography restriction, terrain and step count, hazards on the approach, and the managing body's name and contact for the consent request.
- **Rationale**: milestone 3 is a physical walk of two routes. Any required field discovered later is a second trip. The schema is the checklist.
- **Validate**: Every `required` field in `place.schema.json` and every `required` field in the checkpoint object appears in the checklist, or is explicitly marked as desk-research rather than field-capture.

## Validation

No build system, test harness, or project file exists in this repository yet, so there are no project-specific commands to run. Validation at this milestone is schema-level and reviewable:

```bash
npx --yes ajv-cli validate -s content/schema/content-bundle.schema.json -d "content/**/*.json" --strict=false
```

Manual review gates, in order:

1. The two template files validate clean against the schemas.
2. A deliberately broken template — missing `en`, missing `sources` on a `tercatat` block, a `placeID` with no matching Place, a non-contiguous `order` — fails validation. A schema that only passes valid input has not been tested.
3. The content lead confirms every field in the checklist is capturable in one visit to a site.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Model is designed against the wrong routes — milestone 2 (consent) cuts a site and the structure assumed something specific to it | Medium | Keep the model route-agnostic. No field may encode anything true only of Denpasar or Ubud. The open question "which two routes ship" stays open through this milestone without blocking it. |
| Over-modeling for v2/v3 — building Journal, side-quest state, and cross-quest achievements into the schema now | High | Only `Place`/`Quest` separation and the sync-ready field set are built ahead of need, and both are justified: reversing them later costs a user-data migration. Everything else waits. |
| Content team finds the schema too rigid to write against, and works in a doc instead | Medium | Ship the filled template first, schema second. Authoring happens in JSON only if the template makes it obviously easier than prose; otherwise plan a thin authoring step in milestone 4 rather than fighting it. |
| Accuracy labels degenerate into everything marked `babad` to avoid sourcing work | Medium | Validation requires sources for both labels. Spot-check ratio during milestone 4 review — a quest that is 100% `babad` is a content-quality flag, not a schema failure. |
| Bilingual requirement stalls the schema gate — Indonesian written, English lagging | High | Validation is per-quest, not per-bundle. One finished bilingual quest can pass and ship while the second is still being translated. |

## Acceptance

- [ ] `Place`, `Quest`, and `QuestCheckpoint` are defined as distinct entities, with the quest-specific vs standalone lore split stated explicitly
- [ ] Accuracy label is a required structural field on every lore block, with sources required for both label values
- [ ] `LocalizedText` requires both `id` and `en`, with no fallback path
- [ ] `schemaVersion` and `contentVersion` are separated, and the pin-at-start rule plus the append-only-publish rule are written normatively
- [ ] Content and user state are separated, with sync-ready fields on user state and no CloudKit dependency
- [ ] Templates validate clean; deliberately broken fixtures fail
- [ ] Field-validation checklist covers every required field milestone 3 must capture
- [ ] No implementation code written under this plan
