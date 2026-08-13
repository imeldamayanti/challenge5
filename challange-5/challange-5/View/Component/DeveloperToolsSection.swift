import ContentKit
import DesignSystem
import SwiftUI

#if DEBUG
/// Debug builds only.
///
/// `FR-START-08` says a quest must not be startable from outside its start radius *by any path*,
/// and release acceptance criterion 13 tests exactly that. This switch does not weaken it: the
/// whole section, and the provider it drives, are inside `#if DEBUG`, so a release build contains
/// no code that could reach it. What it changes is where the app thinks it is — the radius and
/// accuracy gate in `ArrivalEvaluator` still runs, unmodified, which is the point. A bypass that
/// skipped the gate would test a code path no walker ever takes.
///
/// A view of its own rather than a computed property on `SettingsView`, because the switch needs
/// `@AppStorage` and only a view can hold one. A hand-rolled `Binding` over `UserDefaults` reads
/// correctly and then never redraws — the switch flips under the finger and snaps straight back,
/// which is exactly what it did before this was a view.
struct DeveloperToolsSection: View {
    @Environment(\.kultaraPalette) private var palette
    @AppStorage(DeveloperPreferences.simulateArrivalKey) private var simulatesArrivalAnywhere = false

    let language: ContentLanguage

    var body: some View {
        SettingsSection(heading: .devHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Toggle(isOn: $simulatesArrivalAnywhere) {
                    Text(UIStrings.string(.devSimulateArrivalTitle, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: KultaraMetrics.minimumTapTarget)

                Text(UIStrings.string(.devSimulateArrivalNote, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.warning.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
#endif
