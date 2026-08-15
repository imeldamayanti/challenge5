# S6 — Testing and acceptance

## 1. Where each rule is tested

The app target has no unit-test bundle, so anything expressed only in a view model or a service is
untested. The table below is the mapping from rule to the place it can actually be checked. Anything
in the "review only" column is a promise, not a guarantee, and should be moved if it can be.

| Rule | Tested by | Suite |
|---|---|---|
| Content shape, decode failures | `swift test` | `ContentKitTests` |
| V19–V28 rejection cases | `swift test` | `ContentValidatorTests` |
| Discovery snapshot, idempotency, letter award once | `swift test` | `SideQuestEngineTests` |
| Quiz grading, reveal-after-three | `swift test` | `SideQuestQuizTests` |
| Collection progress, masking an unearned slot | `swift test` | `LetterCollectionProgressTests` |
| Quiet hours across midnight, cooldown, daily cap, active-Run block | `swift test` | `ProximityTests` |
| Region selection, priority, stability, no-position case | `swift test` | `ProximityTests` |
| Store durability, corrupt document, erase-all | `swift test` | `SideQuestStoreTests` |
| Package import boundaries (no CoreLocation in `RunEngine`) | `swift test` | `ImportBoundaryTests` |
| Contrast of every new Hisplora pair | `swift test` | `HisploraThemeTests` |
| Permission-call confinement (`requestAlwaysAuthorization` in one file) | `swift test` | `PermissionCallBoundaryTests`, extended |
| Navigating the flow end to end | XCUITest | `challange-5UITests` |
| View-model stage transitions | **review only** unless `m7` lands or `UIStrings`/rules move into a package | — |
| UI string ID/EN parity | **review only** — see `s4` §8, fix before merging Phase B | — |

`PermissionCallBoundaryTests` is worth extending carefully: it currently *confines*
`requestWhenInUseAuthorization` and `startUpdatingLocation` to named files and fails if those calls
stop existing, so confinement cannot pass by finding nothing. Add `requestAlwaysAuthorization` and
`startMonitoring(for:)` on the same terms, and keep the outright ban on background location updates
and the tracking prompt.

## 2. Commands

From `challange-5/Packages/Kultara`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run content-validator Sources/ContentKit/Content
```

From `challange-5/`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && export PATH="$DEVELOPER_DIR/usr/bin:$PATH" && "$DEVELOPER_DIR/usr/bin/xcodebuild" test -project challange-5.xcodeproj -scheme challange-5 -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Pin `OS=`. Four runtimes are installed and one carries no devices; an unpinned destination can resolve
onto it and fail for a reason that has nothing to do with the code. Run
`xcrun simctl list devices available` before assuming any device name.

## 3. Simulator walk-through — Phase B acceptance

With **Simulate arrival anywhere** on, or by driving position directly:

```bash
xcrun simctl location <udid> set -8.6595,115.2077
```

| Step | Requirement checked |
|---|---|
| Nearby list shows the sidequest with a distance | `FR-SIDE-07` |
| Notice shows synopsis, and dress code / photo policy at a sacred place before anything else | `FR-TASK-05` |
| Answering "no" records nothing | flow chart, no-branch |
| Answering "yes" opens the arrival gate, not the story | `s3` §6 |
| Live distance and accuracy, never a spinner | `FR-ARR-05`, `FR-ERR-01` |
| Story opens only inside the radius with a good enough fix | `FR-ARR-01` |
| Override appears at 60 s and records `manual` | `FR-ARR-03/04` |
| Story pages carry the accuracy chip and citations | `FR-CP-05`, `s0` D6 |
| A wrong answer changes nothing and can be retried | `s0` D4/D5 |
| The third wrong attempt reveals the answer and still awards the letter | `s0` D5 |
| The letter appears in the collection, and unearned slots stay blank | `FR-SIDE-08` |
| Re-opening a completed sidequest awards nothing new | `FR-SIDE-05` |
| Completing the last letter awards the collection badge once | `FR-SIDE-09` |
| Killing and relaunching the app keeps every letter | `FR-RUN-01` equivalent |
| Airplane mode changes nothing anywhere in the flow | `FR-OFF-02`, `AD-3` |
| Settings → delete my data removes letters, records and alert rows | `FR-SET-02` |

## 4. Device walk-through — Phase C acceptance

Cannot be done on a simulator. Needs a phone, and a walk.

| Step | Requirement |
|---|---|
| Toggle off by default on a fresh install | `FR-PROX-03` |
| Explanation screen precedes the system prompt | `FR-PROX-03` |
| `When In Use` granted instead of `Always` → feature disables itself, says so, offers Settings, everything else unaffected | `FR-PROX-05` |
| Entering the notice radius with the app closed and the phone locked fires the notification | `FR-PROX-01` |
| Paired watch produces a haptic, with no watch app installed | `FR-PROX-06`, `NFR-PLAT-05/06` |
| Tapping opens that sidequest's notice | `FR-PROX-07` |
| No alert while a Run is active | `FR-PROX-08` |
| No second alert for the same place within 24 h; no fourth alert in a day | `FR-PROX-09` |
| Nothing between 22:00 and 07:00 | `FR-PROX-10` |
| Turning the toggle off deregisters every region immediately | `FR-PROX-13` |
| A completed sidequest stops being monitored | `s0` D9 |
| A suppressed sidequest is deregistered on next launch | `FR-PROX-12` |
| Battery over a day of normal carrying is not visibly worse | `NFR-BAT-01/06` |

Record the results in this folder as an executed-verification section, the way
`m6-quest-run-vertical-slice.plan.md` does. A field test that is not written down did not happen.

## 5. Release gates specific to this feature

Added to the PRD's acceptance list (`s7`):

1. Every place in every shipped collection has a real, unexpired consent grant from the site, with a
   named grantor and a named region owner. Self-grants do not pass.
2. Every claim in every sidequest story has an openable citation. No `BELUM DIVERIFIKASI`.
3. Every coordinate and radius has been stood on.
4. The proximity walk-through above, on a device, in the field.
5. Airplane-mode traversal of the whole sidequest flow on a physical device.
6. VoiceOver and largest-Dynamic-Type traversal of all six new screens.
7. A Release build contains neither `SimulatedLocationProvider` nor the simulated region entry —
   verified by grepping the binary.
8. `Info.plist` purpose strings for `Always` location and camera exist in both languages.

## 6. Known gaps this plan does not close

- **View-model behaviour stays untested** unless `m7-restore-test-guards.plan.md` lands. Six new
  screens is the largest untested surface the app would have.
- **iOS 18.0, the deployment floor, has still never been run.** Region monitoring and
  `UNUserNotificationCenter` behave the same there, but the claim is untested, as it is for everything
  else.
- **The 20-region budget is shared and not observable.** `RegionBudget` decides what to register;
  nothing tells the user that a place they walked past was not being watched. If collections grow past
  a single region, this needs a product answer, not a bigger cap.
