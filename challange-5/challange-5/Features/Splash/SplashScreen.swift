import DesignSystem
import SwiftUI

/// The app's opening screen (Figma `207:293`), shown once per launch before onboarding.
///
/// Auto-advances, and the whole screen is tappable so nobody has to wait for it — the wireframe
/// it replaces had the same behaviour; this is the real artwork now that the app has a wordmark.
struct SplashScreen: View {
    let onFinish: () -> Void

    /// The cream-to-tan wash the Figma frame paints top to bottom. The gradient's own end stop
    /// sits at 128.95% down the frame, past the visible bottom edge, so `endPoint` is placed there
    /// rather than at 1.0 — matching the frame exactly rather than a colour eyeballed at the fold.
    private static let backgroundTop = SRGBColor(hex: "FDF2DE")
    private static let backgroundBottom = SRGBColor(hex: "E1C89A")

    /// The mark's box and centre, read off the frame (402×714.667) as fractions of the screen so
    /// the same proportions hold on every device size.
    private static let markWidthFraction = 220.0 / 402.0
    private static let markCenterYFraction = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Self.backgroundTop.color, location: 0),
                        .init(color: Self.backgroundTop.color, location: 0.5),
                        .init(color: Self.backgroundBottom.color, location: 1),
                    ]),
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1.2895))

                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * Self.markWidthFraction)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * Self.markCenterYFraction)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            onFinish()
        }
    }
}
