# Proposed amendment — FR-MAP-01, scoped to in-quest use

**Status: DRAFT. UNSIGNED. No owner named.**
Drafted 2026-08-20 alongside the discovery map's live basemap. The code it describes is written and
merged; this document is what makes it legitimate, and until somebody signs it the implementation is
running ahead of its requirement.

The precedent for the form is `FR-START-04`, amended in PRD §5.5 on 2026-08-16 with af
(afindo.mi01@gmail.com) as owner, and split so its load-bearing half became the unamendable
`FR-START-04a`. This proposes the same shape: narrow the requirement to what it is actually
protecting, and make that part harder rather than softer.

## The requirement as it stands

> **FR-MAP-01** | The route display **MUST NOT** depend on live map tiles. MapKit exposes no public
> offline tile cache, so a live MapKit view is not an acceptable implementation for in-quest use.
> | P0 | v1

Paired with:

> **FR-OFF-03** | The route map **MUST** render offline. See FR-MAP-01. | P0 | v1

## What changed in the code

`Features/Map/Real/` draws the discovery map on `MKMapView`, with `275:2309`'s illustrated chart
placed over it as an `MKOverlay` and the same fog-and-building markers on top
(`276:2520`). `wand.and.sparkles` toggles the chart. The user's own position comes from MapKit
rather than from a projection onto artwork, which is the reason the basemap is there at all.

The run's map is untouched. `RunRouteMapView` still projects the authored `route.geojson` onto a
`Canvas` via `RunEngine.RouteProjection`, and still shares `Geo.earthRadiusM` with `Geo.distanceM`
so the drawn length and the printed distance cannot disagree.

## What is proposed

Split the requirement, so that the half that protects the walk gets stronger and the half that was
over-reaching gets scoped:

| ID | Text | Priority |
|---|---|---|
| FR-MAP-01 | The **in-quest** route display **MUST NOT** depend on live map tiles. MapKit exposes no public offline tile cache, so a live MapKit view is not an acceptable implementation during a Run. This admits no exception. | P0 |
| FR-MAP-01b | A **discovery** surface — one reached before a Run starts, whose purpose is choosing a walk rather than following one — **MAY** draw a live basemap, provided that (a) it degrades to an offline surface when the basemap does not load, (b) the degradation is driven by an observed failure and never by a reachability check (`AD-3`), and (c) no core flow depends on it. | P1 |

## The argument for it

**The stated reason for the ban is about walking, not about choosing.** The requirement gives its
own ground: no public offline tile cache. That matters when a walker is inside Pasar Badung with
no signal and needs to see where the next checkpoint is. It does not matter in the same way when
somebody at home is deciding which walk to do — and if it did, the same logic would ban every
network-dependent thing the app might ever do.

**The degradation is real and is tested.** `QuestMapViewModel` swaps the whole surface to
`RegionMapView` — the shipped illustrated map, which reads authored `mapPoint`s and needs nothing —
the moment `mapViewDidFailLoadingMap` fires. `QuestMapTests` asserts the swap and asserts that the
"real map is unavailable" notice is said only when the reader had actually asked for the real map.

**No reachability check was added.** `AD-3` is intact and `PermissionCallBoundaryTests`'
`noModuleChecksReachability` still passes. Nothing anywhere predicts the network; the fallback is a
reaction to a request that was made and did not return.

**The blast radius is written down and guarded.** `PermissionCallBoundaryTests` now names the three
files permitted to touch MapKit and fails on a fourth, and asserts separately that nothing under
`Features/QuestRun/` and nothing in any package target touches it at all.

## The argument against it, stated fairly

The requirement as written does not say "in-quest" in its normative clause — it says "the route
display", and only the *justification* mentions in-quest use. A reader could hold that the whole map
surface was meant, and the amendment is then a change of intent rather than a clarification. That
reading is why this is an amendment needing a signature rather than a note in a code comment.

Second: a discovery map that looks better with a connection quietly makes the app feel worse
offline, which is the direction `AD-3` exists to push against. The fallback keeps this from becoming
a broken screen, but it does not keep it from becoming a second-best one.

## A second deviation rides with this one — `FR-ONB-04`

> **FR-ONB-04** | Location permission **MUST NOT** be requested during onboarding; it is requested in
> context at the first quest-start attempt.

`QuestMapViewModel.prepareLocation` requests when-in-use authorization the first time the discovery
map is opened, from `.notRequested` only.

The ban itself is untouched — this is not onboarding. What the requirement additionally *states* is
that the prompt happens at the first quest-start attempt, and there are now two in-context moments
rather than one. A map whose whole purpose is to draw where you are standing, that silently draws no
dot and explains nothing, was the bug this fixed; but "silently" is the fault, and asking is not the
only cure. The alternative — draw no dot until the reader has started a quest, and say why — was
rejected as worse, not as impossible.

Proposed wording, if this is accepted:

| ID | Text | Priority |
|---|---|---|
| FR-ONB-04 | Location permission **MUST NOT** be requested during onboarding. It is requested in context, at the first moment the reader asks for something that needs it — the first quest-start attempt, or the first opening of a map that draws their position — and **MUST NOT** be requested again after any answer. | P0 |

`PermissionCallBoundaryTests.foregroundArrivalCalls` admits `QuestMapViewModel.swift` by name, with
that reasoning inline, so the second caller is recorded rather than absorbed.

## What signing this requires

1. An owner named, as `FR-START-04`'s amendment names af.
2. PRD §5 edited to carry both `FR-MAP-01` rows and the reworded `FR-ONB-04`, and §10's outstanding
   list updated.
3. `CLAUDE.md`'s "there is no `MKMapView` and there must never be one" note narrowed to the run map,
   which is what it will then mean.

Until all three happen, `Features/Map/Real/` is shipped code without a requirement behind it, and
`PermissionCallBoundaryTests.onlyTheDiscoveryBasemapDrawsMapsFromLiveTiles` is the only thing
recording how far the deviation reaches.
