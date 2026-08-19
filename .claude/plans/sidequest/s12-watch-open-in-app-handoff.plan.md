# S12 — "Open in App" on the watch: correcting the hand-off claim

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the long-look card's "Open in App" action (and a tap on the card itself) actually do
something on the watch — today it is a dead tap — by making the watch app open to the tapped
sidequest's card locally, and correct the false claim that this action hands off to the iPhone.

**Architecture:** Reuses the already-shipped `SideQuestLongLookView` (`s11`) as the watch-local detail
screen instead of `ContentView`'s placeholder. A new `UNUserNotificationCenterDelegate` on the watch
target captures the tap, resolves the same `synopsis`/`heroImage` pair `SideQuestNotificationController`
already resolves for the long-look scene, and hands it to the app via `@State`, mirroring the exact
retention pattern `challange_5App.swift` already uses on the phone target. No new package dependency.

**Tech Stack:** Swift 6, SwiftUI, `UserNotifications`/`WatchKit` (watchOS 26.5 SDK).

**Spec:** This file. Builds on `s9-watch-notification-scene.plan.md` (Phase A/B) and
`s10-long-look-card-design.md`/`s11-long-look-card.plan.md` (the long-look card itself, already
shipped and unmodified by this plan except for the one access-modifier change in Task 2).

## Context — what's confirmed, and what was wrong

The user supplied the Figma reference for `91:182` ("Example/Notifications kanan") — the exact card
`SideQuestLongLookView` already renders: gold oval frame, black placeholder oval, synopsis text, and a
bottom bar reading "Open in Iphone App". **The card itself is correct and stays as-is.** What's wrong
is what happens when that bar is tapped.

`s10-long-look-card-design.md`'s Status line (line 13-15) states: *"`FR-WATCH-06` (no unsourced
likeness) and `FR-WATCH-07` (Open in App hands off to the iPhone) are already satisfied by Phase A's
action wiring; this phase is what actually renders them."* That claim is false, and this plan is what
found out:

- `SideQuestProximityService.swift`'s `SideQuestNotificationCategory.register(language:)` (the
  **phone's** registration) does correctly set `options: [.foreground]` on its "Open in App" action —
  but that only governs what happens when a tap is handled **by the phone**.
- `hisploraApp.swift`'s `WatchSideQuestNotificationCategory.register()` (the **watch's** registration,
  added later in `s9` Phase A) registers the *same category identifier* locally on the watch with
  `options: []`, on the reasoning — stated in that file's own comment — that leaving it empty "lets the
  tap relay back to the phone's own registration." **There is no such relay.** `UNNotificationAction`
  options are per-device: a `.foreground` action fires the app on whichever device handled the tap.
  Once `s11` added a `WKNotificationScene` bound to this category, the watch app owns presentation and
  interaction for it entirely — the notification is no longer eligible for the system's own "no local
  handler → wake the paired iPhone" mirroring fallback, which is the *only* built-in mechanism that
  would have made a tap open the iPhone.
- Net effect, confirmed by reading the code (no `UNUserNotificationCenterDelegate` exists anywhere in
  `hisplora Watch App`): tapping "Open in App" today does nothing. Tapping the card body (the scene's
  default interaction) foregrounds the watch app into `ContentView`'s "isn't built yet" placeholder,
  discarding which sidequest was tapped.

**There is no supported watchOS API to make a tap on a watch-owned notification scene foreground the
paired iPhone.** This was checked against current developer documentation and community reports before
writing this plan, not assumed. `FR-WATCH-07` ("Open in App... MUST NOT open a screen inside the watch
companion itself") is therefore not achievable as literally written for a notification the watch
renders its own long-look for — it needs a product-owner decision, the same way `FR-CP-05`'s Story
Reveal exception and `FR-START-04a` needed one, not a silent code workaround. This plan does not wait
on that signature to ship a working button; see Task 5.

## Decision this plan implements

**Recommended and implemented here:** the watch owns the interaction. "Open in App" (and a tap on the
card) opens the *watch app's own* view of that sidequest — reusing `SideQuestLongLookView` verbatim, so
the notification and the in-app card look identical — instead of doing nothing or landing on an unrelated
placeholder. This is a strict improvement over the current dead-tap state regardless of how the
`FR-WATCH-07` conversation resolves.

**Copy stays "Open in App" / "Buka di Aplikasi", not Figma's literal "Open in Iphone App".** Now that
the action provably opens the watch's own screen, adopting the Figma frame's literal English label
would assert something false. This mirrors the repo's existing practice of deviating from a literal
Figma string when it's demonstrably wrong (`docs/hisplora-tokens.md`'s recorded deviations) rather than
shipping copy that lies about what tapping the button does. Flagged in Task 5 for the same product
sign-off `FR-WATCH-07` itself needs — this plan proceeds with the accurate label in the meantime.

## Global Constraints

- No `DesignSystem`, no `ContentKit`, no network access from the watch target — same constraint `s10`
  established and `s11` built under. Everything this plan needs is already inside the tapped
  `UNNotification`'s content, exactly like `SideQuestNotificationController.didReceive(_:)` already
  demonstrates.
- Reuse `SideQuestLongLookView` and `SideQuestNotificationController.loadHeroImage` as-is — do not
  duplicate the security-scoped-attachment-read logic a second time in this target.
- Reuse the exact delegate-retention pattern already proven on the phone target
  (`challange_5App.swift:6-9,31-32`): `@State private var notificationDelegate = ...`, assigned to
  `UNUserNotificationCenter.current().delegate` inside `.onAppear`, because the delegate property is
  `weak` and anything not retained is silently dropped.
- `content.userInfo["sideQuestID"]` is the only cross-cutting key already on every notification this
  category carries (`SideQuestProximityService.swift:357`) — read it the same way
  `SideQuestNotificationDelegate` already does on the phone (`SideQuestProximityService.swift:562`).
- Both new/changed files go in `hisplora Watch App/` (a `PBXFileSystemSynchronizedRootGroup` — no
  `project.pbxproj` edit needed for the new file).
- Build verification needs `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and, for
  `xcodebuild`, `PATH="$DEVELOPER_DIR/usr/bin:$PATH"` — see `CLAUDE.md`'s toolchain section. Run
  `xcrun simctl list devices available` before trusting any destination name below.
- **No automated test exists for this feature and this plan does not invent one** — same reasoning
  `s11`'s Global Constraints already recorded (no watch-target test bundle, `UIImage` decoding needs a
  real runtime). Verification is the build commands in each task plus Xcode's `#Preview` canvas; final
  acceptance of the actual tap behavior is device-only, same as every other row in `s9` §7's table.

---

## Task 1: Fix the watch's local category registration

**Files:**
- Modify: `challange-5/hisplora Watch App/hisploraApp.swift:40-61`

**Interfaces:**
- Produces: `WatchSideQuestNotificationCategory.register()` — same signature, corrected behavior.

- [ ] **Step 1: Read the current file**

Confirm the exact current text of `WatchSideQuestNotificationCategory` before editing — it changed
hands across `s9` Phase A and this plan's correction, and the doc comment above it is what's stale.

- [ ] **Step 2: Replace the action's `options` and the comment explaining it**

```swift
enum WatchSideQuestNotificationCategory {
    static let identifier = "sidequest-nearby"
    static let openInAppActionIdentifier = "OPEN_IN_APP"

    /// `s12` — corrects `s9` Phase A's original registration, which left `options` empty on the
    /// (incorrect) belief that doing so would let the tap "relay" to the phone's own category
    /// registration. There is no such relay: `UNNotificationAction` options are evaluated by whichever
    /// device handles the tap, and once this target's `WKNotificationScene` (`s11`) claims the
    /// `"sidequest-nearby"` category, the watch handles every tap on it — the phone's registration in
    /// `SideQuestProximityService.swift` never gets a say. `.foreground` here is therefore correct: it
    /// makes the tap actually open *this* app (to the tapped sidequest, via
    /// `SideQuestWatchNotificationDelegate` — see that file), instead of doing nothing. See
    /// `.claude/plans/sidequest/s12-watch-open-in-app-handoff.plan.md` for the full finding; there is
    /// no supported way to make this action foreground the paired iPhone instead.
    static func register() {
        let openInApp = UNNotificationAction(
            identifier: openInAppActionIdentifier,
            title: "Open in App",
            options: [.foreground])
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: [openInApp],
            intentIdentifiers: [],
            options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add "challange-5/hisplora Watch App/hisploraApp.swift"
git commit -m "fix(watch): open-in-app action foregrounds the watch, not a nonexistent iPhone relay"
```

---

## Task 2: Expose `loadHeroImage` for reuse, add the tap delegate

**Files:**
- Modify: `challange-5/hisplora Watch App/SideQuestNotificationController.swift:49`
- Create: `challange-5/hisplora Watch App/SideQuestWatchNotificationDelegate.swift`

**Interfaces:**
- Consumes: `content.userInfo["sideQuestID"]` (`String`), `content.body` (`String`),
  `content.attachments` (`[UNNotificationAttachment]`) — all already on every notification this
  category's requests carry (`SideQuestProximityService.swift:353-368`).
- Produces: `struct OpenedSideQuestCard { let sideQuestID: String; let synopsis: String; let heroImage:
  UIImage? }`, `final class SideQuestWatchNotificationDelegate: NSObject,
  UNUserNotificationCenterDelegate` with `var onTap: (@MainActor (OpenedSideQuestCard) -> Void)?`.

- [ ] **Step 1: Widen `loadHeroImage`'s access from `private` to internal (the file's default)**

In `SideQuestNotificationController.swift`, change:

```swift
    private static func loadHeroImage(from attachments: [UNNotificationAttachment]) -> UIImage? {
```

to:

```swift
    /// `internal`, not `private` — `s12`'s `SideQuestWatchNotificationDelegate` reuses this exact
    /// security-scoped read instead of duplicating it a second time in the same target.
    static func loadHeroImage(from attachments: [UNNotificationAttachment]) -> UIImage? {
```

- [ ] **Step 2: Write `SideQuestWatchNotificationDelegate.swift`**

```swift
//
//  SideQuestWatchNotificationDelegate.swift
//  hisplora Watch App
//

import UIKit
import UserNotifications

/// `s12` — makes a tap on the `"sidequest-nearby"` long-look card (or its "Open in App" action) open
/// something real on the watch, instead of silently doing nothing or landing on `ContentView`'s
/// generic placeholder with no idea which sidequest was tapped. There is no cross-device hand-off to
/// the iPhone available here — see `.claude/plans/sidequest/s12-watch-open-in-app-handoff.plan.md` for
/// why — so this delegate is the whole answer, not a stopgap for a real hand-off elsewhere.
final class SideQuestWatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    var onTap: (@MainActor (OpenedSideQuestCard) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        if let sideQuestID = content.userInfo["sideQuestID"] as? String {
            let card = OpenedSideQuestCard(
                sideQuestID: sideQuestID,
                synopsis: content.body,
                heroImage: SideQuestNotificationController.loadHeroImage(from: content.attachments))
            Task { @MainActor [onTap] in onTap?(card) }
        }
        completionHandler()
    }

    /// Mirrors the phone's `SideQuestNotificationDelegate.willPresent` — a local notification can
    /// still fire while this app is already foregrounded on the watch.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// The already-resolved facts `ContentView` needs to render the tapped sidequest locally — the same
/// shape `SideQuestNotificationController` resolves for the long-look scene itself, not a new decode
/// path.
struct OpenedSideQuestCard {
    let sideQuestID: String
    let synopsis: String
    let heroImage: UIImage?
}
```

- [ ] **Step 3: Build the watch target to confirm it compiles**

```bash
xcrun simctl list devices available | grep -i watch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme "hisplora Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'
```

Expected: `** BUILD SUCCEEDED **`. Substitute the real destination name/OS from `simctl list` if it
differs.

- [ ] **Step 4: Commit**

```bash
git add "challange-5/hisplora Watch App/SideQuestNotificationController.swift" \
        "challange-5/hisplora Watch App/SideQuestWatchNotificationDelegate.swift"
git commit -m "feat(watch): add the notification-tap delegate that resolves the tapped sidequest"
```

---

## Task 3: Wire the delegate and render the tapped card

**Files:**
- Modify: `challange-5/hisplora Watch App/hisploraApp.swift`
- Modify: `challange-5/hisplora Watch App/ContentView.swift`

**Interfaces:**
- Consumes: `OpenedSideQuestCard`, `SideQuestWatchNotificationDelegate` (Task 2);
  `SideQuestLongLookView(synopsis:heroImage:)` (existing, `s11`).

- [ ] **Step 1: Update `hisplora_Watch_AppApp` to hold and wire the delegate**

```swift
@main
struct hisplora_Watch_AppApp: App {
    @State private var openedCard: OpenedSideQuestCard?
    /// Held here, not constructed inline: `UNUserNotificationCenter.current().delegate` is `weak`,
    /// same reasoning `challange_5App.swift` already documents on the phone target.
    @State private var notificationDelegate = SideQuestWatchNotificationDelegate()

    init() {
        WatchSideQuestNotificationCategory.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(openedCard: openedCard)
                .onAppear {
                    notificationDelegate.onTap = { card in openedCard = card }
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                }
        }
        WKNotificationScene(
            controller: SideQuestNotificationController.self,
            category: WatchSideQuestNotificationCategory.identifier)
    }
}
```

- [ ] **Step 2: Update `ContentView` to render the tapped card, or the existing placeholder**

```swift
//
//  ContentView.swift
//  hisplora Watch App
//
//  Created by Imelda Damayanti on 18/08/26.
//

import SwiftUI

/// Shows the sidequest a notification tap resolved (`s12`, reusing `SideQuestLongLookView` verbatim
/// so the in-app view matches the notification card exactly), or the pre-Phase-B placeholder when the
/// app was opened any other way (`s9` Phase A). See
/// `.claude/plans/sidequest/s12-watch-open-in-app-handoff.plan.md`.
struct ContentView: View {
    let openedCard: OpenedSideQuestCard?

    var body: some View {
        if let openedCard {
            SideQuestLongLookView(synopsis: openedCard.synopsis, heroImage: openedCard.heroImage)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.circle")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hisplora")
                    .font(.headline)
                Text("Tap a nearby sidequest notification to see it here.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview("No card opened") {
    ContentView(openedCard: nil)
}

#Preview("Opened from a notification tap") {
    ContentView(openedCard: OpenedSideQuestCard(
        sideQuestID: "sq-park23",
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: nil))
}
```

- [ ] **Step 3: Build both targets**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Expected: `** BUILD SUCCEEDED **` — proves the watch target links cleanly as an embedded dependency,
not just standalone.

- [ ] **Step 4: Visually verify both `#Preview`s in Xcode**

Open `ContentView.swift`'s canvas: "No card opened" shows the existing walk-icon placeholder; "Opened
from a notification tap" shows the same gold-frame card the long-look scene renders, with the sample
synopsis and no image (placeholder fill).

- [ ] **Step 5: Commit**

```bash
git add "challange-5/hisplora Watch App/hisploraApp.swift" \
        "challange-5/hisplora Watch App/ContentView.swift"
git commit -m "feat(watch): open the tapped sidequest's card instead of the unbuilt placeholder"
```

---

## Task 4: Correct `s9` and `s10`'s false hand-off claims

**Files:**
- Modify: `.claude/plans/sidequest/s9-watch-notification-scene.plan.md`
- Modify: `.claude/plans/sidequest/s10-long-look-card-design.md`

- [ ] **Step 1: Correct `s10`'s Status line**

`s10-long-look-card-design.md` line 13-15 currently reads: *"`FR-WATCH-06`... and `FR-WATCH-07`...are
already satisfied by Phase A's image-slot rule and action wiring."* Replace the `FR-WATCH-07` half of
that sentence with a pointer to this plan's finding — it was not satisfied, and there is no supported
way to satisfy it as written once the watch owns the notification's presentation. Keep the
`FR-WATCH-06` half; that claim was correct.

- [ ] **Step 2: Add an Execution note to `s9`**

Under `s9-watch-notification-scene.plan.md`'s existing Execution section (below the
`s11-long-look-card.plan.md` commits), add a short paragraph: `s12` found and fixed the "Open in App"
hand-off — it does not (and, absent a new watchOS API, cannot) foreground the iPhone; it now opens the
tapped sidequest on the watch itself. `FR-WATCH-07` as literally written needs a product-owner
decision (accept a corrected requirement, or accept dropping the custom long-look in favor of system
mirroring) — record which once decided; this plan does not resolve it, only stops it from being
silently claimed as done.

- [ ] **Step 3: Commit**

```bash
git add .claude/plans/sidequest/s9-watch-notification-scene.plan.md \
        .claude/plans/sidequest/s10-long-look-card-design.md
git commit -m "docs(sidequest): correct s9/s10's false Open-in-App-hands-off-to-iPhone claim"
```

---

## Task 5 (not code — product decision, tracked here so it isn't lost)

`FR-WATCH-07` ("Open in App... MUST hand off to the iPhone app... MUST NOT open a screen inside the
watch companion itself") cannot be satisfied as written for a notification the watch renders its own
long-look for. Needs a named owner to either:

1. Amend `FR-WATCH-07` to describe what this plan actually built (opens the sidequest on the watch),
   the same way `FR-START-04a` formalized a real behavior change, or
2. Accept dropping the custom `WKNotificationScene`/long-look entirely so the notification falls back
   to system mirroring, which does genuinely wake the iPhone — at the cost of `FR-WATCH-05`.

Also needs sign-off on keeping "Open in App" as the action's label rather than Figma `91:182`'s literal
"Open in Iphone App", now that the action provably does not do that.

This plan implements option 1's behavior without waiting for the amendment to be signed, on the same
basis `s9`/`s11` already shipped code ahead of some open questions — but does not mark `FR-WATCH-07`
resolved, and Task 4 above makes sure no other plan file claims it is.

---

## Device verification (not part of these tasks — human-only)

No simulator or automated test renders a real Notification Scene interaction (same constraint `s9` §7
and `s11` already documented). Once Tasks 1-3 are committed, the check is: trigger a dev-test region
entry, let the long-look render, tap "Open in App" — the watch app should foreground directly into that
sidequest's card (matching what the notification just showed), not the "isn't built yet" placeholder
and not the iPhone.
