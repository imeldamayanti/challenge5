import ContentKit
import DesignSystem
import SwiftUI

struct SettingsSection<Content: View>: View {
    @Environment(\.kultaraPalette) private var palette
    let heading: UIStringKey
    let language: ContentLanguage
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(heading, language))
            KultaraCard { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
