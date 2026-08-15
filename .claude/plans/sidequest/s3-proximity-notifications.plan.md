# S3 — Region monitoring and the notification

Phase C. App target, `challange-5/Service/`. This is the part that needs `Always` location, a
physical device, and a walk to verify — which is why nothing else depends on it (`README`, phasing).

`AD-1` splits location by purpose. Arrival sampling is the foreground half and already exists. This is
the background half, and it is the first background location code in the app.

## 1. What it is allowed to do

From `system-design.md` §6.2, unchanged by this feature:

```
registerRegions() triggered by: launch · toggle on · Run completed ·
                                sidequest completed · kill-switch update
   └─ candidates = quest starts (not completed, not suppressed)
                 + sidequests   (not completed, not suppressed)
   └─ RegionBudget.select(..., limit: 20)          FR-PROX-14
   └─ startMonitoring(CLCircularRegion(center:, radius: noticeRadiusM))

didEnterRegion  (app not running — iOS relaunches into the background)
   └─ ProximityGate.decide(...)                    FR-PROX-08/09/10, s2 §6
   └─ schedule UNNotificationRequest (immediate)   FR-PROX-06
   └─ append one ProximityAlert row                NFR-PRIV-09
   └─ return. No network, no analytics, nothing else.  NFR-BAT-06
```

The handler must finish in milliseconds. iOS gives a background relaunch a short budget, and every
other thing it could do is forbidden by `NFR-BAT-06` anyway.

**No `UIBackgroundModes` location entry is added.** Region monitoring does not need one, and adding it
would put the app in the category `NFR-BAT-01` forbids ("MUST NOT use continuous background location
updates in any release"). If a reviewer ever finds that key in `Info.plist`, something has gone wrong.

## 2. `SideQuestProximityService`

```swift
@MainActor
protocol ProximityMonitoring: AnyObject {
    var isEnabled: Bool { get }
    var authorization: LocationAuthorizationSnapshot { get }
    /// `FR-PROX-03` — the plain-language explanation is shown by the caller *before* this is called.
    func requestAlwaysAuthorization()
    func enable() throws
    func disable()
    /// Recomputed on launch, on toggle, on completion, and after a suppression update.
    func refreshRegions()
}
```

`SystemProximityMonitor` is the implementation: a `CLLocationManager` for regions, a
`UNUserNotificationCenter` for the alert, `ProximityGate` for the decision, and a small store for
`ProximityAlert` rows. It holds no rules of its own — every branch it takes comes from a value in
`RunEngine` that `swift test` already covered.

The alert rows live in `Application Support/Kultara/proximity-alerts.json` — one small document, not
one per row, because they are pruned at 7 days and never number more than a few dozen. Pruning happens
on load. `DataEraser` clears them.

## 3. Authorization, honestly

`Always` is not a permission the app can insist on. Requesting it typically yields `When In Use`
first, with the system upgrading later, or never.

| State | What the app does |
|---|---|
| not requested | toggle is off; turning it on shows the explanation screen, then requests |
| `When In Use` after asking for `Always` | feature disables itself, says plainly that iOS has not granted background access, offers a path to Settings (`FR-PROX-05`). Everything else keeps working. |
| `Always` | regions registered |
| denied / restricted | toggle off and disabled, with the same Settings path |
| notifications denied | regions are pointless; the toggle reports it and offers Settings |

Two permissions, asked in this order: `Always` location, then notifications. Both after an in-app
screen that says what will happen (`FR-PROX-03`), never as a cold system prompt.

`Info.plist` gains `NSLocationAlwaysAndWhenInUseUsageDescription`. It must name the single real use —
"to tell you when you walk past a historical place, even when the app is closed" — and it must be
translated. The existing `NSLocationWhenInUseUsageDescription` is English-only, a known gap from M6;
this feature is the moment to add `InfoPlist.strings` for both (`NFR-I18N-02`, `NFR-PRIV-10`).

## 4. The notification itself

- Title: the place's official name. Body: the sidequest's `synopsis`, resolved to the app's language,
  not the device's (`FR-ONB-05` — the app's language is chosen in Settings and may differ).
- `userInfo` carries `sideQuestID` and nothing else. No coordinates in a payload.
- Tapping opens the notice screen for that sidequest (`FR-PROX-07` equivalent). Handled by
  `UNUserNotificationCenterDelegate` → a `pendingSideQuestID` on the root view, consumed once.
- Delivered locally. It is never a remote push, and no server knows a region was entered
  (`FR-PROX-15`).
- On a paired Apple Watch this forwards as a haptic with no watchOS target and no code
  (`NFR-PLAT-05`). It is a system behaviour and must be described as one — it happens when the phone
  is locked and the watch is worn and unlocked, not always (`NFR-PLAT-06`).

## 5. Foreground entry

If the app is open when the region is entered, a notification is the wrong shape. `didEnterRegion`
fires in the foreground too; the service posts a callback instead, and the root view shows the notice
as a sheet. Same `ProximityGate` decision, same alert row — the rate limits exist to protect the
walker's attention, and attention is scarcer when they are already looking at the phone.

An active Run suppresses both paths, with no exception (`FR-PROX-08`, `s0` D1).

## 6. Entering the radius is not the same as unlocking

The notification uses `noticeRadiusM` — the approach warning. Opening the story requires the arrival
rule at `triggerRadiusM`, evaluated in the foreground with `ArrivalEvaluator` exactly as a checkpoint
is (`s0` D3). So:

1. Notification fires at, say, 200 m.
2. The walker taps it and gets the synopsis and the question.
3. Answering yes opens an arrival screen, not the story: sampling runs, the distance counts down, and
   at 75 m with a fix good enough the story opens.
4. If GPS will not confirm it — inside a covered market, next to a wall — the manual override appears
   after 60 seconds and the entry is recorded as `manual` (`FR-ARR-03/04`).

Skipping straight to the story on the notification would hand out letters to anyone who walked past
the end of the street.

## 7. Kill-switch interaction

`AD-5`'s suppression list already names quests and places. It gains `sideQuestIds`. A suppressed
sidequest is deregistered on the next launch (`FR-PROX-12`), disappears from the collection screen as
a slot that cannot currently be earned — **its already-earned letter stays**, because the record is a
snapshot and the walk happened (`FR-SIDE-10`).

## 8. Walking past a place without walking

`FR-START-08`'s desk problem, again. Debug builds gain a second developer tool next to "Simulate
arrival anywhere":

- **Simulate passing a place** — a list of sidequests; picking one calls the same
  `didEnterRegion` handler with that sidequest's id. The input is simulated, the decision is not:
  `ProximityGate` still runs, quiet hours still block at 23:00, the daily cap still counts.
- Both tools stay inside `#if DEBUG`, in `DeveloperToolsSection.swift`, and a release build must not
  contain `SimulatedLocationProvider` or this handler — verifiable by grepping the Release binary.

Note for whoever tests: the simulator's toggles do not respond to synthesized taps from the simulator
MCP. Drive position with `xcrun simctl location <udid> set <lat>,<lon>` instead, as the run flow
already documents.

## 9. Battery and privacy claims this makes

| Claim | Held by |
|---|---|
| No continuous background location, ever | there is no `UIBackgroundModes` location entry and no `startUpdatingLocation` outside the foreground arrival screen. `PermissionCallBoundaryTests` confines those calls by file. |
| Nothing but a notification happens on region entry | the handler's body, and a test over `ProximityGate` that it is a pure decision |
| No movement history is stored | `ProximityAlert` has two fields, neither of them a coordinate (`NFR-PRIV-09`) |
| Nothing is transmitted | no network call exists in this path; the only network document in the app is the suppression list |

## 10. Files touched

| File | Change |
|---|---|
| `Service/SideQuestProximityService.swift` | new — monitor, notification scheduling, alert store |
| `Service/LocationService.swift` | `LocationAuthorizationSnapshot` already covers `.always`; add the `Always` request path |
| `Service/DataEraser.swift` | erase sidequest records and alert rows |
| `Service/StorageReporter.swift` | count the two new directories |
| `Support/KultaraEnvironment.swift` | assemble the monitor, the sidequest store and engine |
| `View/Component/DeveloperToolsSection.swift` | "Simulate passing a place" |
| `View/SettingsView.swift` + `Component/SettingsSection.swift` | the opt-in toggle and its status |
| `challange_5App.swift` | notification delegate, `refreshRegions()` on launch |
| `Info.plist` / `InfoPlist.strings` | `NSLocationAlwaysAndWhenInUseUsageDescription`, both languages |
