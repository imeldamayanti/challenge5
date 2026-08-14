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

**Three assets in the file were deliberately not shipped.** They are not oversights:

- **The Google Maps screenshots** on `89:1402` and `223:2004`, and the traced street map derived
  from them. They are a third party's map imagery under that party's terms, and `FR-MAP-01`
  already rules out live tiles; `RunRouteMapView` draws the authored route instead. A shipped
  static route image per quest (`route.previewImageAsset`) is the supported way to show a map here.
- **The Apple system icons** in the permission-dialog mock. iOS draws that dialog itself.
- **The AI-generated portrait** of I Gusti Ngurah Made Agung — see below.

## What the frames draw that the code does not, and why

These are requirement conflicts, not omissions.

- **"Navigate There"** (`223:2004`) hands off to an external maps app. Not built: it leaves the app
  during the one flow that has to work in airplane mode (`AD-3`), it routes along roads rather than
  the authored walking route, and it makes the clue pointless. The plan's recommendation — allow it
  at the start checkpoint only — is still open.
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
time the cutscene screens had been seen at all. The run reaches them from a desk by setting the
simulator's location to the first checkpoint rather than by the debug toggle:

```bash
xcrun simctl location <udid> set -8.657,115.2085
```

That is `contoh-puri-gerbang-utara`, the start checkpoint of `contoh-jejak-kota-lama`. The arrival
rule is unmodified — the radius and accuracy gate in `ArrivalEvaluator` runs on the reported fix, so
what is exercised is the walker's own code path.
