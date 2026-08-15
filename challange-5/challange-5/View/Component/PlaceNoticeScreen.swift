import ContentKit
import DesignSystem
import SwiftUI

/// The place notice — `50:137` ("Quest") — and the checkpoint's task menu — `51:201` ("Detail
/// Quest"). Two new stops between the story reveal and the walk itself, both reached only when
/// there is something to say: the notice only for a sacred Place (`checkpoint.isSacred`, the same
/// gate `checkpointScreen`'s inline notice already used), the menu always.
///
/// **What is not built.** Both frames carry decoration this run has no asset for: `50:137`'s
/// certificate-shaped background and `51:201`'s postal-stamp badge and its three-tab segmented
/// control (left unlabelled in the frame itself). Rather than invent tab names or draw a shape from
/// nothing, both screens use the same plain-card treatment `StoryTransitionScreen`'s map already
/// sits in — `palette.paperCream` in a rounded rect. The portrait keeps `KultaraPortraitFrame` and
/// `HisploraFramedImage`, the same gilded oval every other story-flow screen frames a picture in.
///
/// **What is not written.** `50:137`'s description and rules are the frame's own sample copy, about
/// a place the content tree does have — but with different words. `placeDescription` renders
/// `Place.loreStandalone` instead: authored, sourced, validated content that has had no screen to
/// appear on since the schema shipped. `51:201`'s three found-object tasks ("The Iron Statue", "The
/// Ancient Script", "The Whip Bearer") do not exist anywhere in the content tree — the shipped
/// checkpoint carries exactly one task, a written reflection — so `CheckpointDetailScreen` lists
/// whatever `tasks` the run actually has, however many that is, titled by `TaskType` rather than by
/// an invented name.
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
    /// description, then (only at a sacred Place) the dress-code and photo-policy points.
    @State private var showsPoints = false

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.top, KultaraMetrics.lg)
                ScrollView {
                    VStack(spacing: KultaraMetrics.lg) {
                        HisploraFramedImage(url: portraitURL, label: placeName)
                            .padding(.horizontal, KultaraMetrics.xxl)
                        card
                    }
                    .padding(.vertical, KultaraMetrics.lg)
                    .padding(.horizontal, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(UIStrings.string(.runStartSafetyAck, language), action: onAcknowledge)
                    .buttonStyle(.hisploraPill)
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.bottom, KultaraMetrics.lg)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
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
                VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                    Text(UIStrings.string(.placeNoticeBeforeExplore, language))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.inkBody.color)
                    point(UIStrings.string(.previewDressCode, language), dressCodeText, index: 0)
                    point(UIStrings.string(.previewPhotoPolicy, language), photoPolicyText, index: 1)
                }
            }
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color, in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
    }

    /// One "highlighted point", staggered in behind the ones before it. Under Reduce Motion or
    /// VoiceOver the stagger collapses to nothing — both points are simply there once `showsPoints`
    /// flips, which for those readers is at the same moment the description itself appears.
    private func point(_ label: String, _ value: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.inkMuted.color)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
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
