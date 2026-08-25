import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Body copy set flush on **both** edges, with the same progressive reveal `HisploraTypewriterText`
/// draws.
///
/// **Why it is UIKit.** SwiftUI's `Text` has no justified alignment: `TextAlignment` is leading,
/// centre and trailing, and `Text` ignores an `NSParagraphStyle` carried on an `AttributedString`.
/// A justified paragraph therefore has to be laid out by something that understands
/// `NSTextAlignment.justified`, which is `UILabel`. Nothing else about the passage moves — the face,
/// the size, the leading and the ink all still come from the role table and the palette.
///
/// **How the reveal works here, and why it is not `prefix`.** The typing effect elsewhere draws a
/// growing prefix of the string. Justification cannot: a shorter string breaks into different lines,
/// so every added character would re-justify the whole paragraph and the page would shimmer. The
/// whole passage is laid out once, always, and the part not yet typed is painted `.clear`. The
/// layout is then identical at every frame of the reveal and identical to the finished page.
///
/// Not an accessibility element: the wrapper carries the label, whole, for the reason
/// `HisploraTypewriterText` documents.
struct JustifiedRevealText: View {
    let text: String
    let visibleCharacters: Int
    let role: KultaraTypography.Role
    let ink: Color
    let lineSpacing: CGFloat

    var body: some View {
        #if canImport(UIKit)
        JustifiedLabel(
            text: text,
            visibleCharacters: visibleCharacters,
            font: KultaraFonts.uiFont(role),
            ink: UIColor(ink),
            lineSpacing: lineSpacing)
        #else
        // macOS — `swift test` builds this package without UIKit. The passage still renders; it is
        // simply not justified, which is a layout difference on a platform that draws no screens.
        Text(text.prefix(max(0, visibleCharacters)))
            .font(KultaraTypography.font(role))
            .foregroundStyle(ink)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}

#if canImport(UIKit)
private struct JustifiedLabel: UIViewRepresentable {
    let text: String
    let visibleCharacters: Int
    let font: UIFont
    let ink: UIColor
    let lineSpacing: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        // Justification needs word wrapping: `byTruncatingTail` on a multi-line label silently
        // falls back to natural alignment on the last visible line.
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.isAccessibilityElement = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributed()
    }

    /// The proposed width is taken as given and only the height is measured. A `UILabel` asked for
    /// its own width returns the width of its longest *unbroken* run, which for a paragraph is the
    /// whole paragraph on one line — and a justified paragraph one line long is not justified at
    /// all.
    func sizeThatFits(
        _ proposal: ProposedViewSize, uiView label: UILabel, context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        label.attributedText = attributed()
        let fitted = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    private func attributed() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing

        let string = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph,
                .foregroundColor: ink,
            ])

        let shown = min(max(visibleCharacters, 0), text.count)
        guard shown < text.count else { return string }
        let tail = text.index(text.startIndex, offsetBy: shown)
        string.addAttribute(
            .foregroundColor, value: UIColor.clear, range: NSRange(tail..<text.endIndex, in: text))
        return string
    }
}
#endif
