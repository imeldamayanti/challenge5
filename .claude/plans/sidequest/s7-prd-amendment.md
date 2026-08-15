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
