# S11 — Long-look card implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a branded long-look card on the paired Apple Watch when a sidequest-nearby
notification's short-look is held past its first glance — the custom `WKNotificationScene` Phase A's
plumbing (category, action, icon) was built to support.

**Architecture:** Two new files in the `hisplora Watch App` target: a plain SwiftUI view
(`SideQuestLongLookView`) that renders a circular image slot (real image or flat-palette placeholder)
plus the sidequest's synopsis, and a `WKUserNotificationHostingController` subclass
(`SideQuestNotificationController`) that resolves a `UNNotification`'s content into that view's inputs
and is registered via one `WKNotificationScene` in `hisploraApp.swift`. No new package dependency, no
`ContentKit`/network access from the watch target — every value the card needs was already resolved
and attached by the phone in Phase A before the notification is ever mirrored to the watch.

**Tech Stack:** Swift 6, SwiftUI, `WatchKit`/`UserNotifications` (watchOS 26.5 SDK), watchOS's reduced
`UIKit` compatibility module (`UIImage` only — no view/controller classes).

**Spec:** `.claude/plans/sidequest/s10-long-look-card-design.md` — read it before
starting; it explains *why* each constraint below holds, this plan only states *what* to build.

## Global Constraints

- No `DesignSystem` package linkage. Brand colors are hardcoded: brown `#804a34`, cream `#fbf1e0` —
  same two hex values already used for the watch app icon (Phase A).
- No `ContentKit`, no `RunEngine`, no network access anywhere in these two files. Everything renders
  from the `UNNotification` the system hands the controller.
- Reuse the existing category identifier — `WatchSideQuestNotificationCategory.identifier` (defined in
  `hisplora Watch App/hisploraApp.swift`, value `"sidequest-nearby"`) — never a new string literal.
- `WKUserNotificationHostingController.isInteractive` stays at its default (`false`). No SwiftUI
  controls inside the scene; "Open in App" remains the system `UNNotificationAction` Phase A already
  wired.
- Do not use `AsyncImage` for the attachment image. `UNNotificationAttachment.url` is a
  security-scoped URL; read it with `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()` around a synchronous `Data(contentsOf:)`, inside
  `didReceive(_:)`, once — not on every `body` access.
- Any failure anywhere in the image-loading path (no attachment, scope access fails, read fails,
  corrupt data) must fall through to the flat-palette placeholder. Never crash, never an empty slot.
- Both new files go in `hisplora Watch App/` (a `PBXFileSystemSynchronizedRootGroup` — creating a file
  there needs no `project.pbxproj` edit). `hisploraApp.swift` is the one existing file this plan
  modifies.
- Build verification commands need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, and
  `xcodebuild` additionally needs `PATH="$DEVELOPER_DIR/usr/bin:$PATH"` for `simctl` to resolve
  correctly — see `CLAUDE.md`'s toolchain section. Run `xcrun simctl list devices available` before
  trusting any destination name below; simulator availability is per-machine and CLAUDE.md warns
  against guessing.
- **No automated test exists for this feature, and this plan does not invent one.** There is no watch-
  target unit-test bundle in this repo (`challange-5Tests` covers the phone app target only), and the
  one piece of logic that would be worth a unit test — `loadHeroImage`'s security-scoped read and its
  fallback — depends on `UIImage`, which requires a real iOS/watchOS/tvOS runtime to decode image data
  and cannot run as a plain `swift test`/command-line check. Verification is: (a) the build commands
  in each task, which catch every compile-time mistake, and (b) Xcode's `#Preview` canvas, which
  exercises the view's actual rendering — including a real `UIImage` decode via
  `UIImage(systemName:)` — inside a real simulator process, not a mock. Final acceptance is still
  device-only, per `s9` §7's existing table; that check is out of this plan's reach and is called out
  at the end.

---

## Task 1: `SideQuestLongLookView` — the card's SwiftUI content

**Files:**
- Create: `challange-5/hisplora Watch App/SideQuestLongLookView.swift`

**Interfaces:**
- Produces: `struct SideQuestLongLookView: View`, memberwise `init(synopsis: String, heroImage:
  UIImage?)` (the struct's own synthesized initializer — declare the two stored properties in that
  exact order so the synthesized init matches what Task 2 calls).
- Produces: `extension Color { init(hex: UInt32) }` — `0xRRGGBB`, alpha always 1. Available to any file
  in this target; Task 2 does not need it, but it is not marked `private` in case a later revision does.

- [ ] **Step 1: Write `SideQuestLongLookView.swift`**

```swift
//
//  SideQuestLongLookView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `s9` Phase B, `FR-WATCH-05` — the custom long-look card a sidequest-nearby notification expands
/// into. Takes already-resolved values, not a `UNNotification`, so it stays previewable and testable
/// in isolation from `SideQuestNotificationController` (see
/// `.claude/plans/sidequest/s10-long-look-card-design.md`).
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    private let imageSlotSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            imageSlot
            Text(synopsis)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var imageSlot: some View {
        if let heroImage {
            Image(uiImage: heroImage)
                .resizable()
                .scaledToFill()
                .frame(width: imageSlotSize, height: imageSlotSize)
                .clipShape(Circle())
        } else {
            // `FR-WATCH-06` — a flat brand-palette fill, never a photo or a likeness. This is the
            // state every sidequest renders today (none carry `heroImageAsset` yet), and it is also
            // the fallback for any attachment-loading failure (see `loadHeroImage` in
            // `SideQuestNotificationController.swift`).
            Circle()
                .fill(Color(hex: 0x804A34))
                .frame(width: imageSlotSize, height: imageSlotSize)
        }
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
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: nil)
}

#Preview("With image") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: UIImage(systemName: "photo.fill"))
}
```

- [ ] **Step 2: Build the watch target to confirm it compiles**

Run (from `challange-5/`; check available destinations first — do not trust the name below blindly):

```bash
xcrun simctl list devices available | grep -i watch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme "hisplora Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'
```

Expected: `** BUILD SUCCEEDED **`. If the destination from `simctl list` differs, substitute the real
name/OS before concluding the build itself is broken.

- [ ] **Step 3: Visually verify both `#Preview`s in Xcode**

Open `hisplora Watch App/SideQuestLongLookView.swift` in Xcode, open the canvas (Editor → Canvas), and
confirm both previews render: "Placeholder — no heroImageAsset" shows a solid brown (`#804a34`) circle
above the synopsis text; "With image" shows a system `photo.fill` glyph inside the circle instead. This
is the only check available for the view's actual rendering before a physical device — do not skip it.

- [ ] **Step 4: Commit**

```bash
git add "challange-5/hisplora Watch App/SideQuestLongLookView.swift"
git commit -m "feat(watch): add the long-look card's SwiftUI view (FR-WATCH-05)"
```

---

## Task 2: `SideQuestNotificationController` + scene registration

**Files:**
- Create: `challange-5/hisplora Watch App/SideQuestNotificationController.swift`
- Modify: `challange-5/hisplora Watch App/hisploraApp.swift`

**Interfaces:**
- Consumes: `SideQuestLongLookView(synopsis: String, heroImage: UIImage?)` from Task 1.
- Consumes: `WatchSideQuestNotificationCategory.identifier` (existing, `hisploraApp.swift`, value
  `"sidequest-nearby"`).
- Produces: `final class SideQuestNotificationController: WKUserNotificationHostingController<SideQuestLongLookView>`.

- [ ] **Step 1: Write `SideQuestNotificationController.swift`**

```swift
//
//  SideQuestNotificationController.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit
import UserNotifications
import WatchKit

/// `s9` Phase B, `FR-WATCH-05` — hosts `SideQuestLongLookView` for the `"sidequest-nearby"` category,
/// registered as a `WKNotificationScene` in `hisploraApp.swift`. `didReceive(_:)` resolves everything
/// once, synchronously, so `body` never redoes the (best-effort, see `loadHeroImage`) attachment read.
final class SideQuestNotificationController: WKUserNotificationHostingController<SideQuestLongLookView> {

    private var synopsis: String = ""
    private var heroImage: UIImage?

    override var body: SideQuestLongLookView {
        SideQuestLongLookView(synopsis: synopsis, heroImage: heroImage)
    }

    override func didReceive(_ notification: UNNotification) {
        synopsis = notification.request.content.body
        heroImage = Self.loadHeroImage(from: notification.request.content.attachments)
    }

    /// Best-effort only. `UNNotificationAttachment.url` is a security-scoped URL, and
    /// `startAccessingSecurityScopedResource()` is documented as unreliable specifically on watchOS
    /// (unlike the same pattern on iOS) — Apple Developer Forums threads 713567 and 70104. Any
    /// failure here — the scope not starting, the read failing, corrupt image data — returns `nil`,
    /// which `SideQuestLongLookView` renders as the flat-palette placeholder (`FR-WATCH-06`'s
    /// fallback), not a crash or an empty slot. If the image slot never shows a real photo even once
    /// a sidequest ships `heroImageAsset`, this is why — read the two forum threads before assuming a
    /// bug in this function.
    private static func loadHeroImage(from attachments: [UNNotificationAttachment]) -> UIImage? {
        guard let url = attachments.first?.url else { return nil }
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
```

- [ ] **Step 2: Build the watch target to confirm it compiles**

Same command as Task 1 Step 2. Expected: `** BUILD SUCCEEDED **`. (The controller isn't wired to a
scene yet, so nothing renders differently — this step only confirms the new file compiles.)

- [ ] **Step 3: Register the `WKNotificationScene` and correct the stale comment in `hisploraApp.swift`**

Read the current file first — it's short (under 60 lines) — then apply these two changes:

1. Add a `WKNotificationScene` alongside the existing `WindowGroup` in `hisplora_Watch_AppApp.body`:

```swift
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        WKNotificationScene(
            controller: SideQuestNotificationController.self,
            category: WatchSideQuestNotificationCategory.identifier)
    }
```

2. `WatchSideQuestNotificationCategory`'s doc comment (added in Phase A's final-review fix wave,
   commit `0311581`) currently poses an open question about which side's category registration is
   load-bearing for a mirrored notification's long-look, pointing at `s9` §3. Replace that open
   question with the resolved answer from this phase's design spec's Context section: scene binding
   for a custom long-look is a **static `Scene` declaration** (the `WKNotificationScene` just added),
   matched against the forwarded notification's `categoryIdentifier` — independent of either side's
   `setNotificationCategories` call. Both registrations (this one, and the phone's from Phase A) stay
   necessary for their own purpose (the action set each side renders), but neither is what makes the
   custom card appear; the `WKNotificationScene` declaration is. Rewrite the comment to state this
   plainly instead of asking it as an open question.

- [ ] **Step 4: Build both targets**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Expected: `** BUILD SUCCEEDED **` — the phone build embeds the watch app, so this also proves the
watch target (with the new scene) builds and links cleanly as a dependency, not just standalone.

- [ ] **Step 5: Update `s9`'s own plan file**

Open `.claude/plans/sidequest/s9-watch-notification-scene.plan.md` and add a short note under its
Phasing table (or wherever this repo's convention places an "Execution" note on other plans, e.g.
`m6`/`m7`/`m8`) recording: Phase B's code landed in this plan's commits, `FR-WATCH-05` is implemented,
and device verification (the table in `s9` §7) is still outstanding — do not claim it as verified,
only as built. Name the actual commit SHAs once Step 6 below creates them (come back and fill this in
after committing, or commit the plan-file update together with the code in one commit — either is
fine, just don't claim device verification happened when it didn't).

- [ ] **Step 6: Commit**

```bash
git add "challange-5/hisplora Watch App/SideQuestNotificationController.swift" \
        "challange-5/hisplora Watch App/hisploraApp.swift" \
        .claude/plans/sidequest/s9-watch-notification-scene.plan.md
git commit -m "feat(watch): host the long-look card via WKNotificationScene (FR-WATCH-05)"
```

---

## Device verification (not part of these tasks — human-only)

Neither task above can be verified end-to-end without a physical iPhone + paired Apple Watch — no
simulator or automated test renders a real Notification Scene (see the Global Constraints note on
testing). Once both tasks are committed, the outstanding check is `s9` §7's existing table, row "Long-
look renders the card": hold the wrist up past short-look on a real device and confirm the image slot,
body text, and "Open in App" pill all appear as designed. This plan does not claim that check passed;
it only gets the code to the point where it can be run.
