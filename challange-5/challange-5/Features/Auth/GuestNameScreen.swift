import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The guest screen — `822:2235`, "What should we call you?".
///
/// The one screen of the three that asks for something the app actually keeps. Its own copy says
/// where the answer goes ("This name will appear on your Explorer's Card and journal"), and that is
/// a promise the app keeps locally: `AppPreferencesStore.explorerDisplayName` is read by
/// `ExplorerCardViewModel`, which headed the card by role until this field existed.
///
/// **Left-aligned where the other two are centred**, and that is the frame's own decision rather
/// than drift: `791:5149` and `791:5113` centre a two-word masthead, and this one is a sentence set
/// across the full 314-point column with a paragraph under it.
struct GuestNameScreen: View {
    @Environment(\.hisploraPalette) private var palette

    @Bindable var model: AuthViewModel
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.authBack, language),
                ink: \.buttonFill,
                size: 24,
                action: { model.back() })
                // 94 on the frame, under a 62-point status bar, less the tap target's own padding.
                .padding(.leading, AuthMetrics.margin - KultaraMetrics.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(UIStrings.string(.authGuestTitle, language))
                        .kultaraFont(.authDisplay)
                        .foregroundStyle(palette.brownSeal.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        // 240 − 146 − 82 on the frame, the title being two lines there. A floor,
                        // not a height, so a title that has grown pushes the paragraph down rather
                        // than being written over (`NFR-A11Y-01`).
                        .padding(.top, Self.titleTop)
                        .padding(.bottom, KultaraMetrics.md)

                    Text(UIStrings.string(.authGuestBody, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)

                    AuthField(
                        kind: .name,
                        placeholder: .authGuestNamePlaceholder,
                        field: .name,
                        model: model,
                        language: language,
                        text: $model.guestDisplayName)
                        // 312 − 240 − 40: the air the frame leaves between the paragraph and the
                        // field.
                        .padding(.top, KultaraMetrics.xl)

                    Button(UIStrings.string(.authGuestAction, language)) { model.submitGuest() }
                        .buttonStyle(.hisploraSealPill)
                        // 372 − 312 − 46: the same step the credential screens put between their
                        // last field and their action.
                        .padding(.top, AuthMetrics.actionGap - AuthMetrics.controlGap)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AuthMetrics.margin)
                .padding(.bottom, KultaraMetrics.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .kultaraDismissesKeyboardOnTap()
        }
    }

    /// 146 − 94 on the frame, measured from the back control's box rather than from the status bar,
    /// for the reason `OnboardingView.illustrationTop` gives: the header is what the page actually
    /// starts under.
    private static let titleTop: CGFloat = 30
}
