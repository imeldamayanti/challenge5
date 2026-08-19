# S14 — Two cards, not one: radar for the notification, gold frame for the app

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the watch target's two surfaces in line with the two Figma frames the user has now
assigned to them — the notification long-look renders `91:176`'s radar motif, the watch app's own
screen renders `91:182`'s gold-frame card — and make the notification tap that reaches that screen
actually work, which it does not today.

**Architecture:** `SideQuestLongLookView` is rewritten as the radar card and stays the
`WKNotificationScene`'s content. A **new** `SideQuestWatchCardView` carries the gold-frame design and
is what `ContentView` shows after a tap. The two are deliberately different views with no shared
chrome — only the `(synopsis, heroImage)` pair they both take. `s12`'s delegate wiring lands
unchanged in substance, retargeted at the new view. No new package dependency; the watch target still
links neither `DesignSystem` nor `ContentKit`.

**Tech Stack:** Swift 6, SwiftUI, `UserNotifications`/`WatchKit`, `os.Logger` (watchOS deployment
target is **26.5**, so no API in this plan is gated by availability).

**Spec:** This file. **Supersedes `s12-watch-open-in-app-handoff.plan.md` and
`s13-long-look-radar-redesign.plan.md` in full** — neither was ever executed (0/15 and 0/11 steps),
and both rest on an assumption the user has now overturned: that the notification card and the in-app
card should look identical. They do not. `s12`'s Tasks 1–3 survive here as Phase 3 with one
retargeting; `s13`'s Task 1 survives as Phase 1 with corrected numbers; `s13`'s Task 2 (delete the
`OrnateFrame` asset) is **cancelled** — the gold frame moves to the app screen rather than being
retired.

---

## Context — the verified state of this branch

Everything in this section was read out of the working tree on 2026-08-19, not carried over from an
earlier plan's claims.

### The gold frame never rendered because its asset does not exist

`challange-5/hisplora Watch App/Assets.xcassets/OrnateFrame.imageset/` contains **only**
`Contents.json`. `OrnateFrame.png` is not on disk, is not in the repository, and
`git log --all -- '*OrnateFrame*'` returns nothing — it was never committed. The imageset is an empty
shell pointing at a filename that has never existed.

This matters beyond the missing picture. `SideQuestLongLookView.swift`'s current doc comment states
the PNG "is 447×558", that inspecting it "confirmed it is *only* the decorative gold border with a
fully transparent oval cutout", and that `holeWidthFraction: 0.6465` / `holeHeightFraction: 0.6846`
were "measured by scanning `OrnateFrame.png`'s alpha channel outward from center, not eyeballed off
the screenshot." **None of that measurement can have happened.** The real figures, read from the
Figma file in this session, are in Phase 2 below and differ materially.

### `s12` was never implemented, and one of its fixes was actively reverted

- `SideQuestWatchNotificationDelegate.swift` does not exist.
- `ContentView` still takes no parameters; `hisploraApp` holds no `@State` and never assigns
  `UNUserNotificationCenter.current().delegate`.
- `HEAD` had `options: [.foreground]` on the watch's "Open in App" action. The working tree changed it
  **back** to `options: []`, re-adding a comment asserting the tap will "relay back to the phone's own
  registration" — the exact belief `s12` proved false. This plan re-applies the fix.

### An undocumented behaviour change is riding along with debug scaffolding

`SideQuestProximityService.swift` in the working tree adds ~10 `print()` calls (a live debugging
session) and, mixed into the same diff, one real change:

```diff
-                title: place.nameOfficial.value(for: language),
+                title: sideQuest.title.value(for: language),
```

The notification's title moved from the place's official name to the sidequest's own title. The
accompanying comment cites "`s9`'s notification-copy revision", which is not a decision recorded in
`s9` or anywhere else in this series. The change looks right; it needs to be committed as itself.

---

## Decisions taken (user, 2026-08-19)

1. **The long-look notification card uses `91:176`'s radar motif.** Confirmed twice now — once when
   `s13` was written, once in this session against both frames side by side.
2. **The watch app's own screen uses `91:182`'s gold-frame design.** This reverses `s12`'s stated
   intent ("so the notification and the in-app card look identical"). The two surfaces are different
   places and get different designs.
3. **`91:182`'s bottom bar is not built as a bar.** The frame draws a filled dark-brown ground pinned
   to the bottom edge with centred text — which on watchOS is the platform's own signature for the
   primary action button. Anything wearing that shape will be tapped, whatever it says, and nothing
   here can be tapped. The ground, the edge-pinning and the centring are all dropped; what remains is
   a plain caption line with an iPhone glyph. Recorded as a deliberate deviation, not an oversight.
4. **The caption reads "The full story is on your iPhone".** Not `91:182`'s literal "Open in Iphone
   App": an imperative verb reads as an instruction to act *here*, and there is nothing to act on. A
   statement of where the thing is makes no promise the screen cannot keep. English, matching every
   other static string already in this target.
5. **`print()` becomes `os.Logger`.** The bug under investigation is "the notification does not reach
   the watch during a real walk", and `print()` is visible only while attached to Xcode's debugger —
   it goes silent in exactly the situation being debugged.

## Decisions this plan does NOT take

- **`FR-WATCH-07` stays open.** "Open in App... MUST hand off to the iPhone app... MUST NOT open a
  screen inside the watch companion itself" is not satisfiable as written for a notification the watch
  renders its own long-look for; `s12` established this and nothing here changes it. It needs a named
  owner, the way `FR-START-04a` got one. Carried into Phase 4, not resolved.
- **Whether `NSUserActivity` Handoff could make the caption into a real action.** Raised in discussion
  and deliberately left unbuilt: the user chose a non-interactive caption. If `FR-WATCH-07` is ever
  answered with "make it work", Handoff from a running watch app is the API to investigate first —
  it is a different mechanism from the notification-tap path `s12` ruled out, and it was never tried.

---

## Global Constraints

- No `DesignSystem`, no `ContentKit`, no network from the watch target — the constraint every plan in
  this series (`s9`–`s13`) has held. `Color(hex:)` at the bottom of `SideQuestLongLookView.swift` stays
  the only colour helper; the new view imports it from the same target.
- `SideQuestLongLookView.init(synopsis:heroImage:)` does not change shape.
  `SideQuestNotificationController.body` needs no edit.
- Sizes are expressed as **fractions of the container**, via `containerRelativeFrame`, not as fixed
  points. `s13` specified `slotDiameter: 128`, which is ~70% of the content width on a 46 mm watch
  against Figma's 55%. Case widths differ across the supported watch sizes, so a fixed point value is
  right on at most one of them.
- Every number in Phases 1 and 2 comes from the Figma file read in this session — node metadata for
  layer geometry, pixel sampling of the rendered frame for colour. Where the two disagree, metadata
  wins. **Do not carry forward any figure from `s10`/`s11`/`s13`.**
- Build verification needs `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and, for
  `xcodebuild`, `PATH="$DEVELOPER_DIR/usr/bin:$PATH"` — see `CLAUDE.md`. Run
  `xcrun simctl list devices available` before trusting any destination name below.
- **No automated test, and this plan does not invent one.** Same reasoning `s11`–`s13` recorded: the
  watch target has no test bundle, and `UIImage` decoding plus SwiftUI rendering need a real runtime.
  Verification is the build commands plus Xcode's `#Preview` canvas; acceptance of tap behaviour and
  of the rendered long-look is device-only.

---

## Phase 0 — clear the working tree

### Task 0.1: Replace `print()` with `os.Logger`

**Files:**
- Modify: `challange-5/challange-5/Service/SideQuestProximityService.swift`
- Modify: `challange-5/hisplora Watch App/SideQuestNotificationController.swift`

- [x] **Step 1: Add a logger to each file**

```swift
import os

private let log = Logger(subsystem: "com.umar.hisplora", category: "proximity")   // phone
private let log = Logger(subsystem: "com.umar.hisplora", category: "watch-notif") // watch
```

- [x] **Step 2: Convert every `#if DEBUG print(...) #endif` block**

Drop the `#if DEBUG` wrapper — `Logger` is meant to ship, and `.debug` level is not persisted unless
someone asks for it. Mark interpolated values explicitly: sidequest IDs and authorization states are
`privacy: .public` (they are content IDs and enum cases, not personal data); nothing here interpolates
a location, and nothing may start.

```swift
log.debug("posting OS notification for \(identifier, privacy: .public)")
log.error("add(request) failed for \(sideQuestID, privacy: .public): \(error.localizedDescription, privacy: .public)")
```

Use `.error` for the two genuine failure paths (`add(request)` failing, authorization denied) and
`.debug` for the flow tracing.

- [x] **Step 3: Build the app scheme**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

- [x] **Step 4: Commit**

```bash
git commit -m "chore: trace sidequest proximity through os.Logger instead of print"
```

### Task 0.2: Commit the notification-title change on its own

**Files:**
- Modify: `challange-5/challange-5/Service/SideQuestProximityService.swift` (comment only)

- [x] **Step 1: Correct the comment's false citation**

The current comment credits "`s9`'s notification-copy revision". No such decision exists in `s9` or
anywhere else in this series. Replace it with the actual reasoning: the notification announces a
sidequest, so the sidequest's own title is the honest headline; the place name is already the
notification's subject matter and repeating it as the title told the walker nothing new.

- [x] **Step 2: Commit separately from Task 0.1**

```bash
git commit -m "feat: title sidequest notifications with the sidequest, not the place"
```

---

## Phase 1 — the notification card: `91:176`'s radar

### Task 1.1: Rewrite `SideQuestLongLookView`

**Files:**
- Modify: `challange-5/hisplora Watch App/SideQuestLongLookView.swift` (full replacement)

**Interfaces:**
- Unchanged: `struct SideQuestLongLookView: View`, `init(synopsis: String, heroImage: UIImage?)`.

**Measured from Figma `91:176` (frame 205×251):**

| Element | Value | Source |
|---|---|---|
| Ground | `#FCF5E8` flat | pixel sample, top and bottom differ by 3 units — not worth a gradient |
| Brown disc | `#804A34`, **55%** of card width | pixel sample; Ø112.6 of 205 |
| Disc centre | 39.6% from the top | metadata: icon frame centre y=99.5 of 251 |
| Centre symbol | em box **31%** of the disc diameter | metadata: 35 of 112.6 |
| Visible cream circle | 24% of the disc diameter | pixel sample — smaller than the em box, as expected |

- [x] **Step 1: Resolve the centre symbol's name — do not guess**

The metadata shows the icon is a **text node whose content is `U+F077D`** — an SF Symbol rendered as a
character, inside `Frame 427319259` at (85, 82), 35×35, horizontally centred (102.5 = 205/2).

Two facts follow. First, the visible cream circle is *part of the glyph*: the pixel sample shows a
cream disc with the figure knocked out in brown, which is how a `.circle.fill` variant composites over
a coloured ground. So this is **one `Image(systemName:)` tinted `#FCF5E8`**, not `s13`'s stack of a
cream `Circle()` plus a separate figure. Second, the name still has to be established.

`U+F077D` could not be resolved offline in this session — it is absent from
`/Applications/SF Symbols.app/Contents/Resources/Fonts/SFSymbolsFallback.otf` and from every
`/System/Library/Fonts/SFNS*.ttf` cmap, because SF Symbols glyphs live in CoreGlyphs' `Assets.car`
rather than in a font table. Resolve it by one of:

- `get_design_context` on node `91:180` (the text node itself) — Figma may report the symbol name; or
- SF Symbols.app → paste the glyph into search, or browse `figure.*` `.circle.fill` variants.

The visual read is a standing figure with one arm raised, so `figure.wave.circle.fill` is the leading
candidate — **but it is a candidate, not the answer.** Writing a guess into the file is precisely the
mistake that produced `holeWidthFraction`'s fictional measurement; do not repeat it.

- [x] **Step 2: Replace the file's contents**

Structure — the `Short Look` component instance's concentric rings and crosshair are visible in the
render but are not exposed as nodes (they live inside an Apple system component instance), so they are
drawn from the render, at low contrast, as secondary detail. Get the disc, the symbol and the ground
right first; the rings are subordinate.

```swift
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            imageSlot
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.55 }
            Text(synopsis)
                .font(.footnote)
                .multilineTextAlignment(.center)
                // No lineLimit: watchOS inherits the paired iPhone's text size and real users sit at
                // accessibility sizes. A limit here truncates the only content this card carries.
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0xFCF5E8))
    }
}
```

- [x] **Step 3: Preserve `FR-WATCH-06`'s photo path**

A sidequest that ships a real `heroImageAsset` fills the disc with that photo, clipped to the same
circle; every sidequest today has none and gets the radar graphic. This is the same slot in two
states, not a graphic bolted next to a photo slot — carried over unchanged from `s13`, which had it
right.

- [x] **Step 4: Label the graphic for VoiceOver**

The image slot currently carries no accessibility label at all, so VoiceOver reads the **asset name**.
Give the photo state a label naming what it shows and mark the radar placeholder
`.accessibilityHidden(true)` — it is decoration standing in for an absent picture, and announcing it
tells a VoiceOver user nothing. The synopsis text is the card's real content and already reads.

- [x] **Step 5: Build the watch target**

```bash
xcrun simctl list devices available | grep -i watch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme "hisplora Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'
```

- [x] **Step 6: Verify both `#Preview`s, then commit**

```bash
git commit -m "feat(watch): render the long-look card as 91:176's radar motif"
```

---

## Phase 2 — the app card: `91:182`'s gold frame

### Task 2.1: Export `OrnateFrame.png` into the empty imageset

**Files:**
- Create: `challange-5/hisplora Watch App/Assets.xcassets/OrnateFrame.imageset/OrnateFrame.png`

- [x] **Step 1: Export node `91:186` from Figma**

`ChatGPT Image Aug 13, 2026 at 09_35_01 AM 1`, 99×116 in frame units. Export at @2x and @3x if the
tooling offers it; the existing `Contents.json` declares a single `1x` entry and will need updating to
match whatever is produced.

- [x] **Step 2: Confirm what the exported PNG actually contains**

Open it and check the alpha channel — the claim this plan inherited (border only, transparent oval
cutout, no portrait baked in) has **never been verified against a real file**. If the export turns out
to carry a face or a figure, stop: that is an unsourced likeness and `FR-WATCH-06` blocks it, and the
gold-frame screen needs a different treatment. Record what you find either way.

- [x] **Step 3: Update `Contents.json` for the scales actually exported, then commit**

```bash
git add "challange-5/hisplora Watch App/Assets.xcassets/OrnateFrame.imageset"
git commit -m "chore(watch): add the OrnateFrame asset the imageset has always pointed at"
```

### Task 2.2: Write `SideQuestWatchCardView`

**Files:**
- Create: `challange-5/hisplora Watch App/SideQuestWatchCardView.swift`

**Interfaces:**
- Produces: `struct SideQuestWatchCardView: View`, `init(synopsis: String, heroImage: UIImage?)` —
  deliberately the same shape as `SideQuestLongLookView` so `ContentView` can swap between them, but
  a separate type with no shared chrome.

**Measured from Figma `91:182` (frame 205×251):**

| Element | Value | Source |
|---|---|---|
| Ground | `#D0B28D` top → `#FCF2DE` bottom | pixel sample down the centre column |
| Gold frame | **48.3%** of card width, aspect **99/116 = 0.853** | metadata: `Group 103`, 99×116 at (53, 24) |
| Oval slot | **0.724 × 0.788** of the frame | metadata: `image 22`, 71.69×91.45 |
| Slot centre | (0.519, 0.509) of the frame | metadata: offset (15.5, 13.275) + half the slot |
| Frame top inset | 9.6% of card height | metadata: y=24 of 251 |

Note the current code's figures for comparison, all of which are wrong: aspect `447/558 = 0.801`,
hole `0.6465 × 0.6846`, and a gradient running cream→brown, i.e. **inverted** as well as
mis-sampled at both stops.

- [x] **Step 1: Write the view**

Same two-state image slot as Phase 1 — a real `heroImage` fills the oval, otherwise the flat
`#804A34` placeholder — with `Image("OrnateFrame")` composited on top. Size everything through
`containerRelativeFrame` off the 48.3% figure, so the hole fractions stay correct at any watch size.

- [x] **Step 2: Add the caption line (Decisions 3 and 4)**

Below the synopsis:

```swift
HStack(spacing: 4) {
    Image(systemName: "iphone")
    Text("The full story is on your iPhone")
}
.font(.footnote)
.foregroundStyle(.secondary)
```

Explicitly **not**: a `Button`, a `.background`, a capsule, a `.disabled(true)` control, or anything
pinned to the bottom edge. A disabled button would still be announced as "dimmed button", which is
worse than plain text; a plain `Text` is skipped by the AssistiveTouch cursor automatically, which is
exactly the intent. Write the reasoning into the file — the next reader will otherwise "fix" it back
towards the Figma frame.

- [x] **Step 3: Build the watch target** (same command as Task 1.1 Step 5)

- [x] **Step 4: Verify both `#Preview`s, then commit**

```bash
git commit -m "feat(watch): add the gold-frame card for the watch app's own screen"
```

---

## Phase 3 — make the tap arrive (`s12` Tasks 1–3)

### Task 3.1: Fix the local category registration

**Files:**
- Modify: `challange-5/hisplora Watch App/hisploraApp.swift`

- [x] **Step 1: Restore `options: [.foreground]` and replace the comment**

The comment currently in the working tree asserts a relay to the phone's registration that does not
exist. `UNNotificationAction` options are evaluated by whichever device handles the tap, and once this
target's `WKNotificationScene` claims `"sidequest-nearby"`, the watch handles every tap on it — the
phone's registration never gets a say. Say that, and point at this plan.

- [x] **Step 2: Commit**

```bash
git commit -m "fix(watch): open-in-app foregrounds the watch, not a nonexistent iPhone relay"
```

### Task 3.2: Add the tap delegate

**Files:**
- Modify: `challange-5/hisplora Watch App/SideQuestNotificationController.swift`
- Create: `challange-5/hisplora Watch App/SideQuestWatchNotificationDelegate.swift`

- [ ] **Step 1: Widen `loadHeroImage` from `private` to internal**

So the delegate reuses the security-scoped attachment read rather than duplicating it. Note in the
doc comment why it is not `private` any more.

- [ ] **Step 2: Write the delegate**

`SideQuestWatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate` with
`var onTap: (@MainActor (OpenedSideQuestCard) -> Void)?`, resolving
`content.userInfo["sideQuestID"]`, `content.body` and `content.attachments` in
`didReceive response:` — the same three keys the phone's own delegate already reads. Plus
`willPresent` returning `[.banner, .sound]`, mirroring the phone: a local notification can fire while
the watch app is already foregrounded.

`struct OpenedSideQuestCard { let sideQuestID: String; let synopsis: String; let heroImage: UIImage? }`
goes in the same file.

- [ ] **Step 3: Build the watch target, then commit**

```bash
git commit -m "feat(watch): resolve the tapped sidequest from the notification response"
```

### Task 3.3: Wire it up and render the gold-frame card

**Files:**
- Modify: `challange-5/hisplora Watch App/hisploraApp.swift`
- Modify: `challange-5/hisplora Watch App/ContentView.swift`

- [ ] **Step 1: Hold the delegate in `@State`**

`UNUserNotificationCenter.current().delegate` is `weak`; anything not retained is silently dropped.
The phone target already documents this pattern in `challange_5App.swift` — follow it exactly:
`@State private var notificationDelegate = ...`, assigned inside `.onAppear`, alongside
`@State private var openedCard: OpenedSideQuestCard?`.

- [ ] **Step 2: `ContentView` renders `SideQuestWatchCardView`, not `SideQuestLongLookView`**

**This is the one place this plan diverges from `s12`'s text**, which reused the long-look view here
so the two surfaces would match. Decision 2 reverses that. The `nil` branch keeps the existing
placeholder, with its copy updated from "The watch experience isn't built yet" to something that
tells the walker what to do — the screen is no longer unbuilt.

- [ ] **Step 3: Build both schemes**

The app scheme build is what proves the watch target links cleanly as an embedded dependency rather
than only standalone.

- [ ] **Step 4: Verify all four `#Preview`s, then commit**

```bash
git commit -m "feat(watch): open the tapped sidequest's card instead of the placeholder"
```

---

## Phase 4 — reconcile the plan record

### Task 4.1: Mark what this plan supersedes

- [ ] `s12-watch-open-in-app-handoff.plan.md` and `s13-long-look-radar-redesign.plan.md`: a header note
  stating neither was executed and both are superseded by this file, with the reason (the two-card
  split). Their findings stay valuable — `s12`'s hand-off analysis in particular is the reason
  `FR-WATCH-07` is known to be unsatisfiable — so neither file is deleted.
- [ ] `s10-long-look-card-design.md`: its `FR-WATCH-07` Status claim is false and its Layout section is
  superseded. Its Architecture section stays accurate.
- [ ] `s11-long-look-card.plan.md`: Task 1's view code was replaced; the file/task structure stands.
- [ ] `s9-watch-notification-scene.plan.md`: an execution note recording what actually shipped.

### Task 4.2: Record three debts that have no owner yet

- [ ] **`FR-WATCH-07` is unresolved.** Needs a named owner to either amend the requirement to describe
  what was built, or accept dropping the custom long-look so system mirroring can wake the iPhone —
  at the cost of `FR-WATCH-05`. `NSUserActivity` Handoff is an untried third option.
- [ ] **The watch target has no i18n path.** Every static string in it is a hardcoded English literal:
  "Open in App", "The full story is on your iPhone", the placeholder copy. The synopsis is localised
  because the phone resolved it before posting. `NFR-I18N-01` is not violated by any guard's
  reckoning — no guard scans this target — but it is violated in substance, and adding a second
  language means solving it.
- [ ] **`OrnateFrame.png` is a generative asset** (`ChatGPT Image Aug 13, 2026...`). Ornamental, no
  likeness — assuming Task 2.1 Step 2 confirms that against the real file. Recorded so that
  `docs/hisplora-tokens.md`'s ledger of what was and was not built from generated frames stays honest.

- [ ] **Commit**

```bash
git commit -m "docs(sidequest): record s14's two-card split and what it supersedes"
```

---

## Device verification (human-only, not part of the tasks)

No simulator and no automated test renders a real Notification Scene interaction — the constraint every
plan in this series has recorded. Once all phases are committed:

1. Trigger a dev-test region entry.
2. Raise the wrist past the short look → the long look shows **the radar card** (`91:176`): cream
   ground, brown disc, centre symbol, synopsis. No gold frame anywhere.
3. Tap "Open in App" → the watch app foregrounds into **the gold-frame card** (`91:182`) for that same
   sidequest — gold frame, oval, tan-to-cream gradient, and the caption line "The full story is on your
   iPhone" as plain text with no button chrome. Not the placeholder, and not the iPhone.
4. Confirm nobody in the room tries to tap the caption. If they do, Decision 3 did not go far enough.
