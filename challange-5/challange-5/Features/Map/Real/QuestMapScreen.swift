import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The discovery map, as `275:2309` and `276:2520` draw it: one map with two grounds, and a
/// `wand.and.sparkles` that swaps between them.
///
/// The frames also draw a `rectangle.stack.fill` above the wand. It is not built, for the same
/// reason `docs/hisplora-tokens.md` already records it as unbuilt: nothing anywhere says what it
/// does, and a control whose behaviour is invented is worse than a control that is missing.
struct QuestMapScreen: View {

    @Environment(\.kultaraPalette) private var palette

    private let model: RegionMapViewModel
    @State private var map: QuestMapViewModel
    @State private var illustration: UIImage?
    private let onSelect: (String) -> Void
    private let onClose: (() -> Void)?

    init(
        model: RegionMapViewModel,
        map: QuestMapViewModel = QuestMapViewModel(),
        onSelect: @escaping (String) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.model = model
        _map = State(initialValue: map)
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            surface
            controls
        }
        .overlay(alignment: .bottom) { offlineNotice }
        .task { await loadIllustration() }
        .kultaraHiddenNavigationBar()
    }

    /// With no basemap there is nothing for the chart to stand on, so the screen hands over to the
    /// surface that never needed one. `RegionMapView` reads the authored `mapPoint`s, ships its own
    /// artwork, and has always worked in airplane mode (`FR-OFF-03`, `AD-3`).
    @ViewBuilder private var surface: some View {
        if map.usesOfflineSurface {
            RegionMapView(model: model, onSelect: onSelect, onClose: onClose)
        } else {
            QuestBaseMapView(
                pins: model.pins,
                georeference: model.georeference,
                illustration: illustration,
                showsIllustration: map.showsIllustrationOverlay,
                palette: palette,
                onSelect: onSelect,
                onBasemapFailure: { map.basemapDidFail() },
                onBasemapRecovery: { map.basemapDidLoad() })
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) { closeButton }
        }
    }

    /// `276:2556`/`276:2557` sit at x 334 in a 402-point frame — 20 points off the trailing edge,
    /// 48 points square. With the stack button unbuilt the wand takes the upper slot rather than
    /// floating below a gap where a control the reader never saw would have been.
    @ViewBuilder private var controls: some View {
        if !map.usesOfflineSurface && model.georeference != nil && illustration != nil {
            Button { map.toggleMode() } label: {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(palette.seal.color)
                    .frame(width: 48, height: 48)
                    .background { glass }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.string(
                map.showsIllustrationOverlay ? .questMapShowReal : .questMapShowIllustrated,
                model.language))
            .padding(.trailing, 20)
            .padding(.top, KultaraMetrics.xxl)
        }
    }

    /// The frames' component is iOS 26's liquid glass. The deployment target is 18.0, so the
    /// button is drawn in the closest thing every supported version has and upgraded where the
    /// real material exists — rather than shipping a hand-painted approximation of a system
    /// material to everyone.
    @ViewBuilder private var glass: some View {
        if #available(iOS 26.0, *) {
            Circle().fill(.clear).glassEffect(in: Circle())
        } else {
            Circle().fill(.regularMaterial)
        }
    }

    @ViewBuilder private var closeButton: some View {
        if let onClose {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkOnSeal.color)
                    .frame(width: KultaraMetrics.minimumTapTarget,
                           height: KultaraMetrics.minimumTapTarget)
                    .background(palette.sealFill.color, in: Circle())
            }
            .accessibilityLabel(UIStrings.string(.questListListTab, model.language))
            .padding(.leading, KultaraMetrics.lg)
            .padding(.top, KultaraMetrics.xxl)
        }
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
