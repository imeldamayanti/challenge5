import DesignSystem
import SwiftUI

/// Shown when the content resources are missing — a build error surfaced as a screen rather than a
/// crash, since a crash on launch tells whoever finds it nothing (`NFR-REL-04`).
struct ContentUnavailableScreen: View {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        KultaraThemeProvider {
            VStack(spacing: KultaraMetrics.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(message)
                    .kultaraFont(.body)
                    .multilineTextAlignment(.center)
            }
            .padding(KultaraMetrics.xl)
        }
    }
}
