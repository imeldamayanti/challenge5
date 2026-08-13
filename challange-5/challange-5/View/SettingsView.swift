import ContentKit
import DesignSystem
import SwiftUI

struct SettingsView: View {
    @Environment(\.kultaraPalette) private var palette
    @Environment(\.openURL) private var openURL

    private let model: SettingsViewModel

    init(model: SettingsViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                // Typed at the top of the sheet rather than set in the bar, for the same reason as
                // the quest list: the theme's heading is a line on the page.
                Text(UIStrings.string(.settingsTitle, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                languageSection
                locationSection
                storageSection
                deletionSection
                attributionSection
                reportSection
                #if DEBUG
                developerSection
                #endif
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
        .background(palette.paper.color)
        // Deliberately empty: the sheet's name is the typed heading at the top of the page, and a
        // bar title as well would print it twice. The heading carries the header trait, so nothing
        // is lost to VoiceOver.
        .navigationTitle("")
        .kultaraInlineNavigationTitle()
        .confirmationDialog(
            model.deleteConfirmTitle,
            isPresented: Binding(get: { model.isConfirmingDelete },
                                 set: { if !$0 { model.cancelDelete() } }),
            titleVisibility: .visible
        ) {
            Button(model.deleteConfirmAction, role: .destructive) { model.confirmDelete() }
            Button(model.deleteCancelAction, role: .cancel) { model.cancelDelete() }
        } message: {
            Text(model.deleteConfirmBody)
        }
    }

    private var languageSection: some View {
        SettingsSection(heading: .settingsLanguageHeading, language: language) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ContentLanguage.allCases, id: \.self) { candidate in
                    Button { model.selectLanguage(candidate) } label: {
                        HStack {
                            Text(model.title(for: candidate))
                                .kultaraFont(.body)
                                .foregroundStyle(palette.ink.color)
                            Spacer()
                            // A tick *and* a label change, so selection is not colour-only
                            // (`NFR-A11Y-05`).
                            if candidate == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(palette.seal.color)
                            }
                        }
                        // Vertical padding as well as a minimum height: at accessibility sizes the
                        // label outgrows 44 pt and the rows would sit flush against the divider.
                        .padding(.vertical, KultaraMetrics.sm)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(candidate == language ? [.isSelected] : [])
                    if candidate != ContentLanguage.allCases.last { KultaraRule() }
                }
            }
        }
    }

    private var locationSection: some View {
        SettingsSection(heading: .settingsLocationHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                LabelledValue(label: UIStrings.string(.settingsLocationHeading, language),
                              value: model.locationStatusText)
                Text(model.locationExplanation)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = model.systemSettingsURL {
                    Button { openURL(url) } label: {
                        Text(model.openSystemSettingsTitle)
                            .kultaraFont(.buttonLabel)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }

    private var storageSection: some View {
        SettingsSection(heading: .settingsStorageHeading, language: language) {
            Text(model.storageUsedText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
        }
    }

    private var deletionSection: some View {
        SettingsSection(heading: .settingsDeleteHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(model.deleteScopeNote)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button { model.requestDelete() } label: {
                    Text(model.deleteActionTitle)
                        .kultaraFont(.buttonLabel)
                        .foregroundStyle(palette.seal.color)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                }
                if model.lastDeletionSummary != nil {
                    Text(model.deleteDoneText)
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.ink.color)
                }
            }
        }
    }

    private var attributionSection: some View {
        SettingsSection(heading: .settingsAttributionHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(model.attributionBody)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                KultaraRule()
                ForEach(model.attributionEntries, id: \.self) { entry in
                    Text("· \(entry)")
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(model.contentVersionText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                Text(model.placeholderContentNotice)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.warning.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reportSection: some View {
        SettingsSection(heading: .settingsReportHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(model.reportBody)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = model.reportDestination {
                    Button { openURL(url) } label: {
                        Text(model.reportActionTitle)
                            .kultaraFont(.buttonLabel)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }
}

#if DEBUG
extension SettingsView {
    var developerSection: some View {
        DeveloperToolsSection(language: language)
    }
}
#endif
