# S7 — Proposed PRD amendment: `FR-SIDE-*`

**Status: proposed, not accepted.** `.claude/prds/cultural-heritage-quest.full.prd.md` is the
authoritative requirements document, and the sidequest feature is not in it. Nothing in `s0`–`s6`
should be built until this block is accepted, amended, or rejected — the specs are authoritative, and
the working practice here is to say so explicitly rather than to work around a gap.

Insert as **§5.15 Sidequests and letter collections**, after §5.14 (`FR-PROX`, `FR-WATCH`).

## Framing paragraph

> A sidequest is a single-place activity outside any quest: a story with its provenance, one
> challenge, and one letter of a collectible phrase. It exists to reach the traveller who did not
> plan a walk — the same audience `FR-PROX` was written for — and to give a reason to return to a
> region after its quests are finished. A sidequest never blocks, alters, or is part of a Run.

## Requirements

| ID | Requirement | Priority | Release |
|---|---|---|---|
| FR-SIDE-01 | A sidequest **MUST** be independent of any Run. Discovering or completing one **MUST NOT** change a Run's state, progress, or awards, and **MUST NOT** be required to complete any quest. | P0 | v2 |
| FR-SIDE-02 | Opening a sidequest's story **MUST** require the same two-condition gate as checkpoint arrival (`FR-ARR-01`): inside the trigger radius, with horizontal accuracy no worse than that radius. | P0 | v2 |
| FR-SIDE-03 | A manual override **MUST** be offered after 60 s of unsuccessful detection, and immediately when location permission is refused. The entry method and last known accuracy **MUST** be recorded, and a manual entry **MUST NOT** be rewarded differently. | P0 | v2 |
| FR-SIDE-04 | Sidequest story claims **MUST** display their accuracy label and **MUST** make their sources reachable, as `FR-CP-05`/`FR-CP-06` require at a checkpoint. | P0 | v2 |
| FR-SIDE-05 | Completing a sidequest's challenge **MUST** award exactly one letter, once. Re-opening a completed sidequest **MUST NOT** award a second. | P0 | v2 |
| FR-SIDE-06 | A quiz challenge **MUST** allow unlimited attempts with no penalty, and **MUST** reveal the correct answer with its explanation after three wrong attempts, awarding the letter regardless. | P0 | v2 |
| FR-SIDE-07 | An incomplete sidequest **MUST** remain openable at its place indefinitely, and **MUST** be reachable from the collection screen and from a nearby-places list without waiting for a notification. | P0 | v2 |
| FR-SIDE-08 | Collection progress **MUST** show earned letters in place and unearned slots as blanks. An unearned slot **MUST NOT** reveal its letter. | P0 | v2 |
| FR-SIDE-09 | Completing every slot of a collection **MUST** award that collection's badge, once. | P1 | v2 |
| FR-SIDE-10 | A sidequest record **MUST** render identically after the content that produced it is corrected, replaced, or withdrawn. Place name, story, citations and letter **MUST** be snapshotted at discovery, and the content version pinned. | P0 | v2 |
| FR-SIDE-11 | Proximity notification for sidequests **MUST** follow `FR-PROX-03` … `FR-PROX-15` in full: opt-in with a default of off, region monitoring only, self-disabling without `Always`, local delivery, quiet hours, and rate limits. | P0 | v2 |
| FR-SIDE-12 | Sidequest alerts **MUST NOT** fire while any Run is active, and **MUST NOT** fire for a sidequest already completed. | P0 | v2 |
| FR-SIDE-13 | A photo challenge's photograph **MUST** remain on the device, **MUST** be stored by a path relative to the app container, and **MUST** be deleted by `FR-SET-02` erasure. | P0 | v2 |
| FR-SIDE-14 | Sidequests suppressed by the kill-switch (`AD-5`) **MUST** disappear from every surface and have their regions deregistered on next launch. Letters already earned **MUST** be retained. | P0 | v2 |
| FR-SIDE-15 | Every part of the sidequest flow except the kill-switch fetch **MUST** work with no network. | P0 | v2 |
| FR-SIDE-16 | The number of monitored regions across quests and sidequests **MUST NOT** exceed the platform limit; when candidates exceed it, the app **MUST** register the nearest, recomputed from coarse location, rather than failing silently. (Supersedes `FR-PROX-14`'s v3 timing.) | P0 | v2 |

## Decisions that need the product owner's signature, not just an ID

### 1. The challenge gates the letter — `AD-2` is not weakened

`AD-2` states tasks never gate progression, and validator rule V8 makes it auditable. A sidequest's
challenge gates its own letter and nothing else: no checkpoint, no quest, no other sidequest.

Record this in `AD-2`'s own text as an explicit carve-out, so nobody later reads `FR-SIDE-05` as a
violation and removes it, and nobody widens V8 to cover sidequest challenges.

### 2. The collection phrase is not localized

`BALI THE EXPLORER` is the same string in both interface languages. Translating it changes the letter
count, which changes the number of places, which forks the content tree per language. `NFR-I18N-01`
still holds for every sentence around it. This is a product constraint that has to be accepted
knowingly.

### 3. An unearned slot hides the place name as well as the letter

Proposed in `s4` §5, on the grounds that a visible list of addresses makes the notification pointless.
The counter-argument — that a traveller wants to plan — is real. Product decides; whichever way, it
belongs in `FR-SIDE-08` rather than in a view.

### 4. `FR-CP-05` still needs its earlier amendment

Separate from this feature, and outstanding since 2026-08-13: the run flow's Story Reveal pages render
lore without the accuracy chip or citation, by a product decision recorded in
`m8-qa-fixes.plan.md` and `docs/hisplora-tokens.md` but **not** in the PRD. `FR-SIDE-04` deliberately
does not inherit that exception. Both need writing down — one as an amendment or signed exception with
an owner, the other as the new requirement above.

## Sections of the PRD that also change

| Section | Change |
|---|---|
| §2 release table, Notifications row | v2 gains "sidequest proximity (opt-in, off)" |
| `AD-2` | the carve-out in decision 1 above |
| `AD-1` | background region monitoring now covers sidequest places as well as quest starts |
| §4 data model | `SideQuestRecord`, `SideQuestChallengeResult`, `AwardType.letter` |
| §5.14 `FR-PROX-14` | superseded by `FR-SIDE-16` for timing |
| release acceptance criteria | the eight gates in `s6` §5 |
| open items | the phrase length, and `noticeRadiusM`'s default, join `proximity_radius_m` as figures that must come from field validation rather than a spreadsheet |

---

## Execution — 2026-08-15

**One file changed: `.claude/prds/cultural-heritage-quest.full.prd.md`.** No code, no content, no
`contentBundleVersion` bump — nothing under `Sources/ContentKit/Content/` was touched. `git status`
shows that single modification.

### Product decisions taken before writing

Four things in this plan were the product owner's call and were put to them rather than guessed:

| Question | Decision | Where it landed |
|---|---|---|
| How the block lands, given "proposed, not accepted" | **Marked PROPOSED, pending signature.** Written into the authoritative PRD so the IDs are reserved and stable, but every fragment carries the marker and reverts as a unit if rejected. | §5.15 status banner, and a `¹`-style marker on each edit made elsewhere |
| Decision 3 — does an unearned slot hide the place name? | **No. It names the place; only the letter stays hidden.** Overrules `s4` §5's recommendation, which is exactly what `s4` said should happen if product disagreed — a line here, not a quiet change in a view. | `FR-SIDE-08` requirement text, plus decision 3's rationale |
| `s0` D2 — the `SideQuest` name collision | **Rename the existing type to `BonusPrompt`**, JSON key `sideQuests` → `bonusPrompts`; the new entity takes `SideQuest`. | Glossary, §4.1 Checkpoint, `FR-TASK-08/09` wording |
| Decision 2 — the collection phrase is not localized | **Accepted knowingly.** Same string in ID and EN; the letter count is the place count. | §5.15 decision 2, marked accepted 2026-08-15 |

### What was written

- **§5.15 Sidequests and letter collections — `FR-SIDE`**, new. Status banner, framing paragraph,
  `FR-SIDE-01` … `FR-SIDE-16`, and the four signature decisions with their current status. Requirement
  text is as drafted above except `FR-SIDE-08`, which gained the place-name clause per the decision,
  and cross-references added where the plan implied them (`FR-ARR-03/04` on `FR-SIDE-03`, `AD-4` on
  `FR-SIDE-10`, `AD-3` on `FR-SIDE-15`).
- **Existing §5.15 Post-MVP renumbered to §5.16.** Section number only; no requirement ID moved, per
  the document's own never-renumber rule. Grepped `.claude/prds/`, `docs/` and `.claude/plans/` for
  references to either number — there are none.
- **§2 release table** — Notifications *and* Background location rows both gain sidequest coverage in
  the v2 column, with a footnote marking them proposed. The plan named only the Notifications row; the
  Background location row carries the same fact and would have been left contradicting `AD-1`.
- **`AD-1`** — an "Extension in v2" paragraph: monitored regions grow to include sidequest places, the
  foreground/background split is unchanged, and the 20-region cap becomes live arithmetic.
- **`AD-2`** — the carve-out, stated as two things nobody may reverse by inference: **V8 keeps its exact
  current scope and must not be widened to sidequest challenges**, and `FR-SIDE-05` is not a violation
  to be "fixed".
- **§4.1 Checkpoint** — `side_quests[]` → `bonus_prompts[]`, with the rename's reason and its
  `contentBundleVersion` cost recorded on the row.
- **§4.2** — `Award.type` gains `letter`; a new proposed subsection carries `SideQuestRecord` and
  `SideQuestChallengeResult`, with `s0` D1's three reasons for a separate aggregate and the
  no-object-reference rule restated.
- **§5.14** — `FR-PROX-14`'s release struck through to a footnote: the requirement and its ID are
  unchanged, only the timing moves, and it reverts to v3 if the block is rejected.
- **`FR-TASK-08/09`** — reworded from "Side quest" to "Bonus prompt", IDs untouched, with a note that
  only the term moved and they have nothing to do with `FR-SIDE-*`.
- **§8** — the eight gates from `s6` §5, as a separate v2 subsection rather than appended to the v1
  list, since that list opens "v1 is not shippable until all of the following hold".
- **§9 traceability** — one `FR-SIDE` row. Not in this plan's change table; added because §9's own text
  makes a P0 block with no traceability row "a candidate for cutting".
- **§10 open questions** — the phrase length, `noticeRadiusM`'s default, a cross-link tying it to
  `proximity_radius_m`'s open field-validation question, and the `FR-CP-05` exception.

### Verification

Nothing executable changed, so both commands are regression checks rather than proof of new behaviour.

```
$ swift test
􁁛  Test run with 244 tests in 27 suites passed after 0.036 seconds.

$ swift run content-validator Sources/ContentKit/Content
OK  1 quest(s), 5 place(s), 2788535 bytes — all 18 rules pass.
EXIT=0
```

244 tests, 27 suites, all passing. 18 validator rules, all passing — V19–V28 belong to `s1` and do not
exist yet. `xcodebuild` was not run: the app target is untouched.

### Left out, deliberately

- **All code.** `s1` ContentKit types and rules V19–V28, `s2` `RunEngine` records and store, `s3`
  proximity, `s4` screens, `s5` content and consent. This plan produces requirements, not a feature.
- **The rename itself.** `ContentKit.SideQuest` → `BonusPrompt` is now *decided and written into the
  PRD*, but the type, the JSON key in all five checkpoints of `badung-empat-wajah`, and the
  `contentBundleVersion` bump are `s1`'s work. **The PRD and the code currently disagree on this name**
  — that is the expected state between an accepted amendment and its implementation, but it is a real
  gap and `s1` closes it.
- **The authored content entities.** §4.1 gained no Sidequest or Letter-collection row. The plan's
  change table named three user entities and only those; the authored half is specified in `s1` and
  §4.2 points there.
- **`FR-CP-05` itself.** Left unedited. Decision 4 needs an amendment *or* a signed exception with a
  named owner, and no owner exists — softening the requirement without one would put the same
  undocumented exception into the authoritative document, which is the thing being complained about.
  Recorded in §10 instead, with its 2026-08-13 date.

### New known gaps

1. **The block is unsigned.** Every edit above is marked proposed and reverts as a unit. `s0` §4's
   blocker table — "PRD amendment accepted → blocks everything shipping" — is still accurate, and
   `s1`–`s6` remain blocked.
2. **`FR-CP-05` has no owner.** Outstanding since 2026-08-13 and now recorded in the PRD, which makes
   it visible but does not resolve it. It is independent of this feature and should not wait on it.
3. **PRD-vs-code name divergence** on `SideQuest`/`BonusPrompt` until `s1` runs — see above.
4. **`FR-SIDE-08`'s place-name decision has a content consequence nobody has costed.** Naming every
   unearned slot's place means the collection screen lists places whose consent records may not exist
   yet (`s5`, Phase E). A place must not be named on a surface before it is cleared to be named at all
   — `NFR-GOV-01` and the consent `scope[]` value `naming`. `s4` and `s5` need to honour this; it is not
   a new requirement, but it is a new place where the existing one bites.
