# Sidequest — implementation plan

**Status:** planned, nothing built.
**Owner:** unassigned.
**Scope of requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`, `docs/system-design.md`,
`docs/schema.md`. The feature is **not in the PRD today** — `s7` is the amendment that has to be
accepted before any of this ships.

## What the feature is, in one paragraph

Outside any quest, the app watches a set of authored places. When the walker enters one, a
notification says a historical place is nearby. Tapping it shows a short synopsis and asks whether
they want the story. Yes leads to the place's history, then a challenge — a quiz or a photo — and
completing the challenge awards **one letter of a phrase**. Collecting every letter of, say,
`BALI THE EXPLORER` means visiting and completing every place in that collection. A sidequest is
never part of a Run, never blocks one, and never changes one.

## The user's flow chart, mapped to screens

| Box on the chart | What builds it |
|---|---|
| user pass the places | region entry, `SideQuestProximityService` (`s3`) |
| notification | `UNNotificationRequest`, guarded by `ProximityGate` (`s3`) |
| User in radius of the place that we provide back story | `ArrivalEvaluator` reused unchanged (`s2`) |
| User see the sinopsis of the place | `SideQuestNoticeView` (`s4`) |
| wanna see the story? — no | dismiss, record nothing but the alert row (`s3`) |
| historical place nearby | `SideQuestStoryView` (`s4`) |
| user see and read the story, and finish | story pages → challenge → letter (`s4`) |
| wanna see the story? (second diamond) | re-entry: an incomplete sidequest is re-openable forever (`FR-SIDE-07`) |
| pake konsep mel, detailnya map nanti | the collection map is **out of scope** — `s0`, deliberately-not-in-it |

## Files in this folder

| File | What it decides |
|---|---|
| `s0-scope-and-decisions.plan.md` | what is in, what is out, and the twelve decisions the rest depends on |
| `s1-content-schema.plan.md` | `ContentKit` types, JSON layout, validator rules V19–V28 |
| `s2-engine-and-store.plan.md` | `RunEngine`: records, store, the pure values that hold the rules |
| `s3-proximity-notifications.plan.md` | region monitoring, `Always` permission, rate limits, debug tooling |
| `s4-ui-flow.plan.md` | screens, view models, presentation models, theme seam, strings |
| `s5-content-authoring.plan.md` | the places, their consent, their citations, the phrase |
| `s6-testing-and-acceptance.plan.md` | the test matrix and the acceptance gates |
| `s7-prd-amendment.md` | the `FR-SIDE-*` requirement block to add to the PRD |
| `s8-watch-prd-amendment.plan.md` | the `FR-WATCH-04`…`08` requirement block for a v2 watch companion's branded proximity/sidequest card — not `FR-WATCH-03`, which is a different feature |
| `s9-watch-notification-scene.plan.md` | the `hisplora Watch App` target, the Notification Scene, the image-placeholder decision, and the Open-in-App handoff |
| `s10-long-look-card-design.md` | resolves `s9`'s own Phase B (§3/§4) — the `WKNotificationScene`/`WKUserNotificationHostingController` API verified against Apple's current docs, the flat-palette placeholder choice, why `DesignSystem` isn't linked into the watch target, and the security-scoped attachment-read caveat |
| `s11-long-look-card.plan.md` | the implementation plan for `s10` — `SideQuestLongLookView`, `SideQuestNotificationController`, and the `WKNotificationScene` registration |

## Phasing

Each phase is shippable on its own and leaves the app in a working state.

| Phase | Delivers | Gate to the next |
|---|---|---|
| **A** — content spine and rules | `s1`, `s2`. No UI at all. | `swift test` green, validator green on a fixture tree |
| **B** — the flow, foreground only | `s4` minus notifications; entry from a Nearby list and the debug switch | one sidequest walkable end to end on the simulator |
| **C** — proximity notifications | `s3` | fires on a real device, respects quiet hours and limits |
| **D** — photo challenges | `s4` §7 | photo captured, stored relative, erasable |
| **E** — content | `s5` | consent records signed, citations openable |

**A and E run in parallel.** Phase E is governance work with a lead time measured in weeks and is the
thing most likely to stop this shipping (`s5` §1); the code does not wait on it, and a fixture
content tree stands in until it lands.

**Phase B depends on nothing from C.** That ordering is deliberate: the notification is the part
that needs `Always` location, a physical device and a field walk to verify, and hanging the whole
feature off it would leave nothing demonstrable until the very end.

| **F** — watch notification card | `s9`, gated by `s8` | short-look shows the right icon/title/body and long-look renders on a physical Apple Watch, Open in App wakes the paired iPhone |

**Phase F depends on C**, not on A/B/D/E — it dresses up the notification `s3` already produces and
adds nothing to the content model, so it can start as soon as `s3` posts a real notification and does
not wait on sidequest content authoring (`s5`) at all.
