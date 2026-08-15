import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

struct SectionContainer<Content: View>: View {
    let heading: UIStringKey
    let language: ContentLanguage
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(heading, language))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
