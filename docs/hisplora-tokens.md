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
| `trackDim` | `#926954` | the unfilled segment of the onboarding bar, `523:2054`–`2056` — the frame's 25% `inkCream` over `brownMid`, flattened |
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

Twelve, all recorded rather than argued. Deviations 6–9 came from `452:3132`, `447:1880` and
`452:3028` on 2026-08-17; deviation 10 came from `452:2651` on 2026-08-18; 11 and 12 came from the
three onboarding frames on 2026-08-18.

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

11. **Onboarding is four screens, not the frames' three.** `523:1946`, `523:1973` and `523:1999`
    are Explore / Quest / Collection, and none of them explains that the phone goes in a pocket
    between checkpoints. `FR-ONB-03` is a P0 MUST and `AD-1` is the safety model of the product, so
    that screen survives the redesign; `FR-ONB-02` allows four, so nothing had to be traded for it.
    It is the second of the four — a walker who taps Skip on screen three has still been told — and
    it is the one screen whose picture is an SF Symbol in a ruled circle rather than an export,
    because inventing an illustration would make it read as a fourth Figma screen, which it is not.
    Two screens from the old onboarding were dropped with no requirement behind them: the
    accuracy-label screen (the labels are on every lore block, where `FR-CP-05` puts them) and the
    still-in-use screen (dress and photo rules are shown before any task, where `FR-TASK-05` puts
    them).

12. **The onboarding bar's segments are flexible, and it is a position indicator.** The frames draw
    three fixed 115-point segments; a fourth screen at that width runs off the row, so the segments
    are equal and flexible instead. What is *not* changed is which one is lit: `523:1985`–`1987` dim
    the first **and** third segment on screen two, so the bar marks position rather than filling as
    it goes, and it is reproduced that way. The unfilled segment's 25% cream over `brownMid` is
    flattened into `trackDim` rather than left as an alpha, because the suite measures token pairs
    and a translucency over "whatever is behind it" is not a pair anyone measured; against a filled
    segment it is 4.33:1. The row carries a spoken "Screen 2 of 4", so the count is never in the
    shape alone (`NFR-A11Y-05`).

## Assets shipped from the file

| Asset | Where | Note |
|---|---|---|
| `portrait-frame.png` | `DesignSystem/Resources/Images` | the gilded oval, laid over the picture |
| `typewriter.png` | `DesignSystem/Resources/Images` | the machine, cropped from the photograph at 47% height so the drawn sheet joins it |
| `quest-parchment.png` | `DesignSystem/Resources/Images` | `447:1886`, the sheet the task is printed on |
| `quest-scroll.png` | `DesignSystem/Resources/Images` | the rolled scroll — a list row's icon at 48, and the map hint's glyph at 32, tilted 41.6° |
| `onboarding-explore.png` | `DesignSystem/Resources/Images` | `670:1692`, the dancers — **1×, wants replacing, see below** |
| `onboarding-quest.png` | `DesignSystem/Resources/Images` | `670:1694`, three fanned task scrolls — **1×, wants replacing** |
| `onboarding-collection.png` | `DesignSystem/Resources/Images` | `670:1749`, five stamps under a wax seal — **1×, wants replacing** |
| `story-divider.png` | `DesignSystem/Resources/Images` | `447:1887`'s flourish, **converted to an alpha mask** — see below |
| `SpecialElite-Regular.ttf` | `DesignSystem/Resources/Fonts` | Apache 2.0, licence shipped beside it |

**The three onboarding pictures are 1× and want a hand export.** Same failure mode as the divider
below, in the other direction: `download_assets` at 3× composites the *frame's* fill behind the art,
and on these three frames that is a cream sheet — so each picture arrived opaque, sitting on a cream
card that does not exist in the design (`#FEF8F8` on `523:1946`, `#EEE7D2` on the other two, read out
of the corner pixel). The only transparent form the tool returns is a contents-only render, which it
will not upscale past the node's own size. So what ships is 378×277, 353×267 and 321×300 — exactly
the frames' boxes, shadows included, at 1×, and soft on a 3× screen. A 3× export made from Figma's
own export panel is a drop-in replacement: same three names, same three boxes, and the fractions in
`HisploraOnboardingArt` are in points and do not move.

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
| `523:1946` | Onboarding 1 — "Explore Beyond The Surface" |
| `523:1973` | Onboarding 2 — "History Becomes A Quest" |
| `523:1999` | Onboarding 3 — "Your Story, Your Collection" |
| `1:92` | Typography (template) |
| `1:632` | Colors (template) |

The SSE serialization fault that blocked four of these on 2026-08-13 has cleared for individual
frames; all eleven return `get_design_context` cleanly. It still breaks on the **board** — both
`get_design_context` and `get_metadata` on `13:128` fail with a truncated SSE frame, and
`get_metadata` on the page (`0:1`) omits the section entirely, listing only the two template
frames. So the board cannot be enumerated from the tool: query frames by the node ids in this
table, which is the reason the table exists.

## Seen rendering

**`452:3132`, `447:1880` and `452:3028` were verified on iPhone 17 / iOS 26.5 on 2026-08-17**,
walked in one pass from a fresh install: splash → onboarding (Skip) → login wireframe (Skip for
now) → quest card → story preview → safety notice → location rationale → permission → cutscene
intro (the scratch reveal needs real drag paths) → cutscene portrait → story reveal → place notice
→ **All Quest** → **the task sheet** → **the site plan**, pinched to zoom and closed back to the
sheet. Screenshots are in `docs/screenshots/m9-*.png`. The grey-bar divider bug above was found
on that pass and nowhere else — no test could have seen it.

**`452:2651` was verified on iPhone 17 / iOS 26.5 on 2026-08-18** — the filled plan, dragged to its
right edge and pinched to zoom, in `docs/screenshots/m10-site-map-full.png` and
`m10-site-map-zoomed.png`. It was reached with a temporary probe in `challange_5App.swift` rather
than by walking, and the probe was reverted: the story-reveal pill and the forward FAB do not
respond to the simulator MCP's synthesized taps reliably, which is the same class of problem the
"Simulate arrival anywhere" toggle has. `ArtworkViewportTests` is what holds the geometry; the
screenshots are what show it against the frame.

A resumed walk lands on `.atCheckpoint` and skips all three, so reaching them from a desk means a
fresh install (`xcrun simctl uninstall com.umar.hisplora`) rather than relaunching.

**`523:1946`, `523:1973` and `523:1999` were verified on iPhone 17 Pro / iOS 26.4 on 2026-08-18**,
from a fresh install, tapped through all four screens and out into the login wireframe.
Screenshots are in `docs/screenshots/m10-onboarding-1.png` … `-4.png`. Screen two of the four is the
pocket-the-phone screen, which is not in Figma — see below.

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
