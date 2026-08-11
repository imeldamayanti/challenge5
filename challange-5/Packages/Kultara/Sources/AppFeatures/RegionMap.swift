import ContentKit
import DesignSystem
import SwiftUI

/// One quest marker on the illustrated map, at its start point.
///
/// A pin per quest rather than per Place: the map is a discovery surface, and a traveller choosing a
/// walk wants to see where walks *begin*. Marking all five stops of every quest would draw the
/// route's shape onto a map that is explicitly not a navigation aid (`FR-MAP-03`).
public struct RegionMapPin: Sendable, Identifiable, Equatable {
    public let questID: String
    public let title: String
    public let placeName: String
    public let point: MapPoint
    public let accessibilityLabel: String

    public var id: String { questID }
}

@MainActor
@Observable
public final class RegionMapViewModel {

    public let language: ContentLanguage
    public let pins: [RegionMapPin]
    public let mapImageURL: URL?
    public let aspectRatio: Double

    /// The centre of the pin cluster, so the map can open showing the pins rather than whichever
    /// corner of the illustration happens to sit at the scroll origin. Bali's south coast is two
    /// thirds of the way down a portrait drawing; without this the first thing a user sees is
    /// open sea.
    public var pinCentroid: MapPoint {
        guard !pins.isEmpty else { return MapPoint(x: 0.5, y: 0.5) }
        let x = pins.map(\.point.x).reduce(0, +) / Double(pins.count)
        let y = pins.map(\.point.y).reduce(0, +) / Double(pins.count)
        return MapPoint(x: x, y: y)
    }

    /// Pins ordered top to bottom, so the alternating label side is stable rather than following
    /// manifest order — otherwise reordering content silently reshuffles the layout.
    public var labelOrderedPins: [RegionMapPin] {
        pins.sorted { ($0.point.y, $0.point.x) < ($1.point.y, $1.point.x) }
    }

    /// The pin closest to the cluster's centre. The map scrolls to *this marker* rather than to a
    /// zero-sized anchor at the centroid: `ScrollViewReader` positions real, laid-out views
    /// reliably, and a 1×1 `Color.clear` inside a `.position` modifier is neither.
    public var anchorPinID: String? {
        let centre = pinCentroid
        return pins.min {
            hypot($0.point.x - centre.x, $0.point.y - centre.y)
                < hypot($1.point.x - centre.x, $1.point.y - centre.y)
        }?.questID
    }

    /// Nil when content ships no region map. The screen then has nothing to draw, and saying so is
    /// better than presenting an empty frame that looks like a failed download — which, given
    /// `AD-3`, it could never be.
    public init?(
        repository: any ContentRepository,
        language: ContentLanguage,
        suppressedQuestIDs: Set<String> = [],
        suppressedPlaceIDs: Set<String> = []
    ) {
        guard let regionMap = (try? repository.manifest())?.regionMap else { return nil }

        self.language = language
        aspectRatio = regionMap.aspectRatio
        mapImageURL = (try? repository.assetURL(regionMap.asset)) ?? nil

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
                // NFR-A11Y-02: a marker is a control, so it says what it is and where it starts.
                accessibilityLabel: "\(title) — \(placeName)")
        }
    }
}

// MARK: - View

public struct RegionMapView: View {
    @Environment(\.kultaraPalette) private var palette

    private let model: RegionMapViewModel
    private let onSelect: (String) -> Void

    public init(model: RegionMapViewModel, onSelect: @escaping (String) -> Void) {
        self.model = model
        self.onSelect = onSelect
    }

    public var body: some View {
        // The map scrolls in both directions rather than being scaled to fit: fitting a portrait
        // illustration into a portrait screen leaves the pins too close together to hit reliably at
        // 44 pt (`NFR-A11Y-06`).
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    mapImage
                    ForEach(Array(model.labelOrderedPins.enumerated()), id: \.element.id) { index, pin in
                        marker(pin, labelBelow: index.isMultiple(of: 2))
                            .position(
                                x: mapSize.width * pin.point.x,
                                y: mapSize.height * pin.point.y)
                            .id(pin.questID)
                    }
                }
                .frame(width: mapSize.width, height: mapSize.height)
            }
            .onAppear {
                guard let anchorPinID = model.anchorPinID else { return }
                proxy.scrollTo(anchorPinID, anchor: .center)
            }
        }
        .background(palette.paper.color)
        // At the top, not the bottom: the pins sit low on a portrait island, and a floating hint at
        // the bottom edge covered the very markers it was pointing at.
        .overlay(alignment: .top) {
            Text(UIStrings.string(.mapPinHint, model.language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkOnPhoto.color)
                .padding(.horizontal, KultaraMetrics.md)
                .padding(.vertical, KultaraMetrics.sm)
                .background(palette.photoScrim.color, in: Capsule())
                .padding(.top, KultaraMetrics.sm)
                .allowsHitTesting(false)
        }
    }

    /// Drawn far wider than the screen, for two reasons. The illustration keeps its detail, and the
    /// pins keep their distance: quests in one city sit within a few hundred metres of each other,
    /// so at fit-to-screen their markers and labels land on top of one another — the overlap
    /// `NFR-A11Y-01` forbids, arriving through placement rather than through type size.
    private var mapSize: CGSize {
        let width: CGFloat = 1100
        return CGSize(width: width, height: width / max(model.aspectRatio, 0.05))
    }

    @ViewBuilder private var mapImage: some View {
        if let url = model.mapImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .frame(width: mapSize.width, height: mapSize.height)
                .accessibilityHidden(true)
        } else {
            Rectangle()
                .fill(palette.paperSunken.color)
                .frame(width: mapSize.width, height: mapSize.height)
                .overlay(
                    Text(UIStrings.string(.mapUnavailable, model.language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .padding(KultaraMetrics.lg))
        }
    }

    /// `labelBelow` alternates down the cluster, so two adjacent markers put their labels on
    /// opposite sides of the pin instead of into the same strip of map.
    private func marker(_ pin: RegionMapPin, labelBelow: Bool) -> some View {
        Button { onSelect(pin.questID) } label: {
            VStack(spacing: KultaraMetrics.xs) {
                if !labelBelow { label(pin) }
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.sealFill.color)
                    .background(Circle().fill(palette.inkOnSeal.color).padding(3))
                if labelBelow { label(pin) }
            }
            .frame(minWidth: KultaraMetrics.minimumTapTarget, minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pin.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// On the opaque scrim rather than straight on the illustration: parchment under ink drawing is
    /// the one background whose contrast cannot be measured (`NFR-A11Y-03`).
    private func label(_ pin: RegionMapPin) -> some View {
        Text(pin.title)
            .kultaraFont(.chipLabel)
            .foregroundStyle(palette.inkOnPhoto.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 132)
            .padding(.horizontal, KultaraMetrics.sm)
            .padding(.vertical, 3)
            .background(palette.photoScrim.color, in: RoundedRectangle(cornerRadius: KultaraMetrics.xs))
    }
}

/// Loads a bundled image from disk. In one place because the card, the preview and the map all need
/// it, and because `Image(contentsOfFile:)` does not exist.
enum BundledImage {
    static func load(_ url: URL) -> Image? {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}
