# S9 — Watch notification scene: target, content, and the long-look card

**Status: `s8` accepted (owner imelda, 2026-08-18).** `s8-watch-prd-amendment.plan.md`'s requirement
block (`FR-WATCH-04`…`08`) is accepted into scope, so the gate `s1`–`s6` sit behind `s7` is now
satisfied here too. See this plan's own Execution section below for how far Phase B has since gone.

## What builds it

| `s8` requirement | What builds it |
|---|---|
| `FR-WATCH-04` — system-default short-look | An `AppIcon` asset for the watch target, plus the existing `content.title`/`content.body` on the notification the iPhone already posts. No new Swift code. |
| `FR-WATCH-05` — custom long-look | A `WKNotificationScene`-hosted SwiftUI view in `hisplora Watch App`. |
| `FR-WATCH-06` — no unsourced likeness | A placeholder asset, chosen below, standing in for `SideQuest.heroImageAsset` when a sidequest doesn't carry one — which today is every sidequest (`s3`'s finding: 0 of 11 have it set). |
| `FR-WATCH-07` — Open in App hands off to iPhone | A `UNNotificationAction` with `.foreground`, same category on both targets, routed through the existing `SideQuestNotificationDelegate.onTap` path (`SideQuestProximityService.swift`). |
| `FR-WATCH-08` — v1 unaffected without the companion | Nothing changes about `SystemProximityMonitor.postNotification`'s existing call shape for a phone with no paired watch, or a watch with no companion installed — see §4. |

## 1. Target — already scaffolded, unmodified

`hisplora Watch App` exists (added 2026-08-18): `PRODUCT_BUNDLE_IDENTIFIER =
com.umar.hisplora.watchkitapp`, `SDKROOT = watchos`, `WATCHOS_DEPLOYMENT_TARGET = 26.5`, companion to
`challange-5`. Contents are Xcode's unmodified template — `hisploraApp.swift`, `ContentView.swift`, an
empty `Assets.xcassets` with placeholder `AppIcon`/`AccentColor` sets. Nothing in this plan has been
built yet.

## 2. App icon (`FR-WATCH-04`)

Design reference: Figma `91:176`, the "App Icon" component inside the "Short Look" instance — a
circular brown (`#804a34`)/cream (`#fbf1e0`) icon with the concentric guide-ring look the mock is
built from (Apple's own icon-grid guides, not a custom animation — see `s8`'s framing). Export a real
raster `AppIcon.appiconset` for `hisplora Watch App` matching that palette. This is asset work — no
Swift.

## 3. Long-look — the Notification Scene (`FR-WATCH-05`)

A SwiftUI view hosted via a `WKNotificationScene` in `hisploraApp.swift`, keyed to a category
identifier both targets share (see §5). Content, per Figma `91:182`:

- Circular image slot, top — see §4 for what fills it.
- Body text (the sidequest's `synopsis`, same string the iPhone notification already carries).
- Dismiss `xmark` — system-provided by the notification chrome, not custom-drawn.
- "Open in App" pill, bottom, `chevron.forward` trailing — a `UNNotificationAction`, not an in-scene
  button (see §5).

**Resolved in `s10-long-look-card-design.md`** (2026-08-18): the API surface above is now verified
against Apple's current docs (`WKNotificationScene`/`WKUserNotificationHostingController`, both
current as of watchOS 26, not deprecated) rather than trusted verbatim from this section. `s10` also
resolves which side's category registration governs a mirrored notification's long-look (§5's open
question below) and the `heroImageAsset` attachment's security-scoped read caveat. `s11-long-look-card.plan.md`
is the implementation plan. This section's content above is kept as the original framing; `s10` is the
authoritative design once implementation starts.

## 4. The image slot (`FR-WATCH-06`, `s8` decision 2)

**Decision: a generic placeholder, not per-place photography.** `heroImageAsset` stays optional on
`SideQuest` exactly as it is today (`ContentKit.SideQuestEntities.swift:117`) — this plan does not
mandate authoring one for the 11 existing sidequests. The long-look's image slot resolves:

1. The sidequest's `heroImageAsset`, if a future content update sets one.
2. Otherwise, a single generic placeholder asset shipped with the watch target — a flat
   Hisplora-palette fill (brown/cream), not a photograph, not a silhouette of a person. Exact asset
   TBD at implementation time; it is decoration for an empty slot, not a claim about anything, so it
   carries no `sources` entry and needs no validator rule.

This unblocks the whole feature immediately rather than waiting on `docs/field-verification-checklist.md`
or new site photography — the placeholder is correct today, and a future content pass can add real
`heroImageAsset` values without touching this code.

## 5. Category, action, and the handoff (`FR-WATCH-07`)

`SystemProximityMonitor.postNotification` (`SideQuestProximityService.swift:295`) needs:

- A shared `UNNotificationCategory` identifier (e.g. `"sidequest-nearby"`), registered on both
  targets via `UNUserNotificationCenter.current().setNotificationCategories(_:)` at launch.
- `content.categoryIdentifier` set on the request the iPhone already builds.
- If `heroImageAsset` resolves to a real path, attach it via `UNNotificationAttachment` — local file,
  no network fetch, consistent with `AD-3`.

"Open in App" is a `UNNotificationAction(identifier:title:options: [.foreground])`. Tapping it (or
the notification body itself) already routes through `SideQuestNotificationDelegate.onTap` on the
iPhone (`SideQuestProximityService.swift:448`) — this plan adds no new deep-link logic, it reuses
`FR-PROX-07`'s existing tap-to-open path. The watch side does not open a screen of its own; the action
exists to wake and foreground the iPhone app, per `NFR-PLAT-06`'s framing (forwarding only happens
locked+worn+unlocked).

## 6. Why `FR-WATCH-08` needs no code

`postNotification`'s call shape (title, body, `userInfo`, sound) does not change for a phone with no
paired watch or a watch with no companion installed — a category identifier and an optional local
attachment are additive fields a plain system-rendered notification already tolerates. Nothing here
is conditional on the watch companion's presence; the companion is what makes the *rendering* richer,
not a dependency the iPhone-side code checks for.

## 7. Testing

Device-only, same caveat as `s3`/`s6` — CI and the simulator location-injection path exercise the
notification decision logic (`ProximityGate`), never the rendered watch UI.

| Check | How |
|---|---|
| Short-look shows the right icon + title/body, no watch companion installed | Trigger a dev-test region entry (`park23` et al.), phone locked, watch worn/unlocked, companion **not** installed — confirms `FR-WATCH-08` |
| Short-look with companion installed | Same, companion installed — confirms `FR-WATCH-04` looks identical (system default either way) |
| Long-look renders the card | Hold wrist up past short-look — image slot, body, Open in App pill |
| Open in App wakes the iPhone | Tap the action — iPhone app foregrounds to the same screen `FR-PROX-07`'s tap already opens |
| Placeholder never shows the AI portrait | Grep the shipped watch target's `Assets.xcassets` for the `ChatGPT Image…` filename pattern — must not exist (guards `FR-WATCH-06`) |

## Phasing

| Phase | Delivers | Gate to the next |
|---|---|---|
| **A** — icon + category plumbing | §2, §5's category registration, `postNotification` additive fields | builds and installs on both targets, short-look shows correct icon/title/body |
| **B** — long-look scene | §3, §4's placeholder asset | card renders on a physical watch, Open in App wakes the iPhone |

Both phases were `s8`-gated in full — nothing here shipped ahead of the amendment being accepted,
and `s8` is now accepted (owner imelda, 2026-08-18).

## Execution — 2026-08-18

**Status: Phase B's code is built, not verified.** `FR-WATCH-05` is implemented per this plan's §3
and `s10`'s resolved design. `s11-long-look-card.plan.md` carried the implementation as two tasks:

- **Task 1** — `SideQuestLongLookView.swift` (the SwiftUI card: image slot, synopsis text,
  `FR-WATCH-06` flat-palette placeholder fallback). Commit `a196571` (the view). A task reviewer
  then raised a concern that `imageSlotSize`'s `private` access would demote the synthesized
  memberwise init to `private` too, making it uncallable from Task 2's file — commit `e2a872e`
  widened it to `internal` on that basis. That claim turned out to apply only to a stored property
  declared *without* a default value; `imageSlotSize` has one (`= 64`), so the memberwise init was
  never affected and the original `private` was correct all along. The property has been reverted
  back to `private` (see Finding 3 of the whole-branch review that caught this).
- **Task 2** — `SideQuestNotificationController.swift` (hosts the view, resolves `synopsis` and
  `heroImage` from the delivered `UNNotification` in `didReceive(_:)`, with the best-effort
  security-scoped attachment read `s10` flagged as watchOS-unreliable) and the
  `WKNotificationScene(controller:category:)` registration added to `hisplora_Watch_AppApp.body` in
  `hisploraApp.swift`, closing the open question §3 used to carry about which side's category
  registration is load-bearing (resolved: neither — the static `Scene` declaration is). Commit
  `7ac7920`.

Both targets build clean (`hisplora Watch App` alone, then `challange-5` — which embeds the watch
app and proves the new scene links as a dependency, not just standalone).

**What is still outstanding: every row of §7's table.** No simulator or CI path renders a real
Notification Scene (see this plan's own testing note above) — device verification needs a physical
iPhone + paired Apple Watch and has not been attempted. Do not read "builds clean" as "the card
renders correctly"; those are different claims and only the first one is made here.

## Execution — 2026-08-19 (`s14`, what actually shipped)

`s14-watch-two-card-alignment.plan.md` finished Phase B and changed two things this plan assumed.

**The long look is `91:176`'s radar, and the watch app has a second, different card.** §3 and §4 were
written when there was one design for both surfaces. There are now two, deliberately
(`s14` D1/D2): `SideQuestLongLookView` renders the radar for the notification, and the new
`SideQuestWatchCardView` renders `91:182`'s gold frame for the screen a tap opens. They share only
their `(synopsis, heroImage)` initialiser. §4's image-slot rule (`FR-WATCH-06`) is unchanged and both
cards implement it — one slot, two states, a flat brand fill wherever no sourced photo exists.

**§5's hand-off does not work, and `FR-WATCH-07` is open.** This plan states the category and action
wiring satisfies it. They do not: once this target's `WKNotificationScene` claims `"sidequest-nearby"`,
the watch renders the long look and handles every tap on it, and a `UNNotificationAction`'s options
are evaluated by the device that handles the tap — the phone's registration never gets a say. `s12`
established this; `s14` shipped the honest version, which is that "Open in App" foregrounds the
**watch** app (`options: [.foreground]`, restored in `s14` Task 3.1 after the working tree had
reverted it to `options: []`, where the tap did nothing at all). The requirement needs a named owner.

**§7's table is still outstanding**, with one row narrowed. Both cards have now been rendered and
measured on a 46 mm watchOS 26.5 simulator by hosting them in `ContentView`
(`docs/screenshots/s14-watch-*.png`), which is more than "builds clean" — but it is still not a real
Notification Scene interaction. A notification pushed with `simctl push` is delivered and its long
look needs a wrist raise no simulator reproduces, so the long look *in situ* and the tap that
foregrounds the app remain device-only and unverified.
