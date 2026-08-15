# S0 — Scope, and the decisions everything else rests on

## 1. In scope

- A new authored content entity, the **sidequest**: one place, one synopsis, one history, one
  challenge, one letter.
- A new authored content entity, the **letter collection**: a phrase, and one slot per letter, each
  slot naming the sidequest that fills it.
- A user-data aggregate for sidequests that is **separate from `Run`** and stored separately.
- Entry by the same GPS rule arrival already uses, with the same manual override.
- Two challenge mechanics: **quiz** (Phase B) and **photo** (Phase D).
- Background region monitoring and a local notification when the walker enters a sidequest's notice
  radius (Phase C).
- A collection screen showing filled and blank letters, in the Journal tab.

## 2. Deliberately not in it

Named here so the gaps are decisions rather than oversights.

| Left out | Why |
|---|---|
| A map of sidequest places (the board's `pake konsep mel, detailnya map nanti`) | `FR-MAP-01`/`FR-OFF-03` rule out live tiles, and the region map is an authored illustration whose pins are authored per place (`mapPoint`). A sidequest map is a second illustration and a second authoring job; it is a follow-on, not part of the first release. |
| Sharing a completed collection | `FR-SHARE-*` is unbuilt for quests too. Building it for sidequests first would ship a share card whose only source of truth is a snapshot format that has not settled. |
| A leaderboard, streaks, or timed challenges | `FR-TASK-05` forbids timed and puzzle mechanics at sacred places, and most of these places are sacred. A mechanic that cannot be offered at most of the content is not a mechanic. |
| Hints bought with anything | there is no currency and no account. |
| Sidequests inside an active Run | `FR-SIDE-01`. A walker mid-quest is engaged; interrupting them is the exact thing `FR-PROX-08` already forbids for quests. |
| Server-side anything | `AD-3`, `AD-5`. The only network document in the whole app is the suppression list. |

## 3. Decisions

### D1 — A sidequest is its own aggregate, not a `Run` with one checkpoint

Modelling it as a one-checkpoint `Run` would be less code and would be wrong in three ways: the home
screen's "active run" resume entry (`FR-RUN-03`) would start offering sidequests; `activeRun(questID:)`
assumes one active Run per quest, which a place visited twice breaks; and `FR-PROX-08` ("no alerts
during an active Run") would suppress the very alerts this feature exists to send. Separate records,
separate store, separate engine — sharing only the pure values (`ArrivalEvaluator`, `Geo`,
`LoreBlockSnapshot`).

### D2 — The name `SideQuest` is already taken, and the existing one moves

`ContentKit.SideQuest` exists today: a checkpoint-level optional prompt (`id` + `prompt`), authored in
all five checkpoints of `badung-empat-wajah`, decoded, and **rendered by nothing**. Two entities called
sidequest in one codebase is a defect waiting to be written.

Recommended: rename the existing type to `BonusPrompt` and its JSON key `sideQuests` → `bonusPrompts`,
and give the new entity the name `SideQuest`. The rename is cheap precisely because the old type has no
presentation layer — it is a decode-only field. It costs one `contentBundleVersion` bump.

If the rename is refused, the fallback is to name the new entity `Discovery` throughout. Do not ship
both meanings of the word.

### D3 — Entry uses `ArrivalEvaluator`, unchanged

`FR-ARR-01` is two conditions, and the second — `horizontalAccuracy <= radius` — is the load-bearing
one. A sidequest that unlocked on distance alone would hand out letters from the next neighbourhood on
a cell-tower fix. The same evaluator, the same 60-second manual override (`FR-ARR-03`), the same
recording of `arrivalMethod` and the last known accuracy (`FR-ARR-04`: manual is a legitimate path, not
a lesser one).

The one difference: there is no named presence confirmation (`FR-START-09`). That confirmation exists
because starting a quest from the wrong place ruins a route of five stops. A sidequest has one stop and
nothing downstream to ruin.

### D4 — The challenge gates the **letter**, and nothing else

`AD-2` says tasks never gate progression, and rule V8 makes it auditable. That rule is about a walk:
a photograph must never stand between a walker and the next checkpoint.

A sidequest's challenge is not that. It is the sidequest. Completing it awards the letter; not
completing it awards nothing and blocks nothing — no other sidequest, no quest, no route. The letter
slot simply stays blank and the place stays re-openable forever (`FR-SIDE-07`).

`AD-2` is therefore untouched and V8 keeps its exact current meaning. `s7` states this in the PRD so
nobody later reads the letter rule as an `AD-2` violation and "fixes" it.

### D5 — A wrong quiz answer costs nothing, and after three attempts the answer is shown

Unlimited retries, no penalty, no lockout. After the third wrong attempt the correct option is
revealed with its explanation and the letter is awarded anyway.

The reason is the same one behind `FR-ARR-03`: this app is used by someone standing in a street. A
person stuck on a multiple-choice question in front of a temple gate does not go away and study; they
close the app. The quiz is a way of making the story land, not an examination, and the record keeps
`attempts` so the content team can see which questions are badly written.

### D6 — Sidequest lore shows its accuracy labels and citations

`FR-CP-05` requires the epistemic status of each claim to be visible. The Story Reveal screen in the
run flow has an undocumented exception to this, taken as a product decision on 2026-08-13
(`m8-qa-fixes.plan.md`, Decisions taken, item 2) and still not written into the PRD.

That exception does not extend to a new surface by default. Sidequest story pages render the accuracy
chip and keep the citations one tap away, as `LoreClaimList` already does at the checkpoint. If the
product owner wants the Hisplora unlabelled treatment here too, that is a second signed exception with
an owner, not an inference from the first.

### D7 — The phrase cannot be localized

A collection is `BALI THE EXPLORER` — 15 letters, therefore 15 places. Translate it and the letter
count changes, which changes the number of places, which changes the content tree per language. The
phrase is a plain `String`; a `caption: LocalizedText` next to it carries the explanation in both
languages (`NFR-I18N-01` still holds for every sentence the user reads).

This is a product constraint, not a technical one, and it needs stating out loud: **the collection
phrase is the same string in Indonesian and English.**

### D8 — Snapshot-on-complete, exactly as `Run` does it

A completed sidequest copies the resolved place name, the synopsis, the lore blocks with their
citations, the challenge prompt and the awarded letter into the user's record, and pins
`contentBundleVersion`. No object reference to any content entity, ever
(`system-design.md` §4).

Without this, correcting a sentence in a place's history would rewrite what somebody read last month,
and withdrawing a place would blank a letter they earned. The letter especially: a collection is a
record of where someone has been, and it has to survive the content that described those places.

### D9 — The notification path inherits `FR-PROX` wholesale

Opt-in, default off. Region monitoring only, never continuous background updates (`NFR-BAT-01`).
`Always` refused → the feature disables itself, says so, and nothing else in the app is affected
(`FR-PROX-05`). Quiet hours 22:00–07:00. At most one alert per sidequest per 24 h and three per day.
Nothing but scheduling the notification happens in the background handler (`NFR-BAT-06`).

Two of those rules become sharper for sidequests:

- **The 20-region iOS cap is now a live problem, not a v3 one.** `FR-PROX-14` deferred nearest-N
  selection to v3 on the arithmetic that v1 has two quests. A 15-place collection plus quest starts
  exceeds 20 the moment a second collection is authored. The nearest-N selection is built now, as a
  pure value (`s2` §6).
- **A completed sidequest is deregistered**, the same way a completed quest's start region is
  (`FR-PROX-08`).

### D10 — Rules live in `RunEngine` as pure values, because there is nowhere else to test them

The app target has no unit-test bundle. Anything expressed only in a view model or a service is
untested, and this feature's rules — quiet hours, rate limits, region selection, quiz grading, letter
progress — are exactly the kind that fail quietly and at night.

Every one of them is a `Sendable` value type or a static function in `RunEngine`, with an injected
clock, covered by `swift test` on macOS. The service layer becomes a thin adapter: CoreLocation and
`UNUserNotificationCenter` on one side, a decided fact on the other. This is the same shape that keeps
`ArrivalEvaluator` testable, and it is a constraint rather than a preference.

### D11 — Photos come last and never leave the device

Photo tasks are unbuilt everywhere (`FR-TASK-03/04`, deferred in M6). Phase D builds the first photo
pipeline in this app: capture, write to the app container, store a **relative** path (`NFR-REL-05` —
an absolute path resolves to nothing after a restore from backup), never upload, delete with
`FR-SET-02` erasure. `FR-TASK-06` still applies: no photo challenge is offered where photography is
prohibited, enforced by a validator rule and again at runtime.

### D12 — Two wireframes become real screens and are deleted

`WireframeCatalog.nearbyNotice` and `WireframeCatalog.nearbyStory` are drawings of exactly this
feature. When their screens are built, their catalogue entries are deleted in the same commit
(`WireframeCatalog`'s own rule). Their copy moves into `UIStrings`.

## 4. What this feature is blocked on

| Blocker | Blocks | Owner |
|---|---|---|
| PRD amendment (`s7`) accepted | everything shipping | product |
| Consent records for every new place (`NFR-GOV-01`, validator V4/V5) | Phase E, and therefore any release | region owner, named |
| Openable citations for every claim (`NFR-CONT-01/02`, V2/V3) | Phase E | content |
| The phrase, and therefore the number of places (`D7`) | Phase E scoping | product |
| `Always` location copy, reviewed (`FR-PROX-03`, `NFR-PRIV-10`) | Phase C | product + legal |
| No unit-test target for view models (`m7-restore-test-guards.plan.md` not done) | test coverage of `s4` | engineering |
