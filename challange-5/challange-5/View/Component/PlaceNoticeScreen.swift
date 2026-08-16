import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The place notice — `293:1613` ("Quest"), which replaces the earlier `50:137` treatment — and the
/// checkpoint's task menu — `51:201` ("Detail Quest"). Two stops between the story reveal and the
/// walk itself, both reached only when there is something to say: the notice only for a sacred
/// Place (`checkpoint.isSacred`, the same gate `checkpointScreen`'s inline notice already used),
/// the menu always.
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
/// `51:201`'s three found-object tasks ("The Iron Statue", "The Ancient Script", "The Whip Bearer")
/// do not exist anywhere in the content tree either — the shipped checkpoint carries exactly one
/// task, a written reflection — so `CheckpointDetailScreen` lists whatever `tasks` the run actually
/// has, titled by `TaskType` rather than by an invented name.
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

    /// The frame's margins, in its own 402-point terms: 20 to the screen's edge for the pill and
    /// the back arrow, and a 66-point column inside the plaque for everything printed on it.
    private static let margin: CGFloat = 20
    private static let plaqueColumn: CGFloat = 66

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ZStack(alignment: .top) {
                ScrollView {
                    plaque
                        // The plate's drawn top edge falls at about 130 of 874, which on a screen
                        // whose status bar has already taken 59 is this much. It is not the
                        // `293:1630` node's own 94: that PNG carries transparent margin above the
                        // artwork, and `HisploraPlaqueShape` does not. Getting this wrong puts the
                        // cream under the back arrow, where a cream arrow disappears.
                        .padding(.top, 71)
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

    /// The plate, with the gilded oval standing over its head the way `320:2485` draws it.
    private var plaque: some View {
        HisploraPlaquePanel {
            VStack(spacing: 0) {
                HisploraFramedImage(url: portraitURL, label: placeName)
                    // 156.856 of 402 wide, and 31 below the plate's own top edge.
                    .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
                        width * (156.856 / 402.0)
                    }
                    .padding(.top, 31)
                    // 375 − 321: the gap between the oval's foot and the first line of prose.
                    .padding(.bottom, 54)
                printedMatter
                    .padding(.horizontal, Self.plaqueColumn)
                    // The plate runs on well past its last line; it does not end on it.
                    .padding(.bottom, KultaraMetrics.xxl + KultaraMetrics.xl)
            }
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

/// The checkpoint's task menu — `51:201` ("Detail Quest"). A menu, not the tasks themselves: every
/// row continues into the existing checkpoint screen, where `TaskCard` already carries the answer
/// field, the save, and the skip (`FR-TASK-02`). This screen's own job is narrower — name what is
/// waiting, in the order it is waiting in — so it does not duplicate that machinery.
struct CheckpointDetailScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let tasks: [ContentTask]
    let taskPrompts: [String: String]
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                .overlay {
                    Text(placeName)
                        .font(KultaraTypography.font(.questTitle))
                        .foregroundStyle(palette.inkCream.color)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.top, KultaraMetrics.lg)
                ScrollView {
                    rows
                        .padding(.vertical, KultaraMetrics.lg)
                        .padding(.horizontal, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                HStack {
                    Spacer()
                    HisploraNextButton(
                        accessibilityLabel: UIStrings.string(.checkpointDetailContinue, language),
                        action: onContinue)
                }
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.bottom, KultaraMetrics.lg)
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { offset, task in
                if offset > 0 {
                    Rectangle()
                        .fill(palette.inkDark.color.opacity(0.2))
                        .frame(height: KultaraMetrics.hairline)
                        .accessibilityHidden(true)
                }
                row(task)
            }
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color, in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
    }

    private func row(_ task: ContentTask) -> some View {
        Button(action: onContinue) {
            HStack(spacing: KultaraMetrics.md) {
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    Text(taskTypeLabel(task.type))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.brownDeep.color)
                    Text(taskPrompts[task.id] ?? "")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(palette.inkBody.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .foregroundStyle(palette.brownDeep.color)
            }
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func taskTypeLabel(_ type: TaskType) -> String {
        switch type {
        case .reflection: UIStrings.string(.taskTypeReflection, language)
        case .photo: UIStrings.string(.taskTypePhoto, language)
        case .question: UIStrings.string(.taskTypeQuestion, language)
        }
    }
}
