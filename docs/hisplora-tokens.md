# Hisplora tokens

Sampled 2026-08-13 and re-read 2026-08-14 from Figma file `Ok5TmLeDGTbIDuxGbDQFeM`, board `13:128`,
per-frame nodes listed below. Recorded here so the next person does not need Figma access to know what the numbers were, or
which of them had to be adjusted.

The values live in `DesignSystem/HisploraTheme.swift`; the measurements are asserted by
`HisploraThemeTests`, not by this document. If the two disagree, the test is right.

## Where the values came from

**Not from the file's variables.** `get_variable_defs` on the Colors page (`1:632`) returns a
template palette — Blond `#FBF3B9`, Light Hot Pink `#FE9BE3`, Maximum Blue Purple `#3BA0ED`, Android
Green `#A3CD3E`, plus 0–900 ramps for four of them. None of it appears on any screen. The screens are
drawn in browns, cream and sepia as raw fills, so every token below was read off the frames.

**Not Plus Jakarta Sans either.** The Typography frame (`1:92`) specifies Plus Jakarta Sans at five
sizes. No frame on the board uses it. The story frames are set in **New York Extra Large** for
display (`81:588`, `98:1588`, `187:866` all name it), SF Pro for everything read or operated, and
**Special Elite** for the typewriter sheet on `81:588`.

Both are now implemented as drawn. New York is the system's own serif, reached through the
`storyDisplay` role — the museum catalogue keeps Instrument Serif, so the app carries two display
faces separated at the same screen boundary the palette is. Special Elite is shipped with the
package (Apache 2.0, licence beside the face) and is registered by `KultaraFonts` like Instrument
Serif; `typedSheet` and `typedFigure` are the only two roles that use it, which
`TypewriterTests.onlyTheSheetRolesAreSetInTheTypewriterFace` holds.

Both pages read as untouched template material. Worth asking the designer to publish real variables
so the next import is not another archaeology exercise.

## The palette

| Token | Hex | Where it is drawn |
|---|---|---|
| `brownDeep` | `#6E2717` | ground: story reveal, location screens, transition |
| `brownMid` | `#6E3B26` | frame fill behind the cutscene; fill of the circular next control |
| `brownStone` | `#58453E` | ground: story preview and both cutscene frames — the full-bleed rect each of them lays over itself |
| `paperCream` | `#EEE7D2` | the typewriter sheet on `81:588`; the clue card |
| `paperWarm` | `#EADBC7` | the sketch pages of Story Reveal |
| `paperLight` | `#F4EADD` | Location Checking |
| `inkCream` | `#FDF2DE` | headings on the brown grounds |
| `inkDusty` | `#D0B5AE` | muted leads on the brown grounds — **moved, see below** |
| `inkDark` | `#1D1D1D` | headings on paper |
| `inkBody` | `#444444` | body copy on paper |
| `inkMuted` | `#5E5A5A` | secondary copy on paper |
| `buttonFill` | `#151311` | the pill |
| `inkOnButton` | `#FFFFFF` | the pill's label |
| `buttonRing` | `#B69682` | the pill's boundary — **added, see below** |
| `highlight` | `#E0B341` | the drawn annotation on Story Reveal; decoration only |

## Measured ratios

Produced by `HisploraThemeTests.reportMeasuredContrastRatios`.

| Pair | Measured | Needs | |
|---|---|---|---|
| inkCream on brownDeep | 9.63:1 | 3.0 | PASS |
| inkCream on brownMid | 8.17:1 | 3.0 | PASS |
| inkCream on brownStone | 8.11:1 | 3.0 | PASS |
| inkDusty on brownDeep | 5.55:1 | 4.5 | PASS |
| inkDusty on brownMid | 4.71:1 | 4.5 | PASS |
| inkDusty on brownStone | 4.67:1 | 4.5 | PASS |
| inkDark on paperCream | 13.64:1 | 4.5 | PASS |
| inkBody on paperCream | 7.88:1 | 4.5 | PASS |
| inkMuted on paperCream | 5.51:1 | 4.5 | PASS |
| inkDark on paperWarm | 12.41:1 | 4.5 | PASS |
| inkBody on paperWarm | 7.17:1 | 4.5 | PASS |
| inkMuted on paperWarm | 5.01:1 | 4.5 | PASS |
| inkDark on paperLight | 14.18:1 | 4.5 | PASS |
| inkBody on paperLight | 8.19:1 | 4.5 | PASS |
| inkMuted on paperLight | 5.72:1 | 4.5 | PASS |
| inkOnButton on buttonFill | 18.53:1 | 4.5 | PASS |
| buttonRing on brownMid | 3.31:1 | 3.0 | PASS |
| buttonRing on brownDeep | 3.90:1 | 3.0 | PASS |
| buttonRing on brownStone | 3.29:1 | 3.0 | PASS |

`highlight` is deliberately not in this table. It is a hand-drawn annotation over text that is
already measured, it fails against the paper by a wide margin (1.45:1), and it therefore never
carries meaning by itself — the phrase it marks carries a weight change too (`NFR-A11Y-05`).
`HisploraThemeTests.everyTokenIsMeasuredExceptTheDrawnAnnotation` names it as the one exclusion, so
it cannot quietly start carrying text.

## Deviations from the frames

Five, all recorded rather than argued.

1. **`inkDusty` was lightened.** As drawn it is `#AA9B8E`, which measures 3.34:1 on `brownStone` —
   it carries the lead paragraph under the cutscene's title, so it is held to body text.
   `NFR-A11Y-03` says the theme yields, not the threshold, so it moved to the nearest passing
   value, `#D0B5AE` (4.67:1). The difference is a shade; the failure was not.

2. **The pill gained a hairline.** The frames draw a near-black pill directly on brown, which is
   about 2:1 — below the 3:1 WCAG 1.4.11 asks of a control's visual boundary. Rather than lighten
   the ground or the fill, the control gained a `buttonRing` outline. `HisploraThemeTests` asserts
   both halves, so restoring the frame's borderless pill fails the suite and says why.

3. ~~Special Elite is not embedded.~~ **Closed 2026-08-14.** The face is Apache 2.0, it ships in
   `DesignSystem/Resources/Fonts` with its licence beside it, and the sheet on `81:588` is set in
   it. `TypewriterTests.theTypewriterFaceRegisters` fails if the resource is ever dropped, rather
   than the sheet quietly reverting to SF Pro monospaced.

4. **The 402 × 874 absolute layouts are gone.** Every frame places its children by x/y. Rebuilt as
   stacks with the theme's spacing, because a layout that only works at one size fails
   `NFR-A11Y-04` at AX5 on a small device.

5. **The typed sheet is set at a readable size.** The frame types the hook at 8.5 pt, because on
   the frame the sheet is a small object inside a photograph. Reproduced literally it is
   unreadable at the default text size and off the paper at the first size above it. `typedSheet`
   is 14 pt scaling from `.footnote`, and the composition changed with it: the photograph is
   cropped to the *machine*, the paper is drawn in code above it, and the two are stacked, so the
   sheet grows with the reader's text size while the machine stays the size it is
   (`KultaraTypewriter`).

## Assets shipped from the file

| Asset | Where | Note |
|---|---|---|
| `portrait-frame.png` | `DesignSystem/Resources/Images` | the gilded oval, laid over the picture |
| `typewriter.png` | `DesignSystem/Resources/Images` | the machine, cropped from the photograph at 47% height so the drawn sheet joins it |
| `SpecialElite-Regular.ttf` | `DesignSystem/Resources/Fonts` | Apache 2.0, licence shipped beside it |

Both images are generated art exported from the design file (`ChatGPT Image Aug 10 …` and
`ChatGPT Image Aug 13 …`). They depict objects and claim nothing, so they are a licence question to
answer rather than an editorial one — recorded here and in the component headers so it stays
answerable.

**Four assets in the file were deliberately not shipped.** They are not oversights:

- **The Google Maps screenshots** on `89:1402` and `223:2004`, and the traced street map derived
  from them. They are a third party's map imagery under that party's terms, and `FR-MAP-01`
  already rules out live tiles; `RunRouteMapView` draws the authored route instead. A shipped
  static route image per quest (`route.previewImageAsset`) is the supported way to show a map here.
- **The Apple system icons** in the permission-dialog mock. iOS draws that dialog itself.
- **The AI-generated portrait** of I Gusti Ngurah Made Agung — see below.
- **The place notice's plate**, `293:1630` on `293:1613` — see the next section.

### The plate on `293:1613`, and what the code draws instead

`293:1630` is a stock wedding-invitation plate. Exported, it carries a dozen real individuals' and
businesses' names engraved across its middle; in Figma the designer laid three opaque rectangles
(`293:1631`–`1633`) over them rather than removing them. Shipping the file — whole or patched — would
put third parties' names and somebody else's licensed engraving in every copy of the app, so it is
out, and no amount of cropping changes that.

What replaced it went through three passes, and the first two are worth recording because they are the
failure modes of drawing ornament in code:

1. **Silhouette only.** Cream fill, one inset rule, scooped corners. On device it read as a blank
   cream ticket beside the mock-up — which is the state the user rejected.
2. **Stroked centre lines.** Stems, hooks and hung arcs at 0.9–2.2 points. It read as wire: a pair of
   antennae flanking the portrait, then a scatter of pins. Bare centre lines do not read as carving.
3. **What ships now.** Every limb is a tapered ribbon with two edges, filled and then outlined; leaves
   are closed teardrops whose belly is held to a third of their own length (asked for less, they
   render as blades and the spray reads as wheat); volutes are spirals sampled 40 times a turn, not
   8 (at 8 the eye is a visible hexagon). Plus four corner flourishes, a pendant sized to the lobe it
   sits in, and a quatrefoil watermark at 26-point pitch and 3.8% ink.

**Every dimension of the shape is measured, not styled.** `HisploraPlaqueMetrics` holds the numbers
and `PlaqueGeometryTests` asserts them, read off the exported plate's alpha coverage (402 × 675,
sitting at y = 94 on the 874-point frame): straight sides at x = 24…381, sheet top at y = 44 and
bottom at y = 616, a head lobe rising to y ≈ 8, a pendant lobe falling to y ≈ 660, and corner arcs
centred **on** the corner point — a scoop, radius 36. A conventional inset rounded corner misses three
of the five measured edge samples by more than 20 points, which is why the test checks the wrong
answer as well as the right one.

**The gilded oval straddles the plate's head.** `320:2485` draws it at y = 125 while the sheet starts
at 138, so 13 points of gold overlap the cream — reproduced, because centring it politely below the
edge is a different design. It is an overlay on the panel rather than its first row, since a row
inside the panel cannot hang past it.

**What is still not the mock-up: the ornament's density.** The drawn spray is a delicate laurel; the
stock plate is a dense damask. Closing that gap needs artwork this project owns — commissioned,
licensed, or generated for it. The seam for that is already in place: `HisploraPlaqueArtwork` prefers
`Resources/Images/plaque-engraving.png`, clipped to the same silhouette, and falls back to the drawn
spray whenever the file is absent (as it is today). Dropping the file in is the whole change; no sizes
or layout move.

## What the frames draw that the code does not, and why

These are requirement conflicts, not omissions.

- **"Navigate There"** (`223:2004`) hands off to an external maps app. **Now built** — the earlier
  entry here said it was not, and that is what changed. `FR-MAP-04` permits the handoff outright
  ("presented as leaving the app"), so the objection was never that it is forbidden; it was that
  nothing must *depend* on it. It does not: the clue, the drawn route, the distance and the manual
  override are all still on the screen and all still work with the radio off (`AD-3`). The three
  things that make it honest rather than a shortcut are the arrow glyph and the accessibility hint
  (`locationNavigateThereHint`) that say it leaves the app, the fact that it hides itself when no
  place resolves rather than opening nothing, and `ExternalMapsLink` building a `maps.apple.com`
  URL rather than importing MapKit — which `PermissionCallBoundaryTests` bans for `FR-MAP-01`.
  It routes along roads, which is Apple Maps' job and not this app's (`FR-MAP-03`); the authored
  walking route is what `RunRouteMapView` still draws above it. Apple Maps reverse-geocodes the
  coordinate for the pin's label, so the `q` place name is not what the walker sees — with the
  seed coordinates still unwalked, the pin lands on a street name, not the place.
- **The back arrow and "Back to Homepage"** (`223:2004`) are built. Both pop the run screen; neither
  abandons the walk — the draft Run stays on disk and the quest list resumes it.

### The arrival screen now matches `223:2004` exactly, and four requirements lost their controls

Decided 2026-08-17, on the instruction that the screen match the frame element for element. **This
is the one place in this document where the design wins and the requirement yields**, and it is
recorded here rather than resolved, because the reverse is what the rest of this file argues for.

Gone from the arrival screen: the clue card (`FR-CP-03`, `NFR-SAFE-02`), the distance and
fix-quality readout (`FR-ARR-05`), the manual override (`FR-START-10`), the abandon control
(`FR-RUN-04`) and the link to system Settings shown on a permission refusal (`FR-ERR-02`). The
`CHECKPOINT n OF m` eyebrow (`FR-CP-08`) went with them.

What that costs, plainly: **a walker whose GPS never resolves can no longer reach the checkpoint.**
`FR-START-10` exists because inside a covered market the accuracy gate fails legitimately and often,
and the override was the way out. There is no longer one. A walker who refused location permission
likewise has no route to Settings from this screen.

None of the code was deleted. `manualOverride`, `manualOverrideSheet`, `arrivalNumbers` and
`LocationClueCard` are all still built and still wired to `QuestRunViewModel`; restoring any of them
is putting its line back in `arrivalScreen`'s stack. `QuestRunTests` stays green because those
guards assert on the view model, which is unchanged — **so the tests will not catch this if it was
the wrong call.** It needs a signed PRD exception with an owner, like `FR-START-04a` got and unlike
`FR-CP-05`'s Story Reveal omission, which is still outstanding.

### What is measured on that screen now

| Element | Frame value | Shipped |
|---|---|---|
| Ground | `#58453E` | `brownStone` — was `brownMid`, now the drawn value |
| Title | New York 40, tracking −0.8, `#FDF2DE` | as drawn (`inkCream`) |
| Lead | SF Pro Display 15, tracking −0.45, `#AA9B8E` | `inkDusty` `#D0B5AE` — the documented lift; `#AA9B8E` is 3.34:1 on this ground |
| Primary action | white capsule, 58 tall, label SF Pro Medium 17 / −0.51 / `#151311` | `HisploraLightPillButtonStyle`; no ring, because white on `brownStone` already clears 3:1 |
| Second action | SF Pro Medium 17 / −0.51 / white | `hisploraPlain(ink: \.inkOnButton)` |
| Back glyph | `arrow.backward`, 24, at `20, 82` | as drawn; tap target stays 44 (`NFR-A11Y-06`) |
| Lead line count | one line | **two** — SF Pro Text is set wider than the SF Pro Display the frame specifies, and iOS has no public API to ask for the Display cut below 20 points. The gap under it is 59 rather than the drawn 100 so the map still lands at 328. |
- **The `Maps` rectangle** on `223:2004` and the scrolled paper map on `89:1402` are replaced by
  `RunRouteMapView`, the drawn canvas from `FR-MAP-02`. `FR-MAP-01` forbids live tiles.
- **The AI-generated portrait** of I Gusti Ngurah Made Agung is not shipped. A likeness of a named
  historical person is a claim; `FR-CP-05` requires every claim to carry its accuracy label and its
  source; the sample content ships no such person, no consent record and no citation. The gilded
  frame around it *is* shipped, and both cutscene screens and the story preview render it with
  whatever picture the quest supplies — today the quest's own hero image, which has provenance
  behind it. Dropping the portrait in is a content change, not a code change: give a quest a hero
  image, a `LoreBlock` naming the sitter with its `accuracy` and `sourceRefs`, and a consent record
  the validator can resolve (`V4`). Until those exist, shipping the likeness would put an unsourced
  claim about a real person on the screen the whole flow opens with.
- **The sketch illustrations** behind the Story Reveal pages are per-quest content art. The screen
  renders them when content supplies them and lays out correctly without them.
- **The clue and the manual override** appear on none of the three location frames and are on the
  arrival screen anyway: `FR-CP-03` requires the clue re-readable for the whole walk, and
  `FR-START-10` makes the override mandatory.

## The `FR-CP-05` exception

The Story Reveal pages render lore without the accuracy chip and without citations. This is a
knowing deviation, taken by the product owner on 2026-08-13 and recorded in
`.claude/plans/m8-qa-fixes.plan.md` (Decisions taken, item 2).

**It is not yet reflected in the PRD, and it needs to be** — as an amendment to `FR-CP-05` or as a
recorded exception with a named owner. `LoreBlock` still carries `accuracy` and `sourceRefs`, and
the checkpoint screen still displays both; what changed is that the reveal screen does not.

## Frames read

| Node | Frame |
|---|---|
| `81:588` | story preview (typewriter) |
| `223:1877` | system location prompt over a map |
| `81:617` | Location Checking |
| `89:1402` | Location Verified |
| `223:2004` | Not Quite There |
| `98:1588` | Cutscene — "A Legend Will Guide Your Journey" |
| `187:866` | Cutscene — portrait, "Start the Journey" |
| `105:1699` | Story Reveal 1 |
| `187:954` | Story Reveal 2 |
| `187:1053` | Story Reveal 3 |
| `187:1103` | Transition |
| `1:92` | Typography (template) |
| `1:632` | Colors (template) |

The SSE serialization fault that blocked four of these on 2026-08-13 has cleared for individual
frames; all eleven return `get_design_context` cleanly. It still breaks on the **board** — both
`get_design_context` and `get_metadata` on `13:128` fail with a truncated SSE frame, and
`get_metadata` on the page (`0:1`) omits the section entirely, listing only the two template
frames. So the board cannot be enumerated from the tool: query frames by the node ids in this
table, which is the reason the table exists.

## Seen rendering

`81:588`, `98:1588` and `187:866` were verified on iPhone 17 / iOS 26.5 on 2026-08-14 — the first
time the cutscene screens had been seen at all. **`293:1613` was verified the same way on 2026-08-17**,
also for the first time: the place notice at Puri Agung Pemecutan, reached in one pass — splash →
onboarding (Skip) → login wireframe (Skip for now) → quest card → story preview → `FR-START-04a`
safety notice → location rationale → permission → cutscene portrait (the scratch reveal needs a real
drag path, not taps) → story reveal → place notice. It is what drove the plate rewrite above. The run
reaches these screens from a desk by setting the simulator's location to the first checkpoint rather
than by the debug toggle:

```bash
xcrun simctl location <udid> set -8.6595,115.2077
```

That is `badung-puri-agung-pemecutan`, the start checkpoint of `badung-empat-wajah` — an
unverified seed coordinate (`c1-badung-single-quest-content.plan.md` §11.0), so re-check it before
trusting a failed arrival. The arrival
rule is unmodified — the radius and accuracy gate in `ArrivalEvaluator` runs on the reported fix, so
what is exercised is the walker's own code path.
