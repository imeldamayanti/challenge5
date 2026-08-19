# S13 — Long-look card redesign: the "kiri" radar motif replaces the oval gold frame


> **SUPERSEDED — never executed (0/11 steps).** Replaced in full by
> `s14-watch-two-card-alignment.plan.md`, whose Phase 1 is this plan's Task 1 with corrected numbers.
>
> Two things it got wrong. Its Task 2 deletes `OrnateFrame.imageset` as unused; the gold frame was
> instead **moved** to the watch app's own screen (`s14` D2), so the asset is now shipped for the
> first time rather than retired. And its geometry is off: `slotDiameter: 128` is a fixed point value,
> about 70% of the content width on a 46 mm watch against the frame's 55%, and it plans a cream
> `Circle()` with a separate figure on top where the frame's centre is one `.circle.fill` glyph whose
> cream disc is part of the glyph.
>
> Its core call — that the long look is `91:176`'s radar, not the gold frame — was right and is what
> shipped.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SideQuestLongLookView`'s entire visual design — currently the oval gold-frame card
from Figma `91:182` ("kanan") — with the flat-cream, concentric-ring "radar" motif from Figma `91:176`
("kiri"), confirmed by the user against a fresh screenshot of that frame.

**Architecture:** One file rewritten (`SideQuestLongLookView.swift`), no interface change — same
`init(synopsis: String, heroImage: UIImage?)` `SideQuestNotificationController` (`s11`) and `ContentView`
(`s12`) already call. The oval/gold-frame chrome is replaced by a programmatic SwiftUI shape (concentric
circles + a center icon), consistent with `s10`'s existing precedent that the placeholder is drawn, not
an exported file. `OrnateFrame.imageset` becomes unused and is deleted.

**Tech Stack:** Swift 6, SwiftUI (watchOS 26.5 SDK). No new dependency.

**Spec:** This file. Supersedes the visual design half of `s10-long-look-card-design.md` (§"Layout") and
`s11-long-look-card.plan.md` (Task 1's view code) — both stay accurate about the *architecture*
(no `DesignSystem`/`ContentKit` linkage, `didReceive`/attachment-loading flow, `FR-WATCH-06` fallback
rule); only the card's rendered look changes. `s12-watch-open-in-app-handoff.plan.md`'s delegate/tap
wiring is untouched — it calls this view by the same signature.

## Context — why this isn't a `FR-WATCH-04` violation

`s8`'s Decision 3 and `s9` §2 both read Figma `91:176` as a literal instance of Apple's system
**Short Look** component, used there only as the source for the watch app icon's design (the
brown/cream concentric guide-ring look). `FR-WATCH-04` bans a *custom short-look interface* — that
constraint is about what renders before the wrist stays raised, and is untouched by this plan: no code
changes what the system shows at that stage.

What this plan does is different: take `91:176`'s **visual content** (the concentric rings, the center
icon, the flat cream ground, the body-text treatment) and use it as the design for the **long-look**
card instead — which `FR-WATCH-05` already permits to be fully custom ("MAY expand into a custom
long-look interface"). The oval gold-frame design (`91:182`, "kanan") that `s10`/`s11` built is
retired as the long-look's look; nothing about `FR-WATCH-05` required that specific frame, only *a*
custom long-look, and the user has now confirmed `91:176`'s motif is what should render there instead.

## Decision this plan preserves: `FR-WATCH-06` still governs the image slot

`FR-WATCH-06` requires the image slot show a real `heroImageAsset` photo when a sidequest has one, and
never render an unsourced likeness otherwise. The radar/rings graphic is the **placeholder** state of
that same slot — exactly the role the flat-black oval fill played in the old design — not a decorative
element bolted on separately. So `heroImage`'s existing behavior is preserved unchanged: when a
sidequest ships a real `heroImageAsset`, the circular slot shows that photo (clipped to the same circle
the rings otherwise occupy); when it doesn't (every sidequest today), the slot shows the concentric
rings + icon. This is a deliberate carry-over, not an oversight — flagging it here so a future reader
doesn't read the redesign as having quietly dropped `FR-WATCH-06`'s photo path.

## Open item: the exact center icon

The screenshot shows a standing figure with one arm raised inside the small center disk. The closest
SF Symbol available on watchOS is `figure.wave`. This plan uses that as the working choice — it has not
been checked against the Figma layer's own icon name/asset, because this session has no direct Figma
file access. **Task 1 below flags where to swap it** if inspecting the actual Figma layer (via Figma
MCP, if connected, or by asking the design owner) turns up a different glyph or a custom vector instead
of an SF Symbol match.

## Global Constraints

- No `DesignSystem`, no `ContentKit` — same constraint every prior watch-target plan (`s9`-`s12`) has
  held. `Color(hex:)` (already defined at the bottom of `SideQuestLongLookView.swift`) is the only
  color helper used.
- Reuse the existing brand hex values already established for this target — brown `0x804A34`, cream
  `0xFBF1E0` (`s9` §2's app-icon palette) — rather than sampling new ones from the screenshot. The oval
  design's separate tan/gold gradient stops (`0xE6CC9C`, `0xFBF3E4`) are retired along with the frame
  that used them.
- `init(synopsis: String, heroImage: UIImage?)` does not change — `SideQuestNotificationController`
  (`s11`) and `ContentView` (`s12`) both call it positionally/by-name today and need no edits.
- The placeholder graphic is drawn with SwiftUI shapes, not an exported image asset — same precedent
  `s10`'s Non-goals section already set ("No placeholder *image asset* — the placeholder is a
  programmatic SwiftUI shape, not a file").
- Build verification needs `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and, for
  `xcodebuild`, `PATH="$DEVELOPER_DIR/usr/bin:$PATH"` — see `CLAUDE.md`'s toolchain section. Run
  `xcrun simctl list devices available` before trusting any destination name below.
- **No automated test** — same reasoning `s11`/`s12` already recorded (no watch-target test bundle,
  `UIImage`/SwiftUI rendering needs a real runtime). Verification is the build commands plus Xcode's
  `#Preview` canvas; final visual acceptance is device-only, same as every other row in `s9` §7's table.

---

## Task 1: Rewrite `SideQuestLongLookView.swift`

**Files:**
- Modify: `challange-5/hisplora Watch App/SideQuestLongLookView.swift` (full replacement)

**Interfaces:**
- Unchanged: `struct SideQuestLongLookView: View`, memberwise `init(synopsis: String, heroImage:
  UIImage?)`. `SideQuestNotificationController.body` and `ContentView` (both existing) call this and
  need no edits.

- [ ] **Step 1: Replace the file's contents**

```swift
//
//  SideQuestLongLookView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `s13` — the custom long-look card a sidequest-nearby notification expands into, redesigned around
/// Figma `91:176` ("Example/Notifications kiri")'s radar motif: concentric rings around a standing-
/// figure icon on a flat cream ground, replacing `s10`/`s11`'s oval gold-frame design (`91:182`,
/// "kanan"). `91:176` was originally read (`s8`/`s9`) as a literal instance of Apple's system Short
/// Look component and used only as the watch app icon's design source — this view repurposes its
/// *visual content* for the long-look, which `FR-WATCH-05` already permits to be fully custom; it does
/// not reintroduce a custom short-look interface, which stays banned by `FR-WATCH-04`.
///
/// Takes already-resolved values, not a `UNNotification`, so it stays previewable and testable in
/// isolation from `SideQuestNotificationController` (see `s10-long-look-card-design.md`'s Architecture
/// section, unchanged by this redesign).
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    private let slotDiameter: CGFloat = 128
    private let outerRingDiameter: CGFloat = 92
    private let innerRingDiameter: CGFloat = 58
    private let centerDiskDiameter: CGFloat = 40

    var body: some View {
        VStack(spacing: 20) {
            imageSlot
                .padding(.top, 12)
            Text(synopsis)
                .font(.footnote)
                .foregroundStyle(Color(hex: 0x151311))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        // Flat cream ground, no gradient — `91:176`'s background, replacing the oval design's
        // tan-to-cream vertical gradient. The system-rendered "Open in App" action still supplies the
        // dark brown bar at the very bottom; this background does not try to paint that part.
        .background(Color(hex: 0xFBF1E0))
    }

    @ViewBuilder
    private var imageSlot: some View {
        ZStack {
            if let heroImage {
                // `FR-WATCH-06`'s photo path, unchanged by the redesign — a real `heroImageAsset`
                // still fills this slot, just clipped to the plain circle the radar graphic otherwise
                // occupies instead of the retired oval gold frame.
                Image(uiImage: heroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: slotDiameter, height: slotDiameter)
                    .clipShape(Circle())
            } else {
                // `FR-WATCH-06`'s placeholder path — the radar motif itself, never a photo or a
                // likeness. TODO(design): `figure.wave` is a working stand-in for the screenshot's
                // standing/raised-arm silhouette, not yet checked against the Figma layer's own icon —
                // swap here if that turns out to be a different glyph or a custom vector.
                Circle()
                    .fill(Color(hex: 0x804A34))
                    .frame(width: slotDiameter, height: slotDiameter)
                Circle()
                    .stroke(Color(hex: 0xFBF1E0).opacity(0.16), lineWidth: 1)
                    .frame(width: outerRingDiameter, height: outerRingDiameter)
                Circle()
                    .stroke(Color(hex: 0xFBF1E0).opacity(0.16), lineWidth: 1)
                    .frame(width: innerRingDiameter, height: innerRingDiameter)
                Circle()
                    .fill(Color(hex: 0xFBF1E0))
                    .frame(width: centerDiskDiameter, height: centerDiskDiameter)
                Image(systemName: "figure.wave")
                    .font(.system(size: centerDiskDiameter * 0.5))
                    .foregroundStyle(Color(hex: 0x804A34))
            }
        }
        .frame(width: slotDiameter, height: slotDiameter)
    }
}

extension Color {
    /// `0xRRGGBB`, opaque. A local equivalent of `DesignSystem`'s palette tokens — not a link to that
    /// package, which does not build for watchOS (see the design spec's Architecture section for why).
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview("Placeholder — no heroImageAsset") {
    SideQuestLongLookView(
        synopsis: "This exact spot has a real history moment.",
        heroImage: nil)
}

#Preview("With image") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: UIImage(systemName: "photo.fill"))
}
```

- [ ] **Step 2: Build the watch target to confirm it compiles**

```bash
xcrun simctl list devices available | grep -i watch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme "hisplora Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'
```

Expected: `** BUILD SUCCEEDED **`. Substitute the real destination name/OS from `simctl list` if it
differs.

- [ ] **Step 3: Visually verify both `#Preview`s in Xcode**

Open `SideQuestLongLookView.swift`'s canvas: "Placeholder — no heroImageAsset" shows the brown circle
with two faint concentric ring outlines, a cream center disk holding the `figure.wave` glyph, and the
sample body text below, all on a flat cream background — no gold frame, no oval clip, no gradient.
"With image" shows the sample `photo.fill` system image filling a plain circle instead of the radar
graphic.

- [ ] **Step 4: Commit**

```bash
git add "challange-5/hisplora Watch App/SideQuestLongLookView.swift"
git commit -m "feat(watch): redesign the long-look card around the radar motif (91:176)"
```

---

## Task 2: Remove the now-unused `OrnateFrame` asset

**Files:**
- Delete: `challange-5/hisplora Watch App/Assets.xcassets/OrnateFrame.imageset/` (both `Contents.json`
  and `OrnateFrame.png`)

- [ ] **Step 1: Confirm nothing else references it**

```bash
grep -rln "OrnateFrame" "challange-5"
```

Expected after Task 1's edit: no matches (the only prior references were the view file just rewritten
and the asset folder's own `Contents.json`).

- [ ] **Step 2: Delete the imageset**

```bash
git rm -r "challange-5/hisplora Watch App/Assets.xcassets/OrnateFrame.imageset"
```

- [ ] **Step 3: Build the watch target again to confirm no missing-asset warning regressions**

Same command as Task 1 Step 2. Expected: `** BUILD SUCCEEDED **`, no "unassigned children"/missing-
asset warnings referencing `OrnateFrame`.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(watch): drop the unused OrnateFrame asset after the radar redesign"
```

---

## Task 3: Correct `s10`/`s11`'s design references

**Files:**
- Modify: `.claude/plans/sidequest/s10-long-look-card-design.md`
- Modify: `.claude/plans/sidequest/s11-long-look-card.plan.md`

- [ ] **Step 1: Add a superseded note to `s10`'s Layout section (§"Layout (Figma `91:182`)")**

Add a line above that section stating the card's visual design is superseded by `s13`'s `91:176` radar
motif as of this plan's execution date — `s10`'s Architecture/data-flow sections (no `DesignSystem`
linkage, attachment-loading flow, `FR-WATCH-06` fallback rule) remain accurate and unchanged.

- [ ] **Step 2: Add the same note to `s11`'s Task 1 header**

A one-line pointer at the top of `s11-long-look-card.plan.md`'s "Task 1: `SideQuestLongLookView` —
the card's SwiftUI content" section: the view code originally landed here was replaced by `s13`; the
file/task structure and build-verification steps stayed the template `s13` followed.

- [ ] **Step 3: Commit**

```bash
git add .claude/plans/sidequest/s10-long-look-card-design.md \
        .claude/plans/sidequest/s11-long-look-card.plan.md
git commit -m "docs(sidequest): point s10/s11 at s13's radar redesign of the long-look card"
```

---

## Device verification (not part of these tasks — human-only)

Same constraint every prior watch-target plan in this series has recorded: no simulator or automated
test renders a real Notification Scene. Once Tasks 1-3 are committed, the outstanding check is `s9` §7's
"Long-look renders the card" row, re-run against the new design: hold the wrist up past short-look on a
real device and confirm the radar graphic, body text, and "Open in App" pill all render as intended —
plus, separately, `s12`'s device check (tapping "Open in App" opens this same card inside the watch app,
not the iPhone).
