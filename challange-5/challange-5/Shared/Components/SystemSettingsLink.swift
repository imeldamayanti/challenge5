import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `FR-START-03` — a path to Settings wherever a refused permission is explained.
struct SystemSettingsLink: View {
    @Environment(\.kultaraPalette) private var palette
    @Environment(\.openURL) private var openURL
    let language: ContentLanguage

    var body: some View {
        if let url = URL(string: "app-settings:") {
            Button(UIStrings.string(.settingsOpenSystemSettings, language)) { openURL(url) }
                .buttonStyle(.ruled)
        }
    }
}
