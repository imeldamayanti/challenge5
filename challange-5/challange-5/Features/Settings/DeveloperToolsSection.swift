import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

#if KULTARA_DEV_TOOLS
/// Debug and TestFlight builds only.
///
/// `FR-START-08` says a quest must not be startable from outside its start radius *by any path*,
/// and release acceptance criterion 13 tests exactly that. This switch does not weaken it: the
/// whole section, and the provider it drives, are inside `#if KULTARA_DEV_TOOLS`, and the call site
/// additionally asks `DeveloperToolsAvailability.isEnabled` — `false` in an App Store install — so
/// a published build contains no path a walker could reach. What it changes is where the app thinks
/// it is — the radius and accuracy gate in `ArrivalEvaluator` still runs, unmodified, which is the
/// point. A bypass that skipped the gate would test a code path no walker ever takes.
///
/// The arrival switch is the half a TestFlight tester needs: they are reviewing a walk around
/// Denpasar from wherever they are. The sidequest-proximity and notification buttons below it stay
/// `#if DEBUG`, because they force OS-level behaviour that is only meaningful next to a debugger.
///
/// A view of its own rather than a computed property on `SettingsView`, because the switch needs
/// `@AppStorage` and only a view can hold one. A hand-rolled `Binding` over `UserDefaults` reads
/// correctly and then never redraws — the switch flips under the finger and snaps straight back,
/// which is exactly what it did before this was a view.
struct DeveloperToolsSection: View {
    @Environment(\.kultaraPalette) private var palette
    @AppStorage(DeveloperPreferences.simulateArrivalKey) private var simulatesArrivalAnywhere = false
    @State private var selectedSideQuestID: String?

    let model: SettingsViewModel

    private var language: ContentLanguage { model.language }

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

                #if DEBUG
                KultaraRule()
                simulatePassingSection
                #endif
            }
        }
    }

    #if DEBUG
    /// `s3` §8 — fires the same `didEnterRegion` handler `SystemProximityMonitor` uses for a real
    /// region entry. The position is simulated; `ProximityGate` — quiet hours, the cooldown, the
    /// daily cap — is not.
    private var simulatePassingSection: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text(UIStrings.string(.devSimulatePassingTitle, language))
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)

            let options = model.devSideQuestOptions
            if options.isEmpty {
                Text(UIStrings.string(.sideQuestNearbyEmpty, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
            } else {
                Picker(UIStrings.string(.devSimulatePassingTitle, language), selection: $selectedSideQuestID) {
                    ForEach(options, id: \.id) { option in
                        Text(option.title).tag(Optional(option.id))
                    }
                }
                .pickerStyle(.menu)
                .onAppear { selectedSideQuestID = selectedSideQuestID ?? options.first?.id }

                Button {
                    guard let selectedSideQuestID else { return }
                    model.simulateSideQuestPassing(selectedSideQuestID)
                } label: {
                    Text(UIStrings.string(.devSimulatePassingTitle, language))
                        .kultaraFont(.buttonLabel)
                        .foregroundStyle(palette.seal.color)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                }
                .disabled(selectedSideQuestID == nil)

                // The other half of the same simulation. The button above forces the OS
                // notification (the watch's long look, and "is the pipeline alive"); this one
                // raises the in-app path, which is what a region firing with the app open does and
                // the only way to reach `1108:2780`'s New Discovery card from a desk.
                Button {
                    guard let selectedSideQuestID else { return }
                    model.simulateNearbyWhileOpen(selectedSideQuestID)
                } label: {
                    Text("Simulate passing a place (in-app card)")
                        .kultaraFont(.buttonLabel)
                        .foregroundStyle(palette.seal.color)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                }
                .disabled(selectedSideQuestID == nil)
            }

            Text(UIStrings.string(.devSimulatePassingNote, language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.warning.color)
                .fixedSize(horizontal: false, vertical: true)

            KultaraRule()

            // A pure OS-pipeline diagnostic: fixed content, no sidequest, no ProximityGate, no
            // location authorization. If this doesn't show up either, the cause is outside this
            // app entirely — iOS Settings → Notifications for this app.
            Button {
                model.fireHardcodedTestNotification()
            } label: {
                Text("Kirim notifikasi test (hardcode)")
                    .kultaraFont(.buttonLabel)
                    .foregroundStyle(palette.seal.color)
                    .frame(minHeight: KultaraMetrics.minimumTapTarget)
            }
        }
    }
    #endif
}
#endif
