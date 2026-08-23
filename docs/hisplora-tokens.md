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
| `paperTicket` | `#EFEBD7` | the quest-row ticket on `452:3132` |
| `inkTicket` | `#34312E` | that row's title |
| `trackWell` | `#8D7870` | the well of the segmented task bar, `452:3138` |
| `trackDim` | `#C3BAAB` | the unfilled segment of the onboarding bar, `702:2081`–`2082` — the frame's 25% `buttonFill` over `paperSheet`, flattened. **Re-sampled 2026-08-20**: it was `#926954` while onboarding stood on `brownMid` |
| `inkQuiet` | `#4F4B44` | the underlined Skip at the top right of the onboarding frames, `737:4731`/`4734`/`4741` — 75% `buttonFill` over `paperSheet`, flattened |
| `mapGround` | `#DFCDB5` | ground: the site-map screen `452:3028` — the one paper ground in the flow |
| `mapMarker` | `#B44934` | the marker dots on the site plan, `452:3032`–`3034` |
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

Fourteen, all recorded rather than argued. Deviations 6–9 came from `452:3132`, `447:1880` and
`452:3028` on 2026-08-17; deviation 10 came from `452:2651` on 2026-08-18; 11 and 12 came from the
first onboarding board on 2026-08-18 and were re-stated against the second on 2026-08-20; 13 and 14
came from that second board, `702:2068` / `702:1999` / `702:1980`.

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
   is **12 pt** scaling from `.footnote` — down from 14 on 2026-08-18, and 12 is the floor
   `TypewriterTests.theSheetIsSetLargerThanTheFrameDrawsIt` holds — and the composition changed
   with it: the photograph is cropped to the *machine*, the paper is drawn in code above it, and
   the two are stacked (`KultaraTypewriter`).

5a. **The machine does not move, and the page does.** Until 2026-08-18 the whole stack sat in one
    scroll view, so a page taller than the screen carried the photograph up with it — the object
    the screen is a picture of slid about. Now the title and the machine are fixed, and the scroll
    view is *inside* `KultaraTypewriter`, around the paper alone. Two costs, both deliberate:

    - ~~The machine is cropped from the top.~~ **Reverted the same day.** A typewriter with its
      front lip off the screen reads as a mistake, not as a close crop. The machine is drawn whole,
      and the height it takes back comes from the page **overlapping it**: the sheet is pulled down
      over the machine's own paper stub by `rollerInsetFraction` (y 105 of the photograph's 573)
      and drawn above it, so the page runs into the roller instead of stopping at a seam. Two
      thirds of the photograph's transparent foot (y 523…573) is reclaimed the same way — the
      layout cannot see that those points are blank.
    - The crest is drawn **150 pt wide against `35:431`'s 180**, and **0.70 of it is behind the
      paper against the frame's 0.56** — its height is space the page does not get.
    - The typewriter takes the **full width** of the stage, not an inset column. The sheet is cut to
      the paper in the roller, so every point off the machine comes off the page twice; at the
      inset width the pair "Distance | Total time" fell to two stacked rows, which costs more
      height than the wider machine ever did. `KultaraTypedFigures`' row gap went `lg` → `md` for
      the same reason.

5c. **Everything about the sheet's geometry is one block of constants.** `TypewriterMetrics` in
    `DesignSystem/Typewriter.swift`: `paperWidthFraction` and the three margins are its size,
    `paperCentreOffsetFraction` and `rollerInsetFraction` are where it sits, and the two `crest*`
    fractions are the object standing on it. The top margin is the deep one (28 pt against the
    bottom's 10) because it is the head of a page — text starting a hair under the paper's edge
    reads as a label rather than as something typed into a machine.

5d. **The sheet is the width of the paper in the photograph, and is sized off the machine.**
    `typewriter.png` is 720 × 573 and its paper spans x 143…593 — `paperWidthFraction` is that
    451/720, and `paperCentreOffsetFraction` nudges the drawn sheet the 8 px the photographed one
    sits right of centre. It is measured against the **machine**, not the container: those two are
    not the same width, and a fraction of the *screen* overhangs the paper by the stage's inset.

    Only the sheet is sized that way, and only because it lives inside the scroll view and cannot
    widen anything. Feeding the same measurement into the crest — a sibling in the same stack —
    spun a layout loop: with nothing measured the crest took its intrinsic width, that widened the
    stack, the wider stack widened the machine, and the new measurement resized the crest. It held
    the CPU at 100% and froze the screen.

    The crest itself sits **outside** that scroll view, above it, with the negative bottom padding
    pulling the window up over its lower half. It is an object standing on the desk, not something
    printed on the page: it holds still while the paper feeds in and while a long page scrolls, and
    the text disappears behind it rather than carrying it up the screen. The machine then takes
    `machineLift` (20 pt) of clearance over the action, so it reads as standing on a desk rather
    than growing out of the button.

    At AX3 and above the page no longer fits and scrolls inside its window; the machine and the
    action stay where they are, which is what `NFR-A11Y-04` wanted from the old full-page scroll
    without moving the furniture.

5b. **The hook is cut to 300 characters on this screen.** A window rather than a growing column
    means a passage that overruns it becomes a scroll inside a photograph.
    `TypewriterMetrics.sheetText` cuts on a word boundary, drops a stub paragraph left at the cut
    (the shipped hook used to end on an orphaned "At the…"), and adds an ellipsis only where the
    page does not already end on a full stop. **Display only** — `hookLore` is untouched, and the
    whole passage is what the run's other screens and every snapshot still carry.

6. **The task bar's unfilled segments lost their wash.** `452:3139`–`3141` fill the unfilled
   segments with 29% `#EEE7D7` over the well, which measures **2.25:1** against a filled segment —
   so the one thing the bar communicates, which activities are done, would be the thing failing
   contrast. Unwashed, a filled segment against the bare well is 3.36:1.
   `HisploraThemeTests.theUnfilledProgressSegmentLostItsWashSoTheBarsStateIsReadable` holds both
   halves, so restoring the wash fails the suite and says why.

7. **The task bar's outline is `buttonRing`, not the drawn `#9F8E88`.** As drawn it is **2.87:1** on
   `brownStone` — under WCAG 1.4.11. Rather than add a sixth token that cannot pass anything, the
   bar borrows the ring the pill already uses (3.29:1). No new value; a reused one.

8. **The "Take Photo" pill's outline is `brownMid`, not the drawn `#CAB7B0`.** `447:1900` is the one
   control on that screen, its fill is 45% white over a cream sheet — within a shade of the paper,
   about 1.06:1 — and the drawn outline measures **1.61:1** against the sheet's lightest sampled
   interior (`#F3F1E5`). So the control would have no discernible boundary at all. `brownMid` is
   7.22:1 there and is already the ink the place name above it is set in, so the pill reads as part
   of the sheet rather than as a new colour.

9. **`inkMuted` is not used on `mapGround`.** It measures **4.39:1** there — a tenth under body
   text — so the site plan's citation is set in `inkBody` (6.28:1) and the pair is deliberately
   absent from `contrastPairs`.
   `HisploraThemeTests.theSiteMapScreenAvoidsTheMutedInkBecauseItMissesByATenth` records that as a
   threshold call rather than an oversight.

10. **The plan does not get `452:2651`'s literal 594.6 points of height, because the citation stays
    on screen.** The frame gives the drawing y 130 → 724.6 and prints nothing under the gesture
    hint. The plan is content asserting distances and gate positions about a real puri, so
    `FR-CP-05` puts its `sources` citation on the screen — in full, not truncated, not behind a tap
    — and today's citation runs to four lines. It therefore takes its space first and the drawing
    fills what is left, about 520 points on an iPhone 17. Everything else about the frame's crop is
    reproduced exactly: leading inset 16, no trailing inset, filled by height so the drawing runs
    off the right edge, opening on its leading edge rather than centred.

11. **Onboarding is the frames' three screens, and `FR-ONB-03` is the price.** `702:2068`,
    `702:1999` and `702:1980` are Explore / Quest / Collection — as `523:1946`, `523:1973` and
    `523:1999` were before them — and none of them explains that the phone goes in a pocket between
    checkpoints. A fourth screen carrying it stood second from 2026-08-18 until **2026-08-20, when
    the owner asked for exact frame parity and it was removed on that instruction**. This entry is
    therefore no longer a deviation from the frames; it is a deviation from the PRD, recorded here
    because that is worse and easier to lose.

    The paragraph itself survives: the `FR-START-04` safety notice, which the walker must
    acknowledge before the first Run of every quest, already printed it under the quest's authored
    `safetyNotes` and still does. The string moved from `onboardingPocketBody` to
    **`safetyPocketBody`**; the title and `OnboardingIllustration.symbol` went with the screen. What
    is lost is the timing — a walker who never starts a quest is never told — and `FR-ONB-03` is a
    P0 MUST that wants an amendment or a signed exception with an owner.

    Two screens from the *old* onboarding were dropped earlier with no requirement behind them: the
    accuracy-label screen (the labels are on every lore block, where `FR-CP-05` puts them) and the
    still-in-use screen (dress and photo rules are shown before any task, where `FR-TASK-05` puts
    them).

12. **The onboarding bar's segments are flexible, and it is a position indicator.** The frames draw
    three fixed 115-point segments; the segments are equal and flexible instead, so the bar takes
    whatever `total` it is given without running off the row — which is what let it carry a fourth
    screen between 2026-08-18 and 2026-08-20 and carry three again now. What is *not* changed is which one is lit: `702:2080`–`2082` dim
    every segment but one, so the bar marks position rather than filling as it goes, and it is
    reproduced that way. The unfilled segment's 25% ink over the ground is flattened into `trackDim`
    rather than left as an alpha, because the suite measures token pairs and a translucency over
    "whatever is behind it" is not a pair anyone measured; against a filled segment it is 9.65:1.
    The row carries a spoken "Screen 2 of 4", so the count is never in the shape alone
    (`NFR-A11Y-05`).

13. **The onboarding pill loses its ring.** `HisploraPillButtonStyle` adds a hairline the frames
    never draw, because a near-black pill on `brownMid` measures 2.04:1 and WCAG 1.4.11 wants 3:1
    for a control's boundary (deviation 3). On the redesign's cream the same pill measures 16.71:1
    — the fill *is* the boundary — while `buttonRing` measures 2.47:1 there, so keeping the ring
    would add an outline fainter than the edge it outlines. The style takes `ring:` and onboarding
    passes `nil`; `theActionNeedsNoRingOnTheCreamGround` holds both halves.

14. **Skip is a top-right link on every screen, including the last.** The earlier board drew it as
    a footer pill beside Next, which forced it off `523:1999` — there Skip and "Begin Your First
    Quest" do the same thing, so drawing both offered a choice that is not one. `737:4731`,
    `737:4734` and `737:4741` move it into the header on all three, where it reads as leaving
    rather than as the second way forward, and it can therefore be drawn everywhere. Two things
    were added to the frame's text: it is a real `Button` rather than a tapped label, so VoiceOver
    announces and activates it, and its 17-point box is padded out to the 44-point target
    (`NFR-A11Y-05`, `NFR-A11Y-06`). The frames' zero-opacity Skip pill in the footer (`702:2075`,
    `702:2010`) is reproduced as what it looks like — a half-width Next — rather than as an
    invisible control, which VoiceOver would still find.

## Assets shipped from the file

| Asset | Where | Note |
|---|---|---|
| `portrait-frame.png` | `DesignSystem/Resources/Images` | the gilded oval, laid over the picture |
| `typewriter.png` | `DesignSystem/Resources/Images` | the machine, cropped from the photograph at 47% height so the drawn sheet joins it |
| `quest-parchment.png` | `DesignSystem/Resources/Images` | `447:1886`, the sheet the task is printed on |
| `quest-scroll.png` | `DesignSystem/Resources/Images` | the rolled scroll — a list row's icon at 48, and the map hint's glyph at 32, tilted 41.6° |
| `onboarding-explore.png` | `DesignSystem/Resources/Images` | `737:4729`, the dancers — 3×, alpha recovered, see below |
| `onboarding-quest.png` | `DesignSystem/Resources/Images` | `737:4674`, three fanned task scrolls — 3×, alpha recovered |
| `onboarding-collection.png` | `DesignSystem/Resources/Images` | `737:4649`, five stamps under a wax seal — 3×, alpha recovered |
| `story-divider.png` | `DesignSystem/Resources/Images` | `447:1887`'s flourish, **converted to an alpha mask** — see below |
| `SpecialElite-Regular.ttf` | `DesignSystem/Resources/Fonts` | Apache 2.0, licence shipped beside it |
| `<place>-stamp1…3.png` × 5 places | `DesignSystem/Resources/Images` | the fifteen stamp illustrations, composited out of the SVGs at 480 × 519 — see below |
| `hisplora-ground.png` | `DesignSystem/Resources/Images` | `547:2953` rendered, 804 × 1748 — the printed brown the Journal and the Explorer's Card sit on |
| `OrnateFrame.png` | `hisplora Watch App/Assets.xcassets` | `91:186`, 447 × 558 with a transparent oval — the **only** image in the watch target, and the only asset here outside `DesignSystem` — see below |

**`OrnateFrame.png` is a generative asset, and it is ornament.** The layer is named `ChatGPT Image
Aug 13, 2026 at 09_35_01 AM 1`. It was checked against `FR-WATCH-06` before being committed
(`s14` Phase 2, Task 2.1 Step 2, which exists for exactly this): it is an ornate gold picture frame
and carries **no face, no portrait and no human likeness**, so it raises none of the unsourced-claim
question the AI-generated portrait of a named historical figure did — that one is still not built,
below. Two things about it are worth keeping visible anyway. It is the only image the watch target
ships, so it is governed by nothing: content assets under `ContentKit` carry a `sourceRef` and a
citation the validator resolves, and an asset catalog in an app target has no such field. And Figma
places it in a 99 × 116 box against its own 447/558, and **FILL-crops** it rather than stretching —
`SideQuestWatchCardView` reproduces that with `.scaledToFill()` plus `.clipped()`, so the top and
bottom of the scrollwork are cut by ~3% exactly as the frame cuts them.

**The three onboarding pictures are 3×, and their transparency is arithmetic rather than exported.**
Figma returns two things and neither is what is wanted alone. `download_assets` at 3× composites the
*frame's* fill behind the art, and on these frames that is a cream sheet — so each picture arrives
opaque on a cream card that does not exist in the design (`#FCF2DE`, read out of the corner pixel;
one unit off the `#FDF2DE` the screen is actually painted, which is enough to print a rectangle).
`get_screenshot` with `contentsOnly` is transparent but will not upscale past the node's own size,
whatever `maxDimension` asks for — that was re-tested on 2026-08-20 and the 1× ceiling is still
there.

So each file is built from both. The 3× export supplies the colour, the 1× contents-only render
supplies the alpha resampled up, and the ground is divided back out:
`art = (composite − (1 − α)·cream) / α`. Alpha upscales forgivingly — these mattes are mostly 0 or 1
with soft shadow ramps — while the colour stays the design's own pixels at full resolution. Keying
the cream out by colour instead would have left a hard halo everywhere a shadow fades, which is the
whole reason the shadows are drawn.

Two details are load-bearing. **Alpha is never quantised**: `explore` and `collection` are reduced to
a 256-colour palette for size (334 KB and 213 KB against 1.4 MB and 1.2 MB), but the octree merges
near-zero alpha into an entry at 1–2/255, and a "transparent" ground carrying alpha 2 over black
darkens the cream by two units — a visible rectangle, which is exactly what shipped for one build
before it was measured. The `tRNS` chunk is floored to 0 below 8 after saving. And `quest` is **not**
quantised (345 KB): it is a smooth cream gradient, which is the one thing 256 colours band.

The boxes are the exports' own, shadows included — 378×277, 340×257 and 324.33×274 — and the
fractions in `HisploraOnboardingArt` are in points.

**`story-divider.png` is not the frame's pixels.** Figma exports that node with the containing
frame's `#808080` backdrop baked in, so the file as exported is a solid grey bar with a faint
`#AA9B8E` flourish inside it — and that is exactly how it rendered on device before it was caught.
The coverage was lifted out of the red channel (170 against 128, the widest separation of the
three) into alpha, leaving white ink `HisploraOrnamentDivider` tints with `brownMid`. Worth knowing
for the next vector pulled out of this file: check the exported PNG's corner pixel before shipping it.

Both images are generated art exported from the design file (`ChatGPT Image Aug 10 …` and
`ChatGPT Image Aug 13 …`). They depict objects and claim nothing, so they are a licence question to
answer rather than an editorial one — recorded here and in the component headers so it stays
answerable.

**Five assets in the file were deliberately not shipped.** They are not oversights:

- **The Google Maps screenshots** on `89:1402` and `223:2004`, and the traced street map derived
  from them. They are a third party's map imagery under that party's terms, and `FR-MAP-01`
  already rules out live tiles; `RunRouteMapView` draws the authored route instead. A shipped
  static route image per quest (`route.previewImageAsset`) is the supported way to show a map here.
- **The Apple system icons** in the permission-dialog mock. iOS draws that dialog itself.
- **The AI-generated portrait** of I Gusti Ngurah Made Agung — see below.
- **The place notice's plate**, `293:1630` on `293:1613` — see the next section.
- **The circular portrait** `447:1905` puts beside `447:1880`'s title. It is the same generated
  likeness of I Gusti Ngurah Made Agung; `TaskDetailScreen` frames the quest's own hero image in
  that circle instead, and draws nothing when the quest ships no hero.

### The SVGs are the source; three of them ship as pixels

Seventeen SVGs sit in `DesignSystem/Resources/Images` and **none is loaded at runtime**. iOS has no
SVG image loader, and Xcode's asset-catalogue SVG support handles neither the embedded rasters nor
the filters these files are made of. They are kept as the record of where the pixels came from, and
what ships is what each file actually describes.

- **`badges-frame.svg` (152 × 206) is a die, and is drawn as one.** Its proportion is now
  `HisploraStampCard.aspectRatio`, and the card holds it for **the whole object** rather than for
  the picture window alone. Before this the window held a ratio and the caption added whatever
  height it needed, so a two-line place name made one stamp in the grid taller than the one beside
  it and the perforations came out at a different pitch on each — the opposite of what a die-cut
  object does. The value is within a thousandth of the envelope thumbnail's old `25.788 / 35`,
  which is why the franking down the pocket did not move.
- **`Rectangle 10.svg` is a filter, not a fill.** Its rectangle is `#6E3B26`, which is `brownMid`
  and already a token; everything else is `feTurbulence` fractal noise at `baseFrequency 0.588`,
  `luminanceToAlpha`, a discrete transfer keeping ten of a hundred steps, and a white flood at
  `0.25` composited back in. Rendered once through the system's own SVG renderer and shipped as
  `hisplora-ground.png` — 804 × 1748, the frame's 402 × 874 at 2x, 137 KB. `HisploraGround` loads
  it and `HisploraStage(grain:)` prints it over the token, on the Journal and the Explorer's Card.
- **The fifteen stamp SVGs are a frame, a caption and a photograph** — see below.

#### What the printed ground does to the measured ratios

Worth writing out, because white on brown is a stronger mark than the museum theme's speckle:

| | luminance | `inkCream` on it |
|---|---|---|
| `brownMid` alone | 0.0659 | **7.94:1** |
| one speckled pixel | 0.1763 | **4.07:1** |
| the ground, averaged over 10% coverage | 0.0769 | **7.25:1** |

The speckle is a one-point dot at a tenth coverage, so what a reader integrates behind a glyph is
the average, not the dot; the flat `brownMid` token `HisploraThemeTests` measures still honestly
describes the ground. The render's own flat pixels are `#6E3B26` exactly, which is what makes
painting the token first and the sheet over it a true composite rather than a substitution. The
grain is **opt-in on `HisploraStage`** and on only where the design shows it; the story-flow frames
draw the same brown flat.

### The opening runs at half the note's length, and the letter opens in place

Two changes on 2026-08-18, both from watching it rather than from the frames.

**6.4s → 2.9s.** The designer's note asks for a two-to-three second dwell and a slow zoom, and the
sequence was built to it: 900 / 2500 / 1400 / 1600. That is a title sequence's budget, and this is
not a title sequence — it is the gate in front of *every* letter a reader opens. It now runs 520 /
900 / 700 / 780. The beats keep their proportions to each other, and that is what
`theOpeningKeepsItsShapeAtHalfTheNotesLength` pins instead of the note's literal number: flap
quickest, zoom outlasting the rise so the page still arrives slowly, dwell the longest thing that
is not motion. Rebalancing is free; inverting any of those is a different animation.

**The letter is an overlay, not a `fullScreenCover`.** A cover slides up from the bottom — and the
beat immediately before it is a page zooming *toward* the reader, so the opening ended by throwing
that page away and sliding a different one in from somewhere else. `KultaraRootView.journalStack`
now draws `JournalLetterView` in an `.overlay` with an asymmetric transition: in at 1.14× and
settling, out at 0.97×, over 420ms of `easeOut`. It picks the zoom up where it stopped. The cost is
that nothing else takes the floating tab bar away, so `hidesTabBar` names `journalLetter` too.

**And the page is full-bleed.** The sheet had a `KultaraMetrics.lg` margin of brown down both
sides, which reads as a card on a shelf — the exact thing the reader has just left. It now runs
edge to edge and under the status bar, with its own 76-point top inset keeping the masthead clear
of the clock and of the close control. That control was a `paperCream` disc sitting on a
`paperCream` sheet, which at the top of a full-bleed page is an invisible button; it is `brownDeep`
with `inkCream` on it — 9.63:1, a pairing `HisploraThemeTests` already measures — at a fixed 44
points rather than padding that happened to add up.

### The sheet is taller than the envelope, and the opening now admits it

`332:1252`'s page rises out of the pocket. The offsets that did it were fractions of the *card* —
`+0.34` inside, `-0.62` risen — chosen against a sheet the size of the envelope. A real
`SealedLetterPage` is about 190 points tall against a 173-point card, because the card is landscape
and a letter is portrait, so `-0.62` lifted the whole sheet **bottom edge included** clear of the
pocket's lip: a page hanging in front of an envelope it was visibly not coming out of. Three
changes, all in `HisploraEnvelope`:

- The offsets are computed from the sheet's **measured** height against the pocket lip, not from
  the card. `pageRiseRatio` is gone; `pageGripRatio` replaces it and says how deep in the pocket
  the risen sheet's bottom edge stays. How far it stands proud is then whatever is left of it,
  which is the right way round — a tall page rises further because there is more of it.
- What hangs past the card's bottom edge is masked. "Inside the pocket" cannot mean "within the
  card's bounds" for a sheet that does not fit inside it; it means top edge below the lip, with the
  rest cut rather than drawn onto the brown. One mask whose rectangle moves, not a mask that comes
  and goes — swapping between a masked and an unmasked branch changes view identity and restarts
  the scale animation mid-zoom.
- **The sheet goes in front of the envelope from `zooming` on.** At 2.1× it is half a card wider
  than the envelope, and the pocket band went on drawing a strip of paper straight across the
  middle of it. The envelope's own layers fade out across the same 1600 ms, which is what makes the
  z-order swap invisible: at the instant it happens the sheet is still barely larger than the card,
  and a bottom edge appearing over the pocket in one frame reads as a glitch.

### The fifteen stamps are composited from the SVGs, not lifted out of them

The design exports each stamp as a 152 × 206 SVG — `badung-stamp1.svg` and fourteen siblings. Each
file is a perforated outline, a caption set as vector text, and **an embedded base64 PNG** of the
place. They average six megabytes each and total about ninety; the largest is eleven.

None of them is shipped, and none of them can be: `UIImage(data:)` does not read SVG, and every
image in this package is loaded that way (`HisploraWaxSealMetrics.image(named:)`). What ships is
each file's picture **composited the way the file composites it**, at 480 × 519 — 6.4 MB for the
set, against ninety.

That compositing is the whole of the second pass. The first extraction took the embedded PNG whole
and resampled it, which is not what the export draws: the picture is painted into a
`<rect x="9.674" y="11.258" width="132.431" height="143.105">` through an `objectBoundingBox`
pattern whose `<use transform="matrix(a 0 0 d tx ty)">` places the image *larger than the rect and
offset left*, so the stamp shows a crop of it. Taking the payload uncropped shipped a different
picture from the design's — off-centre, and at the wrong aspect. The crop is recoverable from the
matrix alone (`px = (unit − tx) / a` on each axis), and that is what the current PNGs are.

**No SVG sits in `Resources/Images`, and none may.** `Package.swift` declares
`.copy("Resources/Images")`, which copies the *directory*, so eighty-nine megabytes of base64 rode
into the app bundle for as long as the exports were there — invisible in code review, and roughly
fifteen times the size of everything the package actually draws. Every SVG now lives under
`docs/design-sources/`: the fifteen stamp exports in `stamps/`, which is `.gitignore`d because they
are re-exportable and enormous, and the two small vector files (`badges-frame.svg`,
`Rectangle 10.svg`) beside them, which are tracked because they are the record and cost eight
kilobytes — three, since `275:2179`'s ground joined them as `home-ground.svg` on 2026-08-19; it
arrived in `Resources/Images` under Figma's own `Rectangle 10.svg`, which is the name the file
beside it already had. Nothing in the package loads any of them. **Anything dropped into `Resources/Images`
ships**, so check what is in it before adding to it.

Two more things the files turned out to say. Several carry **two stacked pattern images** and only
the last one drawn is visible — the earlier one is a leftover under-layer, and reading it instead
gives the wrong picture entirely. And the design's own tiers are not always three distinct
drawings: `caturmuka-stamp2`/`3` and `pemecutan-stamp2`/`3` are the same photograph in the export,
so the third walk through those places earns a stamp that looks like the second. That is the
design file's duplication faithfully carried, not an extraction bug — worth fixing in Figma rather
than in code.

The outline and the caption are *not* taken from the export, and were not before this: the stamp is
drawn by `HisploraStampShape` and franked by `HisploraStampCard`, for the reason recorded in that
file — a perforation is a parameter, and the same stamp is set at 26 points on the Journal envelope
and at 160 on the Explorer's Card.

**Three drawings per place, and walking is what moves between them.** `HisploraStampArtwork.tier`
holds the rule: one finished quest through a place shows the first drawing, two the second, three or
more the third. It clamps rather than wraps — a fourth walk must not send a reader back to the
sketch — and its floor is the first drawing rather than a blank, because a stamp is only ever drawn
once it has been earned and a walk in progress has earned its stamps without having finished.
`StampArtworkResolver` in the app target does the counting; place id → asset stem is a table there
rather than a field on `Place`, which is a debt to pay the moment content stops being one quest.

The drawings depict real places, so the rule `PortraitFrame.swift` sets out applies: the picture is
a licence question and the words under it are the editorial one. Nothing is captioned from the
artwork — every stamp's name and region come from the Run's own snapshots.

### The story preview's sheet is the photograph's paper, not `paperCream`

`typewriter.png` (720 × 573, **no colour profile** — its bytes are sRGB) is half of the sheet on the
story preview: the drawn page sits on top of the photographed one and the two have to be the same
piece of paper. They were not. The drawn half was `paperCream` `#EEE7D2`; the photographed half is
`#E4D8CD`, the mean of the flat field at x 165…575, y 5…60, which does not move a level anywhere
from row 0 to row 62. Ten levels apart, and on screen it read as two sheets in two creams.

`TypewriterMetrics.paperTone` is that sampled `#E4D8CD`, and it is **not** a palette token. Every
other Hisplora surface keeps `paperCream`; this one is matching a photograph rather than carrying
the design's cream, and adding a near-duplicate to the palette would leave the next author choosing
between two creams with no rule for which. The two inks the sheet is typed in are measured against
it directly instead — `inkDark` 12.5:1, `inkMuted` 4.7:1 — in `TypewriterTests`, which also
re-samples the file so a re-export fails rather than drifting.

Sampling it through a converting reader (`NSBitmapImageRep` → sRGB) answers `#E9DFD6`. That is a
measurement of the conversion, not of the picture, and it is the number an untagged PNG will hand
anyone who checks this the easy way.

Three geometry values were re-read off the same file at the same time. The paper's lit edges are at
x 143 and x 594, so the sheet is 452/720 of the machine and its centre is 8.5 px right of the
image's own — both already right to within half a pixel. Where the drawn sheet *ends* was not: it
was pulled down 105/573, which is past the machine's paper guide (rows 88…102) and into the lit
strip below it, so a band of photographed paper stood under the drawn sheet in the wrong cream. It
now ends at 62/573, inside the flat field, where the two halves are the same colour and the join has
nothing to show. The short black gradient that used to fake a falloff at the foot of the page went
with it: below the join the shading is the photograph's own.

Two consequences worth knowing. The `.offset` that nudges the sheet onto the photograph's centre
line had to move *after* `.background` — `.offset` leaves the layout frame where it was and
`.background` fills that unshifted frame, so the typed text was sitting about 4 pt off the sheet it
was typed on. And the shallower join costs the page some room, so `maximumSheetCharacters` came down
from 300 to 210: at 300 the distance and the duration were pushed behind the roller, which is the
one thing on that page that must not be hidden.

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

#### 2026-08-18: the plate ships as a picture, with the names taken out of it

The user asked for the notice's background to be the plate itself, from `625:4373` — the same screen
again on a later frame, with the same plate (`625:4377`) under the same three blanking rectangles
(`625:4378`–`4380`). It now ships as `Resources/Images/plaque-plate.png`, and
`HisploraPlaquePanel` draws it in place of the shape, the fill, the engraving and the two rules. The
drawn plate above is **not** deleted: it is the fallback, and it is what the screen returns to if the
picture is ever replaced or dropped.

**The names are erased from the pixels, and that is a different claim from the licence being clear.**
The exported file's names sit on flat cream between y 330 and 540; a grayscale morphological closing
(dilate then erode, radius 3) over that box takes thin dark strokes off a light ground and leaves the
cream, its gradient and the faint watermark. Verified by re-running the same scan that found the text:
the only dark run left in the file is the small glyph on the lower lobe. What is *not* settled is the
engraving's own licence — it is still somebody else's plate, and commissioning or generating a
replacement is now a one-file swap rather than a rewrite.

**Three-slice, not resize.** Content length varies with Dynamic Type and a plain `.resizable()`
stretches the crest with the cream. `HisploraPlateArtMetrics` pins the caps at 430 from the top and
141 from the bottom, leaving the 60-pixel band at y 430…490 — measured to be the one horizontal strip
of the artwork carrying no ornament at all, only the two edge rules, which run vertically there and so
extend rather than smear. `PlateArtTests` re-measures that band against the shipped pixels, so an
artwork swap that puts a flourish there fails rather than ships.

**The picture is placed by its sheet, not by its edges.** The artwork is not centred in its own canvas
(26 points of margin on the left, 38 on the right) and every column on this screen is measured against
the sheet's straight sides. `HisploraPlateArtMetrics.frame(forPanel:)` does that arithmetic and
`PlateArtTests` asserts the result lands on `HisploraPlaqueShape.body(in:)` to within half a point —
which is what lets the drawn plate and the picture be swapped for one another with no layout moving.

**Contrast, since the ground is now a picture.** `KultaraPaperTexture`'s note — that the contrast suite
cannot see a picture behind text — applies here in full, so the darkest opaque pixel anywhere text can
land (`#D3CAAD`, a faint flourish) is measured directly: `inkBody` clears **5.95:1** on it, against
7.9:1 on the `paperCream` token. Above AA for body text, and a real drop worth knowing about. The
plate's cream itself samples `#EDE6D1`, one step off `paperCream`'s `#EEE7D2`, so every other ratio
the theme suite measures still describes what is on screen.

**Motion.** The plate fades and rises 14 points over 0.5 s on appear, and does neither under Reduce
Motion — where the value still flips, so the screen is complete on the first frame rather than fading
in slowly. Seen on iPhone 17 / iOS 26.5: `screenshots/m9-place-notice-plate.png`.

### `452:3028`'s site plan is content, not chrome — and that is the whole decision

The plan ships. What changed is *where* it ships from, and it is the one structural decision the three
2026-08-17 screens forced.

Every other image in the table above is chrome: a frame, a machine, a blank sheet, a flourish. They
depict objects and assert nothing, which is why they live in `DesignSystem/Resources/Images` and
travel with the theme. `452:3031` is different. It is a plan of **Puri Agung Pemecutan** annotated
with "171 meters", "158 meters", an entrance gate and an exit gate — claims about a real place, of
exactly the kind `FR-CP-05` holds to a source. Baking it into the design system would also bake a
named place into the presentation layer, which `AD-4` and `FR-RUN-06` rule out on their own.

So it is authored content with a citation:

```
Place.siteMap : { asset, aspectRatio, sourceRef }
```

`sourceRef` indexes the Place's own `sources`, the same way `LoreBlock.sourceRefs` does, and
`PlaceSiteMapScreen` prints that citation under the drawing — which the frame does not. Two validator
rules cover it: **V14** that the asset exists, **V3** that the citation resolves. Both are in
`SiteMapValidationTests`, and both prove violating content is *rejected*.

Today's citation begins `BELUM DIVERIFIKASI` and says in as many words that the drawing is a generated
illustration rather than a survey, so the screen tells the truth about it.
`ShippedSiteMapTests.theShippedPlansCitationSaysItIsUnverified` fails if that stops being true.
Replacing the drawing with a real surveyed plan is a content change and nothing else: a new file, a
new source entry, a `contentBundleVersion` bump.

**What is not drawn:** `452:3032`–`3034`'s three marker dots. They are not authored anywhere, and
inventing coordinates for them would be the app asserting where three things stand inside a real puri
— the precise claim the citation exists to qualify. `SiteMapPresentation.markers` ships empty and the
view renders whatever the content eventually carries.

### `275:2178` and `275:2309` — the Home ground and the illustrated island

Two frames landed on 2026-08-19, and between them they are an asset-and-ground pass rather than a
new screen: nothing was built that did not already exist, and one measured colour moved.

**The ground, from the export rather than from the codegen.** `get_design_context` reports node
`275:2179`'s fill as `#F4EADD`, and that is the flattened appearance, not the sheet. The frame's own
export — `home-ground.svg`, filter `filter0_n_275_2179` — is a **#FDF2DE** stock with a printed
speckle over it: `feTurbulence` fractal noise, `luminanceToAlpha`, a discrete transfer keeping ten
of a hundred steps, and an `rgba(147, 130, 97, 0.5)` flood composited back in.

`KultaraPalette.light.paper` is now **#FDF2DE**, the stock, and the speckle is
`KultaraPaperTexture`, drawn over it — the same split `HisploraGround` documents and for the same
reason: `KultaraThemeTests` measures token pairs and cannot measure a picture.

Rendering it needed a real SVG renderer (headless Chrome; nothing else on this machine runs SVG
filters, and no iOS image loader does either). The render has exactly **two** colours — `#FDF2DE`
and `#C8BAA0` — and `#C8BAA0` is the flood at half alpha over the stock, which is how the coverage
below is known exactly rather than estimated. `home-ground.png` is that render whole: 1206 × 2622,
**1.43% speckle**, 98 KB.

It **supersedes `paper-texture.png`**, the museum direction's earlier hand-made grain — a 445 KB
speckle meant to be attenuated over an arbitrary cream. Keeping both would have left two grounds
with no rule for which screen got which, so the old one is deleted and `KultaraPaperTexture` is now
`KultaraGround`, matching `HisploraGround` in shape: an opaque sheet drawn over the token, at full
opacity, because the design's own alpha is in the pixels. `KultaraGroundTests` therefore stopped
asserting on opacity, which had become the wrong proxy, and asserts on
`opacity × speckleCoverage × speckleAlpha` instead — plus that the render's stock still *is* the
`paper` token, which is what keeps every measured ratio describing the sheet.

The two procedural Hisplora map canvases tiled the old grain at 0.4 with `.multiply`; they now tile
this sheet the same way. It is 98.6% `#FDF2DE`, so multiplying warms their parchment slightly and
the speckle lands as a faint dot.

**Ten museum screens were painting the flat token over it, and that is why the catalogue read as
flat cream while the Journal read as printed paper.** `KultaraThemeProvider` draws paper *and* the
sheet behind the whole app, but `QuestListView`, `QuestPreviewView`, `SettingsView`,
`RunSummaryView`, `QuestRunView`, `OnboardingView`, `SideQuestFlowView`, `LetterCollectionView` and
the two wireframe screens each ended with `.background(palette.paper.color)` — an opaque flat
colour on top of the speckle. Those grounds are not redundant (a `sheet` or `fullScreenCover` is
presented outside the provider's tree and would otherwise show the system's), so they were replaced
rather than removed: `.kultaraGround()` paints the token *and* the sheet. Same colour as before,
with the printing that was being covered up.

**It replaced the Journal's brown ground too, and the Journal's ink flipped with it.** On
2026-08-19 the author asked for one ground rather than two, so `hisplora-ground.png` — `547:2953`'s
`#6E3B26` sheet — and the whole `HisploraGround` type are deleted, and `HisploraStage(grain:)` now
prints `KultaraGroundSheet(respectsAppearance: false)`. The flag matters: this direction is a fixed
editorial pairing that does not follow the system appearance, so it asks for the sheet
unconditionally, where the museum theme keeps the light-only rule.

A cream ground under cream type is not a ground swap, it is an unreadable screen, so the three
callers that print the sheet — the Sealed Letters shelf, the Explorer's Card, the opened letter —
moved from `ground: \.brownMid` to a new **`paperSheet`** token (`#FDF2DE`, the render's own stock,
so what is measured is what is drawn) and their type from `inkCream`/`inkDusty` to
`inkDark`/`inkMuted`. `HisploraExplorerCard`'s tab row and rule, and `HisploraSealBadge`'s label,
went with them — they are only ever set on those screens. The ratios improve rather than degrade:
`inkDark` is 14.18:1 on `paperLight` and **15.26:1** on `paperSheet`, against `inkCream`'s 9.63:1
on `brownDeep`. `HisploraThemeTests` enumerates the new token like any other, so the four papers
are measured as four.

The brown tokens are untouched and still carry the story flow, which is where the frames actually
draw brown.

The ratios went **up**, not down: ink on paper 15.01:1 → **15.26:1**, the hairline 4.06:1 →
**4.13:1** against a 3:1 requirement. The speckle costs about 1% of each — ink lands at 15.12:1 on
the sheet as rendered.

**The cards' photographs.** `275:2178` draws four cards over three images: a watercolour candi
bentar (cards one and three — the frame itself reuses it), a watercolour puri, and a photograph of
Pura Besakih. The first is now the real quest's `heroImageAsset`; the other three are the
`dummy-quest-*` imagesets the filler cards already used. Their provenance is unrecorded, exactly as
`PlaceholderQuestCatalog`'s header already says of the images it replaced: they must not survive
into anything public.

**The card's caption is now the frame's wash, and that is a recorded loss.** `275:2183` draws one
89-point block running from black at 80% along its bottom edge to nothing at its top — the
gradient's `startPoint` is `(0.47, 1)`, so it is drawn upward — with 15 points of horizontal inset,
none vertical, and 10 between the title and the facts. `PhotoQuestCard` drew that as a fade strip
above an **opaque** `photoScrim` block instead, so the type only ever landed on a colour
`PhotoScrimTests` could measure. On 2026-08-19 the author asked for the frame's version and it is
what ships.

What is lost is precise: the tokens are unchanged and still measured, but this card is no longer
where they apply. The title sits high in the block, where the wash is weakest, over an arbitrary
photograph — so `NFR-A11Y-03` is unverified *here* rather than violated in the palette. Two things
were kept: `.black` is drawn as `palette.photoScrim` so the colour stays a token, and the frame's
208 and 89 remain `@ScaledMetric` **minimums** rather than heights, so the card still grows instead
of clipping at the largest content sizes (`NFR-A11Y-01`). Recovering the measurement means an
opaque band behind the title, which is the thing that was just removed.

**The island.** `275:2309` draws the region map as a wide fantasy chart of Bali — 1469 × 1071,
landscape, the whole island plus Java's tip, Nusa Penida and Lombok. It replaces the 853 × 1844
portrait drawing, so `manifest.regionMap.aspectRatio` goes 0.4626 → **1.3716** and
`contentBundleVersion` to **2026.09.4**.

That aspect flip is the whole reason the map now scrolls in both directions. `RegionMapView` fills
the viewport, so a 1.37 drawing on a 0.46 screen is drawn 1199 points wide against 402 — the frame's
own 1198 — and two thirds of it is off-screen at rest. Horizontal panning was already implemented
and simply had nothing to pan before. Three things did change:

- **The pinch floor is 1 — the fitted height is as far out as the map goes.** It was briefly the
  whole artwork, letterboxed; the author's decision on 2026-08-19 is that the current height is the
  limit, so pinching out stops where the drawing still covers the screen and seeing the rest of the
  island is a pan. `RegionMapArtwork.seaEdge` (#8B9999, sampled from the artwork's own four
  corners, which agree to within two levels) stays for the moment during a pinch when the live
  magnification runs ahead of the clamp. Deliberately **not** a palette token: nothing is measured
  against it.
- **Returning to fill no longer resets the pan.** On this artwork fill still leaves two thirds of
  the island off either side, so zeroing it threw the reader back to the middle of the drawing.
- **The map opens on the quest, not on the artwork's middle.** `openOnThePins` used to centre only
  when it had zoomed in; with one pin it did nothing and the marker opened half off the right edge.
  It now centres whenever there are pins at all.
- **Double tap still cycles fill ↔ 2.5×** and never visits the pinched-out view. That is somewhere
  a reader asks to go, not somewhere a stray tap should land them.

**The markers.** The frame does not use a pin. It stands a small ink-and-wash building on the
coast, blows four overlapping puffs of smoke behind it, and writes the quest's name underneath in
the display serif with a hard outline — which `MapPlaceLabel` already drew. `MapLandmarkFigure`
composes the first two at the frame's own geometry (a 159 × 87 cluster with an 85 × 61 building at
(37, −3), so the building's feet are inside the fog and its roof out of the top). Three drawings
ship; `MapLandmarkCatalog`, in the app target, is the quest-id → drawing table, for the same reason
`StampArtworkCatalog` is: which illustration a quest gets is a decision the visual direction owns
and a content update has nothing to say about it. An unlisted quest gets the meru, which is generic
Balinese architecture and not a picture of somewhere it does not go.

The figure is 120 points across and most of that width is fog at low alpha, so the **pressable area
stays a 44-point square** (`NFR-A11Y-06`), hung on the building rather than centred on the figure —
`MapLandmarkFigure.buildingCentreFraction` is published for exactly that. A target the size of the
drawing would be mostly transparent map, which is the overlap failure the old label-sized target
had.

**Every `mapPoint` was re-authored.** The old values were placed against the portrait drawing and
mean nothing on this one. The new ones were fitted to *this illustration's own geometry*: two
features read off the artwork at known real coordinates (the north coast at Singaraja's longitude,
the east tip of Karangasem, the Bukit's southern tip) give 960 px per degree of longitude and 1206
per degree of latitude — the drawing is stretched about 1.24× vertically against true scale, which
is what makes a real map projection useless here — and the cluster is anchored on where `275:2309`
itself stands "The Last Traces of Badung". Each resulting point was then **looked at on the
drawing** before it was written down. That is still authoring, not deriving: the numbers come from
the picture, and CLAUDE.md's rule about not projecting coordinates onto a stylised coastline is the
reason the fit is to the illustration rather than to Bali.

The visible correction: `park23`'s `mapPoint` was a copy of Catur Muka's, 9 km from where the place
actually is. It now sits on the Bukit isthmus.

**The other five were missed, and were fixed at `2026.09.8`.** `bebek-tepi-sawah`, `citra-minang`,
`mahen-living`, `sovereign-bali-hotel` and `taman-ngurah-rai` kept values from the portrait drawing —
34 to 40 km out, all of them landing in the Bali Strait. Nothing showed it, because the region map
draws one pin per quest start checkpoint and only one quest ships. They were re-authored the way this
section describes, in the order it describes: solve the position from the fit (the six good Places
agree on one origin to within 14 m), then look at where it lands on the drawing before writing it
down. All five are Kuta and Tuban addresses and all five now sit on the isthmus beside `park23` —
`citra-minang`, 120 m from `park23` in the world, lands 0.0005 and 0.001 from it on the paper, which
is the cross-check that the fit is doing what it claims.

`IllustratedMapGeoreferenceTests.everyAuthoredMapPointSitsWhereThePlaceIs` now scans every authored
point at a 1.5 km tolerance. That is deliberately loose — about thirteen pixels of longitude here —
because a point is still authored and may be nudged off the exact projection to clear a label or a
coastline. The five were out by more than twenty times it.

**What the frame draws that the code does not.** Three markers on `275:2309` name quests that do not
exist in the content tree — "Where the Gods Come to Dance", "The Serpent's Tidal Shrine", "The
Mother Temple's Forgotten Vow". The map renders one marker per shipped quest and there is one, so
it draws one. `275:2178`'s four cards are a different case: three of them ship as
`PlaceholderQuestCard`, which is drawn like a card, cannot be tapped, and says so — see
`PlaceholderQuestCatalog`.

**`wand.and.sparkles` is built as of 2026-08-20; `rectangle.stack.fill` still is not.** The wand
swaps the discovery map's ground — the illustrated chart drawn over a live basemap (`275:2309`), or
the basemap alone with the same markers on it (`276:2520`) — which is a behaviour the two frames
between them actually specify. The stack button has none: nothing anywhere says what it does, and a
control whose behaviour is invented is worse than one that is missing. With it unbuilt the wand
takes the upper of the two slots (x 334, 48 square, 20 points off the trailing edge) rather than
floating below a gap where a control the reader never saw would have been. The frames' component is
iOS 26 liquid glass and the deployment target is 18.0, so it is `glassEffect` where that exists and
`.regularMaterial` below — not a hand-painted approximation of a system material.

The chart's placement on the world is `RunEngine.IllustratedMapGeoreference`, and it is these same
960 px/°lon and 1206 px/°lat read the other way: the rates fix the drawing's span, and the authored
`mapPoint`s fix its origin. The 1.24× vertical stretch recorded above is why the picture is drawn
about 1.25× wider than its own proportions once its features sit at their real coordinates.
Squashing the art is the cheaper error; see CLAUDE.md's Known state bullet.

### `719:3285` — the envelope, redrawn

An asset swap onto geometry that did not move. The frame is 290 × 174 — the same card
`HisploraEnvelopeMetrics` was already built against — with the same three papers in the same three
places, so nothing about the opening animation, the pocket mask or the flap hinge changed:

| Frame node | Ships as | Transform |
|---|---|---|
| `719:3286` Rectangle 1 | `envelope-inner.png` | `rotate(179.8°)` alone — a true half turn |
| `719:3287` Rectangle 5 | `envelope-body.png` | `rotate(-179.8°) · scaleY(-1)`, which **nets to a horizontal mirror**, not a half turn |
| `719:3288` Rectangle 6 | `envelope-flap.png` | the same net mirror, on its own 290 × 120.652 board, with the export's own bleed |
| `719:3292` + `719:3293` | `wax-seal.png` | the wax at 58 × 53.399 with the emblem struck into it |

**The two transforms are not the same and reading them as the same puts the notch on the wrong
edge.** Tailwind composes rotate before scale, so `-scale-y-100 rotate-[-179.8deg]` is
`R(180)·S(1,−1)` = `S(−1,1)` — a mirror. Compositing it as "rotate then flip" instead turns the
pocket's V notch upside down and stands the flap on its point, which is exactly what the first pass
produced.

Two numbers moved with the artwork. The wax is **58** wide where it was 54.269, and it is struck at
`(117, 90)` rather than `(118.28, 92.64)`. It ships on a square 58-point board with the wax centred
on it — `HisploraWaxSeal` fits a square — so the board's top edge sits 2.3 above the wax's, and
`sealCentre` carries that.

The emblem is new: a Balinese candi bentar with a figure between the gates, cream on the crimson.
It is cropped by its own 39.895 box in the frame (129.41% × 115%, offset −15.03% / −6.67%) and that
crop is baked into the export, because the box is what the design shows.

`envelope-tape.png` survived, which was nearly a mistake: `719:3285` draws no tape and
`HisploraEnvelope` never draws `tapeImage`, so it looked dead. It is not — `SealedLetterEnvelope`
uses it to hold the quest's photograph onto the pocket in `511:1464`. Grepping one file was what
made it look unused.

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
| `452:3132` | Quest 1/3 — the checkpoint's task list |
| `447:1880` | Quest_Filled — one task on its parchment sheet |
| `452:3028` | Site Map — the drawn plan of a place's grounds |
| `452:2651` | Site Map, full — the same plan filled, cropped and dragged |
| `1:92` | Typography (template) |
| `1:632` | Colors (template) |

The SSE serialization fault that blocked four of these on 2026-08-13 has cleared for individual
frames; all eleven return `get_design_context` cleanly. It still breaks on the **board** — both
`get_design_context` and `get_metadata` on `13:128` fail with a truncated SSE frame, and
`get_metadata` on the page (`0:1`) omits the section entirely, listing only the two template
frames. So the board cannot be enumerated from the tool: query frames by the node ids in this
table, which is the reason the table exists.

## The Journal's turn, its two papers and their modal (2026-08-20)

Four frames on the New Hisplora board: `791:5637` ("Journal - Flip"), `791:5585` ("Journal -
Open"), `791:5533` and `791:5551` (both "Journal - Transition to Detail Journal"). They replace the
single-page opening the Journal shipped with — the envelope now turns itself over on the shelf, holds
**two** sheets rather than one, and hands over to a modal instead of to a zoomed cover.

### One new token

| Token | Value | Sampled from | Measured |
|---|---|---|---|
| `paperCard` | `#F5F1E5` | `791:5568`, `791:5814` — the two cards' fill | 15.02:1 under `inkDark`, 8.02:1 under `brownMid`, 16.4:1 under `buttonFill` |

Its own token rather than `paperLight` (`#F4EADD`) rounded to: the two creams sit on the same
screen the moment a card is drawn over the shelf, and the frames' value is what is written down.

### One new type role

`journalPaperTitle` — New York Regular at 26.25, tracking −0.7875, set solid (`leading-none`).
It is neither `storySection` (25, medium) nor `onboardingDisplay` (30, regular): the frames set this
one lighter than the first and smaller than the second, and it is the masthead of an *object* rather
than of a screen.

### Three new packaged pictures

| File | Source node | Size shipped | What it is |
|---|---|---|---|
| `journal-card-paper.png` | `791:5569` | 564 × 564 | the torn sheet both cards are printed on |
| `journal-summary-emblem.png` | `791:5573` | 530 × 471 | the drawn roundel on the Trip Summary card |
| `journal-history-plate.png` | `791:5819` | 664 × 1000 | the painting on the History card |

The painting is exported at 664 × 1000 rather than the source's 1360 × 2048: the card draws it at
209 × 145 points, so even at 3× the shipped file is generous, and the full-size export is 5.3 MB
against 1.2 MB.

**The envelope's back needed no new export at all.** `791:5642`/`791:5643` are the same crumpled
papers the front already ships, turned about their own centres — so `backFace` draws
`envelope-inner` at 180° and nothing else. It deliberately does *not* draw `envelope-body` as well:
that export carries the pocket's flap cutout, and rotated it printed a bright trapezoid and two
notched corners straight across the address.

### Deviations

- **The eyebrow keeps the theme's tracking, not the frame's.** `791:5571` sets "TRIP SUMMARY" in SF
  Pro Bold at 12.75 with −0.255 tracking; it is set here in the `eyebrow` role, which is caps at
  +2. One place decides what a piece of type is, and a negative-tracked caps label is the frame
  drawing at photograph scale rather than a decision about the type system.
- **The scrim is `inkDark` at 80%, not a token of its own.** `791:5567` is `#1A1A1A` at 80% and the
  palette's ink is `#1D1D1D` — the same ink to within a step. A scrim is not a pair anyone measures
  text against, so adding a token would be adding an unmeasurable one.
- **The address is set in Bradley Hand, not Homemade Apple.** `791:5657`'s face is neither a system
  face nor packaged here, and packaging a fifth typeface to write four lines on the back of a card
  is not a trade worth making. `HisploraHandwriting` resolves the system's nearest printed hand and
  falls back to the serif in italic — never to SF Pro, which would turn an address into a form
  field.
- **`zoomScale` fell from 2.1 to 1.5, and then to 1.3.** Two sheets already spread across more than
  the card's width, so the scale a lone page grew to would throw both off the screen before the
  modal arrives; once each sheet became a whole card rather than the frame's crop of its head, 1.5
  walked them off the top and the sides too.

### What was deliberately not built

- **The frame's page dots and "Tap envelope to open" caption** (`791:5625`, `791:5632`). The tap
  *is* wired — the centred envelope opens on a tap — but the labelled "Unseal the Journey" control
  stays, because a tap on a picture is not something VoiceOver announces on its own
  (`NFR-A11Y-05`), and the dots would be a second progress indicator for a carousel that already
  has one.
- **Two separate destination screens behind "Read Summary" and "Read History".** Both open the same
  letter; the history card scrolls it to the first checkpoint. The two cards name two things a
  reader might have come for, and both are already on that one sheet in that order — splitting it
  would mean two screens printing halves of the same snapshots.

### The bug this cost, worth writing down

`clipped()` clips drawing, not touches. The card's torn sheet is laid in at 708 × 480 against a
344 × 321 card, and the History plate is drawn `.fill` in a box narrower than itself — so both
claimed a hit region far larger than the card, and the topmost of them silently swallowed every tap
meant for the card *above* it. "Read Summary" did nothing while "Read History" worked, which reads
like a wiring mistake and is not one. Both decorative layers are now `allowsHitTesting(false)`, and
the card carries a `contentShape(Rectangle())` as the belt to that brace.

### The second pass, and the four things it changed (2026-08-20)

The frames were built first and then looked at on a device, which is what turned up four faults —
three of them in things the frames themselves draw, and one in the shelf's layout.

- **The open envelope is the whole body export now, not a band cut out of it.** The pocket front
  used to be `envelope-body` masked to everything below `pocketTopRatio`, which drew a straight
  horizontal seam across the middle of an open envelope — an edge no envelope has. The export is
  already cut with the pocket's own V: two wings rising to the top corners and a notch between
  them. Drawn whole, it *is* what a real envelope shows once the flap is off its front, and the
  papers behind it are occluded by the export's alpha rather than by a rectangle. `pocketTopRatio`
  is gone; `pocketNotchVertexRatio` (220 / 522 of the export) replaces it and describes the notch
  rather than a mask.
- **The open flap is shaded.** Past the fold the reader is looking at the *back* of the flap,
  standing away from the light the rest of the object is photographed in; at the export's own
  brightness it read as a second, brighter envelope pitched behind the first. `brightness(-0.14)`
  and `saturation(0.8)` while open is what puts it behind.
- **The sheets in the pocket are whole cards.** `791:5595` is 172.5 × 113.5 because the export stops
  where the pocket covers the sheet — it is the *head* of a 344 × 321 card, not a card of its own.
  Cropping the view there too shipped a card with its picture and its "Read Summary" sliced off, and
  the slice showed the moment the sheets rose clear of the envelope. `HisploraJournalPaperThumbnail`
  keeps `cardAspectRatio` now, `HisploraEnvelopeMetrics.paperAspectRatio` is that same ratio, and
  both `PaperSlot` offsets were re-authored against the V: tucked, each sheet's head stands above
  the notch; risen, the whole card is clear of the envelope and still under the screen's heading.
- **The shelf's one envelope was 42 points left of centre.** The half-card gutter was a
  `contentMargins(_:for: .scrollContent)`; the margin moves the content but the resting scroll
  offset is still taken from the content's own origin, so a shelf that cannot scroll at all sat off
  centre. It is `padding(.horizontal, inset)` on the row now — part of the layout, so one card is
  centred by arithmetic rather than by where a scroll view happens to come to rest.

And one thing the same pass restored: **the sealed card's nudge runs on every shelf, not only on one
worth swiping.** It was gated on `showsSwipeHint`, which is false while there is a single letter — so
the first walk a reader finishes sat perfectly still. The rock is the card's own 2D lean and the turn
is about its vertical axis, so the two ride on top of each other rather than replacing one another.

## The shelf rebuilt around the envelope (`791:5601`, 2026-08-20)

One frame, and it re-orders the whole Journal tab. The screen used to be a heading, a carousel, the
letter's title under it and a full-width "Unseal the Journey" pill at the foot. `791:5601` puts the
title **above** the envelope, prints what to do with it under that, marks the shelf's position with
a row of dots, and removes the pill entirely.

| Frame layer | Node | Where |
|---|---|---|
| "Sealed Letters" | `791:5629` | x 24, y 82 — SF Pro Display Semibold 25 / 34, tracking 0.38, `#151311` |
| the letter's title | `791:5626` | a 332-wide box at y 231 — New York Extra Large Regular **Italic** 35, tracking −0.7, solid |
| "Tap envelope to open" | `791:5627` | y 317 — SF Pro Display Medium 17 / 1.4, tracking −0.51, `#6E2717` |
| the envelope | `791:5612` | 290 × 174 at y 375, centred, with its neighbours at 226 wide and mostly off-screen |
| the shelf's position | `791:5632` | four 8-point dots on a 12-point pitch at y 584 — `#444444` inked, `#D9D9D9` idle |

### Three new type roles

| Role | Set as | Why not an existing one |
|---|---|---|
| `journalShelfHeading` | sans, `.title2`, semibold, tracking 0.38 | the frame takes the display serif *off* the screen's own name |
| `journalLetterTitle` | display serif, `.largeTitle`, regular, **italic**, 35, tracking −0.7, solid | `storyDisplay` is 38 and upright; this one is smaller and leans |
| `journalTapHint` | sans, `.body`, medium, tracking −0.51 | there was no 17-point medium in the table, and this is a hint rather than a control's label |

`journalLetterTitle` is the first `displaySerif` role the frames set leaning, which is why
`KultaraFonts` now applies `isItalic` on that branch as well as on `.serif`. A role that declares
its italic and is then drawn upright is a table that lies about what it decides.

### One new string

`journalTapToOpen` — "Ketuk amplop untuk membuka" / "Tap envelope to open". `journalUnsealAction`
stays: it is the envelope's spoken name now (see below), not a button's label.

### The pill's removal is an accessibility change, not a layout one

A picture with an `onTapGesture` is not a control VoiceOver announces or can activate
(`NFR-A11Y-05`). So the card carries `.isButton`, the pill's own label as its accessibility label,
and an `accessibilityAction`; the frame's words are printed above it for everyone else. The swipe
hint (`journalSwipeHint`) survives only as that element's accessibility *hint*, and only on a shelf
with more than one letter — the frame draws the swipe as four dots, and a row of unlabelled circles
is not information anyone can hear.

### One paper, front and back

`envelope-body` and `envelope-flap` are photographed a good deal darker than `envelope-inner` —
means of `#8A6E47` and `#5A472D` against `#D6C1A1`. Nothing had noticed while the two faces were
never on screen together; the idle turn puts them a third of a second apart, and the card visibly
changed colour halfway round. Re-grading the two dark exports means a per-channel gain of
1.55 / 1.75 / 2.26, which clips every highlight in the crumple. So the shape is taken from one
export and the paper from the other: `paperLayer(shapedBy:)` draws `envelope-inner` masked to the
body's or the flap's alpha.

What keeps the object readable once every surface is the same sheet is what does it on a real
envelope: the flap's fold throws a shadow (0.22 closed, 0.18 open), the pocket's lip throws one when
open (0.28), and the inside is a shade darker than the front (`brightness(-0.05)`).

### Smoother, specifically

- **The idle turn's quarter-beats were both `.linear`** — a card that starts at full speed, stops
  dead at the half-turn and starts again. The beat that leaves a face now eases *in* and the beat
  that arrives at one eases *out*, so the two halves join at the fastest point of the movement
  rather than at a stop. The face swap still happens at the quarter turn, where the card has no
  width.
- **The opening's beats are `.smooth` rather than `.easeOut`/`.easeInOut`** — the spring-based curve
  with no bounce, which is the shape those two were reaching for without the flat middle that made
  the rise look dragged at a constant rate.
- **The nudge is two beats and a spring, not four keyframes.** It stepped through +1.6°, −1.6°,
  +0.8°, 0 on four 130 ms eases, every one of them coming to a full stop before the next began — a stutter
  rather than a rock. It now leans once and is let go.

### The open frame is a still, not a keyframe (`791:5585`, `791:5591`) — tried and reverted

The two frames do not draw the same envelope in the same place:

| | sealed (`791:5601`) | open (`791:5585`) |
|---|---|---|
| the card | 290 × 174, centred at (201, 462) | pocket 339.85 × 202.71, centred at (201, 535.8) |
| the letter's title | y 231, with "Tap envelope to open" under it | y 119, and no hint |
| "Sealed Letters" | y 82 | not on the frame at all |

Same centre line, 1.172 times the size, 73.8 points lower. Animating the card into that — with the
title rising 112 points to meet it and the header stepping off — was built, run, and taken out
again. **It reads as the envelope lurching out from under the reader's finger at the exact moment
they tap it.** Three things moving at once, one of them the thing that was just touched, is not a
letter opening; it is a screen rearranging itself.

The open frame is a still of an open envelope laid out for a screen that has no header on it. It is
not a keyframe of the movement between the two states, and treating it as one is the mistake. The
opening holds the card exactly where it stands, swings the flap, and lets the title and the hint
step back out of the flap's way — which is what the shelf shipped with at `8d892e8` and what it goes
back to.

`openScale` and `openDropRatio` were metrics for about an hour and are gone again, rather than left
as unused constants documenting a thing the code does not do.

### The gap between the flap and the card

A flap hinged at `anchor: .top` ought to keep that edge nailed to the card, and it does not. At
168° with `perspective: 0.45` the whole plane is displaced away from the hinge by roughly
`height · sin(12°) · perspective` — about ten points at the size this ships — and the page showed
through as a bright line straight across the middle of the object, between the flap and the body.

Everything cheap was tried first and none of it moved the line: the export's own feathered top rows
(two or three of 362, well under a point), the order of `brightness`/`saturation` against the
rotation, and the flap's `shadow` — which *should* be applied after the rotation, because a shadow
belongs where the flap ends up rather than being carried around by it, and now is. What closes it is
`flapHingeOverlapRatio`: the swung flap is pushed 12 points of the card's 174 back down onto the
card. The overlap is invisible — the envelope's own paper is drawn after the flap and covers it —
and it is a ratio because the displacement scales with the card.

### The turn was being clipped, and the fix is one line

`ScrollView` clips its content. The turn is a `rotation3DEffect` with perspective, so the near edge
of a card at 90° is drawn *wider* than the card's own frame — and the shelf's content is exactly as
wide as its viewport, so the addressed side lost a vertical strip off its right-hand edge every time
it came round. The nudge did the same to the corners. `.scrollClipDisabled()` — nothing on this
shelf needs the clip, because the neighbours it would cut are off-screen anyway.

### Slower, because smoother was not enough

2.9 s was the other failure mode of the halving recorded above: the flap, the card's move into its
open position and the sheets' rise all landed inside a second and a half, and no curve makes
movement that quick read as paper. The beats keep their proportions and give back about half of what
was taken — 820 / 1300 / 1150 / 1250 ms, 4.52 s end to end — and the turn's quarter beats went from
320 to 420 ms on a 6 s cycle. `theFullOpeningIsShortEnoughToSitThroughAndSlowEnoughToRead` is a band
now rather than a ceiling: a test that only says "no longer than" cannot fail the way this did.

### Deviations

- **The heading is `.title2` (22) where the frame sets 25.** Sans roles take the system's size for
  their text style, which is what makes them scale at all; `.title` (28) is the other side of 25 and
  would out-shout the letter's own title beneath it.
- **The idle dot is `inkBody` at 25%, not a `#D9D9D9` token.** A palette token is a colour something
  is measured against, and a decorative pip is not.
- **The header keeps its second child.** `791:5630` is a hidden instance in exactly that slot, and
  the collections have to be reachable from this tab (`FR-SIDE-08`) — this is the one place the
  design leaves for them.
- **The title is set through the type table, not as `Font.custom("New York Extra Large", size: 35)`.**
  The frame's own export names the face and a literal size; a literal size does not scale, which is
  the one thing `NFR-A11Y-01` will not have. `journalLetterTitle` is the same face — `.system(design:
  .serif)` *is* New York, and at 35 points iOS picks the Extra Large optical cut itself — at the
  frame's size, tracking, leading and italic, and it scales.
- **The title and the hint both fade the moment the envelope opens.** `791:5585` keeps the title by
  moving it, and moving things during the opening is what the section above records as a mistake.

## The Explorer's Card's Quests and Stamps tabs (`705:2824`, `705:2767`, 2026-08-20)

Two frames redraw surfaces that already shipped. Nothing on either is new *information* — every row
and every stamp still comes from the reader's own Runs (`FR-DONE-05`, `FR-RUN-06`) — so what
follows is paint, type and one new packaged picture.

### Two new tokens

| Token | Value | Where it came from | Measured |
|---|---|---|---|
| `paperRow` | `#FEF8EE` | `705:2827` — white at 50% over `paperSheet`, flattened | 12.32:1 under `inkTicket`, 9.28:1 under `inkBody` |
| `paperStamp` | `#FFFFFF` | `705:2771`'s `Vector`, which is filled white | 16.86:1 under `inkDark`, 6.80:1 under `inkMuted` |

Flattened rather than left as translucencies, for the reason `trackDim` and `inkQuiet` give: the
suite measures token pairs, and half a pair that is "white over whatever is behind it" is not a pair
anyone measured.

`paperRow` is *lighter* than the sheet it lies on; `paperTicket` (`452:3132`'s quest row) is darker
than its brown ground. Same idea, two grounds, two tokens — collapsing them would put one screen's
layering on the other.

The row's boundary is **not** a token. `705:2827` rules it in `brownMid` at 50%, which flattens to
about 2.5:1 on the row's own paper — under the 3:1 a control's boundary wants, and it is not the
control's boundary: the row is named and hinted by its own type, and the rule is what separates two
near-identical creams. Tokenising it would enumerate a contrast claim the screen does not make.

### Two new type roles

| Role | Face | Style | Drawn at |
|---|---|---|---|
| `stampFranking` | New York Bold, caps | `.footnote` | 13.343 |
| `stampFrankingDetail` | SF Pro Regular, caps | `.caption2` | 8.339 |

**One deviation.** The region line is drawn at 8.34 points and is set at `.caption2` (11) instead —
below that, on a real screen, is the readability failure `NFR-A11Y-01` exists to prevent, and the
same argument the typed sheet's 8.5-point copy already carries.

These are the first caps roles besides `eyebrow`, which had a stated reason to be alone: an all-caps
short word risks VoiceOver spelling it out as an initialism. The franking is exempt because
`HisploraStampCard` ignores its children and speaks one label built from the *un-cased* strings —
"Badung Market, Badung, Bali" however the paper is printed.
`TypographyTests.onlyTheEyebrowAndTheStampsFrankingAreSetInCaps` keeps the list exhaustive so a
third caps role has to be argued for rather than added.

### One new packaged picture

`quest-seal.png` (232 × 214, drawn at 58 × 53.4) — `737:3971`, the crimson wax with a candi bentar
struck into it, which is the mark a finished walk carries on its row. A second export rather than
`badge-seal-crimson` reused: that one is a blank seal and this one carries the gate.

**Its ground was keyed out, and that is not a liberty.** Figma exports the group opaque — the source
raster has white baked in, which is invisible in the frame because the frame's row is nearly white
and visible here for the same reason. The white field is flood-filled from the border only, so the
medallion's own cream interior (`#F4DFB8`) is untouched, and the one-pixel antialiased rim is ramped
rather than cut, which is what stops the wax getting a hard white edge.

### What the frames draw that the code still does not

- **The portrait and the name "Umar".** There are no accounts in this build and nothing has asked
  the reader who they are (`FR-ONB-01`), so the roundel stays empty and the card names the reader by
  what they are. Unchanged by these frames, and the reason is unchanged with it.
- **`705:2769`'s six stamps.** The grid renders what the reader has earned; six is what the frame
  needed to fill a page.

### One thing the frames do not draw, added anyway

`705:2824` lists **finished** walks; the tab shipped listing **unfinished** ones, because Profile is
the only route back into a walk in progress. Both readings are right about a different reader, so
the list carries both behind a three-way filter — All / Unfinished / Done, `HisploraFilterChips`,
centred under the strip. Chips rather than a second ruled strip: `HisploraTabStrip` switches
surfaces, and two controls that look alike would say they do the same thing. Only an unfinished row
carries something to resume; a finished walk's record is its letter and its badge, and a row that
looks tappable and is not is worse than a row that does not.

## The region chart was replaced, and what that re-measured (2026-08-21)

`maps/bali-illustrated.png` is a new drawing: **1536 × 1024**, `aspectRatio` **1.5**, a watercolour
chart of Bali with Nusa Penida and Lembongan and nothing beyond. It replaces `275:2309`'s
1469 × 1071 sepia island at 1.3716, and `contentBundleVersion` goes to **2026.09.11**.

**Nothing measured off the old drawing survives a new one.** Everything below moved together, and
the order matters: the geometry first, then the points, then the pixels.

### The fit

The land was separated from the sea by `G − B > 20` — this palette's sea sits at about −15 and its
land at +50 to +80, so the split is unambiguous — and the mask then eroded three pixels to drop the
offshore rocks, which a foam-inclusive mask bridges to the mainland and which would otherwise have
set the west extremity 28 pixels too far out.

| the drawing | is bound to | because |
|---|---|---|
| x 56 — west extremity | 114.4327°E | Bali's westernmost point, Prapat Agung |
| x 1499 — east extremity | 115.7133°E | Bali's easternmost cape |
| y 58 — north extremity | −8.0611 | the north coast at its highest |
| y 760 — the Bukit isthmus | −8.7750 | the narrowest land bridge, found as the row with the least land between x 700 and 1100 |

**1126.82 px per degree of longitude, 983.33 per degree of latitude.**

### Why latitude is anchored on the isthmus and not on the Bukit's tip

The obvious fourth anchor is the drawn south extremity against Bali's southernmost latitude. It is
wrong, and visibly so. This drawing runs the Bukit peninsula about **twice** its true length — it is
the silhouette's most recognisable feature and the artist gave it room — so binding its tip
stretches the whole latitude scale. Built and rendered before it was caught: the five Denpasar
places landed *on* the isthmus and the six Kuta ones landed *on the Bukit*, every one of them a
place a walker would recognise as wrong.

Anchored on the neck instead, the strip the shipped quests occupy lands where it belongs and the
exaggeration is left where the artist put it: Bali's real southern tip falls at **y ≈ 833** on a
drawing that runs to y 940.

The check that settled it was not arithmetic. Every projected point was drawn onto the artwork and
looked at: the Kuta cluster sits on the coastal strip *north* of the neck, the Denpasar cluster
inland and north-east of it, both on land, in the right relation to each other and to the coast.

### The distortion reversed

| | old chart | this chart |
|---|---|---|
| px/°lon | 960 | 1126.82 |
| px/°lat | 1206 | 983.33 |
| lat ÷ lon | 1.256 | **0.873** |
| drawn, placed for correct geography | 1.25× wider than its own proportions | 1.15× taller |

Less distortion than before, and in the other direction. The residual error is the Bukit's length,
absorbed at the south edge where no quest goes.

### Coverage is tighter

The old chart ran to Java's tip and Lombok. This one stops just past Bali's east cape, so
`theFittedImageCoversTheIsland` asserts 115.72 rather than 115.75. Widening it back would be
asserting coverage the artwork does not have.

### The sea token moved

`RegionMapArtwork.seaEdge` is **#9FD0DC**, the mean of the four corners (#99CCD9, #9ACED9, #A5D5DE,
#A3D3DE). The old value was #8B9999, a grey-green; letterboxing this chart with it printed a band of
the previous map's sea beside the new one. Still deliberately not a palette token — nothing is
measured against it.

### The pyramid

`remacri-4x` at scale 4 gives 6144 × 4096; **513 WebP tiles, levels 0–5, 9.7 MB.** Larger than the
previous chart's 6.2 MB because this drawing is textured where the sepia one had flat washes.
6144 and 4096 are exact multiples of 256, so this pyramid has no padded edge tiles at all — the
overhang rule is still guarded, on a ragged synthetic pyramid, because the tidy case is the one that
stops being true the moment the artwork is re-cut.

### Verified against the live basemap

The only real test of a georeference is the ground underneath it. On iPhone 17 Pro / iOS 26.5, at
one camera, the wand swaps the chart for MapKit: the coastlines line up and the marker sits on
Denpasar — `docs/screenshots/m15-map-new-chart.png`.

### Still open

The chart is bright watercolour on cyan. The Hisplora direction is aged brown and cream paper, and
the Journal and the story flow are built on it. This map now reads as a different app's map next to
those screens. That is a visual-direction decision with an owner, not a bug, and it is recorded here
rather than quietly absorbed.

## The region chart's resolution, and the upscale that raised it (2026-08-21)

`275:2309`'s island is a 1469 × 1071 drawing shown on surfaces that magnify it. That is the whole
of why it looked broken up, and the arithmetic is worth writing down because it is the thing a
tiling scheme cannot argue with.

The chart spans 1.5302° of longitude — 168.4 km at this latitude — across 1469 pixels, so it holds
**8.72 px/km**. An iPhone 17 screen is 1206 pixels across. The drawing is therefore 1:1 only when
the viewport is **138 km wide**, which is very nearly the whole island; the discovery map's opening
camera shows about 22 km, so it was being magnified **6.3×** before anything was drawn.

| viewport | source width needed for 1:1 |
|---|---|
| 138 km | 1,469 px — the authored drawing |
| 60 km | 3,385 px |
| 30 km | 6,770 px |
| 20 km | 10,155 px |
| 5 km | 40,618 px |

Street zoom is unreachable and always was. What ships instead is a **4× super-resolution pass**:
5876 × 4284, 34.9 px/km, 1:1 at a 34.5 km viewport, so the opening camera magnifies 1.6× rather
than 6.3×.

**A pure scale is the reason this was the option taken.** Every `mapPoint` was authored by eye
against this coastline and the 960/1206 px-per-degree rates were measured off this drawing; a
*redrawn* or regenerated chart invalidates all of it and is a content job with an owner. Scaling
the same picture moves nothing on the paper, so `manifest.regionMap.asset`, `aspectRatio 1.3716`,
`IllustratedMapGeoreference` and all eleven authored points are untouched.

### The model, and why not the sharper ones

Upscayl 2.15.0's `upscayl-bin`, four models compared on the same 360 × 270 crop of the south coast
before choosing:

| model | verdict |
|---|---|
| `remacri-4x` | **shipped.** Reconstructs the ink lines, keeps the wash colour and the paper grain, adds no pattern that was not there |
| `high-fidelity-4x` | crisper lines, but hallucinates a heavy canvas weave across the sea |
| `ultrasharp-4x` | sharpest lines, over-contrasts the land, and lays a regular grid weave over the water |
| `digital-art-4x` | cleanest of all — and flattens the sea to plain colour and removes the paper grain, which is the texture the whole direction is built on |

Lanczos was the control and only blurs; it reconstructs nothing.

The 45 MB upscaled master is **not** committed. It is regenerable from the authored PNG, and the
exact command is in the header of `scripts/build-map-tiles.sh` — the same treatment
`docs/design-sources/stamps/` gets, and for the same reason.

### The tiles are WebP, and that is a 37 MB decision

543 tiles: **43 MB as PNG, 6.2 MB as WebP at quality 90.** A q90 tile was compared against its PNG
at 1:1 before the switch rather than assumed equivalent — on this artwork they are
indistinguishable. Below about quality 85 the ink lines start ringing against the paper, which on a
drawing made almost entirely of ink lines is the one artefact that would show. ImageIO has decoded
WebP since iOS 14 and the deployment target is 18.0, so nothing extra is needed to read them;
`tiles.json` states `tileFormat` so no Swift hardcodes the extension.

**34.5 km is a ceiling, not infinity.** A reader who pinches to street level still gets smooth
blur. Going further means a genuinely higher-resolution drawing, or handing the ground over to the
live basemap past the chart's own resolution — neither is built.

## The entry screens (`791:5145`, `791:5109`, `822:2235`, 2026-08-21)

Sign Up, Sign In and Guest — the three frames between onboarding and Home, which stood as
wireframes (`WireframeCatalog.login`/`register`) until now. They are one page drawn three times: the
same cream ground, the same 314-point controls inside a 44-point page margin, the same capsule
fields at 17 × 11 padding, the same fully rounded pill. `AuthCredentialScreen` is Sign Up and Sign
In in two configurations for that reason; `GuestNameScreen` is separate because it is left-aligned
and carries a back control.

### Two new tokens

| Token | Value | Where it came from | Measured |
|---|---|---|---|
| `brownSeal` | `#6E2D26` | `791:5149`, `791:5152`, `822:2248` — the masthead, the primary pill, the closing line's link | 9.16:1 on `paperSheet`, 10.16:1 under `inkOnButton` |
| `fieldRing` | `#8F8B88` | `791:5155`'s outline, moved from the drawn `#918D8A` | 3.05:1 on `paperSheet` |

**`brownSeal` is not `brownDeep` rounded to.** `#6E2717` is a *ground* — the deepest earth the
story reveal is printed on — and this is ink and fill on cream. They are one step apart, exactly the
distance `brownBand` keeps from `brownMid`, and they never appear on the same screen. Collapsing
them would put a ground token on a control.

**`fieldRing` is a deviation, and a three-hundredths one.** The frames draw `#918D8A`, which
measures **2.97:1** on `paperSheet` — under the 3:1 WCAG 1.4.11 asks of a control's visual boundary,
and this hairline is the only thing that says where a field is. The theme yields to the threshold
rather than the other way round (`NFR-A11Y-03`), the same move `inkDusty` and `inkFragments` made.

**The placeholders are not set in it either.** The frames set them in the same `#918D8A`, which as
*text* is nowhere near the 4.5:1 body needs. They are `inkMuted` — already measured on this ground —
rather than the ring token being asked to do a job it fails.

### One new type role

| Role | Face | Style | Drawn at |
|---|---|---|---|
| `authDisplay` | New York Extra Large **Bold** | `.largeTitle` | 34, tracking 0.4 |

The one place in the table the display serif is set bold. Its own role rather than
`onboardingDisplay` grown or `storyDisplay` shrunk: those are regular cuts at 30 and 38, and these
frames set a heavier, smaller title because it stands alone on a cream page with no illustration
over it.

### One new packaged picture, and it is a blocker

`google-mark.png` (87 × 88, drawn at 21.57 × 22) — `791:5174`, exported at 4× rather than drawn.
Never hand-authored: it is a trademark with a published geometry, and an approximation is worse than
none. PNG rather than SVG for the reason `Package.swift` forces — `Resources/Images` is copied
wholesale and everything in it is read through `UIImage(data:)`.

**Whether it ships is a decision with an owner, and it is not taken.** Google's brand terms allow
the "G" on a real Google Sign-In control and nowhere else, and this build has no identity provider
behind the button. This sits beside the `docs/consent-log.md` blockers and the History page's
citations, not instead of them.

### The two provider rows are drawn and disabled

`791:5170` and `791:5173` are on screen exactly as the frames draw them, and neither can be used. A
control labelled "Continue with Apple" that does not call `AuthenticationServices` is a false claim,
and a false Sign in with Apple is one App Review declines besides. `791:5180` ("Continue as a
guest") is the one row here that does what it says.

Two consequences worth writing down:

- **They are not faded.** `HisploraProviderButtonStyle` takes `dimsWhenDisabled:` and both provider
  rows pass `false`, which is the opposite of what a style usually wants. Fading composites the fill
  into the cream — near-black turns to mud and the white row all but disappears — so the screen
  would be drawing two colours nobody sampled and the measured pairs would stop describing what is
  on it. `.disabled` still stops the tap and still makes VoiceOver announce them as dimmed.
- **A line under them says why**, which the frames do not draw. A disabled control with no stated
  reason is the accessibility failure disabling it was meant to avoid.

### What is behind these screens

A **local profile**, and nothing else. No credential is stored, transmitted or checked: the email
and the password are validated for *shape* and discarded. What survives is the display name
`822:2249` promises will appear on the Explorer's Card and in the journal, kept in
`AppPreferencesStore.explorerDisplayName` and read by `ExplorerCardViewModel` — which headed the
card by role until this field existed, and still does for a reader who signed in rather than naming
themselves. `AD-3` is intact: nothing here touches the network, and the entry screens work in
airplane mode like everything else.

**The password length floor is not applied on sign-in**, deliberately. It is a rule about *choosing*
a password, and applying it on the way back in is how a form locks out an account made under a
different rule.

### One string is identical in both languages, on purpose

`authEmailPlaceholder` is "Email" in both columns. The formal Indonesian coinage "surel" exists and
is not what anyone types their address into, so it is exempted by name in both copies of the
half-translation guard — `UIStringsTests` and the app target's `LocalizationTests`.

## Seen rendering

**`452:3132`, `447:1880` and `452:3028` were verified on iPhone 17 / iOS 26.5 on 2026-08-17**,
walked in one pass from a fresh install: splash → onboarding (Skip) → login wireframe (Skip for
now) → quest card → story preview → safety notice → location rationale → permission → cutscene
intro (the scratch reveal needs real drag paths) → cutscene portrait → story reveal → place notice
→ **All Quest** → **the task sheet** → **the site plan**, pinched to zoom and closed back to the
sheet. Screenshots are in `docs/screenshots/m9-*.png`. The grey-bar divider bug above was found
on that pass and nowhere else — no test could have seen it.

**`705:2824` and `705:2767` were verified on iPhone 17 / iOS 26.5 on 2026-08-20** — both tabs, with
one finished walk and one walk two checkpoints in, in `docs/screenshots/m13-profile-quests.png` and
`m13-profile-stamps.png`. The records were seeded as two `FileRunStore` documents in the simulator's
container rather than walked, and were deleted afterwards; what the screenshots show is the
rendering, not a walk anyone took. The keyed-out white behind the wax seal was found on that pass
and nowhere else.

**`452:2651` was verified on iPhone 17 / iOS 26.5 on 2026-08-18** — the filled plan, dragged to its
right edge and pinched to zoom, in `docs/screenshots/m10-site-map-full.png` and
`m10-site-map-zoomed.png`. It was reached with a temporary probe in `challange_5App.swift` rather
than by walking, and the probe was reverted: the story-reveal pill and the forward FAB do not
respond to the simulator MCP's synthesized taps reliably, which is the same class of problem the
"Simulate arrival anywhere" toggle has. `ArtworkViewportTests` is what holds the geometry; the
screenshots are what show it against the frame.

A resumed walk lands on `.atCheckpoint` and skips all three, so reaching them from a desk means a
fresh install (`xcrun simctl uninstall com.umar.hisplora`) rather than relaunching.

**`791:5145`, `791:5109` and `822:2235` were verified on iPhone 17 Pro / iOS 26.5 on 2026-08-21**,
from a fresh install: onboarding (Skip) → Sign Up → the closing line to Sign In and back → an empty
submission printing "Enter a name first." under the name field → "Continue as a guest" → the guest
screen → a name typed and "Start Exploring" → Home → Profile, where the Explorer's Card is headed
with that name instead of "Explorer". Screenshots are in `docs/screenshots/m16-auth-*.png`. The
disabled rows' fade was found on that pass and nowhere else — no test could have seen it.

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

**The four `791:*` Journal frames were verified on iPhone 17 / iOS 26.5 on 2026-08-20**, walked from
a fresh install with one active walk on the shelf: the sealed front, the idle turn onto the
addressed back and back again, the envelope open with both sheets in the pocket, the sheets rising
and zooming, and the modal with both cards and both controls. Screenshots are in
`docs/screenshots/m11-journal-*.png`.

Two things about capturing it, since both cost time: `xcrun simctl io <udid> screenshot` served a
**stale frame** repeatedly while the card was turning — twenty-six consecutive captures were
byte-identical on a screen that was visibly animating — so the turn has to be recorded
(`recordVideo`) and stepped through with `ffmpeg` rather than sampled with stills. And a resumed
shelf never re-runs the opening, so the beats between `dwelling` and `zooming` are only reachable by
unsealing again.

**`791:6414` and `791:6537` were verified on iPhone 17 / iOS 26.5 on 2026-08-20**, from a fresh
install with one completed five-checkpoint walk on the shelf: the summary's masthead, emblem and
three counters, the brown band with a card per place and the walker's own answers on it, the tan
Trip Collection with the gilt medallions and a six-cut-out scatter; then all eight bands of the
History page — the plate and the frangipani, the three paragraphs and the pen rule, the procession
over the dark band with `Puputan Badung.` in gilt, the portrait with the drawn ring around the
king's name, the torn scrap on the second plate, the five-cut-out scatter, and the plaque under its
wax seal. The back control was tapped from both pages and returned to `791:5551`'s modal.
Screenshots are in `docs/screenshots/m13-*.png`.

Reaching them from a desk does not need a walked route. `FileRunStore` writes one JSON document per
Run into `Library/Application Support/Kultara/runs` in the app container, so a completed Run
generated from the shipped content and copied in with
`xcrun simctl get_app_container <udid> com.umar.hisplora data` puts a letter on the shelf directly.
That is a fixture for looking at a screen, not a way to test the engine — nothing about arrival,
ordering or awards is exercised by it.

## The Discovery flow — `670:1826`, `670:1832`, `1108:2636`, `1108:2780`, `949:2461`

Five frames landed on 2026-08-23 as one journey: a proximity notification on the watch, the New
Discovery card the tap opens on the phone, and the Discovery page behind "Read Story".

**No new palette token and no new type role.** Every colour the five frames use already had a
measured token — `paperTrip` `#F3EEE1` for the card and the page, `brownDeep` `#6E2717` for the
caption, `brownSmoke` `#564D48` for the closing band, `inkCreamWhite` and `inkGiltDeep` for the
words on it, `buttonFill` for both pills. The two grounds on the watch are local `Color(hex:)`
values in the watch target, which links no package.

**One recorded deviation.** `1108:2784`'s body is drawn in `#727272`, which measures **3.92:1** on
`paperTrip` — under the 4.5:1 that 15-point body text wants. It ships as `inkMuted` `#5E5A5A`, which
measures **5.43:1** on the same ground. Same handling as `fieldRing` and `trackDim`: where a sampled
value fails, the theme yields and the deviation is written down (`NFR-A11Y-03`).

**Three new cut-outs, two photographs and one stroke.** `sticker-1-21`, `sticker-3-07` (the key) and
`sticker-3-26` (the binoculars) join the eighteen, resampled to three times the size they are drawn
at, and `HisploraStickerTests` pins the count at twenty. `history-marker` is `949:2477`'s
highlighter stroke — 146 cubic segments in the export, so it ships as a 399 × 45 raster rather than
as a transcribed `Shape` the way `HisploraHighlightMark` does; a path nobody can check against the
drawing is worse than a PNG.

**The two photographs ship as JPEGs, and that is a bundle-size decision.** `discovery-gate`
(`949:2470`) and `discovery-grove` (`949:2471`) are rectangular photographs with no alpha: 2.8 MB
between them as PNG against 0.6 MB as JPEG at quality 82. `HisploraStickerArtwork.url(named:)` asks
for `png` then `jpg` so no caller has to know which a drawing is, and
`theDiscoveryPhotographsResolveThroughTheJPEGFallback` guards it.

> **Both photographs are pre-public blockers.** They are photographs of real places by somebody, and
> nothing in this repository records who or under what licence. They sit beside `history-king`,
> `history-plate` and `google-mark.png` on the same list, and beside `docs/consent-log.md`'s
> blockers, not instead of them. `SideQuestDiscoveryText`'s prose is the second half of the same
> problem: nine sentences about the Majapahit landing at Tuban with no citation and no `sources`
> entry, shipping on the same footing as `QuestHistoryText` and needing the same thing before
> anything public.

**The notification's copy is a teaser, and that is the board's split.** `670:1826` titles the short
look "Once upon a time…" over "This exact spot has a real history moment." — not the sidequest's own
title and synopsis, which is what the phone sent before. The synopsis now travels in
`userInfo["synopsis"]` so `670:1832`'s long look can still print it, and
`SideQuestNotificationController.synopsis(from:)` falls back to `content.body` for a notification
from a build that predates the split. `userInfo` still carries no coordinates (`FR-PROX-15`).

**`670:1832` reverses `s14` D1/D2 for the long look only.** Those decisions gave the notification
`91:176`'s radar disc and the watch app's own screen `91:182`'s gold frame, on the grounds that a
card you glanced at and a screen you navigated to are different places. The new board puts the gold
frame on the notification as well, so the radar is gone. The principle survives in that the two are
still two files with different grounds, different type and different closing lines — only the
frame's nine measured fractions are shared, in `OrnateFramedSlot`. **The painted portrait both
frames set into that frame is deliberately not packaged**: it is the same unsourced likeness
`history-king` is, and every sidequest still has `heroImageAsset == nil`, so the slot draws the flat
`#804A34` fill `FR-WATCH-06` asks for.

`670:1841`'s ornament is drawn rather than exported — four concentric rings of `#B44934` at 5%, the
stroke thinning outward, in `NotificationRingPattern`.

### What was seen

**The phone half was verified on iPhone 17 / iOS 26.5 on 2026-08-23**: the notification's teaser copy
in a real banner, the New Discovery card over the dimmed screen, and the whole Discovery page —
masthead, both photographs, the binoculars, the caption, the highlighter stroke under "Majapahit
Empire.", both cut-outs over the right margin, the justified paragraph, the procession over the dark
band with `Gajah Mada,` in gilt, and the "Save and Share" pill.

No screenshots are filed for it, and that is worth a sentence rather than a silent gap: `xcrun
simctl io <udid> screenshot` served **SpringBoard's home screen** on three consecutive captures
while the Discovery page was plainly on the panel — a second flavour of the stale-frame problem this
file already records against the Journal's turn. Capture it with a recording, or from the panel, not
with `simctl io`.

**The watch's long look was not.** It builds and runs, but a standalone watch simulator cannot
present it: the watch app never calls `requestAuthorization` — on a real paired watch the
notification is *forwarded from the iPhone*, which is the production path — so `simctl push` to the
watch delivers nothing to expand. Seeing `670:1832` needs a real paired watch, or an Xcode
notification-payload run destination, and neither has been done.

### The debug tool gained a second button

"Simulate passing a place" always forces the OS notification, which is what makes it useful for the
watch and for "is the notification pipeline alive at all" — and which means it can never reach the
New Discovery card, because that card only appears when the app is foregrounded. **"Simulate passing
a place (in-app card)"** raises `onSideQuestNearby` directly, which is what a region firing with the
app open does. Both are `#if DEBUG`, both skip `ProximityGate` for the reason `forceNotification`
already gave.
