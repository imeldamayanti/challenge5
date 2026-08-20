import DesignSystem
import UIKit

/// The map's two controls, built in **UIKit** and added as siblings of `MKMapView` inside the
/// representable's own container.
///
/// **This is a hit-testing fix, and it took three attempts, so the reasoning is written down.**
///
/// A `UIViewRepresentable` puts a real `UIView` inside the hosting view. UIKit hit-testing reaches
/// that view before SwiftUI resolves content it draws above it, and a map view carries a great many
/// greedy gesture recognizers. Drawn as a SwiftUI layer over the representable, the wand had an
/// exact and reproducible symptom: *it only worked if you held it.* A press long enough for the
/// map's recognizers to fail let the button through; a tap did not, and two taps in the same place
/// became the map's own double-tap-to-zoom.
///
/// Two intermediate versions did not fix it and are worth naming so they are not tried again:
///
/// - **One full-screen `UIHostingController` above the map.** A SwiftUI hosting view answers
///   `hitTest` with itself across its whole bounds when it has interactive content anywhere, so this
///   is a lid: the map stops panning and pinching entirely.
/// - **Two small hosting controllers, one per button.** The map worked again and a deliberate single
///   tap worked, but repeats still leaked through to the double-tap recognizer. SwiftUI's own
///   gesture machinery is still in the path, and it is not the thing arbitrating with UIKit.
///
/// A `UIButton` has no such ambiguity. It is a real view, it is added after the map, it is hit
/// first, and target-action fires on touch-up-inside with nothing to negotiate. The styling is
/// re-made here rather than hosted — `UIVisualEffectView` for the frames' liquid glass, a filled
/// circle for the way back — which is the price of the fix.
@MainActor
final class QuestMapControlsHost {

    /// Everything that is not one of the two buttons belongs to the map. `super.hitTest` returns
    /// this view only where no subview claimed the point, so that is exactly the miss case.
    final class PassthroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hit = super.hitTest(point, with: event)
            return hit === self ? nil : hit
        }
    }

    /// `276:2556`/`276:2557` sit at x 334 in a 402-point frame — 20 points off the trailing edge,
    /// 48 points square — with the way back opposite them at the standard margin.
    private static let wandSize: CGFloat = 48
    private static let wandTrailingInset: CGFloat = 20

    let container: PassthroughView
    private let wand = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let glass: UIVisualEffectView

    private var onToggle: () -> Void = {}
    private var onClose: (() -> Void)?

    init(controls: QuestMapControls) {
        container = PassthroughView()
        container.backgroundColor = .clear

        // The frames' component is iOS 26's liquid glass. The deployment target is 18.0, so the
        // button is drawn in the closest thing every supported version has and upgraded where the
        // real material exists — rather than shipping a hand-painted approximation of one.
        if #available(iOS 26.0, *) {
            glass = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        glass.isUserInteractionEnabled = false
        glass.clipsToBounds = true
        glass.layer.cornerRadius = Self.wandSize / 2

        wand.setImage(
            UIImage(systemName: "wand.and.sparkles",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)),
            for: .normal)
        wand.addTarget(self, action: #selector(wandTapped), for: .touchUpInside)

        close.setImage(
            UIImage(systemName: "chevron.left",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
            for: .normal)
        close.layer.cornerRadius = KultaraMetrics.minimumTapTarget / 2
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        for view in [glass, wand, close] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }

        let guide = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: guide.topAnchor, constant: KultaraMetrics.xxl),
            close.leadingAnchor.constraint(equalTo: guide.leadingAnchor,
                                           constant: KultaraMetrics.lg),
            close.widthAnchor.constraint(equalToConstant: KultaraMetrics.minimumTapTarget),
            close.heightAnchor.constraint(equalToConstant: KultaraMetrics.minimumTapTarget),

            wand.topAnchor.constraint(equalTo: guide.topAnchor, constant: KultaraMetrics.xxl),
            wand.trailingAnchor.constraint(equalTo: guide.trailingAnchor,
                                           constant: -Self.wandTrailingInset),
            wand.widthAnchor.constraint(equalToConstant: Self.wandSize),
            wand.heightAnchor.constraint(equalToConstant: Self.wandSize),

            // The glass is decoration behind the wand and takes no touches of its own.
            glass.topAnchor.constraint(equalTo: wand.topAnchor),
            glass.bottomAnchor.constraint(equalTo: wand.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: wand.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: wand.trailingAnchor),
        ])
        container.bringSubviewToFront(wand)

        update(controls)
    }

    func update(_ controls: QuestMapControls) {
        onToggle = controls.onToggle
        onClose = controls.onClose

        wand.tintColor = UIColor(controls.palette.seal)
        wand.accessibilityLabel = controls.wandLabel
        wand.isHidden = !controls.showsWand
        glass.isHidden = !controls.showsWand

        close.tintColor = UIColor(controls.palette.inkOnSeal)
        close.backgroundColor = UIColor(controls.palette.sealFill)
        close.accessibilityLabel = controls.closeLabel
        close.isHidden = controls.onClose == nil
    }

    @objc private func wandTapped() { onToggle() }
    @objc private func closeTapped() { onClose?() }
}

/// What the two buttons need, gathered so the representable hands over one value.
struct QuestMapControls {
    let showsWand: Bool
    let palette: KultaraPalette
    let wandLabel: String
    let closeLabel: String
    let onToggle: () -> Void
    let onClose: (() -> Void)?
}

private extension UIColor {
    convenience init(_ color: SRGBColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
