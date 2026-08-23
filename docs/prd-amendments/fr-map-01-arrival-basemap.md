# Proposed amendment — FR-MAP-01, the arrival screen's map slot

**Status: DRAFT. UNSIGNED. No owner named.**
Drafted 2026-08-21, when the arrival screen's map slot was changed from the drawn canvas to a live
`MKMapView` on the owner's instruction that `223:2004` be matched as drawn. The code is written and
merged; this document is what would make it legitimate. Until it is signed the implementation is
running ahead of its requirement — and unlike
[the discovery basemap](fr-map-01-discovery-basemap.md), **this one is inside the walk**, which is
exactly the case `FR-MAP-01` was written about.

## The requirement as it stands

> **FR-MAP-01** | The route display **MUST NOT** depend on live map tiles. MapKit exposes no public
> offline tile cache, so a live MapKit view is not an acceptable implementation for in-quest use.
> | P0 | v1

> **FR-OFF-03** | The route map **MUST** render offline. See FR-MAP-01. | P0 | v1

## What changed in the code

`Features/QuestRun/ArrivalRouteMapView.swift` fills frame `223:2004`'s 362 × 218.89 "Maps"
rectangle with an `MKMapView`, able to carry the same four marks the drawn canvas carried: the
arrival radius at true scale (`MKCircle` at `targetRadiusM`), the authored route line, the numbered
stops in their three states, and the walker's dot.

**On the arrival screen itself three of those four are switched off** (`drawsRoute: false`, on the
owner's instruction of 2026-08-24): `223:2004` pastes in a plain street map, and the screen now
matches it — the target stop and the walker, on tiles, with no route line, no bearing dashes and no
arrival ring drawn over them. Nothing about the amendment below changes with it. The route display
this document is about is the *drawn canvas*, which is unchanged and is still what a failed load
falls back to, and the distance and fix quality are still stated as text (`FR-ARR-05`). Any surface
that is about the route rather than about the walker not being at it yet still gets all four marks
— `drawsRoute` defaults to `true`.

Four properties of the implementation are what the proposal below rests on:

1. **The drawn canvas is still there and is still the fallback.** `ArrivalRouteMap` swaps in
   `RunRouteMapView` on `mapViewDidFailLoadingMap` — a report of a load that actually failed, not a
   prediction (`AD-3`; there is still no reachability check anywhere in the codebase).
2. **Nothing on the screen is gated on the map.** The distance text, `ArrivalEvaluator`'s radius and
   accuracy rule, and the Apple Maps handoff (`FR-MAP-04`) are unchanged and all work with the radio
   off. The slot is a picture.
3. **No second permission moment.** The dot is drawn from the arrival sampler's own last fix, not
   from `MKMapView.showsUserLocation`, so `FR-ONB-04`'s single prompt is untouched — unlike the
   discovery map, which does open a second one.
4. **The map is not interactive.** No pan, no zoom, no user tracking (`FR-MAP-03`), which also keeps
   it from stealing the arrival screen's scroll gesture.

## What is proposed

Amend `FR-MAP-01` so that what it protects is the *availability* of the route display rather than
the *technology* drawing it, and make the availability half unamendable:

| ID | Text | Priority |
|---|---|---|
| FR-MAP-01 | The route display **MAY** be drawn from live map tiles where a richer basemap serves the reader. | P1 |
| FR-MAP-01a | Any live-tile route display **MUST** carry an offline fallback that renders from authored content alone, and **MUST** enter it on an observed load failure rather than on any prediction about connectivity. | P0 |
| FR-OFF-03 | Unchanged. Met by FR-MAP-01a's fallback. | P0 |

## What is given up if this is signed

The walk's map is now better where there is signal and identical to before where there is not — but
only for as long as the fallback is maintained. `FR-MAP-01`'s original blanket ban needed nobody to
maintain anything; this version needs the fallback path to keep working, and a fallback path is by
definition the one nobody looks at. `PermissionCallBoundaryTests.theDrawnRunMapSurvivesAsTheOfflineFallback`
is the mechanical part of that maintenance: it asserts that `RunRouteMapView` still draws a `Canvas`,
still imports no MapKit, and that the wrapper still both calls it and drives the swap from
`mapViewDidFailLoadingMap`.

There is a second cost the tests cannot hold: a failed *first* load falls back, but tiles that load
partially — a walker on a thin edge connection — draw a grey grid rather than triggering the
fallback. The drawn canvas never had that state. Nobody has walked this on a real network yet.

## If this is not signed

Revert `QuestRunView.routeMap` to `RunRouteMapView(showsChrome: false)`, delete
`ArrivalRouteMapView.swift`, and drop `arrivalBasemapOwningFiles` from
`PermissionCallBoundaryTests`. That is the whole change; nothing else depends on it.
