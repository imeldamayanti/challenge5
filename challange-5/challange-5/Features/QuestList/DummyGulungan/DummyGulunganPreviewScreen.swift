import DesignSystem
import SwiftUI

/// DUMMY / TRY-OUT ONLY. Not wired into `QuestRunViewModel` or any real `Stage` — a throwaway
/// screen to see `gulungan.mov` as a full-bleed background with the task content layered directly
/// on it (no second parchment graphic — the video's own scroll is the paper), before deciding
/// whether either goes into the real flow. Chrome (back button, title, progress bar, map hint)
/// mirrors `TaskDetailScreen`'s so the comparison is apples to apples. Reached from a temporary
/// entry point on the Quest list, below "Places near you"; delete this whole folder and its
/// `QuestListView` hook once the review is done.
struct DummyGulunganPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hisploraPalette) private var palette
    @State private var draftAnswer = ""

    private static let margin: CGFloat = 20

    var body: some View {
        ZStack {
            // The base layer, full-bleed under everything else, edge to edge.
            DummyScrollVideoView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                Spacer(minLength: 6)
                progressBar
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 62)
                        content
                    }
                    .padding(.bottom, KultaraMetrics.xl)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, Self.margin)
            .kultaraDismissesKeyboardOnTap()
            .safeAreaInset(edge: .bottom) { mapHint.kultaraStaysBelowKeyboard() }
        }
    }

    private var titleBar: some View {
        HStack {
            HisploraBackButton(accessibilityLabel: "Back", size: 24, action: { dismiss() })
            Spacer(minLength: 0)
            Color.clear.frame(width: 40, height: 40)
        }
        .overlay {
            Text("The Last Traces of Badung")
                .font(.system(size: 19))
                .tracking(-0.38)
                .foregroundStyle(palette.inkOnButton.color)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KultaraMetrics.minimumTapTarget + KultaraMetrics.sm)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 13)
    }

    private var progressBar: some View {
        ProgressView(value: 0.25)
            .progressViewStyle(.linear)
            .tint(palette.inkOnButton.color)
            .padding(.vertical, 20)
    }

    /// No parchment image behind this — the video already draws the paper the walker sees, so the
    /// text sits directly on it rather than on a second, unaligned sheet.
    private var content: some View {
        VStack(spacing: 0) {
            Text("Puri Agung Pemecutan")
                .kultaraFont(.storyPlaceMark)
                .foregroundStyle(palette.brownMid.color)
                .multilineTextAlignment(.center)

            Spacer(minLength: 11)
            HisploraOrnamentDivider()
            Spacer(minLength: 24)

            Text("Find The Iron Statue")
                .kultaraFont(.storyTaskTitle)
                .foregroundStyle(palette.buttonFill.color)
                .multilineTextAlignment(.center)

            Spacer(minLength: 4)
            Text("Near the entrance, a figure stands watch, holding a whip in its hand.")
                .font(.system(size: 15, weight: .light))
                .lineSpacing(15 * 0.4)
                .foregroundStyle(palette.inkBody.color)
                .multilineTextAlignment(.center)

            Spacer(minLength: 32)

            answerField
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .frame(maxWidth: .infinity)
    }

    private var answerField: some View {
        TextField("Tulis jawabanmu di sini", text: $draftAnswer, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(palette.inkBody.color)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(KultaraMetrics.md)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.paperTicket.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(palette.brownMid.color, lineWidth: KultaraMetrics.hairline))
    }

    private var mapHint: some View {
        VStack(spacing: 12) {
            HisploraScrollGlyph(size: 32, tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
            Text("Tap to see the map")
                .font(.system(size: 17))
                .tracking(-0.34)
                .foregroundStyle(palette.inkOnButton.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.margin)
        .padding(.bottom, 30)
    }
}

#Preview {
    DummyGulunganPreviewScreen()
}
