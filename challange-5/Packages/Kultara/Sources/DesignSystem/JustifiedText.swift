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
        let label = TopAlignedLabel()
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
    ///
    /// **A proposal of zero is answered, not refused.** The typewriter lays its sheet out once at
    /// width zero before the machine has been measured, and a `nil` here sends SwiftUI to the
    /// label's intrinsic size — one enormously long line — so the page measured a single line tall.
    /// Everything sized off that height was then wrong for a frame: the sheet fed in from the wrong
    /// place, and the passage was drawn on top of the two figures instead of above them. `UILabel`
    /// answers a zero width the way `Text` does, by breaking at every word, which is a wrong height
    /// that is at least the right *kind* of wrong.
    func sizeThatFits(
        _ proposal: ProposedViewSize, uiView label: UILabel, context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width >= 0 else { return nil }
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

/// A `UILabel` that draws from the top of its bounds rather than the middle.
///
/// `UILabel` centres a multi-line block vertically, so a label whose bounds are ever shorter than
/// its text — which is what happens for the frames of an animated height change — spills the block
/// out of *both* ends. On the story preview that put the typed passage across the two figures ruled
/// beneath it. The sheet no longer animates its height, and this makes sure the failure cannot come
/// back by a different route.
private final class TopAlignedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        let fitted = textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines)
        super.drawText(in: CGRect(x: rect.minX, y: rect.minY,
                                  width: rect.width, height: fitted.height))
    }
}
#endif
