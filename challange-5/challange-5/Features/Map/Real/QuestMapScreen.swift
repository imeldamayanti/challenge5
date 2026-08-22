import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The discovery map, as `275:2309` and `276:2520` draw it: one map with two grounds, and a
/// `wand.and.sparkles` that swaps between them. Above the wand sits `298:988`'s liquid-glass
/// `rectangle.stack.fill`, which is now the way back to the list — it replaced the chevron that
/// used to stand there, and a marker tap opens `1026:3514`'s popover rather than navigating.
struct QuestMapScreen: View {

    @Environment(\.kultaraPalette) private var palette
    @Environment(\.hisploraPalette) private var hisplora

    private let model: RegionMapViewModel
    @State private var map: QuestMapViewModel
    @State private var illustration: UIImage?
    private let onSelect: (String) -> Void
    private let onClose: (() -> Void)?

    init(
        model: RegionMapViewModel,
        map: QuestMapViewModel,
        onSelect: @escaping (String) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.model = model
        _map = State(initialValue: map)
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        surface
        .overlay(alignment: .bottom) { offlineNotice }
        .task {
            map.prepareLocation()
            await loadIllustration()
        }
        .kultaraHiddenNavigationBar()
    }

    /// **The map is never unmounted, and that is the fix for a bug rather than a preference.**
    ///
    /// This screen used to swap the whole surface to `RegionMapView` when a tile load failed. That
    /// destroyed the `MKMapView`, so `mapViewDidFinishLoadingMap` could never fire again and the
    /// screen stayed on the fallback for the rest of the session — with the wand gone with it,
    /// because the control was gated on the same flag. One dropped tile and the reader could not get
    /// back to either map.
    ///
    /// Now the failure only forces the chart on. The illustration needs no network, it covers the
    /// viewport by construction, and the projection under it is arithmetic — so `FR-OFF-03` is met
    /// by what is drawn rather than by which screen is mounted, and the moment tiles answer again
    /// the map recovers on its own.
    private var surface: some View {
        QuestBaseMapView(
            pins: model.pins,
            georeference: model.georeference,
            illustration: illustration,
            tiles: model.tiles,
            showsIllustration: map.showsIllustrationOverlay,
            showsUserLocation: map.showsUserLocation,
            palette: palette,
            hisploraPalette: hisplora,
            userLocationLabel: UIStrings.string(.questMapUserLocation, model.language),
            // The chart has to be loaded and placed before the wand can offer to hide it.
            showsWandControl: model.georeference != nil && illustration != nil,
            wandLabel: UIStrings.string(
                map.showsIllustrationOverlay ? .questMapShowReal : .questMapShowIllustrated,
                model.language),
            backLabel: UIStrings.string(.questMapBackToList, model.language),
            language: model.language,
            onToggleMode: { map.toggleMode() },
            onBack: onClose,
            onSelect: onSelect,
            onBasemapFailure: { map.basemapDidFail() },
            onBasemapRecovery: { map.basemapDidLoad() })
            .ignoresSafeArea()
    }

    @ViewBuilder private var offlineNotice: some View {
        if map.showsOfflineNotice {
            Text(UIStrings.string(.questMapOfflineNotice, model.language))
                .kultaraFont(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.inkOnSeal.color)
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.vertical, KultaraMetrics.md)
                .background(palette.sealFill.color, in: Capsule())
                .padding(.horizontal, KultaraMetrics.xl)
                .padding(.bottom, KultaraMetrics.xxl)
                .transition(.opacity)
        }
    }

    /// Decoded off the main actor: the chart is 1469 × 1071 and decoding it inline drops frames on
    /// the first appearance of a screen that is otherwise instant.
    private func loadIllustration() async {
        guard illustration == nil, let url = model.mapImageURL else { return }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        illustration = decoded
    }
}
