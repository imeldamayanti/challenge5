import ContentKit
import Foundation
import RunEngine
import SwiftUI

@MainActor
@Observable
final class RegionMapViewModel {

    let language: ContentLanguage
    let pins: [RegionMapPin]
    let mapImageURL: URL?
    let aspectRatio: Double

    /// The illustration's tile pyramid, when content ships one.
    ///
    /// Both map surfaces read it: at rest they draw a level sized for the viewport, and pinching in
    /// walks *down* the pyramid instead of magnifying a raster that was fixed at the resting size.
    /// Nil falls back to `mapImageURL`, which is what the screens drew before there was a pyramid.
    let tiles: RasterTileImageStore?

    /// Where the illustration sits on the real world, so a live basemap can be drawn under it.
    ///
    /// Nil when no drawn quest reaches a Place carrying a `mapPoint` — the discovery map then has
    /// nothing honest to place the artwork by, and draws no overlay rather than an invented one.
    let georeference: IllustratedMapGeoreference?

    /// The centre of the pin cluster, so the map can open showing the pins rather than whichever
    /// corner of the illustration happens to sit at the scroll origin. Bali's south coast is two
    /// thirds of the way down a portrait drawing; without this the first thing a user sees is
    /// open sea.
    var pinCentroid: MapPoint {
        guard !pins.isEmpty else { return MapPoint(x: 0.5, y: 0.5) }
        let x = pins.map(\.point.x).reduce(0, +) / Double(pins.count)
        let y = pins.map(\.point.y).reduce(0, +) / Double(pins.count)
        return MapPoint(x: x, y: y)
    }

    /// Pins ordered top to bottom, so the alternating label side is stable rather than following
    /// manifest order — otherwise reordering content silently reshuffles the layout.
    var labelOrderedPins: [RegionMapPin] {
        pins.sorted { ($0.point.y, $0.point.x) < ($1.point.y, $1.point.x) }
    }

    /// The distance between the two closest pins, in points, once the illustration is drawn at
    /// `size`. Nil when there are fewer than two pins.
    func closestPinSeparation(drawnAt size: CGSize) -> CGFloat? {
        guard pins.count > 1 else { return nil }
        var closest: CGFloat = .greatestFiniteMagnitude
        for (index, pin) in pins.enumerated() {
            for other in pins[(index + 1)...] {
                let dx = (pin.point.x - other.point.x) * size.width
                let dy = (pin.point.y - other.point.y) * size.height
                closest = min(closest, hypot(dx, dy))
            }
        }
        return closest
    }

    /// How far in the map has to open for the closest two markers to be `minimumSeparation` points
    /// apart.
    ///
    /// The design draws the island whole, and whole is how this opens whenever the content allows
    /// it. But quests in one town sit within a few hundred metres of each other, and at island
    /// scale their markers land on top of one another — the overlap `NFR-A11Y-01` forbids and the
    /// end of the 44-point target `NFR-A11Y-06` requires. So the opening zoom is derived from the
    /// content rather than fixed: spread pins open fitted, a cluster opens on the cluster.
    func initialZoom(
        drawnAt size: CGSize,
        minimumSeparation: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard let separation = closestPinSeparation(drawnAt: size), separation > 0 else { return 1 }
        return min(max(minimumSeparation / separation, 1), maximum)
    }

    /// The pin closest to the cluster's centre. The map scrolls to *this marker* rather than to a
    /// zero-sized anchor at the centroid: `ScrollViewReader` positions real, laid-out views
    /// reliably, and a 1×1 `Color.clear` inside a `.position` modifier is neither.
    var anchorPinID: String? {
        let centre = pinCentroid
        return pins.min {
            hypot($0.point.x - centre.x, $0.point.y - centre.y)
                < hypot($1.point.x - centre.x, $1.point.y - centre.y)
        }?.questID
    }

    /// Nil when content ships no region map. The screen then has nothing to draw, and saying so is
    /// better than presenting an empty frame that looks like a failed download — which, given
    /// `AD-3`, it could never be.
    init?(
        repository: any ContentRepository,
        language: ContentLanguage,
        suppressedQuestIDs: Set<String> = [],
        suppressedPlaceIDs: Set<String> = []
    ) {
        guard let regionMap = (try? repository.manifest())?.regionMap else { return nil }

        self.language = language
        aspectRatio = regionMap.aspectRatio
        mapImageURL = (try? repository.assetURL(regionMap.asset)) ?? nil
        tiles = regionMap.tiles
            .flatMap { (try? repository.assetURL($0)) ?? nil }
            .flatMap(RasterTileImageStore.init(directory:))

        let quests = (try? repository.quests(
            suppressingQuestIDs: suppressedQuestIDs,
            suppressingPlaceIDs: suppressedPlaceIDs)) ?? []

        pins = quests.compactMap { quest -> RegionMapPin? in
            guard let start = quest.startCheckpoint,
                  let place = (try? repository.place(id: start.placeId)) ?? nil,
                  let point = place.mapPoint
            else { return nil }

            let title = quest.title.value(for: language)
            let placeName = place.nameOfficial.value(for: language)
            return RegionMapPin(
                questID: quest.id,
                title: title,
                placeName: placeName,
                point: point,
                coordinate: place.coordinate,
                // NFR-A11Y-02: a marker is a control, so it says what it is and where it starts.
                accessibilityLabel: "\(title) — \(placeName)")
        }

        // Anchored on **every** Place the drawn quests walk through, not on the pins alone. A
        // single anchor fits without complaint and cannot disagree with itself; five that were
        // each eyeballed onto the same drawing agree to within fourteen metres, and the moment one
        // is nudged the fit says so. Places no drawn quest reaches are deliberately excluded —
        // several carry `mapPoint`s that predate this artwork and would drag the overlay tens of
        // kilometres west.
        let anchors: [IllustratedMapGeoreference.Anchor] = quests
            .flatMap(\.checkpoints)
            .compactMap { checkpoint in
                guard let place = (try? repository.place(id: checkpoint.placeId)) ?? nil,
                      let point = place.mapPoint
                else { return nil }
                return IllustratedMapGeoreference.Anchor(point: point, coordinate: place.coordinate)
            }

        georeference = IllustratedMapGeoreference.fittedToBaliIllustration(anchors: anchors)
    }
}
