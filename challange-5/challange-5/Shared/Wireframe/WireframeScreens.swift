import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The screens the app-flow chart draws that the app does not have yet, as wireframes.
///
/// They exist so the flow can be walked end to end in the running app and reviewed as a flow —
/// every node on the chart is reachable, and the ones that are drawings say so on their face. Each
/// is a handful of lines around `WireframeScreen`; the copy is in `WireframeCatalog`.
///
/// When a screen is built for real, its wireframe here is deleted along with its catalogue entry.

// MARK: - Entry: splash

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
        .kultaraSpeckledGround(palette.paper)
        .task {
            // Short, and skippable by the button above — a splash nobody can get past is a splash
            // that makes every later screen slower to reach.
            try? await Task.sleep(for: .seconds(1.2))
            onFinish()
        }
    }
}

// `AuthWireframeView` is **gone**, deleted with its `login` and `register` catalogue entries in
// the commit that shipped the real screens (this file's own rule at the top). What replaced them:
// `Features/Auth/` — `AuthCredentialScreen` in its two configurations and `GuestNameScreen`, from
// Figma `791:5145`, `791:5109` and `822:2235`, reached exactly where the drawing was.

// MARK: - Journal branch
//
// `CreateJournalWireframeView` is **gone**, deleted with its catalogue entry in the commit that
// shipped `WriteJournalScreen` and `JourneySavedScreen` (`Features/RunSummary/`,
// `WireframeCatalog`'s own rule at the top of this file). What replaced it reads a Run's own saved
// entry back rather than drawing empty boxes for one.

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

// MARK: - Passing-by notification branch
//
// `NearbyNoticeWireframeView` and its story screen are **gone**, deleted with their catalogue
// entries in the commit that shipped the real ones (`s0` D12, `WireframeCatalog`'s own rule).
// What replaced them: `SideQuestNoticeView`, `SideQuestStoryView` and the rest of the flow, reached
// from "Places nearby" in the Quests tab today and from a notification once `s3` lands.
