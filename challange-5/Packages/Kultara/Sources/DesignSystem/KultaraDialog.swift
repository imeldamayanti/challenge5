import SwiftUI

/// One choice offered by a `KultaraDialog`.
///
/// `kind` decides both the drawing and the meaning: the destructive action carries a warning glyph
/// and a weight change as well as its own ink, because colour alone cannot be the signal
/// (`NFR-A11Y-05`), and the cancel action is what a swipe-dismiss maps to.
public struct KultaraDialogAction: Identifiable {

    public enum Kind {
        /// The action the dialog is asking for. Drawn as the one filled control.
        case confirm
        /// Loses something the walker cannot get back.
        case destructive
        /// Backing out. Never the destructive one, whatever the dialog is about.
        case cancel
    }

    public let id = UUID()
    public let title: String
    public let kind: Kind
    public let handler: () -> Void

    public init(title: String, kind: Kind, handler: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.handler = handler
    }
}

public extension View {

    /// A confirmation in the theme's own paper, type and controls, in place of `confirmationDialog`.
    ///
    /// A sheet rather than a hand-rolled overlay: dismissal, focus containment and the accessibility
    /// scrim come with it, and those are the parts a `ZStack` version silently drops. The same
    /// argument `KultaraSearchField` makes about the system search bar applies here — the system
    /// dialog brings its own font, fill and button metrics, none of which this theme has measured.
    ///
    /// `isPresented` going false must run the caller's cancel path: swipe-to-dismiss is a cancel,
    /// never a confirm, and the call sites drive `isPresented` from a model flag whose setter does
    /// exactly that.
    func kultaraDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        actions: [KultaraDialogAction]
    ) -> some View {
        modifier(KultaraDialogModifier(
            isPresented: isPresented, title: title, message: message, actions: actions))
    }
}

private struct KultaraDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let actions: [KultaraDialogAction]

    /// Measured from the content rather than fixed, because the abandon dialog's body is two
    /// sentences and at AX5 a hardcoded detent clips them.
    @State private var contentHeight: CGFloat = KultaraDialogMetrics.minimumHeight

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            KultaraThemeProvider {
                KultaraDialogSheet(
                    title: title,
                    message: message,
                    actions: actions,
                    onHeightChange: { contentHeight = $0 })
            }
            .kultaraDialogPresentation(height: contentHeight)
        }
    }
}

enum KultaraDialogMetrics {
    static let minimumHeight: CGFloat = 200
    /// The detent never asks for more than this; past it the sheet scrolls, which is what happens at
    /// the largest accessibility sizes.
    static let maximumHeight: CGFloat = 620
}

private extension View {
    /// Platform-conditional: `presentationDetents` does not exist off iOS, and the package builds
    /// for macOS under `swift test`.
    func kultaraDialogPresentation(height: CGFloat) -> some View {
        #if os(iOS)
        let clamped = min(max(height, KultaraDialogMetrics.minimumHeight),
                          KultaraDialogMetrics.maximumHeight)
        return presentationDetents([.height(clamped)])
            .presentationDragIndicator(.visible)
        #else
        return self
        #endif
    }
}

/// The paper the dialog is printed on: a raised sheet, a rule under the title, the body at reading
/// size, and the actions stacked so a long label at an accessibility size wraps rather than
/// squeezes its neighbour.
struct KultaraDialogSheet: View {
    @Environment(\.kultaraPalette) private var palette

    let title: String
    let message: String
    let actions: [KultaraDialogAction]
    var onHeightChange: (CGFloat) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    Text(title)
                        .kultaraFont(.questTitle)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    KultaraRule()
                }
                Text(message)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: KultaraMetrics.sm) {
                    ForEach(actions) { action in
                        button(for: action)
                    }
                }
            }
            .padding(KultaraMetrics.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: KultaraDialogHeightKey.self,
                                           value: proxy.size.height)
                })
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.paperRaised.color)
        .onPreferenceChange(KultaraDialogHeightKey.self) { height in
            // Plus the sheet's own grabber strip and bottom inset.
            onHeightChange(height + KultaraMetrics.xxl)
        }
        // VoiceOver must not wander into the screen behind the sheet.
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private func button(for action: KultaraDialogAction) -> some View {
        switch action.kind {
        case .confirm:
            Button(action.title, action: action.handler)
                .buttonStyle(.seal)
        case .destructive:
            Button(action: action.handler) {
                HStack(spacing: KultaraMetrics.sm) {
                    // Three signals, not one: the glyph, the heavier label, and the warning ink.
                    // `NFR-A11Y-05` — colour never carries the meaning by itself.
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.small)
                    Text(action.title)
                        .fontWeight(.semibold)
                }
                .kultaraFont(.buttonLabel)
                .foregroundStyle(palette.warning.color)
                .padding(.horizontal, KultaraMetrics.lg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
                .overlay(
                    RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                        .stroke(palette.warning.color, lineWidth: KultaraMetrics.hairline))
            }
            .buttonStyle(.plain)
        case .cancel:
            Button(action: action.handler) {
                Text(action.title)
                    .kultaraFont(.buttonLabel)
                    .foregroundStyle(palette.ink.color)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct KultaraDialogHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
