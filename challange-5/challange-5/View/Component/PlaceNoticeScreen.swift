import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The place notice — `293:1613` ("Quest"), which replaces the earlier `50:137` treatment. One of
/// two stops between the story reveal and the walk itself, and the conditional one: it is reached
/// only at a sacred Place (`checkpoint.isSacred`, the same gate `checkpointScreen`'s inline notice
/// already used). The task menu that always follows it is `CheckpointDetailScreen`.
///
/// **The plaque is drawn, not shipped, and that is a licence decision rather than an omission.**
/// `293:1630` — the ornate cream plate the whole screen is printed on — is a stock
/// wedding-invitation plate. Exported, it carries a dozen real people's and businesses' names
/// engraved across its middle; the frame hides them behind three opaque rectangles rather than
/// removing them. Shipping that file would put those names, and somebody else's licensed
/// engraving, inside every copy of the app. `HisploraPlaquePanel` reproduces the plate's
/// silhouette, its cream and its inset rule in code instead. What is lost is the engraved crown at
/// its head, the corner flourishes, and the small glyph on its lower edge — recorded on that type,
/// and droppable in behind the panel if a licensed ornament is ever commissioned.
///
/// **The portrait is the frame's own.** `320:2487` exports byte for byte as the gilded oval already
/// packaged with the design system, so this screen is `KultaraPortraitFrame` via
/// `HisploraFramedImage` — the same ornament every other story-flow screen frames a picture in.
/// What goes *inside* it stays a parameter: `320:2486` is a generated likeness of a named
/// historical person, which is a claim `FR-CP-05` wants a source and a consent record for, and the
/// content tree ships neither. The frame carries the quest's own hero image instead.
///
/// **What is not written.** `293:1613`'s description and its three rules are the frame's own sample
/// copy about a place the content tree does have — but with different words, and one of the three
/// (the temple-entry rule) has no field behind it at all. `description` renders
/// `Place.loreStandalone` and the rules render the Place's own `dressCode` and `photoPolicy`, so
/// this screen states what the content actually says rather than what the mock-up says.
/// The task menu that follows this screen has the same problem with its own frame's copy, and the
/// same answer; it now lives in `CheckpointDetailScreen.swift`, restyled to `452:3132`.
struct PlaceNoticeScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    let placeName: String
    /// `checkpoint.placeDescription` — `Place.loreStandalone`, already joined and resolved.
    let description: String
    let isSacred: Bool
    let dressCodeText: String
    let photoPolicyText: String
    let portraitURL: URL?
    let onAcknowledge: () -> Void
    let onBack: () -> Void

    /// Set once the description finishes typing. The designer's note — type the passage, then
    /// animate the highlighted points — reads directly onto this screen's own two pieces: the
    /// description, then (only at a sacred Place) the dress-code and photo-policy rules.
    @State private var showsPoints = false

    /// The frame's margins, in its own 402-point terms.
    ///
    /// `margin` is the 20 to the screen's edge the pill and the back arrow both keep. The rest are
    /// read off the exported plate (`293:1630`, alpha-measured — see `HisploraPlaqueMetrics`): its
    /// straight sides stand at x = 24 and x = 381, so the panel is inset `plaqueInset`; the bullets
    /// run x = 66…339, which is `plaqueColumn` inside that; and the description runs x = 90…332, a
    /// further `descriptionIndent` in on the leading edge and `descriptionTrail` on the trailing one.
    /// The mock-up indents its prose past its own list and that reads as deliberate — a lead
    /// paragraph set narrower than the points under it — so it is reproduced rather than tidied away.
    private static let margin: CGFloat = 20
    private static let plaqueInset: CGFloat = 22
    private static let plaqueColumn: CGFloat = 44
    private static let descriptionIndent: CGFloat = 24
    private static let descriptionTrail: CGFloat = 7

    /// Where the gilded oval hangs. `320:2485` draws it 156.856 wide at y = 125, while the plate's
    /// own sheet starts at y = 138 — so the frame **straddles** the plate's head rather than sitting
    /// inside it, and 13 points of gold overlap the cream's top edge. Reproducing that overlap is
    /// most of what separates this screen from the mock-up; centring the oval politely below the edge
    /// reads as a different design.
    private static let portraitWidth: CGFloat = 157
    private static let portraitTopOffset: CGFloat = HisploraPlaqueMetrics.crestHeight - 13

    /// The room the panel reserves above its first line of prose: the oval's 196, plus the 54 of air
    /// `293:1613` leaves under it, less the head lobe the panel already reserves for itself.
    private static let plaqueInteriorTop: CGFloat =
        portraitTopOffset + 196 + 54 - HisploraPlaqueMetrics.crestHeight

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ZStack(alignment: .top) {
                ScrollView {
                    plaque
                        .padding(.horizontal, Self.plaqueInset)
                        // The plate's head lobe tips at y ≈ 105 of 874 — measured, not the
                        // `293:1630` node's own 94, because that PNG carries transparent margin above
                        // the artwork. On a screen whose status bar has already taken 59 that is this
                        // much. Getting it wrong puts cream under the back arrow, where a cream arrow
                        // disappears.
                        .padding(.top, 46)
                        .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom) { acknowledgeButton }
                backBar
            }
        }
    }

    private var backBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                size: 24,
                action: onBack)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 13)
    }

    /// `320:3190` — the one action, a white capsule spanning the frame's 362-point column.
    private var acknowledgeButton: some View {
        Button(UIStrings.string(.runStartSafetyAck, language), action: onAcknowledge)
            .buttonStyle(.hisploraLightPill)
            .padding(.horizontal, Self.margin)
            .padding(.bottom, Self.margin)
    }

    /// The plate, with the gilded oval standing over its head the way `320:2485` draws it — as an
    /// overlay rather than as the panel's first row, because the oval has to hang *past* the cream's
    /// top edge and a row inside the panel cannot.
    private var plaque: some View {
        HisploraPlaquePanel(interiorTop: Self.plaqueInteriorTop) {
            printedMatter
                .padding(.horizontal, Self.plaqueColumn)
                // The plate runs on well past its last line; it does not end on it. 710 − 630, in
                // the frame's terms: its last bullet to the foot of its sheet.
                .padding(.bottom, 80)
        }
        .overlay(alignment: .top) {
            HisploraFramedImage(url: portraitURL, label: placeName)
                .frame(width: Self.portraitWidth)
                .offset(y: Self.portraitTopOffset)
        }
    }

    private var printedMatter: some View {
        VStack(alignment: .leading, spacing: 0) {
            HisploraTypewriterText(
                description,
                font: .system(size: 15),
                ink: \.inkBody,
                onComplete: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        showsPoints = true
                    }
                })
                .padding(.leading, Self.descriptionIndent)
                .padding(.trailing, Self.descriptionTrail)

            if isSacred {
                // The heading belongs to the rules, not to the prose: it arrives with them, once
                // the passage above has finished typing. Shown early it announces a list that is
                // not there yet.
                Text(UIStrings.string(.placeNoticeBeforeExplore, language))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.inkBody.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 454 − 375, less the three lines of prose the frame sets above it.
                    .padding(.top, KultaraMetrics.lg)
                    // `320:3182` sets the heading on the prose's indent, not the list's.
                    .padding(.leading, Self.descriptionIndent)
                    .padding(.trailing, Self.descriptionTrail)
                    .opacity(showsPoints ? 1 : 0)
                    .animation(
                        reduceMotion || voiceOverEnabled ? nil : .easeOut(duration: 0.3),
                        value: showsPoints)
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    // Each rule keeps its label. `293:1613` writes its three as bare sentences,
                    // which works for copy invented for a mock-up; the Place's own `photoPolicy`
                    // resolves to a level ("Allowed", "By permission") that says nothing without
                    // the thing it is a level *of*.
                    rule(UIStrings.string(.previewDressCode, language), dressCodeText, index: 0)
                    rule(UIStrings.string(.previewPhotoPolicy, language), photoPolicyText, index: 1)
                }
                .padding(.top, KultaraMetrics.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One bulleted rule, staggered in behind the ones before it. Under Reduce Motion or VoiceOver
    /// the stagger collapses to nothing — every rule is simply there once `showsPoints` flips,
    /// which for those readers is at the same moment the description itself appears.
    private func rule(_ label: String, _ value: String, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: KultaraMetrics.sm) {
            Text("•")
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .accessibilityHidden(true)
            Text("\(label): \(value)")
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .opacity(showsPoints ? 1 : 0)
        .offset(y: showsPoints ? 0 : 6)
        .animation(
            reduceMotion || voiceOverEnabled ? nil
                : .easeOut(duration: 0.3).delay(Double(index) * 0.15),
            value: showsPoints)
    }
}
