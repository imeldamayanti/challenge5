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

    /// Both buttons sit at x 334 in a 402-point frame — 20 points off the trailing edge, 48 points
    /// square — with `298:988`'s stack above the wand, and no way back opposite them any more: the
    /// stack *is* the way back now (`298:988` replaced the chevron).
    private static let buttonSize: CGFloat = 48
    private static let trailingInset: CGFloat = 20

    let container: PassthroughView
    private let wand = UIButton(type: .system)
    private let stack = UIButton(type: .system)
    private let wandGlass: UIVisualEffectView
    private let stackGlass: UIVisualEffectView

    private var onToggle: () -> Void = {}
    private var onBack: (() -> Void)?

    init(controls: QuestMapControls) {
        container = PassthroughView()
        container.backgroundColor = .clear

        // The frames' component is iOS 26's liquid glass. The deployment target is 18.0, so the
        // button is drawn in the closest thing every supported version has and upgraded where the
        // real material exists — rather than shipping a hand-painted approximation of one.
        if #available(iOS 26.0, *) {
            wandGlass = UIVisualEffectView(effect: UIGlassEffect())
            stackGlass = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            wandGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            stackGlass = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        for glass in [wandGlass, stackGlass] {
            glass.isUserInteractionEnabled = false
            glass.clipsToBounds = true
            glass.layer.cornerRadius = Self.buttonSize / 2
        }

        wand.setImage(
            UIImage(systemName: "wand.and.sparkles",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)),
            for: .normal)
        wand.addTarget(self, action: #selector(wandTapped), for: .touchUpInside)

        stack.setImage(
            UIImage(systemName: "rectangle.stack.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)),
            for: .normal)
        stack.addTarget(self, action: #selector(stackTapped), for: .touchUpInside)

        for view in [wandGlass, stackGlass, wand, stack] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }

        let guide = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: KultaraMetrics.xxl),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor,
                                            constant: -Self.trailingInset),
            stack.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            stack.heightAnchor.constraint(equalToConstant: Self.buttonSize),

            wand.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: KultaraMetrics.md),
            wand.trailingAnchor.constraint(equalTo: guide.trailingAnchor,
                                           constant: -Self.trailingInset),
            wand.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            wand.heightAnchor.constraint(equalToConstant: Self.buttonSize),

            // Each glass is decoration behind its own button and takes no touches of its own.
            stackGlass.topAnchor.constraint(equalTo: stack.topAnchor),
            stackGlass.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
            stackGlass.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            stackGlass.trailingAnchor.constraint(equalTo: stack.trailingAnchor),

            wandGlass.topAnchor.constraint(equalTo: wand.topAnchor),
            wandGlass.bottomAnchor.constraint(equalTo: wand.bottomAnchor),
            wandGlass.leadingAnchor.constraint(equalTo: wand.leadingAnchor),
            wandGlass.trailingAnchor.constraint(equalTo: wand.trailingAnchor),
        ])
        container.bringSubviewToFront(wand)
        container.bringSubviewToFront(stack)

        update(controls)
    }

    func update(_ controls: QuestMapControls) {
        onToggle = controls.onToggle
        onBack = controls.onBack

        wand.tintColor = UIColor(controls.palette.seal)
        wand.accessibilityLabel = controls.wandLabel
        wand.isHidden = !controls.showsWand
        wandGlass.isHidden = !controls.showsWand

        stack.tintColor = UIColor(controls.palette.seal)
        stack.accessibilityLabel = controls.backLabel
        stack.isHidden = controls.onBack == nil
        stackGlass.isHidden = controls.onBack == nil
    }

    @objc private func wandTapped() { onToggle() }
    @objc private func stackTapped() { onBack?() }
}

/// What the two buttons need, gathered so the representable hands over one value.
struct QuestMapControls {
    let showsWand: Bool
    let palette: KultaraPalette
    let wandLabel: String
    let backLabel: String
    let onToggle: () -> Void
    let onBack: (() -> Void)?
}

private extension UIColor {
    convenience init(_ color: SRGBColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
