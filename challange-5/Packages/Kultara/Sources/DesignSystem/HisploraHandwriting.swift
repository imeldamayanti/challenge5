import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The hand that addressed the envelope's back (`791:5657`).
///
/// **The frame's face is not shipped, and this is not a silent substitution.** `791:5657` is set in
/// Homemade Apple, which is neither a system face nor packaged here — and packaging a fifth
/// typeface to write four lines on the back of a card is not a trade worth making. The system's own
/// Bradley Hand is the nearest thing the platform already has: a printed hand rather than a
/// copperplate script, which is what the frame is.
///
/// It resolves through the same `isAvailable` pattern `KultaraFonts` uses, for the same reason —
/// a face that quietly falls back to SF Pro would turn a handwritten address into a form field, and
/// `HisploraHandwritingTests` is what makes that visible if the name ever changes under us.
public enum HisploraHandwriting {

    /// Bradley Hand's PostScript name on iOS.
    public static let faceName = "BradleyHandITCTT-Bold"

    /// Whether the platform actually has it. `false` on macOS, where the pure-logic suites run.
    public static let isAvailable: Bool = {
        #if canImport(UIKit)
        return UIFont(name: faceName, size: 12) != nil
        #else
        return false
        #endif
    }()

    /// The hand at a size, scaling with the reader's text setting (`NFR-A11Y-01`).
    ///
    /// The fallback is the system serif in italic rather than the sans: an address written in SF
    /// Pro is not a fallback, it is a different object.
    public static func font(size: CGFloat, relativeTo style: Font.TextStyle = .footnote) -> Font {
        guard isAvailable else {
            return .system(style, design: .serif).italic()
        }
        return .custom(faceName, size: size, relativeTo: style)
    }
}
