import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The place's history, as labelled claims (`FR-SIDE-04`, `s0` D6).
///
/// It is `StoryRevealScreen` with `showsProvenance` on, rather than a second story screen: one
/// screen means the story flow cannot end up with two typographies for the same job. What the flag
/// turns on is the accuracy chip and the citations — the run flow's unlabelled treatment is a
/// product decision taken on 2026-08-13 for *that* surface, and `s0` D6 is explicit that it does
/// not extend here by inference.
///
/// The text comes from the record's snapshot, not from content: a correction must not rewrite what
/// somebody read last month, and a withdrawn place must not blank a letter they earned
/// (`FR-SIDE-10`, `AD-5`).
struct SideQuestStoryView: View {
    let language: ContentLanguage
    let claims: [LoreClaimPresentation]
    let text: String
    let heroImageURL: URL?
    let onFinish: () -> Void
    let onBack: () -> Void

    var body: some View {
        StoryRevealScreen(
            language: language,
            text: text,
            claims: claims,
            showsProvenance: true,
            illustrationURL: heroImageURL,
            onFinish: onFinish,
            onBack: onBack)
    }
}
