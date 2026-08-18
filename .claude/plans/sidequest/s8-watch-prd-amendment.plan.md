# S8 — Proposed PRD amendment: a v2 watch companion for the proximity/sidequest card

**Status: accepted (owner imelda, 2026-08-18).** `.claude/prds/cultural-heritage-quest.full.prd.md` is
the authoritative requirements document; this block (`FR-WATCH-04`…`08`) is accepted into scope for
the v2 watch companion described below. The PRD document itself still needs the block folded in as a
formal amendment — that edit is tracked separately and is not done by this status change.

## What this is not

This is **not** `FR-WATCH-03`. That requirement (§5.14, P2/v2) is checkpoint arrival haptics during
an active Run — "so the phone can stay pocketed for the whole walk." This amendment is about a
different moment: the **outside-a-Run proximity/sidequest alert** (`FR-PROX`, `FR-SIDE-11`) getting a
richer watch-side presentation than a plain forwarded notification. The two features share nothing
but the word "watch," and `FR-WATCH-03` is untouched by this block.

## What is not changing

`FR-PROX-01…15`, `FR-WATCH-01`, `FR-WATCH-02`, `FR-WATCH-03`, `NFR-PLAT-05`, `NFR-PLAT-06` are all
**already correctly scoped to v1** ("Watch support **in v1** MUST be limited to…", "Apple Watch
support **in v1** requires no watchOS target…"). None of them forbid a v2-scoped watchOS target
existing — `FR-WATCH-03` already anticipates one. v1 ships exactly what those requirements say today:
notification forwarding only, no watch target claimed or required. This amendment adds a v2-only
capability layered on top; it does not loosen v1.

## Framing paragraph

> When a walker has installed the v2 watch companion, the proximity/sidequest notification that
> `FR-PROX-06`/`FR-SIDE-11` already deliver gets a branded long-look interface instead of the system's
> generic one: the place's synopsis, an image, and an "Open in App" action that wakes the paired
> iPhone. The short-look (the first glance, before the wrist stays raised) is **not** custom — it is
> the system's own rendering of the app icon plus the notification's title and body, which costs no
> code, only an icon and two strings. Nothing about this requires the watch companion to be installed,
> and nothing about v1 changes if it never is.

## Source

Figma `Hy5uUv7tx8a8ulvhlBCQXv` ("Ngalcer"), frames `91:176` ("Example/Notifications kiri") and
`91:182` ("Example/Notifications kanan"). `91:176` is a literal instance of Apple's own "Short Look"
watch-notification component — confirming the short/long-look split above is not a simplification of
the design, it's what the design actually specifies once read structurally rather than as a
screenshot. `91:182`'s circular image is the same `ChatGPT Image Aug 13, 2026…` asset already
recorded in `docs/hisplora-tokens.md` as the AI-generated portrait of I Gusti Ngurah Made Agung that
was deliberately **not** shipped, for exactly the reason `FR-WATCH-06` below restates: an unsourced
likeness of a named historical person is a claim, and `FR-CP-05` requires every claim to carry its
source. This amendment does not reopen that decision — it inherits it.

## Requirements

| ID | Requirement | Priority | Release |
|---|---|---|---|
| FR-WATCH-04 | When the v2 watch companion is installed, the proximity/sidequest notification's short-look **MUST** use the system's default rendering — app icon, title, body. No custom short-look interface **MAY** be built. | P2 | v2 |
| FR-WATCH-05 | When the v2 watch companion is installed, holding the wrist up through short-look **MAY** expand into a custom long-look interface showing the place's synopsis, an image slot, and an "Open in App" action. | P2 | v2 |
| FR-WATCH-06 | The long-look interface's image slot **MUST NOT** render an unsourced likeness of a named historical person. It **MUST** show either the sidequest's own already-sourced `heroImageAsset` or a generic placeholder — never a generated portrait with no consent record and no citation. | P1 | v2 |
| FR-WATCH-07 | The long-look's "Open in App" action **MUST** hand off to the iPhone app, resolving to the same place `FR-PROX-07`'s tap-to-open already opens. It **MUST NOT** open a screen inside the watch companion itself. | P1 | v2 |
| FR-WATCH-08 | Absence of the v2 watch companion **MUST NOT** change v1 behavior in any way. The notification continues to mirror via system forwarding exactly as `FR-WATCH-01` specifies. | P0 | v2 |

## Decisions that need the product owner's signature, not just an ID

### 1. A v2-scoped watchOS target existing in the repo ahead of v2

`NFR-PLAT-05`'s text is "Apple Watch support **in v1** requires no watchOS target." Read literally,
a target that exists but ships no v1-claimed functionality does not violate it — the same reading
that already lets `FR-WATCH-03` sit in the PRD as P2/v2 without a target existing yet. The `hisplora
Watch App` target (added 2026-08-18, bundle id `com.umar.hisplora.watchkitapp`,
`WATCHOS_DEPLOYMENT_TARGET = 26.5`) is currently Xcode's unmodified template — no code from this
plan yet. Record explicitly that this reading is accepted, so a later reviewer does not read the
target's presence in `git log` as a silent v1 scope violation.

### 2. The placeholder image, precisely

`FR-WATCH-06` says "a generic placeholder" without naming one. This is a design decision, not an
engineering one — `docs/hisplora-tokens.md`'s established discipline (gilded frame ships, generated
portrait doesn't, quest's own hero image fills the frame instead) is the closest precedent, but
whether the placeholder is a flat Hisplora-palette fill, an SF Symbol, or literally the parent quest's
`heroImageAsset` needs to be picked once, in `s9`, and cited back here.

### 3. Short-look stays system-default even though it was asked to be "in scope"

Product asked for the radar/pulse look to be in v2 scope before the Figma source was read
structurally. Reading `91:176` shows it is Apple's own "Short Look" component — a large tinted app
icon plus title/body, not an animation layer. `FR-WATCH-04` therefore delivers what was asked for
(a distinctive first glance) through icon design rather than through custom code, which is less work
and more correct — a hand-built short-look interface would fight the system template rather than use
it. Recorded here so the scope-down is legible as a finding, not a quiet cut.

## Sections of the PRD that also change

| Section | Change |
|---|---|
| §2 release table, Apple Watch row | v2 cell gains "+ branded proximity/sidequest card ¹" alongside the existing "arrival haptic during a Run" |
| §9 traceability | `FR-WATCH-04`…`FR-WATCH-08` rows |

No data-model change: nothing new is persisted. The card renders from the same `SideQuest`/`Place`
snapshot the iPhone notification already reads (`SideQuestProximityService.postNotification`),
carried to the watch by the system's own notification-forwarding payload.

---

*(No Execution section yet — this amendment has not been written into the live PRD. That happens
once a named owner accepts, amends, or rejects the block above, per `s7`'s precedent.)*
