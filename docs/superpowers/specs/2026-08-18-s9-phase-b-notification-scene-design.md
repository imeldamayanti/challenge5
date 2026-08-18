# S9 Phase B — Watch Notification Scene: design

**Status:** approved by product owner (in-chat brainstorming, 2026-08-18), ready for `writing-plans`.
**Scope:** `.claude/plans/sidequest/s9-watch-notification-scene.plan.md` §3 ("Long-look — the Notification
Scene") and §4 ("The image slot"), Phase B in that plan's phasing table. Builds on Phase A, already
shipped (`fb5421a..2ffd8ef` plus a final-review fix wave `91a2ffa..16f657f` on the `notification`
branch): the watch app icon, the shared `"sidequest-nearby"` `UNNotificationCategory` with its "Open
in App" `UNNotificationAction`, registered at launch on both targets, and `postNotification`'s
unconditional `categoryIdentifier`/attachment fields.

Satisfies `FR-WATCH-05` (custom long-look). `FR-WATCH-06` (no unsourced likeness) and `FR-WATCH-07`
(Open in App hands off to the iPhone) are already satisfied by Phase A's image-slot rule and action
wiring; this phase is what actually renders them.

## Context

`s9` §3 flagged the `WKNotificationScene`/dynamic-interface API surface as unverified against the
installed watchOS 26 SDK before this phase could be scoped further. That verification happened in
this brainstorming session, against Apple's current documentation (not a cached or remembered API
shape):

- `WKNotificationScene<Content, Controller>` — `nonisolated struct`, conforms to `Scene`, available
  since watchOS 7.0, not deprecated. `init(controller: Controller.Type, category: String)`.
- `WKUserNotificationHostingController<Body>` — `@MainActor @preconcurrency class`, available since
  watchOS 6.0, not deprecated. Subclass it, override `var body: Body` and
  `didReceive(_ notification: UNNotification)`. Class vars `isInteractive`, `sashColor`,
  `titleColor`, `subtitleColor`, `wantsSashBlur`, `coalescedDescriptionFormat` control chrome.

One structural question also needed resolving before design could proceed: for a notification
*mirrored* from the iPhone (not scheduled independently on the watch — this app does neither today
nor in this phase), which category registration governs what renders? Apple's own guidance is that
watch notification mirroring forwards the same notification content, `categoryIdentifier` included,
from the phone. The scene binding for a custom long-look, though, is a **static `Scene` declaration**
in the watch app's own `body` (`WKNotificationScene(controller:category:)`), matched against the
forwarded notification's `categoryIdentifier` — it does not depend on which side's
`setNotificationCategories` call "wins". Both Phase A registrations (phone, for its own expanded-view
action; watch, for the action set the watch itself renders) remain necessary and correct; the
`WKNotificationScene` declaration this phase adds is an independent, additional piece, not a
replacement for either. This resolves the final Phase A review's Important finding #4 (the watch-side
comment that flagged this as an open question, not a confirmed fact) — that comment should be
corrected to state the resolved answer when this phase implements it.

## Goals

- Render a branded long-look card (Figma `91:182`) when the wrist stays raised past the short-look,
  for the `"sidequest-nearby"` category.
- Circular image slot (attachment if present, flat-palette placeholder otherwise), the sidequest's
  synopsis as body text.
- No new user-facing strings, no new network access, no new content-model fields.

## Non-goals

- No change to `ContentKit`, `SideQuest`, or any authored content.
- No `DesignSystem` package linkage (see Architecture — a genuine platform constraint, not a
  simplification of convenience).
- No in-scene interactive controls. "Open in App" stays the system `UNNotificationAction` Phase A
  already wired; this phase does not duplicate it as a SwiftUI button.
- No placeholder *image asset* — the placeholder is a programmatic SwiftUI shape, not a file.
- No changes to `SideQuestProximityService.swift` or either target's category registration — Phase A's
  plumbing is consumed as-is.

## Architecture

Two new files under `hisplora Watch App/` (a `PBXFileSystemSynchronizedRootGroup` — no
`project.pbxproj` edit needed, same as Phase A's icon and placeholder-`ContentView` work):

- **`SideQuestNotificationController.swift`** — `final class SideQuestNotificationController:
  WKUserNotificationHostingController<SideQuestLongLookView>`. Stores the `UNNotification` it
  receives; `body` constructs `SideQuestLongLookView` from it. `isInteractive` left at its default
  (`false`) — no SwiftUI controls need touch input inside the scene.
- **`SideQuestLongLookView.swift`** — a plain SwiftUI `View`, no dependencies beyond `SwiftUI` and
  `UserNotifications` (for reading the attachment/content types it's handed). Takes plain values
  (image data or nil, body text) as `init` parameters — not a `UNNotification` directly — so it stays
  independently previewable and testable in isolation from the controller.

`hisploraApp.swift` gains one `Scene` in its `body`:
`WKNotificationScene(controller: SideQuestNotificationController.self, category:
WatchSideQuestNotificationCategory.identifier)` — reusing the identifier constant Phase A already
defined in that file, not a new string literal.

**No `DesignSystem` package linkage.** `Packages/Kultara/Package.swift` declares platforms
`.iOS(.v18)` and `.macOS(.v14)` only — watchOS is absent — and `DesignSystem/NavigationChrome.swift`
unconditionally `import UIKit`, which does not exist on watchOS. Linking `DesignSystem` into the watch
target would require adding a watchOS platform to the whole package and auditing every target for
UIKit/AppKit-only code — real scope creep for one view's color tokens. Brand colors (`#804a34` brown,
`#fbf1e0` cream — the same two already used for the app icon) are hardcoded `Color` literals in
`SideQuestLongLookView.swift`, matching the precedent Phase A's icon already set for this exact
target.

## Data flow

`didReceive(_ notification: UNNotification)` on the controller is the only place a `UNNotification`
is touched. Everything the card needs was already resolved and packed into the notification's content
by the phone in Phase A, before the system ever forwards (mirrors) it to the watch:

- **Body / synopsis** — `notification.request.content.body`. Already localized by
  `LanguageResolver` on the phone side; the watch never makes a language decision.
- **Image slot** — `notification.request.content.attachments.first`. When present (a future content
  update sets `heroImageAsset`), load it via `UNNotificationAttachment.url` (a local file URL, already
  `AD-3`-compliant — no network fetch on either side). When absent (every sidequest today), or if
  loading the attachment's file fails for any reason, fall back to the flat-palette placeholder.
- **No `ContentKit`, no `ContentRepository`, no network access from the watch target at any point.**
  This is a direct consequence of Phase A already having resolved and attached everything on the
  phone — Phase B only renders what it's handed.

## Layout (Figma `91:182`)

- Circular image/placeholder, top, centered.
- Body text (synopsis) below it, plain, scrollable — the long-look interface is natively scrollable,
  so no truncation or "read more" affordance is needed for a long synopsis.
- No custom dismiss control — system-provided (`xmark`), unchanged from system chrome.
- No in-scene "Open in App" control — the system action button from the registered category renders
  below the custom content automatically; the SwiftUI view does not draw it.

## Error handling

- Attachment present but unreadable/corrupt on the watch side (rare, but possible — e.g. a sync glitch
  during mirroring): falls back to the flat-palette placeholder. Never a crash, never an empty card.
- No other failure surface exists in this view — no network, no disk writes, no external state.

## Testing

Device-only for final acceptance, same constraint `s9` §7 and Phase A already documented: no
simulator or unit-test surface can render a real Notification Scene. Two things narrow the gap:

- An `#Preview` in `SideQuestLongLookView.swift` fed fixture data (a sample synopsis string, with and
  without a sample image) — lets layout be checked in Xcode's canvas without a device round-trip for
  every small adjustment. Not a substitute for the device check; a fast local loop for the parts that
  don't need one.
- The existing device-test table in `s9` §7 ("Long-look renders the card — hold wrist up past
  short-look — image slot, body, Open in App pill") is the acceptance gate; this design does not
  change what that row checks, only what code satisfies it.

## Open risks

None blocking. Two things worth watching during implementation, not before:

- The known watchOS quirk (found during API research, several developer-forum reports) that `title`
  and `sashColor` set via `UNMutableNotificationContent`/class vars don't always render as expected on
  some watchOS versions — irrelevant here since this design uses neither (no custom title override, no
  sash color change), but worth knowing if a future revision wants either.
- Whether a mirrored notification's `UNNotificationAttachment` file is guaranteed present on the watch
  by the time `didReceive` fires, or could arrive slightly after — the design's fallback (placeholder
  on any failure) already covers this without needing to know the answer in advance, and no sidequest
  ships `heroImageAsset` today, so this path is untested in practice until content authoring sets one.
