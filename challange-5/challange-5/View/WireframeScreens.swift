import ContentKit
import DesignSystem
import SwiftUI

/// The screens the app-flow chart draws that the app does not have yet, as wireframes.
///
/// They exist so the flow can be walked end to end in the running app and reviewed as a flow —
/// every node on the chart is reachable, and the ones that are drawings say so on their face. Each
/// is a handful of lines around `WireframeScreen`; the copy is in `WireframeCatalog`.
///
/// When a screen is built for real, its wireframe here is deleted along with its catalogue entry.

// MARK: - Entry: splash, login, register

/// Splash. Auto-advances, and is tappable so nobody has to wait for it.
struct SplashWireframeView: View {
    @Environment(\.kultaraPalette) private var palette

    let language: ContentLanguage
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: KultaraMetrics.lg) {
            Spacer()
            WireframeBlock(label: WireframeCatalog.splash.blocks[0].value(for: language))
                .frame(maxWidth: 240)
            Text(WireframeCatalog.splash.title.value(for: language))
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkMuted.color)
            Text(WireframeCatalog.stamp.value(for: language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.warning.color)
            Spacer()
            Button(WireframeCatalog.continueAction.value(for: language)) { onFinish() }
                .buttonStyle(.ruled)
        }
        .padding(KultaraMetrics.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.paper.color)
        .task {
            // Short, and skippable by the button above — a splash nobody can get past is a splash
            // that makes every later screen slower to reach.
            try? await Task.sleep(for: .seconds(1.2))
            onFinish()
        }
    }
}

/// Login, with Register one push away. `onSkip` is the honest control here: there is no account
/// backend, so every button on this screen does the same thing, and only one of them says so.
struct AuthWireframeView: View {
    let language: ContentLanguage
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            WireframeScreen(WireframeCatalog.login, language: language) {
                VStack(spacing: KultaraMetrics.md) {
                    NavigationLink {
                        WireframeScreen(WireframeCatalog.register, language: language) {
                            Button(WireframeCatalog.skipAction.value(for: language)) { onSkip() }
                                .buttonStyle(.seal)
                        }
                    } label: {
                        Text(WireframeCatalog.register.title.value(for: language))
                    }
                    .buttonStyle(.ruled)

                    Button(WireframeCatalog.skipAction.value(for: language)) { onSkip() }
                        .buttonStyle(.seal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Journal branch

/// Home → Journal → visited places. The finished walks in it are real; everything around them is a
/// box.
struct JournalWireframeView: View {
    let language: ContentLanguage
    let journal: RunJournalSummary
    let onOpenRun: (UUID) -> Void

    var body: some View {
        WireframeScreen(WireframeCatalog.journal, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                if let active = journal.activeRun {
                    JournalEntryCard(
                        heading: UIStrings.string(.homeActiveRunHeading, language),
                        entry: active,
                        actionTitle: UIStrings.string(.homeActiveRunAction, language),
                        language: language,
                        action: { onOpenRun(active.id) })
                }
                ForEach(journal.completed) { entry in
                    JournalEntryCard(
                        heading: UIStrings.string(.summaryHeading, language),
                        entry: entry,
                        actionTitle: UIStrings.string(.summaryOpenAction, language),
                        language: language,
                        action: { onOpenRun(entry.id) })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } actions: {
            EmptyView()
        }
    }
}

/// Completion screen → Create Journal → Save Journal → Trip Summary.
struct CreateJournalWireframeView: View {
    let language: ContentLanguage

    var body: some View {
        WireframeScreen(WireframeCatalog.createJournal, language: language) {
            NavigationLink {
                TripSummaryWireframeView(language: language)
            } label: {
                Text(WireframeCatalog.tripSummary.title.value(for: language))
            }
            .buttonStyle(.seal)
        }
    }
}

/// Trip Summary, and the share question that follows it.
struct TripSummaryWireframeView: View {
    let language: ContentLanguage

    var body: some View {
        WireframeScreen(WireframeCatalog.tripSummary, language: language) {
            VStack(spacing: KultaraMetrics.md) {
                NavigationLink {
                    WireframeScreen(WireframeCatalog.shareTemplate, language: language) {
                        EmptyView()
                    }
                } label: {
                    Text(WireframeCatalog.shareTemplate.title.value(for: language))
                }
                .buttonStyle(.seal)

                NavigationLink {
                    WireframeScreen(WireframeCatalog.recommendation, language: language) {
                        EmptyView()
                    }
                } label: {
                    Text(WireframeCatalog.recommendation.title.value(for: language))
                }
                .buttonStyle(.ruled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Profile branch

/// Home → Profile → Account settings → App preferences. The last of those four is a screen that
/// exists, so the profile links straight into it rather than drawing a box for it.
struct ProfileWireframeView<Preferences: View>: View {
    let language: ContentLanguage
    let preferences: () -> Preferences

    var body: some View {
        WireframeScreen(WireframeCatalog.profile, language: language) {
            VStack(spacing: KultaraMetrics.md) {
                NavigationLink {
                    AccountSettingsWireframeView(language: language, preferences: preferences)
                } label: {
                    Text(WireframeCatalog.accountSettings.title.value(for: language))
                }
                .buttonStyle(.ruled)

                NavigationLink {
                    preferences()
                } label: {
                    Text(UIStrings.string(.settingsTitle, language))
                }
                .buttonStyle(.seal)

                NavigationLink {
                    NearbyNoticeWireframeView(language: language)
                } label: {
                    Text(WireframeCatalog.nearbyNotice.title.value(for: language))
                }
                .buttonStyle(.ruled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AccountSettingsWireframeView<Preferences: View>: View {
    let language: ContentLanguage
    let preferences: () -> Preferences

    var body: some View {
        WireframeScreen(WireframeCatalog.accountSettings, language: language) {
            NavigationLink {
                preferences()
            } label: {
                Text(UIStrings.string(.settingsTitle, language))
            }
            .buttonStyle(.seal)
        }
    }
}

// MARK: - Passing-by notification branch

/// "User passes the place" → notification → synopsis → want the story?
struct NearbyNoticeWireframeView: View {
    let language: ContentLanguage

    var body: some View {
        WireframeScreen(WireframeCatalog.nearbyNotice, language: language) {
            NavigationLink {
                WireframeScreen(WireframeCatalog.nearbyStory, language: language) {
                    EmptyView()
                }
            } label: {
                Text(WireframeCatalog.yesAction.value(for: language))
            }
            .buttonStyle(.seal)
        }
    }
}
