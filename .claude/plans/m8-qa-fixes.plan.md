# M8 — QA fixes, then the Hisplora visual direction

**Status:** planned, not executed.
**Source:** manual QA session, 2026-08-13, six findings reported against the build at `c3be71c`.
**Scope of requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`, `docs/system-design.md`.

This milestone has two phases and a gate between them.

- **Phase 1 — fix the six QA findings.** Five are defects or unbuilt requirements; one is the product
  working as specified.
- **Gate — prove Phase 1 works.** The full verification pass below, green, before any pixel moves.
- **Phase 2 — implement the new UI** from the Hisplora Figma file, via the Figma MCP.

The order is deliberate. Phase 2 rewrites the surfaces Phase 1 repairs — the map markers, the arrival
screen, the dialogs. Restyling a broken gesture handler produces a beautiful screen with the same bug
in it, and makes the bug harder to find afterwards because the diff that introduced it is buried in a
thousand lines of layout. Fix the behaviour, prove it, then change how it looks.

The findings are listed in the order they were reported, then re-ordered into a work sequence at the
end.

---

## Finding 1 — The floating tab bar rides up with the keyboard

**Reported:** "Setiap input ke field (search etc) navbar selalu ngikut."

**Confirmed in code.** `KultaraRootView.browser` attaches the bar as a bottom safe-area inset:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    if !hidesTabBar { KultaraTabBar(tabs: tabs, selection: $tab) }
}
```

SwiftUI's keyboard avoidance raises the bottom safe area when a field takes focus, and inset content
is laid out against that safe area — so the bar lifts and sits directly on top of the keyboard. The
inset itself is the right call for the reason the comment at `View/KultaraRootView.swift:58` gives
(it reserves exactly the bar's real height, which a `ZStack` overlay cannot); the defect is that it
inherits keyboard avoidance it should not have.

**Fix.** Opt the inset content out of keyboard avoidance:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    if !hidesTabBar {
        KultaraTabBar(tabs: tabs, selection: $tab)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
```

**The trap to check while verifying.** Applying `.ignoresSafeArea(.keyboard)` to the *container*
instead of the inset content would also stop the content beneath from moving, which would put the
task-answer `TextField`s in `TaskCard` under the keyboard on the checkpoint screen. The modifier
belongs on the bar only. Verify both fields — the Home search field (near the top, must not move)
and a checkpoint task field (mid-screen, must still be pushed clear).

**Fallback if the modifier proves insufficient on device.** Hide the bar entirely while a field is
focused, driven by a `@FocusState` published from the screens that own text fields. This is arguably
the better interaction anyway — the bar is not reachable with the keyboard up — but it costs a piece
of cross-screen state, so it is the second choice, not the first.

**Guard.** A UI test in `challange-5UITests`: tap the search field, assert the tab bar's frame origin
is unchanged from its pre-keyboard value.

---

## Finding 2 — Map pins fire on touches that were meant as pinch or pan

**Reported:** "Pin tempat terlalu gampang di klik, kayak pas zoom in dan zoom out dia terlalu
sensitif kepencet."

**Confirmed in code**, and there are three separate causes stacked on each other in
`View/RegionMapView.swift`.

1. **The tap target is the label, not the pin.** `marker(_:labelBelow:)` wraps a `VStack` of
   `MapPlaceLabel` (up to `labelWidth = 130` points wide, multi-line) *and* the 28-point pin symbol
   in one `Button`, then applies `.contentShape(Rectangle())` over the whole stack. The pressable
   area is therefore roughly 130 points wide by the height of label-plus-pin, most of it transparent
   map. With markers alternating their label above and below (`index.isMultiple(of: 2)`), two
   adjacent markers' rectangles overlap and a touch on empty coastline hits whichever is on top.

2. **Buttons win the touch against the map's own gestures.** The pan and magnify gestures are
   attached to the containing `ZStack`; the markers are children of it and drawn on top. A finger
   that lands on a marker rectangle at the start of a pinch or a drag is claimed by the button, and
   releasing it inside fires `onSelect`. This is exactly the "pas zoom in dan zoom out kepencet"
   case.

3. **Double-tap-to-zoom is swallowed the same way.** `.onTapGesture(count: 2) { toggleZoom() }` is on
   the container, so a double tap that begins over a marker rectangle navigates instead of zooming.

**Fix, in three parts, all inside `RegionMapView`:**

- **Shrink the hit area to the pin.** Move `.contentShape` onto the pin symbol only and give it a
  44-point square frame (`KultaraMetrics.minimumTapTarget`, `NFR-A11Y-06` satisfied by the circle,
  not by the label). The label becomes decorative — it is already `accessibilityHidden(true)` inside
  `MapPlaceLabel`, so nothing is lost to VoiceOver, which reads the marker's own
  `accessibilityLabel`.

- **Gate selection on gesture state.** Add `@State private var isManipulating = false`, set it in
  the `updating` closures of both the drag and the magnify gesture, and clear it on `onEnded` after
  a short settle (~150 ms, so the lift at the end of a pinch does not land as a tap). Markers get
  `.allowsHitTesting(!isManipulating)`.

- **Require a stationary touch.** Replace the marker's `Button` with a tap recognised through
  `DragGesture(minimumDistance: 0)` whose `onEnded` fires `onSelect` only when
  `hypot(translation.width, translation.height) < 10`. Keep `.accessibilityAddTraits(.isButton)` and
  the existing `accessibilityLabel`, and add `.accessibilityAction` so VoiceOver activation still
  selects — a bare `DragGesture` is not activatable by the rotor.

**Guard.** The movement threshold and the settle window are the testable parts: extract them as named
constants and assert in a unit test that a synthetic touch with 40 points of travel does not select.
The gesture arbitration itself is only verifiable by hand; record it in the plan's verification
section as a manual check on the simulator (pinch in, pinch out, drag across a cluster — no
navigation should occur).

---

## Finding 3 — "Can a pin really show route detail? Isn't that supposed to be secret?"

**Reported:** "Emang di pin tempat bisa liat detail route? Itu bukannya jadi 'secret' unless dia ke
tempat itu?"

**This is the specified behaviour, not a defect.** `FR-DISC-04` reads:

> Preview **MUST NOT** reveal checkpoint lore segments or clues. Place names and the map are shown;
> the story is not.

The preview screen was audited against this and complies. `QuestPreviewView` shows the route preview
image (`FR-MAP-01`, a pre-rendered asset), the ordered checkpoint list with place names, dress code,
photo policy, surface and access notes, the cost breakdown, timing and safety notes. It renders
`quest.hookLore` — the quest-level hook, not any checkpoint's `loreSegment` — and it prints
`previewStoryWithheld` to say plainly that the story is held back. No `clueToNext` value reaches the
preview view model.

So the secret, as the PRD defines it, is the *story and the clues*; the route and the place names are
deliberately public so that someone can decide whether to walk it, what it costs, and whether it is
accessible to them. `FR-DISC-05` reinforces this: cost has to be visible *before* preview.

**Two things to do, neither of them a behaviour change:**

1. **Lock the compliance with a test.** `FR-DISC-04` had a guard in `Tests/AppFeaturesTests/
   DiscoveryTests.swift` and `b597b5b` deleted it along with 111 other tests (see
   `.claude/plans/m7-restore-test-guards.plan.md`). Restoring it belongs to M7, and the assertion
   should be the negative one: build a preview view model from content whose checkpoints carry lore
   and clues, and assert that no string it exposes matches either.

2. **Raise the product question separately if it is a real one.** If the team wants place names
   withheld until arrival, that is an amendment to `FR-DISC-04`, and it collides with `FR-DISC-05`
   (cost per place), the accessibility notes per checkpoint, and the route preview image itself —
   a walker cannot judge terrain or cost for stops they are not allowed to see. Do not change this
   in code without the PRD changing first.

---

## Finding 4 — Starting the first checkpoint gives no visible waiting state

**Reported:** "Pas 'start the first point' itu gada modal untuk waiting atau alert untuk waiting."

**Partly built, and what exists is too quiet.** The path after tapping *Mulai dari titik pertama* is
safety notice → location notice → `awaitingArrival`, and the arrival screen does have a status card
(`arrivalStatusCard`) that shows `arrivalSearching` / `arrivalNoFix`, then distance and accuracy once
fixes arrive. `FR-ARR-05` forbids an indefinite spinner, which is why there is no spinner — that part
is correct and must stay correct.

What is wrong is the presentation. The status card is the *third* thing in a scrolling stack (heading,
then `clueCard`, then the status), rendered in body text at the same weight as everything else, so on
a phone the reader can land on the arrival screen and never see that the app is doing anything. There
is no indication of how long the wait might last.

**Fix — make waiting legible without breaking `FR-ARR-05`:**

- Move the arrival status above the clue card. The clue matters while walking; the fix status matters
  the moment the screen opens.
- Give the `.searching` state a *bounded* wait: show the elapsed seconds and the countdown to the
  manual override becoming available ("Menandai sendiri tersedia dalam 0:47"). This is the honest
  version of a progress indicator — the wait genuinely ends at 60 s, because that is `FR-ARR-03`.
- A determinate `ProgressView(value:total:)` driven by that countdown is acceptable; an indeterminate
  spinner is not.
- Keep every state's numbers as they are — distance and accuracy already satisfy `FR-ARR-05` once a
  fix exists.

**No modal here.** The reported wish for a "modal untuk waiting" conflicts with `FR-CP-03`/
`NFR-SAFE-02`: the clue and the status must stay readable at rest, and a modal over the arrival
screen would cover the clue the walker is using to find the place. The fix is prominence and a
countdown, not a sheet. (A sheet *is* the right answer for the manual override — Finding 5.)

**Guard.** View-model tests: `arrival == .searching` exposes a countdown that decreases; it reaches
zero exactly when `manualOverrideAvailable` flips true; a denied permission produces the override
immediately with no countdown (`FR-ERR-02`).

---

## Finding 5 — No map on the way to the next checkpoint, and the self-mark section is unreadable

**Reported:** "Pas berangkat ke titik selanjutnya, bukanya di show map ya? (Ini balik juga gada
preview lokasinya). Bagian 'pindai sendiri' itu gak kebaca, mending di buatin modal aja."

Two defects in one report. The first is an unbuilt P0 requirement.

### 5a. `FR-MAP-02` is not implemented

> During an active Run the map **MUST** show, at minimum: the ordered checkpoint sequence, the user's
> position relative to the next checkpoint, and the straight-line distance remaining.

The arrival screen shows a clue and a distance figure, and no map at all. The distance figure alone
does not satisfy the requirement — position *relative to* the next checkpoint is a direction, not a
scalar.

**Constraints that decide the implementation:**

- `FR-MAP-01` / `FR-OFF-03`: no live tiles, so no `MKMapView`. A MapKit view is explicitly named as
  unacceptable.
- Content already ships what is needed: `RouteInfo.geometryAsset` points at a per-quest
  `route.geojson` (present for all three sample quests), and every `Place` carries a real
  `coordinate` plus an `arrivalRadiusM`.
- `Place.mapPoint` is **not** usable here. It is authored against the stylised island illustration
  (`CLAUDE.md`, and the validator checks range, not geography) and means nothing at street scale.

**Fix — a drawn route canvas, `View/Component/RunRouteMapView.swift`:**

- Decode the route geometry in `ContentKit` (a GeoJSON `LineString` → `[Coordinate]`), behind a
  repository accessor, so `RunEngine` and the views stay Foundation-only and the parsing is tested
  where the other content parsing is tested. Add a validator rule if the geometry can be malformed
  in ways V1–V17 do not already catch.
- Project the polyline and the checkpoint coordinates to view space with an equirectangular
  projection scaled to the bounding box of what is drawn. At a few hundred metres this is accurate
  to well under a pixel, and unlike the illustrated map there is no artwork for it to disagree with.
- Draw, in a `Canvas`: the route polyline, the ordered checkpoint pins numbered by `orderIndex`, the
  target checkpoint's arrival radius as a circle, the user's last fix, and the straight line between
  user and target with the distance printed on it.
- Feed it from `QuestRunViewModel`, which currently discards the fix coordinate in `handle(fix:)` —
  keep the last coordinate alongside `lastKnownAccuracyM` and publish it.
- Show it only when there is a fix; with no fix the canvas still draws the route and the checkpoints,
  which is the "preview lokasi" the report also asks for.

**Spoiler check.** Drawing the whole route reveals the sequence of stops, which the preview already
reveals (Finding 3) — so this adds no disclosure that `FR-DISC-04` withholds. It must not draw lore
or clue text.

**Guard.** Projection and bounding-box maths are pure functions: unit-test them. Assert that the
distance drawn equals `Geo.distanceM` for the same pair, so the map and the status card cannot
disagree.

### 5b. The manual override is invisible until it is not

`manualOverride` in `QuestRunView` renders, before 60 s have passed, a single line of
`.metadata`-sized `inkMuted` text at the bottom of a scrolling screen — "Kalau sinyal tidak juga
datang, pilihan menandai sendiri muncul setelah satu menit." That is the least prominent styling in
the design system, applied to the one control that keeps the product usable when GPS fails
(`FR-START-10`). After 60 s it becomes a `.ruled` button with a second line of the same muted text.

**Fix — a themed sheet, which is what the report asks for and what the requirement wants:**

- Keep an always-visible entry point on the arrival screen, but as a real control at readable weight,
  not a muted caption. Before availability it carries the countdown from Finding 4; after, it reads
  `arrivalManualAction`.
- Tapping it presents a sheet (medium detent) holding: the explanation `arrivalManualNote` at body
  size (`FR-ARR-04` — it costs nothing, stated plainly), the confirm action, and, when permission was
  refused, the `SystemSettingsLink` and the denied-permission copy that today sits in the status
  card.
- At the start checkpoint the sheet's confirm action still routes through the named presence
  confirmation (`FR-START-09`); do not collapse the two steps into one, and do not let the sheet
  become a second way to start a Run from outside the radius (`FR-START-08`).

---

## Finding 6 — The "Hentikan perjalanan" confirmation looks like a system alert

**Reported:** "Hentikan perjalanan modalnya aneh, terlalu native."

**Confirmed.** Four `confirmationDialog`s exist — abandon and presence confirmation in
`QuestRunView`, resume-or-restart in `QuestPreviewView`, erase-data in `SettingsView`. They render in
the system's font, fill and button metrics, none of which the theme has measured, and the same
argument the design system already makes about `KultaraSearchField` ("the system bar brings its own
font, its own fill and its own cancel button, none of which belong to this theme") applies exactly.

**Fix — one component in `DesignSystem`, `KultaraDialog`:**

- A `.sheet` with `presentationDetents([.height(...)])` (not a hand-rolled `ZStack` overlay — a sheet
  gets dismissal, focus containment and the accessibility scrim for free), styled as raised paper
  with a rule, a serif title, body copy, and the theme's `.seal` / `.ruled` button styles.
- A destructive variant for abandon and erase, distinguished by more than colour (`NFR-A11Y-05`):
  the seal glyph plus a weight change, as the tab bar already does for selection.
- Apply to all four call sites at once. Leaving two native and two themed is worse than leaving all
  four native.

**What must not regress.** The system dialog gives, for free, several things a hand-rolled one does
not:

- `.accessibilityAddTraits(.isModal)` on the container, so VoiceOver does not wander into the screen
  behind it.
- Initial focus on the dialog, and focus returned to the invoking control on dismissal.
- Escape / swipe-to-dismiss mapped to *cancel*, never to the destructive action.
- 44-point targets and legible layout at accessibility text sizes — the abandon dialog's body copy
  (`runAbandonConfirmBody`) is two sentences and must not clip at AX5.

`FR-RUN-04` requires the confirmation to name what is kept and what is lost; the existing strings do
this and carry over unchanged.

**Guard.** `KultaraThemeTests` already measures contrast pairs — add the dialog's surface and its
destructive button to that set, so the new component's colours are asserted rather than reviewed.
A UI test should assert that dismissing the abandon dialog by swipe leaves `run.state == .active`.

---

## Phase 1 work sequence

Ordered by ratio of user-visible harm to cost, not by report order.

| # | Work | Touches | Size |
|---|---|---|---|
| 1 | Finding 1 — keyboard inset | `KultaraRootView.swift` | one line plus verification |
| 2 | Finding 2 — pin hit area and gesture gating | `RegionMapView.swift` | small |
| 3 | Finding 6 — `KultaraDialog` and four call sites | `DesignSystem`, 3 views | medium |
| 4 | Finding 4 — arrival status prominence and countdown | `QuestRunView`, `QuestRunViewModel` | medium |
| 5 | Finding 5b — manual override sheet | `QuestRunView`, `QuestRunViewModel` | medium, depends on 3 and 4 |
| 6 | Finding 5a — `FR-MAP-02` route canvas | `ContentKit`, new view, `QuestRunViewModel` | large |
| — | Finding 3 — no code change; test restoration belongs to M7 | — | — |

Items 4 and 5 are one editing pass over the arrival screen and should be done together even though
they are listed apart. Item 6 is the only one that adds a content-parsing surface, and it is the only
one that can be deferred to its own milestone without leaving the app in a half-fixed state — the
other five are all defects in things already shipped.

## The gate — verification of Phase 1

Per item, plus one pass at the end covering all of it. **Phase 2 does not begin until this pass is
green and the manual checks have actually been performed rather than reasoned about.**

- `swift test` from `challange-5/Packages/Kultara` — the pure-logic guards (projection maths, the
  countdown, the tap-travel threshold).
- `xcodebuild test` on `iPhone 17`, `OS=26.5` — the UI-test assertions named above.
- Manual, on the simulator with **Settings → Developer tools → Simulate arrival anywhere** on: walk a
  full quest and check the arrival screen at each of the three checkpoints; pinch and drag the region
  map across a cluster without navigating; type in the search field and watch the bar; open and
  dismiss all four dialogs.
- Manual, at AX5 text size: the dialog, the arrival status block and the override sheet.
- VoiceOver: marker activation on the map, dialog focus containment, the override sheet's reading
  order.

---

# Phase 2 — The Hisplora visual direction

**Source of truth:** Figma file `Ok5TmLeDGTbIDuxGbDQFeM` ("Hisplora"), entry node `13-128`
(`13:128` in MCP node-id form).
**Entered only after the gate above is green.**

## What the Figma file actually contains — read 2026-08-13

Access works: the remote Figma MCP authenticates as the file's owner, and `get_screenshot` and
`get_variable_defs` both return for node `13:128`. Two things were learned, and one blocker remains.

### The board is a user flow, not a screen set

`13:128` is a 7291 × 3318 board titled **"Story Preview"** (author: Nisrina), divided into three
labelled and ticked-off sections:

| Section | Screens on the board |
|---|---|
| Preview & Check Location | story preview (typewriter illustration), the system location prompt over a map, **"Location Checking…"**, a decision diamond, **"Location Verified"** with a route map and a *Continue* button — and, off the failure branch, **"Not Quite There"** with a map and a *Navigate There* button |
| Cutscene | "A Legend Will Guide Your Journey", a framed portrait cutscene, "I Gusti Ngurah Made Agung" with a *Start the Journey* button |
| Story Reveal | sepia sketch pages of narrative, with designer sticky notes attached |

**This matters more than a restyle.** Three of those screens are the QA findings above, already
designed: "Location Checking…" is Finding 4's missing waiting state, "Not Quite There" with a map and
a navigate action is Finding 5a's missing `FR-MAP-02` surface, and "Location Verified" is the
transition between them. The behaviour Phase 1 builds is the behaviour these frames draw. Build the
behaviour in Phase 1 as planned; Phase 2 dresses it.

It also raises a scope question that is not answerable from a screenshot: the flow shows a
**cutscene** between arrival and the story, which the app does not have and the PRD does not
describe. See the open questions.

### The colour variables are not the design's colours

`get_variable_defs` on the style-guide page (`1:632`) returns a template palette — `Blond`,
`Light Hot Pink`, `Maximum Blue Purple`, `Android Green`, `Naples Yellow`, plus 0–900 ramps for four
of them and a `Neutral` ramp. On `13:128` it returns iOS system defaults (`SF Pro Text`,
`Labels/Primary`, `Fills/Secondary`) plus `Primary-Navy/100` and `Green/50` — those last two are the
colours of the board's own "Done" annotation chips, not of the app.

Neither set describes the screens, which are drawn in browns, cream and sepia as raw fills. So
**there is no token layer to import**; the palette has to be sampled from the frames themselves and
named by us. The `Neutral` ramp is the only part worth keeping as-is.

The one page in the document is called "Style Guide" and holds exactly two frames: `1:92`
(Typography, Plus Jakarta Sans, five sizes) and `1:632` (Colors). **Plus Jakarta Sans is a
sans-serif** — the current design system is built on a display serif (`KultaraFonts`), so this is a
type direction change, not a size change, and it needs the licence checked before it ships.

### Blocker — per-frame node IDs

`get_metadata` and `get_design_context` both fail on `13:128`, reproducibly and at the same offset:

> Failed to parse SSE message: Invalid JSON: EOF while parsing a string at line 1 column 880

`whoami`, `get_screenshot` and `get_variable_defs` on the same node all succeed, and `get_metadata`
succeeds on `0:1` — so this is a serialization fault on that specific subtree, not a permissions or
setup problem. The consequence is that the child frames' node IDs cannot be enumerated, and
`get_design_context` — the tool the design-to-code workflow is built on — cannot be called on
anything inside the board.

**What is needed from the designer or the file owner:** a node-specific link per screen (select the
frame in Figma → right-click → *Copy link to selection*), for at least these frames:

1. Story preview
2. Location Checking…
3. Location Verified
4. Not Quite There
5. Cutscene intro / portrait / "Start the Journey"
6. One Story Reveal page
7. The Typography frame (`1:92` — already have the ID)

Guessing IDs was tried and rejected: `13:129` does not exist, and the design-to-code workflow
explicitly forbids guessed node IDs.

## The eleven frames — inventory read 2026-08-13

Node-specific links were supplied for eleven frames. Every frame is **402 × 874** (the iPhone 16/17
Pro logical size) with absolutely positioned children. Seven returned metadata; four hit the same
serialization fault as the board and are marked ✗ — they are readable in the board screenshot but
their structure has not been extracted.

| Node | Frame name | What it is |
|---|---|---|
| `81:588` ✗ | — | story preview, the typewriter screen (from the board render) |
| `223:1877` ✗ | — | the system location prompt over a map (from the board render) |
| `81:617` | Location Checking | "Location Checking…." / "Making sure you're at the right place", a 63 × 63 image at the centre |
| `89:1402` | Location | "Location Verified" / "You're at the right place. The story awaits.", two map images, two pin markers drawn as paired ellipses (10 pt outer, 6 pt inner), *Continue* |
| `223:2004` | Location | "Not Quite There" / "You're not at the right place yet. Get closer to begin the story.", a 362 × 219 `Maps` rectangle, *Navigate There*, *Back to Homepage* |
| `98:1588` | Cutscene quest - Lore | "A Legend Will Guide Your Journey", a 360 × 450 photo frame, "Swipe photo frame to reveal the legends" |
| `187:866` | Cutscene quest - Lore | the portrait, "I Gusti Ngurah Made Agung" / "The Last King of Badung", a two-line lead, *Start the Journey* |
| `105:1699` ✗ | — | Story Reveal 1 — **typing animation, line by line, then the highlighted points animate** |
| `187:954` ✗ | — | Story Reveal 2 |
| `187:1053` | Story - Reveal 3 | two full-bleed sketch images, two paragraphs, a `3/3` pager, a back chevron, a 48 × 48 circular next button |
| `187:1103` | Transition | "Stepping into the First Place of Badung" / "Puri Agung Pemecutan", map with pins — **the place name blinks, auto-advances after 5 s** |

### How these frames map onto the app that exists

- `81:617`, `89:1402` and `223:2004` are **Findings 4 and 5, designed**. Build the behaviour in
  Phase 1 (countdown, route canvas, override sheet); these frames decide what it looks like. Note
  that `223:2004`'s *Navigate There* implies handing off to an external maps app — a new decision,
  not currently in the product, and one that leaves the app mid-quest.
- `98:1588` and `187:866` are the **cutscene**, a stage the app does not have. `QuestRunViewModel.
  Stage` gains cases; see open question 3 — this is a requirement, not a restyle.
- `105:1699` / `187:954` / `187:1053` are a **paged lore reader**, replacing today's scrolling
  `loreSection`. The pager (`3/3`) is per-checkpoint lore split across screens.
- `187:1103` is a **transition between checkpoints**, which today is the arrival screen appearing.

### Constraints these frames run into

Recorded now so they are not discovered mid-implementation:

1. **Absolute positioning does not survive Dynamic Type.** Every child in these frames is placed by
   x/y. Reimplement as stacks with the theme's spacing; a frame that only works at 402 × 874 fails
   `NFR-A11Y-04` at AX5 on an iPhone SE.
2. **The copy is English-only literals.** "You're at the right place. The story awaits." is a string
   that needs `id` *and* `en` in `UIStrings` before it can render (`NFR-I18N-01/03`, and
   `LocalizedText` has no fallback). The Figma copy is a reference for tone; the Indonesian has to be
   authored, not machine-translated in passing.
3. **The frames hardcode one real quest.** I Gusti Ngurah Made Agung, Puri Agung Pemecutan, the
   Puputan — these are content, and content lives in authored JSON keyed by ID. The screens must
   render from `ContentKit` entities. Shipping them with the names baked in would also break
   `AD-4`/`FR-RUN-06`.
4. **The Story Reveal frames show unlabelled prose.** `187:1053` renders two paragraphs of historical
   claim with no accuracy chip and no citation. `FR-CP-05` requires the epistemic status of each
   claim to be visible, and `LoreBlock` structurally has no field for an unlabelled sentence. Either
   the design gains a chip treatment, or the requirement is being dropped — and it cannot be dropped
   silently. **This is the largest conflict in the set.**
5. **The portrait is AI-generated.** The layer is named `ChatGPT Image Aug 13, 2026 at 09_35_01 AM 1`.
   A generated likeness of a named historical king, presented inside a cultural-heritage product that
   maintains signed consent records per place and citations per claim, is a provenance problem before
   it is a design one. It needs the same discipline as any other claim: what it is, where it came
   from, and stated on the screen. Raise it with the team before it ships.
6. **Motion needs an opt-out.** The typing animation, the blinking place name and the 5-second
   auto-advance all have to honour `accessibilityReduceMotion` (render complete, no blink, no
   auto-advance), VoiceOver has to receive the full text rather than a character at a time, and the
   auto-advance must not be the only way forward — a tap continues, and it must not run away from
   someone still reading. `NFR-A11Y-05` also forbids the blink carrying meaning by itself.
7. **`Maps` in `223:2004` is a rectangle, not a decision.** Whether that is the drawn canvas from
   Finding 5a or a live MapKit view is settled by `FR-MAP-01`: no live tiles. It is the canvas.

## Built so far

**`223:1987` — the gilded portrait frame.** `DesignSystem/PortraitFrame.swift`:
`KultaraPortraitFrame` places a portrait behind a carved oval ornament, and `PortraitFrameMetrics`
holds the proportions and the packaged asset. The ornament PNG ships as a `DesignSystem` resource
(`Resources/Images/portrait-frame.png`, added to `Package.swift`) because it is chrome, not content —
content assets live in `ContentKit` and get replaced wholesale.

The opening's ratios were taken from the two instances that draw the group at different scales
(360 × 450 in `98:1588`, 320 × 400 in `187:866`); they agree to four decimal places, and
`PortraitFrameTests` asserts that both reproduce. Four tests, package suite now 188.

The view takes the portrait as a parameter and deliberately does not caption it — see recommendation
1 below.

## Decisions taken 2026-08-13

The recommendations below were put to the product owner. Three are now settled, and the settling
principle for anything not listed is **follow the Figma**.

1. **The portrait ships.** The gilded frame is a template and the picture inside it is swappable; for
   now it carries the image of the king of Badung as drawn. Recommendation 1's labelling proposal was
   put and not taken. Recorded, not re-litigated — but the provenance note stays in
   `PortraitFrame.swift`, and replacing the image later must not require touching the component.
2. **The Story Reveal pages render as the design draws them.** This is a deviation from `FR-CP-05`,
   which requires the accuracy label and source of every claim to be visible, and it is taken
   knowingly. It needs to be reflected in the PRD rather than left as an undocumented divergence —
   either as an amendment to `FR-CP-05` or as a recorded exception with an owner. Note that
   `LoreBlock` still *carries* `accuracy` and `sourceRefs`; what changes is that the reveal screen
   does not display them.
3. **The cutscene follows the design** — the hook, the frame and the photo, nothing more.

Everything not covered above: build what the frames show.

## Recommendations on the open conflicts

Positions, with reasons. Items 1–3 are settled above; 4–8 stand until answered.

### 1. The AI-generated images — split the decision in two

**The frame ornament: ship it.** It depicts nothing and claims nothing. A generated decorative border
is a licensing question, and the provenance is now recorded in the source so the question stays
answerable. No user-facing consequence.

**The portrait of I Gusti Ngurah Made Agung: do not ship it unlabelled.** This product's entire
thesis is that every claim carries its epistemic status — that is what `FR-CP-05`, the `accuracy`
field, the citations and the signed consent records are all for. A fabricated face of the last king
of Badung, framed in gilt and presented as heritage, is the single loudest unlabelled claim the app
could make, on the one subject where being wrong matters most: the Puputan is living memory, and
Kultara — a research partner the team actually interviewed — is exactly who would object.

Three ways out, in order of preference:

1. **Label it as illustration.** Keep the image, extend the accuracy vocabulary with a third value
   for depictions (`illustration` / *ilustrasi*) and render it in the existing `AccuracyChip`, with a
   line saying it is an artist's impression and not a historical likeness. Cheapest, honest, and
   consistent with everything else the app does. Add a validator rule so a portrait asset of a named
   person cannot ship without that label.
2. **Replace it** with a licensed museum or archive image plus its citation. Best outcome, slowest.
3. **Drop the portrait** and frame the *place* instead — the gate, the puri — which the frame suits
   just as well and which claims nothing about a face.

Take this to the research partners before it ships, whichever way it goes.

### 2. `FR-CP-05` on the Story Reveal pages — change the design, keep the requirement

The paged reveal is an *easier* fit for the requirement than the current scrolling column, not a
harder one: one page carries one `LoreBlock`, so it carries exactly one accuracy chip and one
citation, and the `3/3` pager becomes `loreSegment.count`. Put the chip above the paragraph as the
preview already does, and the source line at the page's foot. Nothing in the visual direction has to
give way — the chip is small, and the design has room.

### 3. The cutscene — a presentation, not a new content type

Implement it as a way of showing data that already exists: the quest's `hookLore` plus a place image,
shown once at the first arrival of a walk. It gets a requirement ID, it is skippable (repeat walkers,
and anyone who does not want a timed sequence), and it adds no new content entity in v1. Adding a
`cutscene` object to the schema would mean a validator rule, a consent question and a migration, for
something the existing hook already holds.

### 4. "Navigate There" — allow it at the start checkpoint only

Handing off to Apple Maps mid-quest is three problems: it leaves the app during the one flow that has
to work in airplane mode (`AD-3`), it routes along a road network rather than the authored walking
route, and it makes the clue — the thing the walk is actually built on — pointless. But getting to
the *trailhead* is genuinely outside the story, and refusing to help there is unhelpfulness for its
own sake.

So: offer it on the start checkpoint, as a secondary control whose label says it opens Maps; do not
offer it between checkpoints, where the drawn canvas, the distance and the clue are the answer.

### 5. Plus Jakarta Sans — adopt for UI, keep the serif for narrative, verify first

Plus Jakarta Sans is under the SIL Open Font License, so embedding is fine, but confirm the licence
file before it ships. On the mix: read the actual faces off the frames with `get_design_context`
before deciding — the screenshots suggest the headings are not sans. The current split (display serif
for anything that names something, system sans for anything read or operated) is a decision with a
stated reason in `KultaraFonts`, and it should be overturned deliberately rather than by importing a
style-guide page that may be a template.

### 6. The colour variables — ignore them, sample the frames

Treat the Colors page as stale until the designer says otherwise. Sample the real fills, name the
tokens ourselves, measure every pair, and record the result in `docs/hisplora-tokens.md`. Then ask
the designer to publish real variables so the next import is not another archaeology exercise.

### 7. Scope — build it as the story flow, not as a whole-app restyle

This board covers preview, location check, cutscene and reveal. It does not cover the quest list, the
region map, settings or the summary. Ship the story flow on the new direction and leave the rest on
the current theme until frames exist. A seam at a screen boundary is survivable; a half-restyled
screen is not.

### 8. The motion — three rules, applied to all three animations

- **Typing animation** (`105:1699`): progressive reveal of one `Text`, not a stack of appearing
  lines. Under `accessibilityReduceMotion` it renders complete. VoiceOver gets the whole passage as
  one string. A tap completes it immediately — nobody should have to wait out a typewriter to
  re-read a sentence, and `FR-CP-03` wants lore re-readable at rest.
- **Blinking place name** (`187:1103`): pulse opacity between 1 and about 0.55, never to zero, and
  never as the only signal that the name matters (`NFR-A11Y-05`). Off entirely under Reduce Motion.
- **The 5-second auto-advance**: a visible Continue control always exists, and the timer does not run
  under VoiceOver or Reduce Motion. A screen that moves on by itself while someone is still reading
  it is a timing failure, not a transition.

## Extraction order, once the per-frame IDs exist

Do not start writing SwiftUI from a screenshot. Take the tokens first — the whole point of routing
this through the design system is that a colour appears once.

1. `get_design_context` per frame, with `skillNames: figma-design-to-code`. It returns reference code
   (React + Tailwind), a screenshot and hints; read it as a **description of layout intent**, never as
   code to paste. It knows nothing about `LocalizedText`, the palette, or the requirement IDs the
   current views are built around.
2. Sample the colours and type from that output and name them ourselves, since the file's variables
   do not describe these screens.
3. `get_screenshot` per frame at a higher `maxDimension` — the visual reference to check each built
   screen against.

Record the sampled tokens in `docs/hisplora-tokens.md`, with the WCAG ratio measured for every pair
alongside its hex, so the next person does not need Figma access to know what the numbers were or
which of them had to be adjusted.

## Rules the redesign does not get to break

The design system exists because several of its properties are asserted by tests rather than
reviewed. A new visual direction changes the values; it does not change the rules.

- **Contrast is measured (`NFR-A11Y-03`).** `DesignSystem/Contrast.swift` and `KultaraThemeTests`
  assert every theme pair against WCAG ratios. If a Hisplora colour pair fails, *the theme yields,
  not the threshold* — take the nearest passing value and note the deviation in the tokens doc. Every
  new pair added to the palette gets added to the assertion set in the same commit.
- **44-point targets (`NFR-A11Y-06`)** survive the restyle, including the map markers Phase 1 just
  shrank to the pin.
- **No hardcoded strings.** `DesignSystem` has no localisation table; every string is passed in by
  the caller (`NFR-I18N-01`), and `LocalizedText` has no language fallback (`NFR-I18N-03`). Figma's
  copy is a *reference for tone*, not a source of strings — anything new needs both `id` and `en`
  in `UIStrings`.
- **Content ordering is a requirement, not a layout choice.** `FR-CP-02` fixes lore → tasks → clue on
  the checkpoint screen. `FR-CP-07` puts the stamp before any task is offered. `FR-TASK-05` puts the
  dress code and photo policy above the tasks at a sacred place. `FR-DISC-05` keeps cost on the card.
  If the Figma frames order these differently, the requirement wins and the discrepancy goes in the
  open-questions list below — do not silently reorder.
- **The epistemic labels stay attached (`FR-CP-05`).** Every lore block shows its `accuracy` chip and
  its citation. A visual direction that drops the chip for a cleaner column is not implementable.
- **View models do not move.** This phase touches `DesignSystem` and the `View/` layer. If a screen
  needs data the view model does not expose, add it there — but a redesign that reaches into
  `RunEngine` or `ContentKit` has stopped being a redesign.
- **`Place.mapPoint` stays authored.** If the new direction ships a different illustrated map, the
  points are re-authored against it and `contentBundleVersion` bumps. They are never derived from
  `coordinate`.

## Implementation order

1. **Tokens.** `KultaraTheme` palette values, `KultaraMetrics`, `KultaraFonts` — plus the contrast
   assertions, in the same commit. Nothing else changes; the app should build and look wrong in a
   consistent way.
2. **Components.** `HomeChrome` (search field, map button, tab bar), `MuseumPlate`, `QuestCard`,
   `TaskCard`, `JournalEntryCard`, `SectionContainer`, and the `KultaraDialog` Phase 1 introduced.
   Each is restyled behind its existing initialiser, so the screens do not change while this happens.
3. **Screens**, in the order a user meets them: Onboarding → Quest list → Region map → Quest preview
   → Quest run (arrival, checkpoint) → Summary → Settings.
4. **The run route map** from Finding 5a, restyled to match, last — it is the newest surface and the
   one most likely to be missing from the Figma file entirely.

## Verification for Phase 2

- `swift test` — the contrast and typography suites are the ones that will catch a bad token.
- `xcodebuild test` on `iPhone 17`, `OS=26.5` — the XCUITests find screens by accessibility label, so
  a restyle that breaks one is a restyle that removed an accessibility label.
- Screenshot comparison against the `get_screenshot` output per frame, captured into
  `docs/screenshots/` as the existing verification screenshots are.
- **Re-run the whole Phase 1 manual checklist.** The map gestures, the keyboard inset and the dialogs
  are exactly the things a layout rewrite regresses.
- AX5 text size and VoiceOver on every screen touched. The aged-paper direction failed contrast
  easily; assume the new one has its own version of that problem until measured.

---

## Open questions for the team

1. **Finding 3** — is the current disclosure boundary (route and place names public, story and clues
   withheld) what the product wants? Answering "no" is a PRD amendment, not a bug fix.
2. **Finding 5a** — is a drawn schematic route canvas an acceptable reading of `FR-MAP-02`, or does
   "map" here mean something closer to the illustrated region map? The requirement names three
   contents and no visual style; the plan above reads it literally.
3. **The AI-generated portrait** (`187:866`, layer `ChatGPT Image Aug 13, 2026 at 09_35_01 AM 1`) —
   ships or not? A generated likeness of I Gusti Ngurah Made Agung inside a product built on signed
   consent records and per-claim citations needs a provenance answer, and probably a visible label.
4. **`FR-CP-05` on the Story Reveal pages** — the frames show historical claims as unlabelled prose.
   Does the design gain an accuracy chip, or is the requirement changing? It cannot simply lapse.
5. **The cutscene.** The board draws a three-screen cutscene between arrival and the story —
   "A Legend Will Guide Your Journey", a framed portrait, "I Gusti Ngurah Made Agung", then *Start
   the Journey*. The app has no such stage and the PRD does not describe one. Is this a new
   requirement, or a presentation of the existing lore blocks? If it is new, it needs a `FR-` ID, and
   it has to answer to `FR-CP-05`: every claim carries its accuracy label and its citation, and a
   cinematic portrait screen is exactly where that discipline tends to get dropped. Note also that
   the portrait is of a named historical figure — the citation and the image rights both need
   settling before it ships.
6. **The type direction.** The style guide specifies Plus Jakarta Sans, a sans-serif, against the
   current display serif. Confirm this is intended rather than a placeholder, and confirm the licence
   permits embedding in a shipped app.
7. **The colour variables.** The Colors page reads as an untouched template (Blond, Light Hot Pink,
   Maximum Blue Purple, Android Green) and does not match the sepia screens. Is it stale, or is there
   a second palette elsewhere we have not been shown?
8. **"Navigate There"** (`223:2004`) — handing off to an external maps app is a new product decision.
   It takes the walker out of the app mid-quest, and the route it opens is not the authored route.
9. **Phase 2 scope** — is this board the whole redesign, or the first flow of several? It covers
   preview, location check, cutscene and story reveal; it does not cover the quest list, the region
   map, settings, or the summary. If those are coming, Phase 2 is a milestone of its own rather than
   a week.
10. **Naming** — "Hisplora" is a name, and `CLAUDE.md` records that the app has none ("Kultara" is a
   research partner, not a brand). If Hisplora is the intended product name, that resolves a known
   blocker and the working title should be renamed across the code in its own commit — not smuggled
   in with the visual direction.
